import 'package:yaml/yaml.dart';

import 'spec.dart';

/// Parses a `firepack.yaml` source string into the in-memory [Spec]
/// model. Throws [FormatException] with a precise human-readable
/// message on the first structural problem — we'd rather fail loud at
/// `firepack lint` than emit confused codegen.
class FirepackParser {
  Spec parse(String yamlSource, {String? sourceName}) {
    final raw = loadYaml(yamlSource);
    if (raw is! YamlMap) {
      throw FormatException(
        'firepack: expected YAML mapping at top level (file: ${sourceName ?? '<inline>'})',
      );
    }

    final version = _intRequired(raw, 'firepack', context: 'top-level');
    if (version != 1) {
      throw FormatException(
        'firepack: unsupported spec version $version (only v1 today)',
      );
    }

    final project = _stringRequired(raw, 'project', context: 'top-level');

    final collectionsNode = raw['collections'];
    if (collectionsNode is! YamlMap) {
      throw FormatException(
        'firepack: top-level "collections:" must be a mapping',
      );
    }

    final collections = <String, CollectionSpec>{};
    for (final entry in collectionsNode.entries) {
      final name = entry.key.toString();
      collections[name] = _parseCollection(name, entry.value);
    }

    final storage = <String, StorageBucket>{};
    final storageNode = raw['storage'];
    if (storageNode is YamlMap) {
      for (final entry in storageNode.entries) {
        final bucketName = entry.key.toString();
        storage[bucketName] = _parseStorageBucket(bucketName, entry.value);
      }
    }

    final types = <String, NestedTypeSpec>{};
    final typesNode = raw['types'];
    if (typesNode is YamlMap) {
      for (final entry in typesNode.entries) {
        final typeName = entry.key.toString();
        types[typeName] = _parseNestedType(typeName, entry.value);
      }
    }

    final enums = <String, EnumSpec>{};
    final enumsNode = raw['enums'];
    if (enumsNode is YamlMap) {
      for (final entry in enumsNode.entries) {
        final enumName = entry.key.toString();
        enums[enumName] = _parseEnumSpec(enumName, entry.value);
      }
    }

    return Spec(
      version: version,
      project: project,
      collections: collections,
      storage: storage,
      types: types,
      enums: enums,
    );
  }

  EnumSpec _parseEnumSpec(String name, dynamic node) {
    if (node is! YamlMap) {
      throw FormatException(
        'firepack: enum "$name" must be a mapping with values:',
      );
    }
    final v = node['values'];
    if (v is! YamlList || v.isEmpty) {
      throw FormatException(
        'firepack: enum "$name" needs non-empty values:',
      );
    }
    final wf = node['wireFormat']?.toString();
    final wireFormat = switch (wf) {
      null => EnumWireFormat.dartName,
      'dartName' => EnumWireFormat.dartName,
      'snake_case' => EnumWireFormat.snakeCase,
      _ => throw FormatException(
          'firepack: enum "$name" has unsupported wireFormat "$wf" '
          '(must be "dartName" or "snake_case")',
        ),
    };
    return EnumSpec(
      name: name,
      values: v.map((e) => e.toString()).toList(growable: false),
      wireFormat: wireFormat,
    );
  }

  NestedTypeSpec _parseNestedType(String name, dynamic node) {
    if (node is! YamlMap) {
      throw FormatException(
        'firepack: type "$name" must be a mapping',
      );
    }
    final fieldsNode = node['fields'];
    if (fieldsNode is! YamlMap) {
      throw FormatException(
        'firepack: type "$name" must define "fields:"',
      );
    }
    final fields = <String, FieldSpec>{};
    for (final entry in fieldsNode.entries) {
      final fName = entry.key.toString();
      fields[fName] = _parseField(fName, entry.value, owner: 'type $name');
    }
    return NestedTypeSpec(name: name, fields: fields);
  }

  StorageBucket _parseStorageBucket(String name, dynamic node) {
    if (node is! YamlMap) {
      throw FormatException(
        'firepack: storage bucket "$name" must be a mapping',
      );
    }
    final path = node['path']?.toString();
    if (path == null || path.isEmpty) {
      throw FormatException(
        'firepack: storage bucket "$name" needs "path:" template',
      );
    }
    final tenant = node['tenant']?.toString();
    final ctNode = node['contentTypes'];
    final contentTypes = <String>[];
    if (ctNode is YamlList) {
      for (final ct in ctNode) {
        contentTypes.add(ct.toString());
      }
    }
    return StorageBucket(
      name: name,
      path: path,
      tenant: tenant,
      contentTypes: contentTypes,
    );
  }

