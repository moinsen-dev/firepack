import 'dart:io';

import 'package:firepack/firepack.dart';
import 'package:test/test.dart';

void main() {
  group('generateFirestorePathsFile', () {
    test('emits one static const String per collection', () {
      final spec = FirepackParser().parse('''
firepack: 1
project: blogtest
collections:
  posts:
    fields:
      id: { type: string, primaryKey: true }
  comments:
    fields:
      id: { type: string, primaryKey: true }
''');
      final output = generateFirestorePathsFile(spec);
      expect(output, isNotNull);
      expect(output, contains('class FirestorePaths {'));
      expect(output, contains('FirestorePaths._();'));
      expect(output, contains("static const String posts = 'posts';"));
      expect(output, contains("static const String comments = 'comments';"));
    });

    test('matches the bundled example collections', () {
      final yaml = File('example/firepack.yaml').readAsStringSync();
      final spec = FirepackParser().parse(yaml);
      final output = generateFirestorePathsFile(spec)!;
      for (final name in spec.collections.keys) {
        expect(output, contains("static const String $name = '$name';"),
            reason: 'collection $name must appear in generated paths.dart');
      }
    });

    test('output is deterministic — re-running yields identical bytes', () {
      final yaml = File('example/firepack.yaml').readAsStringSync();
      final spec = FirepackParser().parse(yaml);
      final a = generateFirestorePathsFile(spec);
      final b = generateFirestorePathsFile(spec);
      expect(a, b);
    });
  });
}
