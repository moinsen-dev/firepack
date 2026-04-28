import 'dart:io';

import 'package:firepack/firepack.dart';
import 'package:test/test.dart';

void main() {
  group('FirepackParser', () {
    test('parses a minimal valid spec', () {
      final spec = FirepackParser().parse('''
firepack: 1
project: demo
collections:
  things:
    fields:
      id: { type: string, primaryKey: true }
      name: { type: string, required: true }
''');
      expect(spec.project, 'demo');
      expect(spec.collections.length, 1);
      expect(spec.collections['things']!.fields['id']!.primaryKey, isTrue);
    });

    test('parses the WorkBrief example end-to-end', () {
      final yaml = File('example/workbrief.firepack.yaml').readAsStringSync();
      final spec = FirepackParser().parse(yaml);
      expect(spec.collections.length, 13);
      expect(lint(spec), isEmpty,
          reason: 'WorkBrief reference spec must lint clean');
    });

    test('rejects unknown spec version', () {
      expect(
        () => FirepackParser().parse('firepack: 99\nproject: x\ncollections: {}'),
        throwsA(isA<FormatException>()),
      );
    });

    test('lint catches orphan refs', () {
      final spec = FirepackParser().parse('''
firepack: 1
project: t
collections:
  a:
    fields:
      id: { type: string, primaryKey: true }
      ghost: { type: "ref[doesNotExist.id]" }
''');
      final issues = lint(spec);
      expect(issues, isNotEmpty);
      expect(issues.first.kind, LintKind.orphanRef);
    });
  });
}
