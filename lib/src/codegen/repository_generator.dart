import '../spec/spec.dart';

/// Generates a Dart repository file per collection with `queries:`
/// declared. Output shape:
///
/// ```dart
/// // GENERATED — header
/// import 'package:cloud_firestore/cloud_firestore.dart';
/// import 'package:flutter_riverpod/flutter_riverpod.dart';
/// import '../../core/data/firestore_paths.dart';
/// import '../../core/data/tenant_query.dart';
/// import '../models/<col>.dart';
///
/// class <Cls>Repository {
///   final FirebaseFirestore _firestore;
///   <Cls>Repository(this._firestore);
///
///   Stream<List<Cls>> <queryName>(<params>) => …;
///   Stream<Cls?> watchById(String id) => …;     // when byId: true
///   Future<void> add(<Cls> doc) => …;
///   Future<void> updateById(String id, Map<String, dynamic> fields) => …;
///   Future<void> deleteById(String id) => …;
///
///   <Cls> _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) =>
///       <Cls>.fromJson({...d.data(), 'id': d.id});
/// }
///
/// final <cls>RepositoryProvider = Provider(...);
/// final <cls><Query>Provider = StreamProvider.family(...);  // per-query
/// ```
///
/// Query syntax in the spec (today, growth points marked):
///   where: [tenant]                          → .scopedToOrg(orgId)
///   where: ["<field> == <literal>"]          → .where(field, isEqualTo: literal)
///   where: ["<field> == \$<param>"]          → param via method arg
///   where: ["<field> contains: \$<param>"]   → arrayContains
///   orderBy: <field>:asc|desc                → .orderBy(field, descending)
///   limit: <int>                             → .limit(int)
///   byId: true                               → emits watchById(String id)
///
/// Out-of-scope today (let WorkBrief surface the pain first):
/// - join queries / `whereIn` / `whereNotIn`
/// - cursor-based pagination
/// - server-side aggregations (count(), sum()) — Firebase has them in
///   newer SDK; we'll add when WorkBrief asks
String generateRepositoryFile(
  CollectionSpec collection, {
  String? sourceFile,
}) {
  final cls = collection.className ?? _classNameFor(collection.name);
  final repo = '${cls}Repository';
  final modelImport = _modelImportFor(collection);
  final pathToken = collection.name; // matches FirestorePaths.<name>

  final buf = StringBuffer();
  buf.writeln(_header(sourceFile));
  buf.writeln();
  buf.writeln("import 'package:cloud_firestore/cloud_firestore.dart';");
  buf.writeln("import 'package:flutter_riverpod/flutter_riverpod.dart';");
  buf.writeln();
  buf.writeln("import '../../core/data/firestore_paths.dart';");
  if (collection.tenant != null) {
    buf.writeln("import '../../core/data/tenant_query.dart';");
  }
  buf.writeln("import '$modelImport';");
  buf.writeln();

  // Repository class
  buf.writeln('class $repo {');
  buf.writeln('  final FirebaseFirestore _firestore;');
  buf.writeln('  $repo(this._firestore);');
  buf.writeln();

  // Query methods
  for (final q in collection.queries.values) {
    buf.writeln(_emitQueryMethod(q, cls, pathToken, collection));
    buf.writeln();
  }

  // Mutation helpers — same shape every time, deterministic.
  buf.writeln('  /// Sets the doc by primary-key id (overwrites existing).');
  buf.writeln('  Future<void> add($cls doc) {');
  buf.writeln(
      '    return _firestore.collection(FirestorePaths.$pathToken)');
  buf.writeln('        .doc(doc.id)');
  buf.writeln('        .set(doc.toJson());');
  buf.writeln('  }');
  buf.writeln();
  buf.writeln('  /// Patches a subset of fields without round-tripping the model.');
  buf.writeln('  Future<void> updateById(String id, Map<String, dynamic> fields) {');
  buf.writeln(
      '    return _firestore.collection(FirestorePaths.$pathToken)');
  buf.writeln('        .doc(id)');
  buf.writeln('        .update(fields);');
  buf.writeln('  }');
  buf.writeln();
  buf.writeln('  Future<void> deleteById(String id) {');
  buf.writeln(
      '    return _firestore.collection(FirestorePaths.$pathToken)');
  buf.writeln('        .doc(id)');
  buf.writeln('        .delete();');
  buf.writeln('  }');
  buf.writeln();

  // _fromDoc helper — every QueryDocumentSnapshot → model conversion
  // routes through here. Centralises the {...d.data(), 'id': d.id} merge
  // so we don't sprinkle it across every query method.
  buf.writeln(
      '  $cls _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) =>');
  buf.writeln(
      '      $cls.fromJson({...d.data(), \'id\': d.id});');
  buf.writeln('}');

  // Riverpod providers
  buf.writeln();
  final repoVar = _lowerFirst(repo);
  buf.writeln('final ${repoVar}Provider = Provider<$repo>((ref) =>');
  buf.writeln(
      '    $repo(FirebaseFirestore.instance));');

  for (final q in collection.queries.values) {
    buf.writeln();
    buf.writeln(_emitQueryProvider(q, cls, repoVar));
  }

  return buf.toString();
}

