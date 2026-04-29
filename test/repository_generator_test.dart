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
      final out = generateRepositoryFile(spec.collections['errorReports']!);
      expect(out, contains('class ErrorReportRepository {'));
      expect(
          out, contains('Stream<List<ErrorReport>> watchByOrg(String orgId)'));
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

    test('add() injects FieldValue.serverTimestamp() for serverDefault: now',
        () {
      final spec = FirepackParser().parse('''
firepack: 1
project: t
collections:
  posts:
    fields:
      id:        { type: string, primaryKey: true }
      title:     { type: string, required: true }
      createdAt: { type: dateTime, required: true, serverDefault: now }
    queries:
      watchAll: { byId: true }
''');
      final out = generateRepositoryFile(spec.collections['posts']!);
      expect(out, contains('final data = doc.toFirestore();'));
      expect(
          out, contains("data['createdAt'] = FieldValue.serverTimestamp();"));
      // serverTimestamp injection only on full overwrite (merge: false)
      expect(out, contains('if (!merge)'));
      expect(out, contains('.set(data, SetOptions(merge: merge));'));
    });

    test('add() uses plain .set(doc.toFirestore()) without serverDefault', () {
      final spec = FirepackParser().parse('''
firepack: 1
project: t
collections:
  posts:
    fields:
      id:    { type: string, primaryKey: true }
      title: { type: string, required: true }
    queries:
      watchAll: { byId: true }
''');
      final out = generateRepositoryFile(spec.collections['posts']!);
      expect(
          out, contains('.set(doc.toFirestore(), SetOptions(merge: merge));'));
      expect(out, isNot(contains('FieldValue.serverTimestamp()')));
    });

    test('add() takes a merge parameter (default false)', () {
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
      expect(out, contains('Future<void> add(Post doc, {bool merge = false})'));
    });

    test('repo provider depends on firestoreProvider (not direct instance)',
        () {
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
      expect(out, contains("import '../firestore_provider.dart';"));
      expect(out, contains('ref.watch(firestoreProvider)'));
      expect(
          out, isNot(contains('PostRepository(FirebaseFirestore.instance)')));
    });

    test('repos use fromFirestore (not fromJson) for reads', () {
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
      expect(out, contains('Post.fromFirestore({'));
      expect(out, isNot(contains('Post.fromJson({')));
    });

    test('repos import paths.dart from the new firepack/ location', () {
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
      expect(out, contains("import '../paths.dart';"));
      expect(out,
          isNot(contains("import '../../core/data/firestore_paths.dart';")));
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
      expect(out, contains('Future<void> add(Post doc, {bool merge = false})'));
      expect(
          out,
          contains(
              'Future<void> updateById(String id, Map<String, dynamic> fields)'));
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

    test('emits whereIn const-list for "field in [a, b, c]"', () {
      final spec = FirepackParser().parse('''
firepack: 1
project: t
collections:
  things:
    tenant: orgId
    fields:
      id:    { type: string, primaryKey: true }
      orgId: { type: string, required: true }
      status: { type: string, required: true }
    queries:
      watchActive:
        where: [tenant, "status in [open, in_review, blocked]"]
''');
      final out = generateRepositoryFile(spec.collections['things']!);
      expect(out, contains('Stream<List<Thing>> watchActive(String orgId)'));
      expect(
        out,
        contains(
            ".where('status', whereIn: const ['open', 'in_review', 'blocked'])"),
      );
    });

    test('emits whereIn with List<String> arg for "field in \$param"', () {
      final spec = FirepackParser().parse('''
firepack: 1
project: t
collections:
  things:
    tenant: orgId
    fields:
      id:    { type: string, primaryKey: true }
      orgId: { type: string, required: true }
      status: { type: string, required: true }
    queries:
      watchByStatuses:
        where: [tenant, "status in \$statuses"]
''');
      final out = generateRepositoryFile(spec.collections['things']!);
      expect(
        out,
        contains(
            'Stream<List<Thing>> watchByStatuses(String orgId, List<String> statuses)'),
      );
      expect(out, contains(".where('status', whereIn: statuses)"));
      // Provider should be a record-typed family with List<String> arg.
      expect(
        out,
        contains('({String orgId, List<String> statuses})'),
      );
    });

    test('honours className override in generated class + filename', () {
      final spec = FirepackParser().parse('''
firepack: 1
project: t
collections:
  auditLogs:
    className: AuditLogEntry
    tenant: orgId
    fields:
      id:    { type: string, primaryKey: true }
      orgId: { type: string, required: true }
    queries:
      watchByOrg:
        where: [tenant]
''');
      final files = generateAllRepositories(spec);
      expect(files.keys, contains('audit_log_entry_repository.dart'));
      final body = files['audit_log_entry_repository.dart']!;
      expect(body, contains('class AuditLogEntryRepository'));
      expect(body, contains('Stream<List<AuditLogEntry>> watchByOrg'));
      expect(body, contains('auditLogEntryWatchByOrgProvider'));
    });

    test('skips tenant_query.dart import when no query uses tenant', () {
      final spec = FirepackParser().parse('''
firepack: 1
project: t
collections:
  things:
    tenant: orgId
    fields:
      id:        { type: string, primaryKey: true }
      orgId:     { type: string, required: true }
      parentId:  { type: string, required: true }
    queries:
      watchByParent:
        where: ["parentId == \$parentId"]
''');
      final out = generateRepositoryFile(spec.collections['things']!);
      expect(out, isNot(contains('tenant_query.dart')));
    });
  });
}
