import '../spec/spec.dart';

/// Generates a single Dart model file per collection.
///
/// **Output shape (v0.0.10):**
/// - one immutable Dart class with `final` fields
/// - const constructor with named parameters (required where the spec
///   marked the field required, defaulted where the spec gave a default)
/// - `toJson()` returning `Map<String, dynamic>` — DateTime → ISO string,
///   enums → `.name`, omit-if-null for optional fields
/// - `factory fromJson(...)` — DateTime.parse, enum.values.byName,
///   defaults applied for absent or null fields
/// - `copyWith({...})` with simple pattern (named optional, falls back
///   to current value). Cannot set non-null optional fields to null —
///   document that path explicitly via a setter call if needed.
/// - `operator ==` / `hashCode` — value equality. List + Map compared
///   deep via private `_listEq` / `_mapEq` helpers (no external deps).
/// - generated `enum` classes for every `enum`-typed field, named
///   `<ClassName><FieldNamePascal>` (e.g. `ErrorReportLevel`)
///
/// **Not yet:**
/// - nested freezed-style types (`list[type[DraftTask]]`) — landing in
///   M8.3 with a `types:`-block in the spec
/// - sentinel-based copyWith (set optional field explicitly to null)
String generateDartModel(CollectionSpec collection, {String? sourceFile}) {
  final cls = _classNameFor(collection.name);
  return _emitFile(cls, collection.fields, sourceFile: sourceFile);
}

/// Generates a Dart class for a [NestedTypeSpec]. Same shape as a
/// collection model but the class name is the type-name verbatim
/// (no s-stripping / pascal-casing — `WorkBriefTask` stays `WorkBriefTask`).
String generateNestedTypeModel(NestedTypeSpec type, {String? sourceFile}) {
  return _emitFile(type.name, type.fields, sourceFile: sourceFile);
}

