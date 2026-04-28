# firepack Spec — Reference (v1)

**Status:** Read this *and* [PHILOSOPHY.md](./PHILOSOPHY.md). The spec only
covers what WorkBrief actually consumes today (parser + linter + viz).
Codegen-spezifische Erweiterungen werden hier ergänzt sobald die
entsprechenden M-Items aus [ROADMAP.md](./ROADMAP.md) landen.

## Top-level

```yaml
firepack: 1                # required, only 1 supported today
project: workbrief         # required, free-form identifier
collections:               # required, mapping
  <collection-name>:
    ...
```

## Collection

```yaml
<name>:
  tenant: <field-name>     # optional, default null (untenanted)
  fields:                  # required, mapping (see "Field" below)
  indexes: [...]           # optional, list (see "Index")
  queries: {...}           # optional, mapping (see "Query")
  rules: {...}             # optional, mapping (see "Rules")
```

**`tenant:`** — Pflichtfeld in jedem Doc dieser Collection, das die
Org-Zugehörigkeit speichert. Setzt das automatisch in Queries
(`scopedToOrg(orgId)`) und Rules (`tenantSelf` Helper). WorkBrief nutzt
durchgehend `organizationId` für Tenant-Collections.

## Field

Two equivalent forms:

```yaml
# Shorthand — type only
title: string

# Mapping — full control
title:
  type: string
  required: true
  immutable: true
  default: "Untitled"
  serverDefault: now       # alternative zu default für DateTime-Auto-Set
  primaryKey: false
  optional: false
  autoTouch: false
```

### Types

| Type | Notes |
|---|---|
| `string` | UTF-8 |
| `int` | int64 |
| `double` (alias `number`) | float64 |
| `bool` | |
| `dateTime` (alias `datetime`) | ISO-8601 String in Firestore (Stand WorkBrief) |
| `enum` | requires `values: [a, b, c]` |
| `ref[<col>.<field>]` | foreign-key-Style Referenz; nutzt das Lint-System |
| `list` | requires `of: { type: <inner> }` ODER inline `list[<type>]` |
| `map` | freeform Map (Firestore-Map). Discouraged — bevorzugt strukturieren |

### Flags

| Flag | Effekt |
|---|---|
| `required: true` | non-null, im Codegen ohne `?` |
| `optional: true` | nullable, im Codegen mit `?` |
| `immutable: true` | wird in Update-Rules ausgeschlossen |
| `primaryKey: true` | genau ein Feld pro Collection muss das setzen |
| `default: <val>` | Client-Side-Default beim `create` |
| `serverDefault: now` | DateTime-Felder bekommen `FieldValue.serverTimestamp()` |
| `serverDefault: randomId` | für `id`-Felder, generiert aus `doc().id` |
| `autoTouch: true` | DateTime-Felder werden auf jedem `update` neu gesetzt |

`required` und `optional` sind sich gegenseitig ausschließend; der Linter
fängt das.

### Refs

```yaml
createdBy: { type: "ref[users.id]", required: true, immutable: true }
```

Quoting ist in Flow-Mappings notwendig wegen YAML-Syntax (Brackets sind
reserviert). Linter prüft dass `users` existiert; `users.id` ist heute
ein Hint, kein hard check (kommt mit M3 wenn Codegen die Ziel-Felder
kennen muss).

### Lists

```yaml
# Liste von Strings
fcmTokens: { type: list, of: { type: string } }

# Liste von Refs
assignedUserIds: { type: list, of: { type: "ref[users.id]" } }

# Liste von nested Models (siehe nested-Limitations unten)
tasks: { type: list }   # heute: opaque, M3 wird das ausweiten
```

## Index

```yaml
indexes:
  - fields: [organizationId, createdAt:desc]
  - fields: [organizationId, status, createdAt:desc]
```

**Direction:** `:asc` (default), `:desc`. Mehr Direction-Tokens kommen
nicht — Firestore unterstützt nur diese zwei.

Linter erkennt Duplikate. Codegen (M1) schreibt das in
`firestore.indexes.json` mit `collectionGroup` = Collection-Name,
`queryScope: COLLECTION`.

## Query

```yaml
queries:
  watchByOrg:
    where: [tenant]              # `tenant` ist Reserved Token → wird zu where('organizationId', ==, $orgId)
    orderBy: createdAt:desc
  watchById:
    byId: true                   # → `Stream<T?> watchById(String id)`
  watchByAssignee:
    where: [tenant, "assignedUserIds contains: $uid"]
    orderBy: createdAt:desc
    limit: 50
```

**Reserved Tokens:**
- `tenant` — wird zur tenant-Filter-Where-Clause
- `$<name>` — Funktionsparameter; wird im Codegen zu Method-Argument

Heute werden `queries:` nur geparst; M4 generiert daraus Repo-Methoden.

## Rules

```yaml
rules:
  read: "signedIn && tenantSelf"
  create: "signedIn && supervisorOrAdmin && tenantSelf"
  update:
    - role: "isAdmin && tenantSelf"
      fields: "all"
    - role: "self"
      fields: "name,preferredLanguage,fcmTokens"
  delete: false
```

**Helper-Tokens** (werden in M2 vom Rules-Generator expandiert):
- `signedIn` → `request.auth != null`
- `self` → `request.auth.uid == userId` (oder das passende ID-Feld)
- `tenantSelf` → `request.resource.data.<tenant> == getUserOrgId()`
- `selfOr(<expr>)` → `(self || <expr>)`
- `isAdmin` / `isSupervisor` / `isWorker` → role check
- `supervisorOrAdmin` → admin-or-supervisor

**update:**
- Single string → `update: <expr>` mit `fields: all`
- List of clauses → multi-role; jede Clause gilt für ihren Role-Match
- `fields: "name,foo,bar"` → wird zu `affectedKeys().hasOnly([…])`
- `fields: "all"` → keine Field-Restriction

**delete:**
- `false` → never deletable (immutable history wie `auditLogs`)
- string → boolean expression

## Beispiel

Komplettes Mini-Beispiel:

```yaml
firepack: 1
project: my-app

collections:
  posts:
    tenant: organizationId
    fields:
      id:             { type: string, primaryKey: true }
      organizationId: { type: "ref[organizations.id]", required: true }
      title:          { type: string, required: true }
      status:
        type: enum
        values: [draft, published]
        default: draft
      createdBy:      { type: "ref[users.id]", required: true, immutable: true }
      createdAt:      { type: dateTime, required: true, serverDefault: now }
    indexes:
      - fields: [organizationId, createdAt:desc]
    queries:
      watchPublishedByOrg:
        where: [tenant, "status == published"]
        orderBy: createdAt:desc
    rules:
      read: "signedIn && tenantSelf"
      create: "signedIn && tenantSelf"
      update:
        - role: "isAdmin && tenantSelf"
          fields: "all"
      delete: false
```

## Versions-Politik

`firepack: 1` — heutiger Stand. Spec-Erweiterungen sind additiv (neue
Felder mit Default-Werten). Breaking Changes bekommen einen neuen
Versions-Stand (`firepack: 2`); Parser unterstützt beide eine Migrations-
Phase lang. Folgt der Linux-style Stable-API-Disziplin.
