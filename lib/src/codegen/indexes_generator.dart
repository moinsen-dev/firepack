import '../spec/spec.dart';

/// Generates the Firestore-CLI-compatible `firestore.indexes.json` from a
/// parsed [Spec].
///
/// Output order: collections in spec definition order, indexes in spec
/// list order. No internal sort — predictable diffs trump alphabetical
/// pretty-ness.
///
/// Format style is hand-tuned to match what Firebase CLI emits and what
/// Flutter teams typically check in (each `fieldPath/order` object on
/// one line). The standard `JsonEncoder.withIndent('  ')` blows the
/// field objects open onto multiple lines, which makes every reorder
/// look like 4× the diff. For a tool whose value is "stop hand-editing
/// this file", clean diffs matter.
String generateIndexesJson(Spec spec) {
  final indexes = <_IndexEntry>[];
  for (final collection in spec.collections.values) {
    for (final index in collection.indexes) {
      indexes.add(_IndexEntry(collection.name, index));
    }
  }

  final buf = StringBuffer();
  buf.writeln('{');
  buf.writeln('  "indexes": [');
  for (var i = 0; i < indexes.length; i++) {
    final entry = indexes[i];
    final last = i == indexes.length - 1;
    buf.writeln('    {');
    buf.writeln('      "collectionGroup": "${entry.collection}",');
    buf.writeln('      "queryScope": "COLLECTION",');
    buf.writeln('      "fields": [');
    for (var j = 0; j < entry.index.fields.length; j++) {
      final field = entry.index.fields[j];
      final order =
          field.direction == IndexDirection.desc ? 'DESCENDING' : 'ASCENDING';
      final comma = j == entry.index.fields.length - 1 ? '' : ',';
      buf.writeln(
        '        { "fieldPath": "${field.name}", "order": "$order" }$comma',
      );
    }
    buf.writeln('      ]');
    buf.writeln('    }${last ? '' : ','}');
  }
  buf.writeln('  ],');
  buf.writeln('  "fieldOverrides": []');
  buf.writeln('}');
  return buf.toString();
}

class _IndexEntry {
  final String collection;
  final IndexSpec index;
  const _IndexEntry(this.collection, this.index);
}
