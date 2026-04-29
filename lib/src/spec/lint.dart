import 'spec.dart';

/// One linting issue. `kind` is the rule that fired; `target` lets the
/// CLI render `collection.field`-style paths consistently.
class LintIssue {
  final LintKind kind;
  final String target;
  final String message;
  const LintIssue(this.kind, this.target, this.message);

  @override
  String toString() => '[${kind.name}] $target: $message';
}

enum LintKind {
  orphanRef, // ref points at non-existent collection
  badRefSyntax, // `ref[...]` value didn't parse cleanly
  duplicateIndex, // two indexes with identical field tuples
  missingTenantField, // `tenant: foo` set but no `foo` field
  noPrimaryKey, // collection has no `primaryKey: true` field
  conflictingFlags, // both `required: true` and `optional: true`
  orphanStorageRef, // storageRef[X] points at unknown storage bucket
  storageTenantNotInPath, // bucket.tenant set but `{tenant}` missing in path
  nameCollision, // collection + storage bucket + type share a name
  orphanNestedTypeRef, // type[X] points at unknown nested-type
  orphanEnumRef, // enum[X] points at unknown shared enum
}

/// Runs deterministic structural checks over a parsed [Spec]. Returns
/// an empty list when everything is fine — keeps the CLI happy with a
/// `firepack lint && echo OK` integration in CI.
List<LintIssue> lint(Spec spec) {
  final issues = <LintIssue>[];
  final knownCollections = spec.collections.keys.toSet();
  final knownBuckets = spec.storage.keys.toSet();
  final knownTypes = spec.types.keys.toSet();
  final knownEnums = spec.enums.keys.toSet();

  // Top-level entities (collections, storage buckets, nested types)
  // share a single namespace — Mermaid entities and any future codegen
  // would collide otherwise.
  for (final bucket in knownBuckets) {
    if (knownCollections.contains(bucket)) {
      issues.add(LintIssue(
        LintKind.nameCollision,
        bucket,
        'storage bucket name conflicts with collection of same name',
      ));
    }
    if (knownTypes.contains(bucket)) {
      issues.add(LintIssue(
        LintKind.nameCollision,
        bucket,
        'storage bucket name conflicts with nested type of same name',
      ));
    }
  }
  for (final t in knownTypes) {
    if (knownCollections.contains(t)) {
      issues.add(LintIssue(
        LintKind.nameCollision,
        t,
        'nested type name conflicts with collection of same name',
      ));
    }
  }

  for (final s in spec.storage.values) {
    if (s.tenant != null && !s.path.contains('{${s.tenant}}')) {
      issues.add(LintIssue(
        LintKind.storageTenantNotInPath,
        'storage.${s.name}',
        'tenant: "${s.tenant}" but path does not contain "{${s.tenant}}"',
      ));
    }
  }

  for (final c in spec.collections.values) {
    // Tenant field exists when declared
    if (c.tenant != null && !c.fields.containsKey(c.tenant)) {
      issues.add(LintIssue(
        LintKind.missingTenantField,
        c.name,
        'tenant: "${c.tenant}" but no field "${c.tenant}" defined',
      ));
    }

    // At least one primary key
    final hasPk = c.fields.values.any((f) => f.primaryKey);
    if (!hasPk) {
      issues.add(LintIssue(
        LintKind.noPrimaryKey,
        c.name,
        'no primaryKey: true field — codegen needs one to identify docs',
      ));
    }

    // Field-level checks
    for (final f in c.fields.values) {
      if (f.required && f.optional) {
        issues.add(LintIssue(
          LintKind.conflictingFlags,
          '${c.name}.${f.name}',
          'cannot be both required and optional',
        ));
      }
      if ((f.type == FieldType.ref || f.type == FieldType.list) &&
          f.refTarget != null) {
        final target = f.refTarget!;
        final dot = target.indexOf('.');
        final collection =
            dot >= 0 ? target.substring(0, dot) : target;
        if (!knownCollections.contains(collection)) {
          issues.add(LintIssue(
            LintKind.orphanRef,
            '${c.name}.${f.name}',
            'ref points at unknown collection "$collection"',
          ));
        }
      }
      if (f.storageBucket != null &&
          !knownBuckets.contains(f.storageBucket)) {
        issues.add(LintIssue(
          LintKind.orphanStorageRef,
          '${c.name}.${f.name}',
          'storageRef points at unknown bucket "${f.storageBucket}"',
        ));
      }
      final innerBucket = f.itemSpec?.storageBucket;
      if (innerBucket != null && !knownBuckets.contains(innerBucket)) {
        issues.add(LintIssue(
          LintKind.orphanStorageRef,
          '${c.name}.${f.name}[]',
          'storageRef points at unknown bucket "$innerBucket"',
        ));
      }
      _checkNestedTypeRef(issues, '${c.name}.${f.name}', f, knownTypes);
      _checkEnumRef(issues, '${c.name}.${f.name}', f, knownEnums);
    }

    // Duplicate index detection
    final seen = <String>{};
    for (final i in c.indexes) {
      final sig = i.fields
          .map((f) => '${f.name}:${f.direction.name}')
          .join(',');
      if (!seen.add(sig)) {
        issues.add(LintIssue(
          LintKind.duplicateIndex,
          c.name,
          'duplicate index ($sig)',
        ));
      }
    }
  }

  // Lint nested-type fields too — they can reference other nested
  // types, storage buckets, or collection refs the same way.
  for (final t in spec.types.values) {
    for (final f in t.fields.values) {
      if (f.required && f.optional) {
        issues.add(LintIssue(
          LintKind.conflictingFlags,
          'type ${t.name}.${f.name}',
          'cannot be both required and optional',
        ));
      }
      _checkNestedTypeRef(issues, 'type ${t.name}.${f.name}', f, knownTypes);
      _checkEnumRef(issues, 'type ${t.name}.${f.name}', f, knownEnums);
    }
  }

  return issues;
}

void _checkEnumRef(
  List<LintIssue> issues,
  String target,
  FieldSpec f,
  Set<String> knownEnums,
) {
  if (f.enumRef != null && !knownEnums.contains(f.enumRef)) {
    issues.add(LintIssue(
      LintKind.orphanEnumRef,
      target,
      'enum[...] points at unknown enum "${f.enumRef}"',
    ));
  }
}

void _checkNestedTypeRef(
  List<LintIssue> issues,
  String target,
  FieldSpec f,
  Set<String> knownTypes,
) {
  if (f.nestedTypeRef != null && !knownTypes.contains(f.nestedTypeRef)) {
    issues.add(LintIssue(
      LintKind.orphanNestedTypeRef,
      target,
      'type[...] points at unknown nested type "${f.nestedTypeRef}"',
    ));
  }
  final innerType = f.itemSpec?.nestedTypeRef;
  if (innerType != null && !knownTypes.contains(innerType)) {
    issues.add(LintIssue(
      LintKind.orphanNestedTypeRef,
      '$target[]',
      'type[...] points at unknown nested type "$innerType"',
    ));
  }
}
