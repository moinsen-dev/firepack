import 'package:firepack/firepack.dart';
import 'package:test/test.dart';

void main() {
  group('generateRulesFile', () {
    test('emits the standard rules envelope + helpers', () {
      final spec = FirepackParser().parse('''
firepack: 1
project: t
collections:
  users:
    fields:
      id: { type: string, primaryKey: true }
''');
      final out = generateRulesFile(spec);
      expect(out, startsWith("rules_version = '2';"));
      expect(out, contains('function isSignedIn()'));
      expect(out, contains('function isAdmin()'));
      expect(out, contains('function isSupervisorOrAdmin()'));
      expect(out, contains('function userDoc()'));
      expect(out, contains('match /{document=**}'));
      expect(out, contains('allow read, write: if false;'));
    });

    test('expands signedIn / isAdmin tokens', () {
      final spec = FirepackParser().parse('''
firepack: 1
project: t
collections:
  posts:
    fields:
      id: { type: string, primaryKey: true }
    rules:
      read: "signedIn"
      delete: "isAdmin"
''');
      final out = generateRulesFile(spec);
      expect(out, contains('allow read: if isSignedIn();'));
      expect(out, contains('allow delete: if isAdmin();'));
    });

    test('expands tenantSelf with read vs create context', () {
      final spec = FirepackParser().parse('''
firepack: 1
project: t
collections:
  posts:
    tenant: organizationId
    fields:
      id: { type: string, primaryKey: true }
      organizationId: { type: string, required: true }
    rules:
      read: "signedIn && tenantSelf"
      create: "signedIn && tenantSelf"
''');
      final out = generateRulesFile(spec);
      expect(
          out,
          contains(
              'allow read: if isSignedIn() && resource.data.organizationId == getUserOrgId();'));
      expect(
          out,
          contains(
              'allow create: if isSignedIn() && request.resource.data.organizationId == getUserOrgId();'));
    });

    test('expands update field-allowlist', () {
      final spec = FirepackParser().parse('''
firepack: 1
project: t
collections:
  users:
    fields:
      id: { type: string, primaryKey: true }
    rules:
      update:
        - role: "self"
          fields: "name,fcmTokens"
''');
      final out = generateRulesFile(spec);
      expect(
        out,
        contains(
            "allow update: if request.auth.uid == userId && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['name', 'fcmTokens']);"),
      );
    });

    test('appends verbatim block inside match', () {
      final spec = FirepackParser().parse(r'''
firepack: 1
project: t
collections:
  evidence:
    fields:
      id: { type: string, primaryKey: true }
    rules:
      verbatim: |
        allow delete: if request.auth.uid == resource.data.uploadedBy;
''');
      final out = generateRulesFile(spec);
      expect(
        out,
        contains(
            'allow delete: if request.auth.uid == resource.data.uploadedBy;'),
      );
      // Inside the evidence match block, indented six spaces.
      expect(
        out,
        contains(
            '      allow delete: if request.auth.uid == resource.data.uploadedBy;'),
      );
    });

    test('emits literal "false" for delete: false', () {
      final spec = FirepackParser().parse('''
firepack: 1
project: t
collections:
  auditLogs:
    fields:
      id: { type: string, primaryKey: true }
    rules:
      delete: false
''');
      final out = generateRulesFile(spec);
      expect(out, contains('allow delete: if false;'));
    });
  });
}
