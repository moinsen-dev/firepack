import 'package:firepack/firepack.dart';
import 'package:test/test.dart';

void main() {
  group('generateStoragePathsFile', () {
    test('returns null when no storage buckets', () {
      final spec = FirepackParser().parse('''
firepack: 1
project: t
collections:
  things:
    fields:
      id: { type: string, primaryKey: true }
''');
      expect(generateStoragePathsFile(spec), isNull);
    });

    test('emits typed helpers for each bucket', () {
      final spec = FirepackParser().parse('''
firepack: 1
project: t
storage:
  evidenceFiles:
    path: "evidence/{organizationId}/{briefId}/{evidenceId}"
    tenant: organizationId
    contentTypes: [image/jpeg, image/png]
collections:
  things:
    fields:
      id: { type: string, primaryKey: true }
''');
      final out = generateStoragePathsFile(spec)!;
      expect(out, contains('class StoragePaths {'));
      expect(out, contains('static String evidenceFiles({'));
      expect(out, contains('required String organizationId,'));
      expect(out, contains('required String briefId,'));
      expect(out, contains('required String evidenceId,'));
      expect(out,
          contains("=> 'evidence/\$organizationId/\$briefId/\$evidenceId';"));
      expect(
          out,
          contains("static const List<String> evidenceFilesContentTypes = "
              "['image/jpeg', 'image/png'];"));
    });

    test('handles bucket with no path variables', () {
      final spec = FirepackParser().parse('''
firepack: 1
project: t
storage:
  static:
    path: "static/banner.png"
collections:
  things:
    fields:
      id: { type: string, primaryKey: true }
''');
      final out = generateStoragePathsFile(spec)!;
      expect(out, contains("static String static() => 'static/banner.png';"));
    });

    test('dedupes duplicate path placeholders', () {
      final spec = FirepackParser().parse('''
firepack: 1
project: t
storage:
  weird:
    path: "x/{orgId}/{orgId}/{fileId}"
collections:
  things:
    fields:
      id: { type: string, primaryKey: true }
''');
      final out = generateStoragePathsFile(spec)!;
      // exactly one `required String orgId,` line
      final orgIdLines = 'required String orgId,'.allMatches(out).length;
      expect(orgIdLines, 1);
    });
  });
}