/// Internal: emit one Dart file with a class body + imports + helpers.
String _emitFile(
  String cls,
  Map<String, FieldSpec> fields, {
  String? sourceFile,
}) {
  final buf = StringBuffer();
  buf.writeln(_header(sourceFile));

  // Imports — pull in any nested-type files this class references.
  final imports = _collectImports(fields);
  if (imports.isNotEmpty) {
    buf.writeln();
    for (final imp in imports) {
      buf.writeln("import '$imp';");
    }
  }
  buf.writeln();

  // Per-class generated enum classes — only for inline enums. Shared
  // enums (enumRef set) live in the imported `enums.dart`.
  for (final f in fields.values) {
    if (f.type == FieldType.enum_ && f.enumRef == null) {
      buf.writeln(_emitEnum(cls, f));
      buf.writeln();
    }
  }

  buf.writeln('class $cls {');
  for (final f in fields.values) {
    buf.writeln('  final ${_dartType(cls, f)} ${f.name};');
  }
  buf.writeln();

  // const constructor
  buf.writeln('  const $cls({');
  for (final f in fields.values) {
    final isReq = f.required || f.primaryKey;
    final hasDefault = f.defaultValue != null;
    final keyword = isReq && !hasDefault ? 'required ' : '';
    final defaultPart = hasDefault ? ' = ${_dartLiteral(f.defaultValue, f, cls)}' : '';
    buf.writeln('    $keyword'
        'this.${f.name}'
        '$defaultPart,');
  }
  buf.writeln('  });');
  buf.writeln();

  // copyWith
  buf.writeln('  $cls copyWith({');
  for (final f in fields.values) {
    final t = _dartType(cls, f);
    final paramType = t.endsWith('?') ? t : '$t?';
    buf.writeln('    $paramType ${f.name},');
  }
  buf.writeln('  }) => $cls(');
  for (final f in fields.values) {
    buf.writeln('    ${f.name}: ${f.name} ?? this.${f.name},');
  }
  buf.writeln('  );');
  buf.writeln();

  // toJson
  buf.writeln('  Map<String, dynamic> toJson() => {');
  for (final f in fields.values) {
    final omitIfNull = f.optional && !f.required;
    final access = f.name;
    final ser = _toJsonExpr(access, f);
    if (omitIfNull) {
      buf.writeln("    if ($access != null) '${f.name}': $ser,");
    } else {
      buf.writeln("    '${f.name}': $ser,");
    }
  }
  buf.writeln('  };');
  buf.writeln();

  // fromJson
  buf.writeln('  factory $cls.fromJson(Map<String, dynamic> json) => $cls(');
  for (final f in fields.values) {
    final readExpr = _fromJsonExpr("json['${f.name}']", f, cls);
    buf.writeln('    ${f.name}: $readExpr,');
  }
  buf.writeln('  );');
  buf.writeln();

  // operator ==
  buf.writeln('  @override');
  buf.writeln('  bool operator ==(Object other) =>');
  buf.writeln('      identical(this, other) ||');
  buf.writeln('      other is $cls &&');
  buf.writeln('          runtimeType == other.runtimeType${fields.isEmpty ? ';' : ' &&'}');
  final fieldList = fields.values.toList();
  for (var i = 0; i < fieldList.length; i++) {
    final f = fieldList[i];
    final tail = i == fieldList.length - 1 ? ';' : ' &&';
    final cmp = _eqExpr(f);
    buf.writeln('          $cmp$tail');
  }
  buf.writeln();

  // hashCode
  buf.writeln('  @override');
  if (fieldList.length <= 20) {
    buf.writeln('  int get hashCode => Object.hash(');
    for (var i = 0; i < fieldList.length; i++) {
      final f = fieldList[i];
      final last = i == fieldList.length - 1;
      buf.writeln('        ${_hashExpr(f)}${last ? '' : ','}');
    }
    buf.writeln('      );');
  } else {
    buf.writeln('  int get hashCode => Object.hashAll([');
    for (final f in fieldList) {
      buf.writeln('        ${_hashExpr(f)},');
    }
    buf.writeln('      ]);');
  }

  buf.writeln('}');

  // Collection-equality helpers — only emit the variant actually used.
  final hasList = fields.values.any((f) => f.type == FieldType.list);
  final hasMap = fields.values.any((f) => f.type == FieldType.map);
  if (hasList || hasMap) {
    buf.writeln();
    if (hasList) buf.writeln(_listEqHelper());
    if (hasMap) {
      if (hasList) buf.writeln();
      buf.writeln(_mapEqHelper());
    }
  }

  return buf.toString();
}

/// Returns relative-import paths the generated class needs — one
/// entry per referenced nested type, plus `enums.dart` if any field
/// uses a shared enum. All generated files live next to each other in
/// the same directory, so leaf-only paths are enough.
Set<String> _collectImports(Map<String, FieldSpec> fields) {
  final imports = <String>{};
  for (final f in fields.values) {
    final ref = f.nestedTypeRef ?? f.itemSpec?.nestedTypeRef;
    if (ref != null) {
      imports.add('${_nestedFileName(ref)}.dart');
    }
    if (f.enumRef != null) {
      imports.add('enums.dart');
    }
  }
  return imports;
}

/// Generates a single `enums.dart` file containing every shared enum
/// declared under `Spec.enums`. Models that reference a shared enum
/// import this file. Returns null when the spec has no shared enums.
String? generateSharedEnumsFile(Spec spec, {String? sourceFile}) {
  if (spec.enums.isEmpty) return null;
  final buf = StringBuffer();
  buf.writeln(_header(sourceFile));
  buf.writeln();
  buf.writeln('// Shared enums — referenced from models via `enum[<Name>]`.');
  buf.writeln('// Each enum gets a `<Name>Json` extension with wireFormat-aware');
  buf.writeln('// toJson()/fromJson() so the model layer never touches naming.');
  for (final e in spec.enums.values) {
    buf.writeln();
    buf.writeln('enum ${e.name} { ${e.values.join(", ")} }');
    buf.writeln();
    buf.writeln(_emitEnumJsonExtension(e));
  }
  return buf.toString();
}