  CollectionSpec _parseCollection(String name, dynamic node) {
    if (node is! YamlMap) {
      throw FormatException(
        'firepack: collection "$name" must be a mapping',
      );
    }

    final className = node['className']?.toString();
    final tenant = node['tenant']?.toString();

    final fieldsNode = node['fields'];
    if (fieldsNode is! YamlMap) {
      throw FormatException(
        'firepack: collection "$name" must define "fields:"',
      );
    }
    final fields = <String, FieldSpec>{};
    for (final entry in fieldsNode.entries) {
      final fName = entry.key.toString();
      fields[fName] = _parseField(fName, entry.value, owner: name);
    }

    final indexes = <IndexSpec>[];
    final indexNode = node['indexes'];
    if (indexNode is YamlList) {
      for (final i in indexNode) {
        indexes.add(_parseIndex(i, owner: name));
      }
    }

    final queries = <String, QuerySpec>{};
    final queriesNode = node['queries'];
    if (queriesNode is YamlMap) {
      for (final entry in queriesNode.entries) {
        final qName = entry.key.toString();
        queries[qName] = _parseQuery(qName, entry.value, owner: name);
      }
    }

    RulesSpec? rules;
    final rulesNode = node['rules'];
    if (rulesNode is YamlMap) {
      rules = _parseRules(rulesNode, owner: name);
    }

    return CollectionSpec(
      name: name,
      className: className,
      tenant: tenant,
      fields: fields,
      indexes: indexes,
      queries: queries,
      rules: rules,
    );
  }

  FieldSpec _parseField(
    String name,
    dynamic node, {
    required String owner,
  }) {
    // Field can be either a shorthand string ("string") or a YamlMap.
    if (node is String) {
      return FieldSpec(
          name: name, type: _parseType(node, owner: owner, field: name));
    }
    if (node is! YamlMap) {
      throw FormatException(
        'firepack: field "$owner.$name" must be a string or mapping',
      );
    }

    final typeStr = node['type']?.toString();
    if (typeStr == null) {
      throw FormatException(
        'firepack: field "$owner.$name" is missing required "type:"',
      );
    }
    final type = _parseType(typeStr, owner: owner, field: name);

    List<String>? enumValues;
    String? refTarget;
    FieldSpec? itemSpec;

    if (type == FieldType.enum_ && !typeStr.startsWith('enum[')) {
      // Inline enum — must have values: [...] right here.
      final v = node['values'];
      if (v is! YamlList || v.isEmpty) {
        throw FormatException(
          'firepack: enum field "$owner.$name" needs "values: [..]"',
        );
      }
      enumValues = v.map((e) => e.toString()).toList(growable: false);
    }
    // For shared enums (`enum[Name]`) values live in spec.enums and the
    // generator looks them up — no inline values required.

    if (typeStr.startsWith('ref[') ||
        typeStr.startsWith('list[ref:') ||
        typeStr.startsWith('list[ref[')) {
      final start = typeStr.indexOf('[') + 1;
      final end = typeStr.lastIndexOf(']');
      refTarget = typeStr.substring(start, end);
      // For `list[ref:...]` the leading `ref:` is part of the inner.
      if (refTarget.startsWith('ref:')) refTarget = refTarget.substring(4);
      if (refTarget.startsWith('ref[')) {
        refTarget = refTarget.substring(4, refTarget.length - 1);
      }
    }

    String? storageBucket;
    if (typeStr.startsWith('storageRef[')) {
      final start = typeStr.indexOf('[') + 1;
      final end = typeStr.lastIndexOf(']');
      storageBucket = typeStr.substring(start, end);
    }

    String? nestedTypeRef;
    if (typeStr.startsWith('type[')) {
      final start = typeStr.indexOf('[') + 1;
      final end = typeStr.lastIndexOf(']');
      nestedTypeRef = typeStr.substring(start, end);
    }

    String? enumRef;
    if (typeStr.startsWith('enum[')) {
      final start = typeStr.indexOf('[') + 1;
      final end = typeStr.lastIndexOf(']');
      enumRef = typeStr.substring(start, end);
    }

    if (type == FieldType.list) {
      // Inner type lives in node['of'] OR is encoded into the type string.
      final ofNode = node['of'];
      if (ofNode != null) {
        itemSpec = _parseField('${name}_item', ofNode, owner: owner);
      }
    }

    return FieldSpec(
      name: name,
      type: type,
      enumValues: enumValues,
      refTarget: refTarget,
      itemSpec: itemSpec,
      storageBucket: storageBucket,
      nestedTypeRef: nestedTypeRef,
      enumRef: enumRef,
      required: _bool(node, 'required', def: false),
      optional: _bool(node, 'optional', def: false),
      primaryKey: _bool(node, 'primaryKey', def: false),
      immutable: _bool(node, 'immutable', def: false),
      defaultValue: node['default'],
      serverDefault: _parseServerDefault(node['serverDefault']),
      autoTouch: _bool(node, 'autoTouch', def: false),
    );
  }

