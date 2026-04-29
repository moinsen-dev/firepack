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
      expect(out, contains("if (note != null) 'note': note"));
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
      expect(out, contains("'level': level.name"));
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

    test('emits copyWith with all fields nullable + falling back to this.x', () {
      final spec = FirepackParser().parse('''
firepack: 1
project: t
collections:
  things:
    fields:
      id: { type: string, primaryKey: true }
      title: { type: string, required: true }
      note: { type: string, optional: true }
''');
      final out = generateDartModel(spec.collections['things']!);
      expect(out, contains('Thing copyWith({'));
      expect(out, contains('String? id,'));
      expect(out, contains('String? title,'));
      expect(out, contains('String? note,'));
      expect(out, contains('id: id ?? this.id'));
      expect(out, contains('note: note ?? this.note'));
    });

    test('uses shared enum from spec.enums via enum[Name]', () {
      final spec = FirepackParser().parse('''
firepack: 1
project: t
enums:
  Status:
    values: [draft, published, archived]
collections:
  things:
    fields:
      id: { type: string, primaryKey: true }
      status: { type: "enum[Status]", default: draft }
''');
      final out = generateDartModel(spec.collections['things']!);
      // shared enum is imported, NOT inlined as a per-class enum
      expect(out, contains("import 'enums.dart';"));
      expect(out, isNot(contains('enum ThingStatus')));
      expect(out, contains('final Status status;'));
      expect(out, contains('this.status = Status.draft'));
      expect(out, contains('Status.values.byName'));
    });

    test('generateAllDartModels emits enums.dart when shared enums exist', () {
      final spec = FirepackParser().parse('''
firepack: 1
project: t
enums:
  Status:
    values: [a, b, c]
collections:
  things:
    fields:
      id: { type: string, primaryKey: true }
      status: { type: "enum[Status]" }
''');
      final out = generateAllDartModels(spec);
      expect(out.containsKey('enums.dart'), isTrue);
      expect(out['enums.dart'], contains('enum Status { a, b, c }'));
    });

    test('nested types emit their own files + composition imports', () {
      final spec = FirepackParser().parse('''
firepack: 1
project: t
types:
  ChecklistItem:
    fields:
      id: { type: string, required: true }
      text: { type: string, required: true }
  Task:
    fields:
      id: { type: string, required: true }
      checklist: { type: list, default: [], of: { type: "type[ChecklistItem]" } }
collections:
  things:
    fields:
      id: { type: string, primaryKey: true }
      tasks: { type: list, default: [], of: { type: "type[Task]" } }
''');
      final out = generateAllDartModels(spec);
      expect(out.keys, containsAll(['thing.dart', 'task.dart', 'checklist_item.dart']));
      // outer collection imports inner type, inner type imports leaf
      expect(out['thing.dart'], contains("import 'task.dart';"));
      expect(out['thing.dart'], contains('List<Task> tasks'));
      expect(out['task.dart'], contains("import 'checklist_item.dart';"));
      expect(out['task.dart'], contains('List<ChecklistItem> checklist'));
      // toJson recurses
      expect(out['thing.dart'], contains('tasks.map((e) => e.toJson()).toList()'));
      // fromJson recurses
      expect(out['thing.dart'], contains('Task.fromJson((e as Map).cast<String, dynamic>())'));
    });

    test('emits operator == and hashCode using value equality', () {
      final spec = FirepackParser().parse('''
firepack: 1
project: t
collections:
  things:
    fields:
      id: { type: string, primaryKey: true }
      tags: { type: list, default: [], of: { type: string } }
      meta: { type: map, optional: true }
''');
      final out = generateDartModel(spec.collections['things']!);
      expect(out, contains('bool operator ==(Object other)'));
      expect(out, contains('identical(this, other)'));
      expect(out, contains('id == other.id'));
      expect(out, contains('_listEq(tags, other.tags)'));
      expect(out, contains('_mapEq(meta, other.meta)'));
      expect(out, contains('int get hashCode'));
      expect(out, contains('Object.hash('));
      // helpers should be emitted in the file
      expect(out, contains('bool _listEq('));
      expect(out, contains('bool _mapEq('));
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