/// Emits a `<EnumName>Json` extension on the enum with `toJson()` and a
/// static `fromJson(String)` that honours the wireFormat. dartName
/// extensions are trivial (`name` / `byName`); snake_case extensions
/// emit explicit switch arms so generated code stays grep-friendly
/// and compile-checked.
String _emitEnumJsonExtension(EnumSpec e) {
  final name = e.name;
  final buf = StringBuffer();
  buf.writeln('extension ${name}Json on $name {');
  if (e.wireFormat == EnumWireFormat.dartName) {
    buf.writeln('  String toJson() => name;');
    buf.writeln(
        '  static $name fromJson(String s) => $name.values.byName(s);');
  } else {
    // snake_case
    buf.writeln('  String toJson() => switch (this) {');
    for (final v in e.values) {
      buf.writeln("        $name.$v => '${_camelToSnake(v)}',");
    }
    buf.writeln('      };');
    buf.writeln();
    buf.writeln('  static $name fromJson(String s) => switch (s) {');
    for (final v in e.values) {
      buf.writeln("        '${_camelToSnake(v)}' => $name.$v,");
    }
    buf.writeln(
        "        _ => throw ArgumentError('unknown $name wire value: \$s'),");
    buf.writeln('      };');
  }
  buf.writeln('}');
  return buf.toString();
}

String _camelToSnake(String camel) {
  // workStep → work_step ; checkIn → check_in ; externalAction → external_action
  return camel.replaceAllMapped(
    RegExp(r'(?<=.)([A-Z])'),
    (m) => '_${m.group(0)!.toLowerCase()}',
  ).toLowerCase();
}

String _nestedFileName(String typeName) {
  // WorkBriefTask → work_brief_task; ChecklistItem → checklist_item
  return typeName.replaceAllMapped(
    RegExp(r'(?<=.)([A-Z])'),
    (m) => '_${m.group(0)!.toLowerCase()}',
  ).toLowerCase();
}

String _eqExpr(FieldSpec f) {
  final n = f.name;
  if (f.type == FieldType.list) return '_listEq($n, other.$n)';
  if (f.type == FieldType.map) return '_mapEq($n, other.$n)';
  return '$n == other.$n';
}

String _hashExpr(FieldSpec f) {
  final n = f.name;
  final isNullable = f.optional && !f.required && !f.primaryKey;
  if (f.type == FieldType.list) {
    return isNullable
        ? 'Object.hashAll($n ?? const [])'
        : 'Object.hashAll($n)';
  }
  if (f.type == FieldType.map) {
    final src = isNullable ? '($n ?? const {})' : n;
    return 'Object.hashAllUnordered($src.entries.map((e) => Object.hash(e.key, e.value)))';
  }
  return n;
}

String _listEqHelper() => '''
// Deep list equality — private to this file (no external deps).
bool _listEq(List<dynamic>? a, List<dynamic>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}''';

String _mapEqHelper() => '''
// Deep map equality — private to this file (no external deps).
bool _mapEq(Map<String, dynamic>? a, Map<String, dynamic>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;
  for (final k in a.keys) {
    if (!b.containsKey(k) || a[k] != b[k]) return false;
  }
  return true;
}''';

// ---------------------------------------------------------------------------
// helpers
// ---------------------------------------------------------------------------

String _header(String? sourceFile) {
  final src = sourceFile ?? 'firepack.yaml';
  return '''// GENERATED by firepack — do not edit.
// Source: $src
//
// Regenerate via:
//   dart run firepack:firepack regen --target models --spec <path>
//
// To change a field, edit the spec, then regenerate. Hand-edits here
// are overwritten on the next `firepack regen`.''';
}

String _classNameFor(String collectionName) {
  // workBriefs → WorkBrief, errorReports → ErrorReport, users → User.
  final singular = collectionName.endsWith('s')
      ? collectionName.substring(0, collectionName.length - 1)
      : collectionName;
  return singular[0].toUpperCase() + singular.substring(1);
}