// ---------------------------------------------------------------------------
// query method emission
// ---------------------------------------------------------------------------

class _ParsedQuery {
  final List<_WherePart> wheres = [];
  String? orderByField;
  bool orderByDesc = false;
  int? limit;
  bool wantsTenant = false;
  bool byId;

  _ParsedQuery({required this.byId});
}

class _WherePart {
  final String field;
  final String op; // 'isEqualTo' | 'arrayContains' | 'literalEquals'
  final String? param; // when present, becomes a method arg
  final String? literal; // when present, inlined
  _WherePart({required this.field, required this.op, this.param, this.literal});
}

_ParsedQuery _parseQuery(QuerySpec q) {
  final pq = _ParsedQuery(byId: q.byId);

  for (final raw in q.where) {
    final s = raw.trim();
    if (s == 'tenant') {
      pq.wantsTenant = true;
      continue;
    }
    // "field contains: $param"
    final containsMatch =
        RegExp(r'^(\w+)\s+contains:\s*\$(\w+)$').firstMatch(s);
    if (containsMatch != null) {
      pq.wheres.add(_WherePart(
        field: containsMatch.group(1)!,
        op: 'arrayContains',
        param: containsMatch.group(2),
      ));
      continue;
    }
    // "field == $param" or "field == 'literal'" or "field == literal"
    final eqMatch = RegExp(r'^(\w+)\s*==\s*(.+)$').firstMatch(s);
    if (eqMatch != null) {
      final field = eqMatch.group(1)!;
      final rhs = eqMatch.group(2)!.trim();
      if (rhs.startsWith(r'$')) {
        pq.wheres.add(_WherePart(
          field: field,
          op: 'isEqualTo',
          param: rhs.substring(1),
        ));
      } else {
        // literal — strip surrounding quotes if any.
        var lit = rhs;
        if ((lit.startsWith("'") && lit.endsWith("'")) ||
            (lit.startsWith('"') && lit.endsWith('"'))) {
          lit = lit.substring(1, lit.length - 1);
        }
        pq.wheres.add(_WherePart(
          field: field,
          op: 'literalEquals',
          literal: lit,
        ));
      }
      continue;
    }
  }

  if (q.orderBy.isNotEmpty) {
    final ob = q.orderBy.first;
    final parts = ob.split(':');
    pq.orderByField = parts[0];
    pq.orderByDesc = parts.length > 1 && parts[1] == 'desc';
  }
  pq.limit = q.limit;

  return pq;
}

String _emitQueryMethod(
  QuerySpec q,
  String cls,
  String pathToken,
  CollectionSpec collection,
) {
  if (q.byId) {
    return '''  Stream<$cls?> ${q.name}(String id) =>
      _firestore.collection(FirestorePaths.$pathToken)
          .doc(id)
          .snapshots()
          .map((d) => d.exists
              ? $cls.fromJson({...?d.data(), 'id': d.id})
              : null);''';
  }

  final pq = _parseQuery(q);
  final params = <String>[];
  if (pq.wantsTenant) params.add('String orgId');
  for (final w in pq.wheres) {
    if (w.param != null) params.add('String ${w.param}');
  }

  final paramStr = params.join(', ');
  final buf = StringBuffer();
  buf.writeln(
      '  Stream<List<$cls>> ${q.name}($paramStr) =>');
  buf.write('      _firestore.collection(FirestorePaths.$pathToken)');
  if (pq.wantsTenant) {
    buf.writeln();
    buf.write('          .scopedToOrg(orgId)');
  }
  for (final w in pq.wheres) {
    buf.writeln();
    if (w.op == 'isEqualTo' && w.param != null) {
      buf.write('          .where(\'${w.field}\', isEqualTo: ${w.param})');
    } else if (w.op == 'literalEquals') {
      buf.write(
          '          .where(\'${w.field}\', isEqualTo: \'${w.literal}\')');
    } else if (w.op == 'arrayContains' && w.param != null) {
      buf.write('          .where(\'${w.field}\', arrayContains: ${w.param})');
    }
  }
  if (pq.orderByField != null) {
    buf.writeln();
    buf.write(
        '          .orderBy(\'${pq.orderByField}\', descending: ${pq.orderByDesc})');
  }
  if (pq.limit != null) {
    buf.writeln();
    buf.write('          .limit(${pq.limit})');
  }
  buf.writeln();
  buf.writeln('          .snapshots()');
  buf.write('          .map((s) => s.docs.map(_fromDoc).toList());');
  return buf.toString();
}

