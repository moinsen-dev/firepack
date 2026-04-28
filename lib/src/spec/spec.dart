/// In-memory representation of a parsed `firepack.yaml`.
///
/// The model deliberately mirrors what a developer wrote in YAML —
/// field names + nesting match 1:1 — so you can read either side and
/// reason about the other. Codegens read this tree; lint walks it for
/// orphan refs and missing tenants.
library;

class Spec {
  final int version;
  final String project;
  final Map<String, CollectionSpec> collections;

  const Spec({
    required this.version,
    required this.project,
    required this.collections,
  });
}

class CollectionSpec {
  final String name;

  /// Field name on this collection that scopes documents to a tenant.
  /// When set, queries auto-include `where(tenant, ==, tenantId)` and
  /// rules auto-check `request.auth.token.{role}.{org} == tenant`.
  /// Most production Firestore schemas live with one — for WorkBrief
  /// it's `organizationId` everywhere except the few singletons.
  final String? tenant;

  final Map<String, FieldSpec> fields;
  final List<IndexSpec> indexes;
  final Map<String, QuerySpec> queries;
  final RulesSpec? rules;

  const CollectionSpec({
    required this.name,
    this.tenant,
    required this.fields,
    this.indexes = const [],
    this.queries = const {},
    this.rules,
  });
}

class FieldSpec {
  final String name;
  final FieldType type;

  /// Only valid when [type] is [FieldType.enum_].
  final List<String>? enumValues;

  /// Only valid when [type] is [FieldType.ref] or [FieldType.list]
  /// of refs. Format: `<collection>.<field>` (defaults to `id`).
  final String? refTarget;

  /// Only valid for `list[X]` types. Holds the element type spec.
  final FieldSpec? itemSpec;

  final bool required;
  final bool optional;
  final bool primaryKey;
  final bool immutable;
  final dynamic defaultValue; // String | num | bool | List | null
  final ServerDefault? serverDefault;
  final bool autoTouch; // dateTime fields with autoTouch:true → updatedAt

  const FieldSpec({
    required this.name,
    required this.type,
    this.enumValues,
    this.refTarget,
    this.itemSpec,
    this.required = false,
    this.optional = false,
    this.primaryKey = false,
    this.immutable = false,
    this.defaultValue,
    this.serverDefault,
    this.autoTouch = false,
  });
}

enum FieldType {
  string,
  int_,
  double_,
  bool_,
  dateTime,
  enum_,
  ref,
  list,
  map,
}

enum ServerDefault { now, randomId }

class IndexSpec {
  /// Each entry can be a bare field name or `field:asc` / `field:desc`.
  /// Direction defaults to `asc`.
  final List<IndexField> fields;

  const IndexSpec(this.fields);
}

class IndexField {
  final String name;
  final IndexDirection direction;
  const IndexField(this.name, this.direction);
}

enum IndexDirection { asc, desc }

class QuerySpec {
  final String name;

  /// `byId: true` → exposes `watchById(id)` instead of a where-query.
  final bool byId;

  /// Tokenized `where:` predicates from YAML. Keep as raw strings for
  /// now — the codegen will translate. `tenant` is a reserved token
  /// that stands in for the auto-injected tenant filter.
  final List<String> where;

  /// Same idea: `field:asc | field:desc`.
  final List<String> orderBy;
  final int? limit;

  const QuerySpec({
    required this.name,
    this.byId = false,
    this.where = const [],
    this.orderBy = const [],
    this.limit,
  });
}

class RulesSpec {
  /// Boolean expression in the firepack rule language. Currently a
  /// thin wrapper over Firestore rule expressions; we may grow our
  /// own helpers (`tenantMatchOrAdmin`, `supervisorOrAdmin`, …) on top.
  final String? read;
  final String? create;

  /// Update can be a single string OR a list of role-scoped clauses.
  /// Each clause is `role: <expr> -> <fields|all>`.
  final List<RuleClause> update;
  final String? delete;

  /// Escape-hatch for rule fragments the spec language doesn't model
  /// yet — raw Firestore-rule-DSL text appended inside the match block,
  /// after the generated `allow` lines. Kept as a string so the spec
  /// stays untyped where the generator hasn't reached parity with our
  /// real-world rules. Whitespace + linebreaks preserved.
  final String? verbatim;

  const RulesSpec({
    this.read,
    this.create,
    this.update = const [],
    this.delete,
    this.verbatim,
  });
}

class RuleClause {
  final String roleExpr;

  /// `'all'` or a list of field names.
  final String fieldsExpr;

  const RuleClause({required this.roleExpr, required this.fieldsExpr});
}