String _enumNameFor(String className, String fieldName) {
  // ErrorReport + level → ErrorReportLevel
  return className + fieldName[0].toUpperCase() + fieldName.substring(1);
}

String _emitEnum(String className, FieldSpec f) {
  final name = _enumNameFor(className, f.name);
  final values = f.enumValues!.join(', ');
  return 'enum $name { $values }';
}

String _dartType(String className, FieldSpec f) {
  String base;
  switch (f.type) {
    case FieldType.string:
      base = 'String';
    case FieldType.int_:
      base = 'int';
    case FieldType.double_:
      base = 'double';
    case FieldType.bool_:
      base = 'bool';
    case FieldType.dateTime:
      base = 'DateTime';
    case FieldType.enum_:
      // Shared enum (enum[Name]) → use the shared name; inline enum
      // → use the per-class generated name.
      base = f.enumRef ?? _enumNameFor(className, f.name);
    case FieldType.ref:
      // Refs serialise as doc-id strings.
      base = 'String';
    case FieldType.list:
      // List<X> based on inner item spec — string/ref → List<String>,
      // nested type → List<NestedTypeName>, fallback → List<dynamic>.
      final inner = f.itemSpec;
      if (inner != null) {
        if (inner.nestedTypeRef != null) {
          base = 'List<${inner.nestedTypeRef}>';
        } else if (inner.type == FieldType.string || inner.type == FieldType.ref) {
          base = 'List<String>';
        } else {
          base = 'List<dynamic>';
        }
      } else {
        base = 'List<dynamic>';
      }
    case FieldType.map:
      base = 'Map<String, dynamic>';
    case FieldType.nestedType:
      base = f.nestedTypeRef!;
  }

  // Required + default → non-nullable (the constructor enforces required).
  // Optional → nullable.
  // primaryKey → non-nullable.
  if (f.optional && !f.required && !f.primaryKey) {
    return '$base?';
  }
  return base;
}

String _dartLiteral(dynamic value, FieldSpec f, String className) {
  if (value == null) return 'null';
  if (value is bool) return value.toString();
  if (value is num) return value.toString();
  if (value is List) {
    if (value.isEmpty) return 'const []';
    final items = value.map((v) => _dartLiteral(v, f, className)).join(', ');
    return 'const [$items]';
  }
  if (f.type == FieldType.enum_) {
    final enumName = f.enumRef ?? _enumNameFor(className, f.name);
    return '$enumName.$value';
  }
  // strings — quote and escape minimally
  final s = value.toString().replaceAll('\\', '\\\\').replaceAll("'", "\\'");
  return "'$s'";
}

String _toJsonExpr(String access, FieldSpec f) {
  final isOpt = f.optional && !f.required;
  switch (f.type) {
    case FieldType.dateTime:
      return isOpt
          ? '$access?.toIso8601String()'
          : '$access.toIso8601String()';
    case FieldType.enum_:
      // Shared enum (enumRef set) goes through generated `toJson()`
      // extension method — handles wireFormat conversion (dartName /
      // snake_case). Inline enums keep using `.name` for terseness.
      if (f.enumRef != null) {
        return isOpt ? '$access?.toJson()' : '$access.toJson()';
      }
      return isOpt ? '$access?.name' : '$access.name';
    case FieldType.nestedType:
      return isOpt ? '$access?.toJson()' : '$access.toJson()';
    case FieldType.list:
      // list[type[X]] needs deep toJson; list[String|dynamic|ref] passes through.
      final inner = f.itemSpec;
      if (inner?.nestedTypeRef != null) {
        return isOpt
            ? '$access?.map((e) => e.toJson()).toList()'
            : '$access.map((e) => e.toJson()).toList()';
      }
      return access;
    default:
      return access;
  }
}