String _emitQueryProvider(QuerySpec q, String cls, String repoVar) {
  final providerName = '${_lowerFirst(cls)}${_pascal(q.name)}Provider';

  if (q.byId) {
    return 'final $providerName = StreamProvider.family<$cls?, String>(\n'
        '    (ref, id) => ref.watch(${repoVar}Provider).${q.name}(id));';
  }

  final pq = _parseQuery(q);
  final params = <String>[];
  if (pq.wantsTenant) params.add('orgId');
  for (final w in pq.wheres) {
    if (w.param != null) params.add(w.param!);
  }

  if (params.isEmpty) {
    // No params: simple StreamProvider.
    return 'final $providerName = StreamProvider<List<$cls>>(\n'
        '    (ref) => ref.watch(${repoVar}Provider).${q.name}());';
  }

  if (params.length == 1) {
    return 'final $providerName = StreamProvider.family<List<$cls>, String>(\n'
        '    (ref, ${params.first}) => ref.watch(${repoVar}Provider).${q.name}(${params.first}));';
  }

  // Multi-param: emit as a record-typed family.
  // Riverpod 2.x supports this via Dart record types.
  final argsRecord = '({${params.map((p) => 'String $p').join(', ')}})';
  final argDestructure = params.map((p) => 'args.$p').join(', ');
  return 'final $providerName = StreamProvider.family<List<$cls>, $argsRecord>(\n'
      '    (ref, args) => ref.watch(${repoVar}Provider).${q.name}($argDestructure));';
}

// ---------------------------------------------------------------------------
// helpers
// ---------------------------------------------------------------------------

String _header(String? sourceFile) {
  final src = sourceFile ?? 'firepack.yaml';
  return '''// GENERATED by firepack — do not edit.
// Source: $src
//
// Regenerate via:
//   dart run firepack:firepack regen --target repos --spec <path>
//
// Hand-edits here are overwritten on the next `firepack regen`.''';
}

String _classNameFor(String collectionName) {
  final singular = collectionName.endsWith('s')
      ? collectionName.substring(0, collectionName.length - 1)
      : collectionName;
  return singular[0].toUpperCase() + singular.substring(1);
}

String _modelImportFor(CollectionSpec c) {
  // Respect className override: AuditLogEntry → audit_log_entry.dart;
  // otherwise default convention: workBriefs → work_brief.dart.
  if (c.className != null) {
    final snake = c.className!.replaceAllMapped(
      RegExp(r'(?<=.)([A-Z])'),
      (m) => '_${m.group(0)!.toLowerCase()}',
    ).toLowerCase();
    return '../models/$snake.dart';
  }
  final snake = c.name.replaceAllMapped(
    RegExp(r'[A-Z]'),
    (m) => '_${m.group(0)!.toLowerCase()}',
  );
  final singular = snake.endsWith('s') ? snake.substring(0, snake.length - 1) : snake;
  return '../models/$singular.dart';
}

String _lowerFirst(String s) =>
    s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);

String _pascal(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

String _fileNameFor(String collectionName) {
  final snake = collectionName.replaceAllMapped(
    RegExp(r'[A-Z]'),
    (m) => '_${m.group(0)!.toLowerCase()}',
  );
  final singular =
      snake.endsWith('s') ? snake.substring(0, snake.length - 1) : snake;
  return '${singular}_repository.dart';
}

/// Convenience — emits one repository file per collection that has
/// `queries:` declared. Caller writes them to disk.
Map<String, String> generateAllRepositories(
  Spec spec, {
  String? sourceFile,
}) {
  final out = <String, String>{};
  for (final c in spec.collections.values) {
    if (c.queries.isEmpty) continue;
    final fileName = c.className != null
        ? '${_classNameToSnake(c.className!)}_repository.dart'
        : _fileNameFor(c.name);
    out[fileName] = generateRepositoryFile(c, sourceFile: sourceFile);
  }
  return out;
}

String _classNameToSnake(String className) =>
    className.replaceAllMapped(
      RegExp(r'(?<=.)([A-Z])'),
      (m) => '_${m.group(0)!.toLowerCase()}',
    ).toLowerCase();
