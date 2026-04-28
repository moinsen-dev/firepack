import 'package:firepack/firepack.dart';
import 'package:test/test.dart';

void main() {
  group('generateDartModel', () {
    test('emits a class with const ctor + toJson + fromJson', () {
      final spec = FirepackParser().parse('''
firepack: 1
project: t
collections:
  things:
    fields:
      id: { type: string, primaryKey: true }
      title: { type: string, required: true }
      done: { type: bool, default: false }
''');
      final out = generateDartModel(spec.collections['things']!);
      expect(out, contains('class Thing {'));
      expect(out, contains('final String id;'));
      expect(out, contains('final String title;'));
      expect(out, contains('final bool done;'));
      expect(out, contains('const Thing({'));
      expect(out, contains('required this.id'));
      expect(out, contains('required this.title'));
      expect(out, contains('this.done = false'));
      expect(out, contains('Map<String, dynamic> toJson()'));
      expect(out, contains('factory Thing.fromJson(Map<String, dynamic> json)'));
    });

    test('handles optional fields as nullable + omit-if-null in toJson', () {
      final spec = FirepackParser().parse('''
firepack: 1
project: t
collections:
  things:
    fields:
      id: { type: string, primaryKey: true }
      note: { type: string, optional: true }
''');
      final out = generateDartModel(spec.collections['things']!);
      expect(out, contains('final String? note;'));
      expect(out, contains("if (this.note != null) 'note': this.note"));
      expect(out, contains('note: json[\'note\'] as String?'));
    });

    test('emits enum class + serialises via .name', () {
      final spec = FirepackParser().parse('''
firepack: 1
project: t
collections:
  things:
    fields:
      id: { type: string, primaryKey: true }
      level:
        type: enum
        values: [low, medium, high]
        default: medium
''');
      final out = generateDartModel(spec.collections['things']!);
      expect(out, contains('enum ThingLevel { low, medium, high }'));
      expect(out, contains('final ThingLevel level;'));
      expect(out, contains('this.level = ThingLevel.medium'));
      expect(out, contains("'level': this.level.name"));
      expect(out, contains('ThingLevel.values.byName(json[\'level\'] as String)'));
    });

    test('list[string] becomes List<String> with default', () {
      final spec = FirepackParser().parse('''
firepack: 1
project: t
collections:
  things:
    fields:
      id: { type: string, primaryKey: true }
      tags: { type: list, default: [], of: { type: string } }
''');
      final out = generateDartModel(spec.collections['things']!);
      expect(out, contains('final List<String> tags;'));
      expect(out, contains('this.tags = const []'));
      expect(out,
          contains("tags: json['tags'] == null ? const [] : (json['tags'] as List).cast<String>()"));
    });

    test('dateTime → DateTime with ISO round-trip', () {
      final spec = FirepackParser().parse('''
firepack: 1
project: t
collections:
  things:
    fields:
      id: { type: string, primaryKey: true }
      createdAt: { type: dateTime, required: true }
''');
      final out = generateDartModel(spec.collections['things']!);
      expect(out, contains('final DateTime createdAt;'));
      expect(out, contains('createdAt.toIso8601String()'));
      expect(out, contains("DateTime.parse(json['createdAt'] as String)"));
    });
  });

  group('generateAllDartModels', () {
    test('produces one file per collection with snake_case names', () {
      final spec = FirepackParser().parse('''
firepack: 1
project: t
collections:
  workBriefs:
    fields:
      id: { type: string, primaryKey: true }
  errorReports:
    fields:
      id: { type: string, primaryKey: true }
''');
      final out = generateAllDartModels(spec);
      expect(out.keys, containsAll(['work_brief.dart', 'error_report.dart']));
    });
  });
}