String _fromJsonExpr(String expr, FieldSpec f, String className) {
  final isOpt = f.optional && !f.required && !f.primaryKey;
  final defaultLiteral = f.defaultValue != null
      ? _dartLiteral(f.defaultValue, f, className)
      : null;

  String coreFor(String src, String castType) {
    switch (f.type) {
      case FieldType.string:
      case FieldType.ref:
        return '$src as String${isOpt ? '?' : ''}';
      case FieldType.int_:
        return '($src as num${isOpt ? '?' : ''})${isOpt ? '?' : ''}.toInt()';
      case FieldType.double_:
        return '($src as num${isOpt ? '?' : ''})${isOpt ? '?' : ''}.toDouble()';
      case FieldType.bool_:
        return '$src as bool${isOpt ? '?' : ''}';
      case FieldType.dateTime:
        return isOpt
            ? '$src == null ? null : DateTime.parse($src as String)'
            : 'DateTime.parse($src as String)';
      case FieldType.enum_:
        final enumName = f.enumRef ?? _enumNameFor(className, f.name);
        // Shared enum → use generated static `fromJson` (wireFormat-aware).
        // Inline enum → values.byName as before (dartName only today).
        if (f.enumRef != null) {
          return isOpt
              ? '$src == null ? null : ${enumName}Json.fromJson($src as String)'
              : '${enumName}Json.fromJson($src as String)';
        }
        return isOpt
            ? '$src == null ? null : $enumName.values.byName($src as String)'
            : '$enumName.values.byName($src as String)';
      case FieldType.list:
        final inner = f.itemSpec;
        if (inner?.nestedTypeRef != null) {
          final nested = inner!.nestedTypeRef!;
          return isOpt
              ? '($src as List?)?.map((e) => $nested.fromJson((e as Map).cast<String, dynamic>())).toList()'
              : '($src as List).map((e) => $nested.fromJson((e as Map).cast<String, dynamic>())).toList()';
        }
        if (inner != null &&
            (inner.type == FieldType.string || inner.type == FieldType.ref)) {
          return isOpt
              ? '($src as List?)?.cast<String>()'
              : '($src as List).cast<String>()';
        }
        return isOpt
            ? '($src as List?)?.cast<dynamic>()'
            : '($src as List).cast<dynamic>()';
      case FieldType.map:
        return isOpt
            ? '($src as Map?)?.cast<String, dynamic>()'
            : '($src as Map).cast<String, dynamic>()';
      case FieldType.nestedType:
        final nested = f.nestedTypeRef!;
        return isOpt
            ? '$src == null ? null : $nested.fromJson(($src as Map).cast<String, dynamic>())'
            : '$nested.fromJson(($src as Map).cast<String, dynamic>())';
    }
  }

  if (defaultLiteral != null) {
    // For fields with defaults: read or fall back to default.
    final readExpr = coreFor(expr, '');
    if (f.type == FieldType.list || f.type == FieldType.map) {
      return '$expr == null ? $defaultLiteral : $readExpr';
    }
    return '$expr == null ? $defaultLiteral : $readExpr';
  }

  return coreFor(expr, '');
}

/// Multi-collection convenience — emits one model file per collection
/// AND per nested type, keyed by the suggested filename. Caller writes
/// them to disk.
Map<String, String> generateAllDartModels(
  Spec spec, {
  String? sourceFile,
}) {
  final out = <String, String>{};
  for (final c in spec.collections.values) {
    final fileName = _fileNameFor(c.name);
    out[fileName] = generateDartModel(c, sourceFile: sourceFile);
  }
  for (final t in spec.types.values) {
    final fileName = '${_nestedFileName(t.name)}.dart';
    out[fileName] = generateNestedTypeModel(t, sourceFile: sourceFile);
  }
  final enumsFile = generateSharedEnumsFile(spec, sourceFile: sourceFile);
  if (enumsFile != null) {
    out['enums.dart'] = enumsFile;
  }
  return out;
}

String _fileNameFor(String collectionName) {
  // workBriefs → work_brief.dart
  final snake = collectionName.replaceAllMapped(
    RegExp(r'[A-Z]'),
    (m) => '_${m.group(0)!.toLowerCase()}',
  );
  // strip trailing 's' for singular naming convention
  final singular = snake.endsWith('s') ? snake.substring(0, snake.length - 1) : snake;
  return '$singular.dart';
}
