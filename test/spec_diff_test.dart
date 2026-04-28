import 'package:firepack/firepack.dart';
import 'package:test/test.dart';

void main() {
  group('diffSpecs', () {
    test('detects added + removed collections', () {
      final oldS = FirepackParser().parse('''
firepack: 1
project: t
collections:
  oldThing:
    fields:
      id: { type: string, primaryKey: true }
''');
      final newS = FirepackParser().parse('''
firepack: 1
project: t
collections:
  newThing:
    fields:
      id: { type: string, primaryKey: true }
''');
      final diff = diffSpecs(oldS, newS);
      expect(diff.addedCollections, ['newThing']);
      expect(diff.removedCollections, ['oldThing']);
    });

    test('detects field add/remove/change', () {
      final oldS = FirepackParser().parse('''
firepack: 1
project: t
collections:
  things:
    fields:
      id: { type: string, primaryKey: true }
      title: { type: string, required: true }
      legacy: { type: int }
''');
      final newS = FirepackParser().parse('''
firepack: 1
project: t
collections:
  things:
    fields:
      id: { type: string, primaryKey: true }
      title: { type: string, optional: true }
      newField: { type: bool, default: false }
''');
      final diff = diffSpecs(oldS, newS);
      final cd = diff.changedCollections['things']!;
      expect(cd.addedFields.first, contains('newField'));
      expect(cd.removedFields, contains('legacy'));
      expect(cd.changedFields.first, contains('title'));
      expect(cd.changedFields.first, contains('→'));
    });

    test('detects index add/remove via stable signature', () {
      final oldS = FirepackParser().parse('''
firepack: 1
project: t
collections:
  things:
    fields:
      id: { type: string, primaryKey: true }
    indexes:
      - fields: [orgId, createdAt:desc]
''');
      final newS = FirepackParser().parse('''
firepack: 1
project: t
collections:
  things:
    fields:
      id: { type: string, primaryKey: true }
    indexes:
      - fields: [orgId, createdAt:desc]
      - fields: [orgId, status, createdAt:desc]
''');
      final diff = diffSpecs(oldS, newS);
      final cd = diff.changedCollections['things']!;
      expect(cd.addedIndexes, hasLength(1));
      expect(cd.addedIndexes.first, contains('status'));
    });

    test('renders markdown with header + sections', () {
      final oldS = FirepackParser().parse('''
firepack: 1
project: t
collections:
  things:
    fields:
      id: { type: string, primaryKey: true }
''');
      final newS = FirepackParser().parse('''
firepack: 1
project: t
collections:
  things:
    fields:
      id: { type: string, primaryKey: true }
      added: { type: string, optional: true }
  brandNew:
    fields:
      id: { type: string, primaryKey: true }
''');
      final md = renderMarkdown(diffSpecs(oldS, newS));
      expect(md, contains('## firepack spec diff'));
      expect(md, contains('### Collections'));
      expect(md, contains('➕ **brandNew**'));
      expect(md, contains('#### ~ things'));
      expect(md, contains('field `added'));
    });

    test('empty when specs are identical', () {
      final yaml = '''
firepack: 1
project: t
collections:
  things:
    fields:
      id: { type: string, primaryKey: true }
''';
      final diff = diffSpecs(
        FirepackParser().parse(yaml),
        FirepackParser().parse(yaml),
      );
      expect(diff.isEmpty, isTrue);
      expect(renderMarkdown(diff), contains('No changes detected'));
    });
  });
}
