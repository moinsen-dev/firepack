import '../spec/spec.dart';

/// Renders a [Spec] as a Mermaid `erDiagram`. Mermaid is the smallest
/// path to a useful visual: every modern Markdown viewer (GitHub,
/// VSCode, JetBrains) renders it natively, so the output of
/// `firepack viz` ships fine even without an HTML host.
///
/// Beyond ER, we annotate tenant-scoped collections with `[T]` and
/// list each field's required/optional status so the diagram captures
/// what would otherwise live in a separate doc.
String renderMermaid(Spec spec) {
  final b = StringBuffer();
  b.writeln('erDiagram');

  for (final c in spec.collections.values) {
    b.writeln('  %% ${c.name}${c.tenant != null ? ' [tenant=${c.tenant}]' : ''}');
    b.writeln('  ${c.name} {');
    for (final f in c.fields.values) {
      final type = _mermaidType(f);
      final flags = <String>[];
      if (f.primaryKey) flags.add('PK');
      if (f.required) flags.add('required');
      if (f.optional) flags.add('optional');
      if (f.immutable) flags.add('immutable');
      if (f.refTarget != null) flags.add('FK');
      if (f.storageBucket != null) flags.add('storage');
      final flagStr = flags.isEmpty ? '' : ' "${flags.join(',')}"';
      b.writeln('    $type ${f.name}$flagStr');
    }
    b.writeln('  }');
  }

  // Storage-buckets — rendered as their own nodes so the cross-system
  // edge from a Firestore field to a Storage path is visible.
  for (final s in spec.storage.values) {
    b.writeln('  %% storage:${s.name}${s.tenant != null ? ' [tenant=${s.tenant}]' : ''}');
    b.writeln('  ${s.name} {');
    b.writeln('    string path "${_escape(s.path)}"');
    if (s.contentTypes.isNotEmpty) {
      b.writeln('    string contentTypes "${_escape(s.contentTypes.join(","))}"');
    }
    b.writeln('  }');
  }

  // Relationships — every ref / list[ref] yields one edge.
  for (final c in spec.collections.values) {
    for (final f in c.fields.values) {
      if (f.refTarget != null) {
        final target = f.refTarget!.split('.').first;
        final cardinality = f.type == FieldType.list ? '}o--||' : '||--||';
        b.writeln(
          '  ${c.name} $cardinality $target : "${f.name}"',
        );
      }
      if (f.storageBucket != null) {
        b.writeln(
          '  ${c.name} }o--|| ${f.storageBucket} : "${f.name}"',
        );
      }
      // list[storageRef[X]] → edge from collection to bucket too.
      final innerBucket = f.itemSpec?.storageBucket;
      if (innerBucket != null) {
        b.writeln(
          '  ${c.name} }o--|| $innerBucket : "${f.name}[]"',
        );
      }
    }
  }
  return b.toString();
}

String _escape(String s) =>
    s.replaceAll('"', "'").replaceAll('\n', ' ');

String _mermaidType(FieldSpec f) {
  switch (f.type) {
    case FieldType.string:
      return 'string';
    case FieldType.int_:
      return 'int';
    case FieldType.double_:
      return 'double';
    case FieldType.bool_:
      return 'bool';
    case FieldType.dateTime:
      return 'datetime';
    case FieldType.enum_:
      return 'enum_${f.enumValues?.length ?? 0}';
    case FieldType.ref:
      return 'ref';
    case FieldType.list:
      return 'list';
    case FieldType.map:
      return 'map';
  }
}
