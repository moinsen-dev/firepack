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

    test('parses the bundled blog example end-to-end', () {
      final yaml = File('example/blog.firepack.yaml').readAsStringSync();
      final spec = FirepackParser().parse(yaml);
      expect(spec.collections.length, 4);
      expect(spec.storage.length, 2);
      expect(lint(spec), isEmpty,
          reason: 'bundled example must lint clean');
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

    test('parses storage block + storageRef field type', () {
      final spec = FirepackParser().parse('''
firepack: 1
project: t
storage:
  evidenceFiles:
    path: "evidence/{orgId}/{briefId}/{fileId}"
    tenant: orgId
    contentTypes: [image/jpeg, image/png, application/pdf]
collections:
  evidence:
    fields:
      id:           { type: string, primaryKey: true }
      storagePath:  { type: "storageRef[evidenceFiles]", required: true }
      orgId:        { type: string, required: true }
''');
      expect(spec.storage.length, 1);
      final bucket = spec.storage['evidenceFiles']!;
      expect(bucket.path, 'evidence/{orgId}/{briefId}/{fileId}');
      expect(bucket.tenant, 'orgId');
      expect(bucket.contentTypes, ['image/jpeg', 'image/png', 'application/pdf']);

      final f = spec.collections['evidence']!.fields['storagePath']!;
      expect(f.type, FieldType.string);
      expect(f.storageBucket, 'evidenceFiles');
      expect(lint(spec), isEmpty);
    });

    test('lint catches orphan storageRef', () {
      final spec = FirepackParser().parse('''
firepack: 1
project: t
collections:
  a:
    fields:
      id:   { type: string, primaryKey: true }
      file: { type: "storageRef[ghostBucket]" }
''');
      final issues = lint(spec);
      expect(issues.any((i) => i.kind == LintKind.orphanStorageRef), isTrue);
    });

    test('lint catches storage tenant not in path', () {
      final spec = FirepackParser().parse('''
firepack: 1
project: t
storage:
  bad:
    path: "static/{fileId}"
    tenant: orgId
collections:
  c:
    fields:
      id: { type: string, primaryKey: true }
''');
      final issues = lint(spec);
      expect(
        issues.any((i) => i.kind == LintKind.storageTenantNotInPath),
        isTrue,
      );
    });

    test('lint catches name collision between collection + bucket', () {
      final spec = FirepackParser().parse('''
firepack: 1
project: t
storage:
  evidence:
    path: "evidence/{id}"
collections:
  evidence:
    fields:
      id: { type: string, primaryKey: true }
''');
      final issues = lint(spec);
      expect(issues.any((i) => i.kind == LintKind.nameCollision), isTrue);
    });

    test('mermaid renders storage buckets as nodes + edges', () {
      final spec = FirepackParser().parse('''
firepack: 1
project: t
storage:
  evidenceFiles:
    path: "evidence/{orgId}/{fileId}"
collections:
  evidence:
    fields:
      id:          { type: string, primaryKey: true }
      storagePath: { type: "storageRef[evidenceFiles]", required: true }
''');
      final mermaid = renderMermaid(spec);
      expect(mermaid, contains('evidenceFiles {'));
      expect(mermaid, contains('string path "evidence/{orgId}/{fileId}"'));
      expect(mermaid, contains('evidence }o--|| evidenceFiles : "storagePath"'));
      expect(mermaid, contains('storage'));  // FK-like flag in field line
    });
  });
}
