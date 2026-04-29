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
  nameCollision, // collection + storage bucket share a name
}

/// Runs deterministic structural checks over a parsed [Spec]. Returns
/// an empty list when everything is fine — keeps the CLI happy with a
/// `firepack lint && echo OK` integration in CI.
List<LintIssue> lint(Spec spec) {
  final issues = <LintIssue>[];
  final knownCollections = spec.collections.keys.toSet();
  final knownBuckets = spec.storage.keys.toSet();

  // Storage-buckets must not collide with collection names — Mermaid
  // entities share a single namespace, and so does any future codegen.
  for (final bucket in knownBuckets) {
    if (knownCollections.contains(bucket)) {
      issues.add(LintIssue(
        LintKind.nameCollision,
        bucket,
        'storage bucket name conflicts with collection of same name',
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

  return issues;
}