  FieldType _parseType(
    String raw, {
    required String owner,
    required String field,
  }) {
    final s = raw.trim();
    if (s == 'string') return FieldType.string;
    if (s == 'int') return FieldType.int_;
    if (s == 'double' || s == 'number') return FieldType.double_;
    if (s == 'bool') return FieldType.bool_;
    if (s == 'dateTime' || s == 'datetime') return FieldType.dateTime;
    if (s == 'enum' || s.startsWith('enum[')) return FieldType.enum_;
    if (s.startsWith('ref[')) return FieldType.ref;
    if (s.startsWith('list[') || s == 'list') return FieldType.list;
    if (s == 'map') return FieldType.map;
    // storageRef[<bucket>] — runtime type is string (the path); the
    // bucket marker lives separately on FieldSpec.storageBucket.
    if (s.startsWith('storageRef[')) return FieldType.string;
    // type[<nestedTypeName>] — embedded nested class. Runtime type is
    // the nested class itself (NOT a string), so this is a real new
    // FieldType — not a string-with-marker like storageRef.
    if (s.startsWith('type[')) return FieldType.nestedType;
    throw FormatException(
      'firepack: unknown type "$s" on "$owner.$field"',
    );
  }

  ServerDefault? _parseServerDefault(dynamic node) {
    if (node == null) return null;
    final s = node.toString();
    if (s == 'now') return ServerDefault.now;
    if (s == 'randomId') return ServerDefault.randomId;
    throw FormatException('firepack: unsupported serverDefault "$s"');
  }

  IndexSpec _parseIndex(dynamic node, {required String owner}) {
    if (node is! YamlMap || node['fields'] is! YamlList) {
      throw FormatException(
        'firepack: index in "$owner" must be a mapping with "fields:" list',
      );
    }
    final fields = <IndexField>[];
    for (final f in node['fields'] as YamlList) {
      final s = f.toString();
      if (s.contains(':')) {
        final parts = s.split(':');
        final dir =
            parts[1] == 'desc' ? IndexDirection.desc : IndexDirection.asc;
        fields.add(IndexField(parts[0], dir));
      } else {
        fields.add(IndexField(s, IndexDirection.asc));
      }
    }
    return IndexSpec(fields);
  }

  QuerySpec _parseQuery(
    String name,
    dynamic node, {
    required String owner,
  }) {
    if (node is! YamlMap) {
      throw FormatException(
        'firepack: query "$owner.$name" must be a mapping',
      );
    }
    final byId = _bool(node, 'byId', def: false);
    final where = <String>[];
    final whereNode = node['where'];
    if (whereNode is YamlList) {
      for (final w in whereNode) {
        where.add(w.toString());
      }
    }
    final orderBy = <String>[];
    final obNode = node['orderBy'];
    if (obNode is YamlList) {
      for (final o in obNode) {
        orderBy.add(o.toString());
      }
    } else if (obNode is String) {
      orderBy.add(obNode);
    }
    return QuerySpec(
      name: name,
      byId: byId,
      where: where,
      orderBy: orderBy,
      limit: (node['limit'] as int?),
    );
  }

  RulesSpec _parseRules(YamlMap node, {required String owner}) {
    final read = node['read']?.toString();
    final create = node['create']?.toString();
    final delete = node['delete']?.toString();

    final updateClauses = <RuleClause>[];
    final updateNode = node['update'];
    if (updateNode is String) {
      updateClauses.add(RuleClause(roleExpr: updateNode, fieldsExpr: 'all'));
    } else if (updateNode is YamlList) {
      for (final c in updateNode) {
        if (c is String) {
          updateClauses.add(RuleClause(roleExpr: c, fieldsExpr: 'all'));
        } else if (c is YamlMap) {
          // YAML mapping: { role: <expr>, fields: <list|all> } OR
          // a single-key mapping mirroring the inline syntax.
          final roleExpr = c['role']?.toString() ?? c.keys.first.toString();
          final fieldsExpr = c['fields']?.toString() ?? 'all';
          updateClauses.add(
            RuleClause(roleExpr: roleExpr, fieldsExpr: fieldsExpr),
          );
        }
      }
    }

    return RulesSpec(
      read: read,
      create: create,
      update: updateClauses,
      delete: delete,
      verbatim: node['verbatim']?.toString(),
    );
  }

  // -----------------------------------------------------------------
  // tiny helpers
  // -----------------------------------------------------------------

  String _stringRequired(YamlMap node, String key, {required String context}) {
    final v = node[key];
    if (v is! String || v.isEmpty) {
      throw FormatException(
        'firepack: $context is missing required string "$key"',
      );
    }
    return v;
  }

  int _intRequired(YamlMap node, String key, {required String context}) {
    final v = node[key];
    if (v is! int) {
      throw FormatException(
        'firepack: $context is missing required int "$key"',
      );
    }
    return v;
  }

  bool _bool(YamlMap node, String key, {required bool def}) {
    final v = node[key];
    if (v == null) return def;
    if (v is bool) return v;
    if (v is String) return v.toLowerCase() == 'true';
    return def;
  }
}
