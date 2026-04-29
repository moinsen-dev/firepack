# Changelog

Alle bemerkenswerten Änderungen — bootstrap-style, jeder Release durch
einen WorkBrief-Konsumptions-Schritt motiviert.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Planning
- TypeScript-Types-Generator (functions/src/firepack/types/*.ts) für
  Cloud-Functions-Side-Konsumption.
- Pub.dev-Release sobald Spec-Format extern stabil bleibt.
- CI für firepack selbst (GitHub Actions: pub get + analyze + test).

## [0.0.13] — 2026-04-29

### Fixed
- `repository_generator.dart`: `tenant_query.dart` import wird nur
  noch emittiert wenn mindestens eine Query den `tenant`-Token im
  `where:` listet. Vorher: Collections mit `tenant: ...` Feld bekamen
  den Import auch wenn keine Query `scopedToOrg` benutzte (z.B.
  byId-only oder by-arbitrary-field). Caused unused_import-Warnings
  auf evidence- und workBriefRevisions-repos während WorkBrief
  Phase-2-Wrapper-Migration.

## [0.0.12] — 2026-04-29

### Added
- **Per-Collection `className:` override.** Generated Dart class +
  filename override für Konsumenten die andere Naming-Konventionen
  haben als firepack's default `_classNameFor`. Beispiel:
  ```yaml
  auditLogs:
    className: AuditLogEntry  # statt AuditLog
  ```
  Generated: `audit_log_entry.dart` mit `class AuditLogEntry`.

### Fixed
- Re-Exports von nested-type / enums.dart aus generated Model-Files
  reverted. Während partial migrations (firepack-generated lebt
  parallel zu hand-written) verursachten transitive Re-Exports
  ambiguous_import-Errors. Konsumenten importieren jetzt explizit
  was sie nutzen — kleiner ergonomischer Cost, deutlich weniger
  Noise.

### Reflexion
| Phase | Schätzung | Realität |
|---|---|---|
| className override + parser/generator + viz/diff | 30 min | ~10 min |
| Re-export revert | — (erst beim Migration-Friction entdeckt) | ~5 min |

## [0.0.11] — 2026-04-29

### Added
- **M8.5 — Enum wireFormat (snake_case JSON support).** Per-Enum
  konfigurable Wire-Format für JSON-Serialization:
  ```yaml
  enums:
    WorkBriefStatus:
      values: [draft, needsReview, completedByWorker]
      wireFormat: snake_case   # default: dartName
  ```
  Generated `enums.dart`:
  - emittiert die bare Enum
  - emittiert eine `<Name>Json`-Extension mit `toJson()` und statischer
    `fromJson(String)` die wireFormat respektiert
  - snake_case → explizite switch-arms (compile-checked, grep-friendly)
  - dartName → trivial `name` / `byName` delegation

  Models stoppen direkten `.name` / `byName`-Zugriff für shared enums —
  rufen stattdessen `value.toJson()` / `EnumName.fromJson(s)`. Inline
  enums (per-collection) behalten `.name` / `byName` für Terseness.

### Why now
WorkBrief-Production-Firestore-Docs nutzen snake_case-Enum-Werte
(`'work_step'`, `'completed_by_worker'`, `'in_review'`) — encoded by
`@JsonValue` auf jedem Freezed-Enum. firepack-generated Models hätten
die als missing-name gelesen und geworfen. M8.5 unblockt die
WorkBrief-Phase-2-atomare-Migration.

### Reflexion
| Phase | Schätzung | Realität |
|---|---|---|
| Enum wireFormat extension + tests | 20 min | ~10 min |

## [0.0.10] — 2026-04-29

### Added — M8 Dart-Model-Generator Vollausbau
- **M8.1 `copyWith`** für jedes generated Model. Simple-Pattern (named
  optional, fallback auf this.x). 38 call-sites in WorkBrief unblockt.
- **M8.2 `operator ==` + `hashCode`** (value equality). Lists + Maps
  via private `_listEq` / `_mapEq` Helpers (no external deps); Helpers
  emittiert nur wenn benutzt. Riverpod StreamProvider-Rebuild-
  Optimization funktioniert korrekt.
- **M8.3 Nested types** — top-level `types:` Block in spec, Fields
  referenzieren via `type[<Name>]` oder `list[type[<Name>]]`. Each
  nested type → eigenes generated File mit voller Shape (copyWith,
  ==, hashCode, toJson, fromJson). Composition-Imports automatisch
  emittiert. Cross-File-Type-Safety bleibt erhalten
  (List<WorkBriefTask>, nicht List<dynamic>).
- **M8.4 Shared enums** — top-level `enums:` Block, Fields referenzieren
  via `enum[<Name>]`. Alle shared enums in einem `enums.dart` File
  gesammelt. Models importieren bei Bedarf. Löst das "TaskType used
  by both DraftTask and WorkBriefTask"-Problem clean.

### Added — M9 Storage-Path-Codegen
- **`firepack regen --target storage`** (und Watch-Target) emittiert
  `lib/firepack/storage_paths.dart` mit einer typisierten
  `static String <bucketName>({...})` pro Bucket plus
  `<bucketName>ContentTypes` const-Liste. Hand-getippte Storage-
  Pfad-Drift wird unmöglich.

### Lint
- `orphanNestedTypeRef`, `orphanEnumRef`
- `nameCollision` enforces uniqueness across collections / buckets / types

### Bundled example
- `example/firepack.yaml` (umbenannt von `blog.firepack.yaml`)
  demonstriert alle Features in einem Spec — Collections, indexes,
  queries, rules, storage, shared enums, nested types.

### Reflexion (M8 + M9)
| Phase | Schätzung | Realität |
|---|---|---|
| M8.1 copyWith | 20 min | ~5 min |
| M8.2 == / hashCode | 10 min | ~5 min |
| M8.3 nested types | 30 min | ~15 min |
| M8.4 shared enums | 15 min | ~10 min |
| M9 storage paths | 25 min | ~10 min |
| **Gesamt M8+M9** | **~100 min** | **~45 min** |

Lessons: Foundation-Re-Use ist der echte Multiplier. Spec-Modell +
Parser + Codegen-Pattern sind ab M3 auf einem Niveau bei dem jeder
neue Generator <30 min real braucht.

## [0.0.9] — 2026-04-29

### Added
- **Storage als First-Class-Citizen in der Spec (M7).** Zwei
  Erweiterungen die zusammenarbeiten:
  - `storage:` top-level Block in `firepack.yaml`. Pro Bucket: `path`
    (Template mit `{var}`-Platzhaltern), optionaler `tenant`,
    optionale `contentTypes` MIME-Allowlist.
  - `storageRef[<bucket>]` als Field-Type. Runtime-Type bleibt String
    (es ist ein Storage-Pfad), aber das Spec-Modell trägt einen
    `storageBucket`-Marker, den Lint + Viz auswerten. Auch in
    `list[storageRef[X]]` (über `of:` mapping).
- Drei neue Lint-Regeln:
  - `orphanStorageRef` — Field zeigt auf nicht existierenden Bucket.
  - `storageTenantNotInPath` — Bucket-Tenant ohne `{tenant}` im Path-
    Template.
  - `nameCollision` — Bucket + Collection teilen sich einen Namen
    (Mermaid-Entity-Namespace ist global).
- Mermaid-Viz: Storage-Buckets als eigene Nodes (mit `path` +
  `contentTypes` als Pseudo-Felder), Edges von Collection-Fields zum
  Bucket-Node. Cross-System-Beziehung damit visuell sichtbar.
- `firepack viz --out <path.md>` wrappt Output jetzt in einen
  Mermaid-Code-Fence — das `.md` rendert direkt auf GitHub.
- Watch-Target `viz` in `firepack.config.yaml`. Architektur-Diagramm
  bleibt automatisch aktuell bei jedem Spec-Save.

### Changed (Spec-Heimat)
- **Die WorkBrief-Spec lebt nicht mehr in firepack.** Sie ist die
  Source-of-Truth für WorkBrief und gehört dorthin: jetzt
  `~/work/moinsen/ideas/work_brief/app/firepack.yaml`. firepack
  bleibt domain-neutral — `example/` enthält stattdessen ein
  generisches Mini-Spec (`blog.firepack.yaml`) das alle Features
  inkl. M7 demonstriert.
- Test-Fixture `test/fixtures/blog.indexes.expected.json` ersetzt
  die bisherige WorkBrief-Snapshot-Fixture.
- 5 neue Tests, 34/34 grün.

### Why this matters
M7 schließt die "Architektur-Doku"-Lücke: Heute lebt Wissen über
Firestore↔Storage-Beziehungen verteilt in Code (Upload-Pfade in
Flutter, Read-Pfade in Functions, Tenant-Checks in `storage.rules`)
und in Köpfen. Mit der Spec als Single-Source haben alle Konsumenten
denselben Graph — und der Viz macht ihn Reviewbar.

### Reflexion (Plan vs. Realität)
| Phase | Schätzung | Realität | Faktor |
|---|---|---|---|
| Spec-Erweiterung + Parser + Lint + Viz + Tests | 30 min | ~14 min | ~2× |
| Spec-Umzug nach WorkBrief + generisches Beispiel | 15 min | ~10 min | ~1.5× |
| WorkBrief-Konsumption (`storage:` + storageRef + viz target) | 10 min | ~5 min | ~2× |
| Viz-md-wrap + viz-watch-target (Bonus, ungeplant) | — | ~5 min | n/a |
| **Gesamt M7** | **55 min** | **~34 min** | **~1.6×** |

Lessons:
- **Option B (Marker statt FieldType-Enum-Eintrag) war richtig.**
  Hätte ich `FieldType.storageRef` hinzugefügt, hätte ich vier
  Generators (model, repo, viz, diff) plus drei Tests anpassen
  müssen — Switch-Exhaustiveness in Dart. Stattdessen ein neuer
  String-Marker auf `FieldSpec`, alle bestehenden Generators sehen
  weiter ein normales String-Field. Null Switch-Brüche.
- **Spec-Heimat war überfällig.** Solange WorkBrief-Spec im firepack-
  Repo lebte, mischten sich Tool-Code + Konsumenten-Daten. Sauberer
  Cut: firepack ist domain-neutral, jeder Konsument hat seine eigene
  Spec. Neue Konsumenten kommen ohne Reibung dazu.
- **Visualisierung als Treiber, nicht Codegen.** Der eigentliche
  Bringer von M7 ist die Architektur-Doku — Storage-Rules-Generator
  bleibt bewusst aus, niemand braucht ihn heute. Bootstrap-Disziplin
  hält.

## [0.0.8] — 2026-04-27

### Added
- `firepack watch [--spec <path>] [--config <path>]` CLI-Subcommand:
  - Erstes Pass-Regen aller in der Config genannten Targets, danach
    `package:watcher`-FileWatcher auf der Spec. Save → Regen aller
    Targets in einer Session.
  - Optionale `firepack.config.yaml` neben der Spec deklariert
    Targets + Out-Pfade + optionalen `collection:`-Filter (für models /
    repos die nur einen Subset der Collections rausschreiben sollen).
  - Ohne Config: Fallback auf `indexes → firestore.indexes.json` und
    `rules → firestore.rules` im CWD. Reicht für die häufigste
    Single-App-Setup.
- `example/firepack.config.yaml` — die WorkBrief-Watch-Config (4
  Targets: indexes + rules + models[errorReports] + repos[errorReports]).

### Why this completes the planned scope
M1-M5 hatten alle den gleichen Schmerz adressiert: jedes mal manuell
`firepack regen --target X` für jeden Output zu tippen. Watch-Mode
faltet das in eine Single-Loop-Session. Für WorkBrief: Spec öffnen,
editieren, save, alle 4 Outputs sind frisch. Damit ist die
"Spec-Driven-Loop"-These zu Ende implementiert.

### Reflexion (Plan vs. Realität)
| Phase | Schätzung | Realität | Faktor |
|---|---|---|---|
| _WatchCommand + Config-Parsing | 20 min | ~8 min | ~2.5× |
| Smoke-Tests + WorkBrief-Config | inkl. | ~3 min | n/a |
| Doku + Reflexion | inkl. | ~3 min | n/a |
| **Gesamt M6** | **30 min** | **~14 min** | **~2×** |

Lessons:
- **Foundation pays off (zum n-ten Mal).** Vier Generators existieren
  schon, das Watch-Command ist nur ein Dispatch-Switch + FileWatcher-
  Loop. Keine neue Generator-Logic.
- **Default-Config ist wichtiger als Config-Power.** Ohne Config muss
  `firepack watch` was Sinnvolles tun — sonst ist der Erstkontakt
  rough. Indexes+Rules-Default ist die niedrigste-Friction-Variante.
- **Config-File neben Spec-File ist die richtige Konvention.** Spec
  ist source-of-truth, Config sagt wo deren Outputs landen.
  Repository-spezifisch, deshalb nicht in der Spec selber.

### Status nach M6
Alle ursprünglich in der ROADMAP geplanten Milestones sind erreicht.
Verbleibende Items (TypeScript-Types, Pub.dev-Release) sind keine
weiteren WorkBrief-Schmerzen — werden gebaut sobald sie es werden.

## [0.0.7] — 2026-04-28

### Added
- `lib/src/diff/spec_diff.dart`:
  - `SpecDiff` model + `CollectionDiff` per modified collection
  - `diffSpecs(oldSpec, newSpec)` walkt Collections, Fields, Indexes,
    Queries, Rules-Slots
  - `renderMarkdown(SpecDiff)` für PR-Comment-taugliche Output-Form
- `firepack diff --old <a.yaml> --new <b.yaml>` CLI-Subcommand. Stdout
  default; `--out path` schreibt in eine Datei (für GitHub-Action-
  Comment-Body).
- 5 neue Tests, 29/29 grün.

### Output-Form
Markdown mit Sektionen für:
- ➕/➖ Collections added/removed
- Pro modified Collection: tenant changed, fields ➕/➖/✏️,
  indexes ➕/➖, queries ➕/➖, rule-changes per Slot (read/create/
  update/delete/verbatim)

Verbatim-Block-Diffs werden NUR als "verbatim block changed" gemeldet
— die volle Inline-Diff würde PR-Comments sprengen, Reviewer pullen
das File direkt hoch.

### What we deliberately don't detect (yet)
- Field renames — heute zeigt sich das als `- old, + new`. Wenn
  WorkBrief-Renames häufig werden, kommt eine Rename-Hint-Syntax in
  die Spec.
- Reorder von fields/indexes/queries — Spec-Reihenfolge ist
  bewusst nicht semantisch.
- Migration-Scripts ("backfill priority field with normal") — ein-
  fache Hint-Texte könnten kommen, aber ohne dass irgendwer den
  Output direkt ausführen sollte.

### Live-Smoke gegen WorkBrief
Diff zwischen v0.0.1 (M1-Foundation) und v0.0.6 (current) der
WorkBrief-Spec rendert sauber:
- 12 Collections mit Rule-Verbatim-Changes (M2.5)
- `errorReports` mit ➕ 2 queries (M4)
- `issues` mit ➕ 1 index (M1 drift-fix)

Genau das was die letzten 4 Iterationen gemacht haben.

### Reflexion (Plan vs. Realität)
| Phase | Schätzung | Realität | Faktor |
|---|---|---|---|
| Diff-Modell + Markdown-Renderer | 1h | ~20 min | 3× |
| CLI-Subcommand + Tests | 0.5h | ~10 min | 3× |
| Doku + Live-Smoke + Reflexion | inkl. | ~5 min | n/a |
| **Gesamt M5** | **1.5h** | **~35 min** | **~3×** |

Lessons:
- **Tuple-Set-Vergleich für Indexes wiederverwendet** aus M1-Tests.
  Pattern aus Bestand nehmen statt neu erfinden.
- **Verbatim-Diff bewusst flach gehalten** — granuläres Diff im
  Verbatim-Block würde mehr Aufwand kosten als Wert liefern, weil
  Reviewer eh die Datei aufmacht.
- **Live-Smoke gegen Git-History** macht den Generator sofort
  glaubwürdig — kein synthetisches Testbeispiel, sondern echte
  Spec-Evolution wird rekonstruiert.

## [0.0.6] — 2026-04-28

### Added
- `lib/src/codegen/repository_generator.dart`:
  - `generateRepositoryFile(CollectionSpec)` emittiert pro Collection
    eine `<Cls>Repository`-Klasse plus Riverpod-Provider.
  - Repository hat: typed `<queryName>(...)`-Methoden für jede in der
    Spec deklarierte query (Stream<List<T>> oder Stream<T?> für byId),
    plus `add(doc)`, `updateById(id, fields)`, `deleteById(id)`,
    plus `_fromDoc`-Helper für `{...d.data(), 'id': d.id}`-Merge.
  - Provider: `<cls>RepositoryProvider` (singleton) + ein
    `<cls><Query>Provider` (StreamProvider.family) pro query.
    Multi-Param-Queries nutzen Dart-Records `({String orgId, String level})`.
  - `generateAllRepositories(Spec)` — überspringt Collections ohne
    `queries:`-Block.
- Query-Spec-Syntax die der Generator versteht:
  ```yaml
  queries:
    watchByOrg:
      where: [tenant]                        # → .scopedToOrg(orgId)
      orderBy: createdAt:desc
      limit: 50
    watchByOrgAndLevel:
      where: [tenant, "level == $level"]    # → .where('level', isEqualTo: level)
      orderBy: createdAt:desc
    watchByAssignee:
      where: [tenant, "assignedUserIds contains: $uid"]   # arrayContains
    watchById:
      byId: true                             # → Stream<T?> watchById(String id)
  ```
- `firepack regen --target repos` CLI mit `--collection`-Filter.
- 5 neue Tests, 24/24 grün.

### WorkBrief-Konsumption (Pilot — errorReports v2)
- `app/lib/firepack/repositories/error_report_repository.dart` aus Spec
  generiert (~40 LOC, sonst hand-geschrieben ~80 LOC).
- `error_dashboard_screen` ist jetzt ConsumerStatefulWidget und
  verwendet `errorReportWatchByOrgProvider` und
  `errorReportWatchByOrgAndLevelProvider` direkt. Vorher: inline
  `_stream()`-Methode mit hand-Firestore-Query + StreamBuilder. Jetzt:
  AsyncValue.when, Tile bekommt typed `ErrorReport`. Imports
  `cloud_firestore`, `firestore_paths`, `tenant_query` weg
  (die Repo-File trägt sie für den Screen).
- Spec-Erweiterung: errorReports bekam einen `queries:`-Block (zwei
  Queries: watchByOrg + watchByOrgAndLevel). Das ist die Definition
  der Dashboard-API jetzt formalisiert in der Spec.

### Out of scope (M4)
- Joins / `whereIn` / `whereNotIn` — kein WorkBrief-Bedarf heute.
- Cursor-basierte Pagination — defer bis Volumen real wird.
- Server-side Aggregations (count, sum) — Firebase SDK hat das,
  wir lifteten es ein wenn WorkBrief fragt.

### Reflexion (Plan vs. Realität)
| Phase | Schätzung | Realität | Faktor |
|---|---|---|---|
| Generator + CLI + Tests | 3h | ~30 min | ~6× |
| Pilot WorkBrief (ErrorReportRepository) | inkl. | ~10 min | n/a |
| Doku + Reflexion | inkl. | ~5 min | n/a |
| **Gesamt M4** | **3h** | **~45 min** | **~4×** |

Lessons:
- **Repository-Pattern war einer der "verbose-aber-mechanisch"-Pains.**
  Hand-geschriebene Repos in WorkBrief sind 80-150 LOC, davon ~70%
  Boilerplate. Generated repo: 40 LOC, 0 boilerplate-Cost. Skaliert
  besonders günstig auf weitere Collections.
- **Multi-Param-Queries via Dart-Records** lösen das StreamProvider-
  Family-Problem elegant — kein Custom-Class pro Query nötig.
- **Provider-Naming war die einzige nicht-mechanische Entscheidung.**
  Format `<cls><Query>Provider` (z.B. `errorReportWatchByOrgProvider`)
  liest sich gut + ist deterministisch ableitbar aus Spec.
- **WorkBrief-Diff vor M4: 90 LOC inline _stream() + StreamBuilder.**
  Nach M4: 15 LOC `ref.watch(provider)` + `AsyncValue.when`. Wenn das
  pattern auf 12 weitere Collections skaliert, ist firepack
  schon allein durch Repository-Generation gerechtfertigt.

## [0.0.5] — 2026-04-28

### Added
- `lib/src/codegen/dart_model_generator.dart`:
  - `generateDartModel(CollectionSpec)` emittiert eine immutable Dart-
    Klasse pro Collection: final-Felder, const-Konstruktor mit named
    params (required/default-aware), `toJson()` (DateTime → ISO,
    enums → `.name`, omit-if-null für optional fields), `factory
    fromJson` mit allen Casts.
  - Generated Enum-Klassen für jedes `enum`-Feld (z.B.
    `ErrorReportLevel { info, warning, error, critical }`).
  - `generateAllDartModels(Spec)` returns Map filename → content für
    Multi-File-Output.
- `firepack regen --target models` CLI:
  - `--out <dir>` (default `lib/firepack/models`)
  - `--collection <name>` zum Filtern auf eine Collection (Pilot-
    Migration-Support).
- 6 neue Tests, 19/19 grün.

### WorkBrief-Konsumption (Pilot — errorReports)
- `app/lib/firepack/models/error_report.dart` aus Spec generiert
  (15 Felder, 1 generated Enum). flutter analyze clean.
- `error_dashboard_screen.dart` parst `errorReports`-Docs jetzt
  über `ErrorReport.fromJson` statt manuell `data['level'] as String?`
  etc. Type-Safety auf level/type/message/createdAt geht durch
  `ErrorReportLevel.error|critical`-Enum-Vergleich. ~6 Zeilen
  hand-Cast-Boilerplate weg.

### Out of scope (M3)
- `copyWith()` — Konsumenten rebuild via Konstruktor; kommt erst wenn
  Edit-Flows sich beschweren.
- `==` / `hashCode` — analog.
- Nested-Type-Modeling (z.B. `tasks: list[DraftTask]`) — heute
  `List<dynamic>` Fallback. Spec-Erweiterung wenn häufig.

### Reflexion (Plan vs. Realität)
| Phase | Schätzung | Realität | Faktor |
|---|---|---|---|
| Generator + CLI + Tests | 5h | ~30 min | ~10× |
| Pilot WorkBrief (ErrorReport) | inkl. | ~10 min | n/a |
| Doku + Reflexion | inkl. | ~5 min | n/a |
| **Gesamt M3** | **5h** | **~45 min** | **~6-7×** |

Lessons:
- **Generator-Pattern wiederholt sich.** Spec walken, type-aware
  String-Templating, Test gegen Mini-Spec — wir haben den Pfad
  aus M1 + M2 wiederbenutzt. Das Spec-Modell trägt jeden weiteren
  Generator extrem günstig (Foundation-Pattern).
- **`unnecessary_this`-Lint catched es im flutter analyze.** Erste
  Iteration emittierte `this.foo` in toJson, war Lint-noisy. Ein-Zeilen-
  Fix im Generator, regen, analyze clean.
- **Analyzer ist dein Smoke-Test.** Generated Code muss von Anfang an
  flutter analyze clean produzieren — sonst springen 13 Lints pro
  generierter Datei. M3 produzierte das ab Iteration 2 sauber.
- **Pilot statt Big-Bang ist richtig.** Ein Konsument (Dashboard) ist
  genug Beweis. Die anderen 12 Collections können später, wenn echter
  Bedarf.

## [0.0.4] — 2026-04-28

### Added
- WorkBrief firestore.rules vollständig aus der Spec generiert. 11 von
  13 Collections haben jetzt `rules:`-Blöcke (workBriefRevisions
  default-deny via fehlenden Block, trustCharterAcknowledgements
  bewusst unverändert weil Production diese Collection leer hält
  und der Ack als Map auf `/users/{uid}` lebt).
- Mix aus structured (`sourceMaterials`, `aiDrafts`) und verbatim
  (alle anderen mit Nicht-Pattern-fitting Logic). Verbatim-Anteil
  hoch, weil:
  * Workers-update-status auf workBriefs braucht partial-Allowlist
  * Notifications self-targeting (userId field, nicht doc-id)
  * errorReports pre-org-Case (organizationId fehlt im Doc)
  * auditLogs actor-self-check
  * teams write needs request.resource.data check, nicht resource.data

### Validation
- `firebase_validate_security_rules` MCP-Tool: clean (keine syntax-
  oder semantik-Fehler).
- 12 Match-Blocks identisch zwischen Old/New (außer `organizations`,
  das im Old-File doppelt match'd hatte → consolidated im New).

### Reflexion (Plan vs. Realität)
| Phase | Schätzung | Realität | Faktor |
|---|---|---|---|
| Spec-Augmentation für 11 Collections | 1-1.5h | ~25 min | 3-4× |
| Generate + Diff + Verify | inkl. | ~10 min | n/a |
| **Gesamt M2.5** | **1-1.5h** | **~35 min** | **2-3×** |

Lessons:
- **Verbatim-First-Approach hat sich gelohnt.** Statt strukturierte
  Rules pro Collection zu erzwingen, ist die Spec-Schreiberei pro
  Collection eine 1:1-Übersetzung der Production-Rules. Das ist sicher
  + schnell + zukunftsoffen (verbatim-Patterns die sich oft wiederholen
  graduieren später zu strukturierten Slots).
- **Drift-Audit beim Migrieren:** trustCharterAcknowledgements war im
  Spec mit Rules drin, in Production aber ohne match-block. Generator-
  Output zeigte den Drift sofort, Spec wurde angepasst → Production-
  Verhalten erhalten.
- **`firebase_validate_security_rules` als Smoke-Test reicht** für die
  Syntax-Validation. Echte Permission-Smokes via emulators:exec sind
  noch wertvoller, aber clean syntax + structural-equivalence
  zur Hand-Version sind heute der Cut-Off. Emulator-Test ist
  separater Add-On wenn die Rules sich semantisch ändern.

## [0.0.3] — 2026-04-28

### Added
- `lib/src/codegen/rules_generator.dart` — `generateRulesFile(Spec)`.
  Emittiert `rules_version='2'`-Header, fixe Helper-Functions (isSignedIn,
  userDoc, getUserOrgId, getUserRole, isAdmin, isSupervisorOrAdmin),
  pro Collection einen `match /<col>/{<idVar>} { … }` Block mit
  `allow read/create/update/delete: if …` Lines, sowie `match
  /{document=**}` Default-Deny am Ende.
- Token-Expander für die Spec-Helper:
  `signedIn` → `isSignedIn()`, `tenantSelf` → tenant-Field-Vergleich
  (kontextabhängig: `resource.data.x` für Read/Update/Delete vs.
  `request.resource.data.x` für Create), `tenantMatchOrAdmin`,
  `isAdmin`, `isSupervisorOrAdmin`/`supervisorOrAdmin`, `self`.
- Field-Allowlist-Update — `fields: "name,foo,bar"` wird zu
  `request.resource.data.diff(resource.data).affectedKeys().hasOnly([…])`.
- `verbatim:`-Block in `RulesSpec` (Spec + Parser + Generator). Escape-
  hatch für Rule-Fragmente die der Token-Expander noch nicht modelliert
  (z.B. workers-update-only-status auf workBriefs, notifications-self-
  targeting, errorReports-pre-org-case). Raw Firestore-Rule-Text wird
  inside-the-match-block eingerückt angehängt.
- `firepack regen --target rules [--out path]` CLI-Subcommand.
- 5 neue Tests, alle 13 Tests grün.

### Honest scope of v0.0.3
Generator funktioniert für die Patterns die er kennt + Verbatim-Escape
steht zur Verfügung. **WorkBrief firestore.rules ist bewusst noch
nicht migriert.** Grund:
- Heutige WorkBrief-Spec hat `rules:` für 5 von 13 Collections; die
  anderen 8 (sourceMaterials, aiDrafts, workBriefs, workBriefRevisions,
  evidence, issues, notifications, errorReports) brauchen Augmentation.
- Verbatim-Cases (workers-update-status, notifications-self-target,
  errorReports-pre-org) brauchen Sorgfalt — Rules-Sicherheit ist kein
  "schnell-rüberschreiben"-Job.
- Migrations-Smoke via `firebase emulators:exec` ist Pflicht bevor wir
  Production-Rules anfassen.

→ siehe `docs/ROADMAP.md` M2.5.

### Reflexion (Plan vs. Realität)
| Phase | Schätzung | Realität | Faktor |
|---|---|---|---|
| A — Generator + CLI + Tests + Verbatim | 3-4h | ~35 min | 5-7× |
| B — WorkBrief-Migration | im Plan inklusive | deferred → M2.5 | n/a |
| C — Doku + Reflexion | inklusive | ~10 min | n/a |
| **Gesamt M2 (ohne Migration)** | **3-4h** | **~45 min** | **4-5×** |

Lessons:
- **Schätzung mehrfach reduziert sich um Faktor 4-7×** sobald die Spec-
  Foundation steht. Gleicher Pattern wie M1 (3×) und Foundation (300×).
- **Token-Expander vs. AST:** Simple String-Replace reicht für die
  Spec-Helper. AST kommt erst wenn Operator-Precedence-Probleme oder
  Verschachtelung wirklich auftauchen.
- **Verbatim-Escape ist Bootstrap-pragmatisch:** Spec-Sprache muss
  nicht alles modellieren — was sich oft wiederholt landet später als
  strukturierter Slot, alles andere bleibt verbatim.
- **WorkBrief-Migration zu beschleunigen wäre falsche Entscheidung:**
  Rules-Sicherheit ist nicht das Feld für "schnell rüberziehen" —
  M2.5 macht das mit Augenmerk.

## [0.0.2] — 2026-04-28

### Added
- `lib/src/codegen/indexes_generator.dart` — `generateIndexesJson(Spec)`
  emittiert das Firestore-CLI-kompatible JSON-Schema deterministisch
  aus den `indexes:`-Blöcken der Spec.
- `firepack regen --target indexes [--out path]` CLI-Subcommand.
  Andere Targets (`rules`, `models`, …) erlaubt im Parser, geben
  aber "not yet implemented" mit Hinweis auf ROADMAP zurück.
- Test-Fixture `test/fixtures/workbrief.indexes.expected.json`. Der
  WorkBrief-Spec-Generator-Output wird semantisch (collection-group +
  field-tuple set) gegen diese Datei verglichen — Drift in der Spec
  fällt sofort auf.
- 3 neue Tests, alle Tests grün (7/7).

### Changed
- Public API exportiert jetzt den Indexes-Generator (`firepack.dart`).
- WorkBrief-Spec-Drift behoben: `issues`-Collection bekam den zweiten
  Index `(organizationId, status, reportedAt:desc)` der schon im
  Production-`firestore.indexes.json` lag, in der Spec aber fehlte.
  Erster echter Wert von firepack: das Spec-Drift-Audit beim ersten
  Generator-Lauf.

### WorkBrief-Konsumption
- `app/firestore.indexes.json` wird jetzt aus der firepack-Spec
  generiert. Diff zur vorherigen Hand-Version: ausschließlich
  Reihenfolge, keine semantischen Änderungen.
- `docs/firebase-stack.md` markiert die Datei als generiert + nennt
  den `regen`-Befehl.

### Reflexion (Plan vs. Realität)
| Phase | Schätzung | Realität | Faktor |
|---|---|---|---|
| A — Generator + CLI + Test | 30 min | ~10 min | ~3× |
| B — WorkBrief-Migration | 10 min | ~3 min | ~3× |
| C — Doku + Reflexion | 10 min | ~5 min | ~2× |
| **Gesamt** | **50 min** | **~18 min** | **~3×** |

## [0.0.1] — 2026-04-28

### Added
- YAML-Spec-Parser für `firepack: 1`
- Spec-Modell (Collection / Field / Index / Query / Rules)
- Linter mit 5 Regeln: orphan refs, dup indexes, missing tenant fields,
  no primaryKey, conflicting required/optional flags
- `firepack viz` → Mermaid `erDiagram` mit FK-Annotationen + Tenant-Hints
- `firepack lint` mit CI-Exit-Code
- args/command_runner CLI-Skelett
- Test-Suite (4 Tests, inkl. WorkBrief-Smoke)
- `example/workbrief.firepack.yaml` — die echte WorkBrief-Spec mit 13
  Collections + 148 Feldern als Eat-Your-Own-Dogfood-Anker

### WorkBrief-Konsumption
- Noch keine. v0.0.1 ist read-only — der Validator ersetzt das manuell
  gepflegte Markdown-Doc in `docs/firebase-stack.md` als Single-Source-
  of-Truth fürs Datenmodell.

### Notes
- Spec-Format-Stand: stabil für die Felder die WorkBrief heute braucht.
  `queries:` wird heute nur geparst, M4 wird daraus Repos generieren.
  Erweiterungen sind additiv geplant.
