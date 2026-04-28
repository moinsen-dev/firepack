import '../spec/spec.dart';

/// Computes the structural difference between two parsed [Spec]s and
/// renders it as a Markdown report suitable for a PR comment.
///
/// What we detect today (v0.0.7):
/// - collections added / removed
/// - per existing collection: tenant changed, fields added / removed /
///   changed (type, required/optional/immutable, default), indexes
///   added / removed, queries added / removed, rules string changes
///   per slot (read/create/update/delete/verbatim)
///
/// What we don't detect yet (let the WorkBrief flow surface real pain
/// before we add cleverness):
/// - field rename (would need "rename hints" syntax in the diff or a
///   manual annotation; today a rename shows as `- old, + new`)
/// - reorder of fields/indexes/queries (deliberate — the spec's order
///   is not semantic)
/// - migration scaffolding ("this change requires backfilling field X
///   with default Y") — emit as plain text hint, not actionable yet
class SpecDiff {
  final List<String> addedCollections;
  final List<String> removedCollections;
  final Map<String, CollectionDiff> changedCollections;

  const SpecDiff({
    required this.addedCollections,
    required this.removedCollections,
    required this.changedCollections,
  });

  bool get isEmpty =>
      addedCollections.isEmpty &&
      removedCollections.isEmpty &&
      changedCollections.isEmpty;
}

class CollectionDiff {
  final String name;
  final String? oldTenant;
  final String? newTenant;
  final List<String> addedFields; // "name (type)"
  final List<String> removedFields;
  final List<String> changedFields; // "name: oldType -> newType"
  final List<String> addedIndexes; // "(orgId, createdAt:desc)"
  final List<String> removedIndexes;
  final List<String> addedQueries; // "watchByOrg"
  final List<String> removedQueries;
  final List<String> ruleChanges; // "read: <new>"

  const CollectionDiff({
    required this.name,
    this.oldTenant,
    this.newTenant,
    this.addedFields = const [],
    this.removedFields = const [],
    this.changedFields = const [],
    this.addedIndexes = const [],
    this.removedIndexes = const [],
    this.addedQueries = const [],
    this.removedQueries = const [],
    this.ruleChanges = const [],
  });

  bool get hasChanges =>
      oldTenant != newTenant ||
      addedFields.isNotEmpty ||
      removedFields.isNotEmpty ||
      changedFields.isNotEmpty ||
      addedIndexes.isNotEmpty ||
      removedIndexes.isNotEmpty ||
      addedQueries.isNotEmpty ||
      removedQueries.isNotEmpty ||
      ruleChanges.isNotEmpty;
}

SpecDiff diffSpecs(Spec oldSpec, Spec newSpec) {
  final oldNames = oldSpec.collections.keys.toSet();
  final newNames = newSpec.collections.keys.toSet();

  final added = newNames.difference(oldNames).toList()..sort();
  final removed = oldNames.difference(newNames).toList()..sort();

  final changed = <String, CollectionDiff>{};
  for (final name in newNames.intersection(oldNames)) {
    final oldC = oldSpec.collections[name]!;
    final newC = newSpec.collections[name]!;
    final cd = _diffCollection(oldC, newC);
    if (cd.hasChanges) changed[name] = cd;
  }

  return SpecDiff(
    addedCollections: added,
    removedCollections: removed,
    changedCollections: changed,
  );
}

CollectionDiff _diffCollection(CollectionSpec oldC, CollectionSpec newC) {
  // Fields
  final oldFields = oldC.fields.keys.toSet();
  final newFields = newC.fields.keys.toSet();
  final added = <String>[];
  final removed = <String>[];
  final changed = <String>[];

  for (final f in (newFields.difference(oldFields).toList()..sort())) {
    added.add('${f} (${_fieldShape(newC.fields[f]!)})');
  }
  for (final f in (oldFields.difference(newFields).toList()..sort())) {
    removed.add(f);
  }
  for (final f in newFields.intersection(oldFields).toList()..sort()) {
    final o = oldC.fields[f]!;
    final n = newC.fields[f]!;
    final oShape = _fieldShape(o);
    final nShape = _fieldShape(n);
    if (oShape != nShape) {
      changed.add('$f: $oShape → $nShape');
    }
  }

  // Indexes — represent by a stable signature
  final oldIdx = oldC.indexes.map(_indexSig).toSet();
  final newIdx = newC.indexes.map(_indexSig).toSet();
  final addIdx = (newIdx.difference(oldIdx).toList()..sort());
  final remIdx = (oldIdx.difference(newIdx).toList()..sort());

  // Queries — by name
  final oldQ = oldC.queries.keys.toSet();
  final newQ = newC.queries.keys.toSet();
  final addQ = (newQ.difference(oldQ).toList()..sort());
  final remQ = (oldQ.difference(newQ).toList()..sort());

  // Rules — slot-by-slot string compare. Verbatim diffs render as a
  // bullet "verbatim block changed" — full inline diff would explode
  // the PR comment; reviewer can pull up the file directly.
  final ruleChanges = <String>[];
  if (oldC.rules?.read != newC.rules?.read) {
    ruleChanges.add('read: ${_short(newC.rules?.read)}');
  }
  if (oldC.rules?.create != newC.rules?.create) {
    ruleChanges.add('create: ${_short(newC.rules?.create)}');
  }
  if (oldC.rules?.delete != newC.rules?.delete) {
    ruleChanges.add('delete: ${_short(newC.rules?.delete)}');
  }
  if (_updateClausesText(oldC.rules?.update) !=
      _updateClausesText(newC.rules?.update)) {
    ruleChanges.add('update: clauses changed');
  }
  if ((oldC.rules?.verbatim ?? '').trim() !=
      (newC.rules?.verbatim ?? '').trim()) {
    ruleChanges.add('verbatim block changed');
  }

  return CollectionDiff(
    name: newC.name,
    oldTenant: oldC.tenant,
    newTenant: newC.tenant,
    addedFields: added,
    removedFields: removed,
    changedFields: changed,
    addedIndexes: addIdx,
    removedIndexes: remIdx,
    addedQueries: addQ,
    removedQueries: remQ,
    ruleChanges: ruleChanges,
  );
}

