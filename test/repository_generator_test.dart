import 'package:firepack/firepack.dart';
import 'package:test/test.dart';

void main() {
  group('generateRepositoryFile', () {
    test('emits class + Riverpod provider for tenant query', () {
      final spec = FirepackParser().parse('''
firepack: 1
project: t
collections:
  errorReports:
    tenant: organizationId
    fields:
      id: { type: string, primaryKey: true }
      message: { type: string, required: true }
    queries:
      watchByOrg:
        where: [tenant]
        orderBy: createdAt:desc
        limit: 50
''');
      final out =
          generateRepositoryFile(spec.collections['errorReports']!);
      expect(out, contains('class ErrorReportRepository {'));
      expect(out, contains('Stream<List<ErrorReport>> watchByOrg(String orgId)'));
      expect(out, contains('.scopedToOrg(orgId)'));
      expect(out, contains(".orderBy('createdAt', descending: true)"));
      expect(out, contains('.limit(50)'));
      expect(out, contains('errorReportRepositoryProvider'));
      expect(
        out,
        contains('errorReportWatchByOrgProvider'),
      );
      expect(
        out,
        contains('StreamProvider.family<List<ErrorReport>, String>'),
      );
    });

    test('emits watchById for byId queries', () {
      final spec = FirepackParser().parse('''
firepack: 1
project: t
collections:
  posts:
    fields:
      id: { type: string, primaryKey: true }
    queries:
      watchById: { byId: true }
''');
      final out = generateRepositoryFile(spec.collections['posts']!);
      expect(out, contains('Stream<Post?> watchById(String id)'));
      expect(out, contains('postWatchByIdProvider'));
      expect(
        out,
        contains('StreamProvider.family<Post?, String>'),
      );
    });

    test('emits arrayContains for "field contains: \$param"', () {
      final spec = FirepackParser().parse(r'''
firepack: 1
project: t
collections:
  workBriefs:
    tenant: organizationId
    fields:
      id: { type: string, primaryKey: true }
    queries:
      watchByAssignee:
        where: [tenant, "assignedUserIds contains: $uid"]
        orderBy: createdAt:desc
''');
      final out = generateRepositoryFile(spec.collections['workBriefs']!);
      expect(out, contains('watchByAssignee(String orgId, String uid)'));
      expect(
        out,
        contains(".where('assignedUserIds', arrayContains: uid)"),
      );
    });

    test('emits add / updateById / deleteById', () {
      final spec = FirepackParser().parse('''
firepack: 1
project: t
collections:
  posts:
    fields:
      id: { type: string, primaryKey: true }
''');
      final out = generateRepositoryFile(spec.collections['posts']!);
      expect(out, contains('Future<void> add(Post doc)'));
      expect(out, contains('Future<void> updateById(String id, Map<String, dynamic> fields)'));
      expect(out, contains('Future<void> deleteById(String id)'));
    });
  });

  group('generateAllRepositories', () {
    test('skips collections without queries', () {
      final spec = FirepackParser().parse('''
firepack: 1
project: t
collections:
  withQueries:
    fields:
      id: { type: string, primaryKey: true }
    queries:
      watchById: { byId: true }
  withoutQueries:
    fields:
      id: { type: string, primaryKey: true }
''');
      final out = generateAllRepositories(spec);
      expect(out.keys, contains('with_querie_repository.dart'));
      expect(out.keys, isNot(contains('without_querie_repository.dart')));
    });
  });
}
