import 'dart:io';

import 'package:firepack/firepack.dart';
import 'package:test/test.dart';

void main() {
  group('generateIndexesJson', () {
    test('emits valid JSON for an empty spec', () {
      final spec = FirepackParser().parse('''
firepack: 1
project: empty
collections:
  things:
    fields:
      id: { type: string, primaryKey: true }
''');
      final output = generateIndexesJson(spec);
      expect(output, contains('"indexes": ['));
      expect(output, contains('"fieldOverrides": []'));
    });

    test('round-trips a single composite index', () {
      final spec = FirepackParser().parse('''
firepack: 1
project: t
collections:
  posts:
    fields:
      id: { type: string, primaryKey: true }
    indexes:
      - fields: [orgId, createdAt:desc]
''');
      final output = generateIndexesJson(spec);
      expect(output, contains('"collectionGroup": "posts"'));
      expect(output, contains('"queryScope": "COLLECTION"'));
      expect(
        output,
        contains('{ "fieldPath": "orgId", "order": "ASCENDING" }'),
      );
      expect(
        output,
        contains('{ "fieldPath": "createdAt", "order": "DESCENDING" }'),
      );
    });

    test('matches the bundled blog fixture', () {
      // Semantic check: every `(collectionGroup, fields[])` tuple in the
      // generated output must be present in the fixture, and vice versa.
      // Frozen snapshot of `example/firepack.yaml` — re-generate the
      // fixture with `firepack regen --target indexes --spec
      // example/firepack.yaml --out test/fixtures/blog.indexes.expected.json`
      // when the example legitimately changes.
      final yaml = File('example/firepack.yaml').readAsStringSync();
      final spec = FirepackParser().parse(yaml);
      final generated = generateIndexesJson(spec);
      final fixture =
          File('test/fixtures/blog.indexes.expected.json').readAsStringSync();

      final genTuples = _extractTuples(generated);
      final fixTuples = _extractTuples(fixture);
      expect(
        genTuples.toSet(),
        fixTuples.toSet(),
        reason: 'Generated and fixture indexes must contain the same '
            'collectionGroup+fields tuples.\n'
            'Only in generated: ${genTuples.toSet().difference(fixTuples.toSet())}\n'
            'Only in fixture:   ${fixTuples.toSet().difference(genTuples.toSet())}',
      );
    });
  });
}

/// Parses a firestore.indexes.json string into a sorted list of
/// "<collection>::<field>:<dir>,<field>:<dir>..." tuples — the
/// content-semantic identity of an index. Skips JSON formatting noise.
List<String> _extractTuples(String json) {
  // Tiny throwaway parser — we control both inputs.
  final tuples = <String>[];
  final indexBlocks = RegExp(
    r'\{\s*"collectionGroup":\s*"(?<col>[^"]+)",\s*"queryScope":\s*"COLLECTION",\s*"fields":\s*\[(?<fields>[^\]]*)\]',
    multiLine: true,
  ).allMatches(json);
  for (final m in indexBlocks) {
    final col = m.namedGroup('col')!;
    final fieldsBlob = m.namedGroup('fields')!;
    final fields = RegExp(
      r'"fieldPath":\s*"(?<name>[^"]+)",\s*"order":\s*"(?<order>ASCENDING|DESCENDING)"',
    )
        .allMatches(fieldsBlob)
        .map((fm) =>
            '${fm.namedGroup('name')}:${fm.namedGroup('order')!.toLowerCase()}')
        .join(',');
    tuples.add('$col::$fields');
  }
  return tuples;
}