String _fieldShape(FieldSpec f) {
  final flags = <String>[];
  if (f.primaryKey) flags.add('PK');
  if (f.required) flags.add('required');
  if (f.optional) flags.add('optional');
  if (f.immutable) flags.add('immutable');
  if (f.defaultValue != null) flags.add('default=${f.defaultValue}');

  String typeStr;
  switch (f.type) {
    case FieldType.enum_:
      typeStr = 'enum[${f.enumValues?.join(",") ?? ""}]';
    case FieldType.ref:
      typeStr = 'ref[${f.refTarget ?? "?"}]';
    case FieldType.list:
      typeStr = 'list';
    default:
      typeStr = f.type.name.replaceAll('_', '');
  }
  return flags.isEmpty ? typeStr : '$typeStr ${flags.join(",")}';
}

String _indexSig(IndexSpec i) =>
    '(${i.fields.map((f) => "${f.name}:${f.direction.name}").join(", ")})';

String _updateClausesText(List<RuleClause>? clauses) {
  if (clauses == null || clauses.isEmpty) return '';
  return clauses.map((c) => '${c.roleExpr}|${c.fieldsExpr}').join(';;');
}

String _short(String? s) {
  if (s == null) return '(removed)';
  if (s.length <= 60) return s;
  return '${s.substring(0, 57)}…';
}

// ---------------------------------------------------------------------------
// Markdown rendering
// ---------------------------------------------------------------------------

String renderMarkdown(SpecDiff diff) {
  if (diff.isEmpty) {
    return '## firepack spec diff\n\nNo changes detected.\n';
  }

  final buf = StringBuffer();
  buf.writeln('## firepack spec diff');
  buf.writeln();

  if (diff.addedCollections.isNotEmpty ||
      diff.removedCollections.isNotEmpty) {
    buf.writeln('### Collections');
    for (final c in diff.addedCollections) {
      buf.writeln('- ➕ **$c** added');
    }
    for (final c in diff.removedCollections) {
      buf.writeln('- ➖ **$c** removed');
    }
    buf.writeln();
  }

  if (diff.changedCollections.isEmpty) return buf.toString();

  buf.writeln('### Modified');
  for (final cd in diff.changedCollections.values) {
    buf.writeln();
    buf.writeln('#### ~ ${cd.name}');
    if (cd.oldTenant != cd.newTenant) {
      buf.writeln(
        '- 🏷 tenant: `${cd.oldTenant ?? "(none)"}` → `${cd.newTenant ?? "(none)"}`',
      );
    }
    for (final f in cd.addedFields) {
      buf.writeln('- ➕ field `$f`');
    }
    for (final f in cd.removedFields) {
      buf.writeln('- ➖ field `$f`');
    }
    for (final f in cd.changedFields) {
      buf.writeln('- ✏️ field `$f`');
    }
    for (final i in cd.addedIndexes) {
      buf.writeln('- ➕ index `$i`');
    }
    for (final i in cd.removedIndexes) {
      buf.writeln('- ➖ index `$i`');
    }
    for (final q in cd.addedQueries) {
      buf.writeln('- ➕ query `$q`');
    }
    for (final q in cd.removedQueries) {
      buf.writeln('- ➖ query `$q`');
    }
    for (final r in cd.ruleChanges) {
      buf.writeln('- 🛡 rule $r');
    }
  }
  return buf.toString();
}
