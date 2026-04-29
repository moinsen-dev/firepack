# firepack — Roadmap

**Bootstrap-Driven.** Jeder Meilenstein löst einen konkreten WorkBrief-
Schmerz. Die Reihenfolge richtet sich nach Schmerzhärte × Aufwand, nicht
nach Architektur-Eleganz. Siehe [PHILOSOPHY.md](./PHILOSOPHY.md).

## Done

### v0.0.13 — Generator hygiene fix (2026-04-29, ~5 min)

- `repository_generator.dart`: tenant_query.dart import nur wenn echt
  benutzt. Unused-import-Warnings auf evidence/workBriefRevisions
  beseitigt während der WorkBrief Phase-2-Wrapper-Migration.

### v0.0.12 — Per-Collection className override (2026-04-29, ~10 min)

- Spec: `className: <DartClass>` pro Collection. Filename folgt der
  Konvention. Konsumenten mit eigenem Naming (AuditLogEntry,
  AppNotification, WorkBriefIssue) bleiben damit konsistent.
- Re-Exports aus generated Files reverted — caused ambiguous_import
  collisions during partial migrations.

### v0.0.11 — M8.5 enum wireFormat (2026-04-29, ~10 min)

- Per-enum `wireFormat: snake_case | dartName` für JSON-Serialization.
- Generated `<Name>Json`-Extension mit explizitem `toJson` /
  static `fromJson(s)`.
- Unblockt WorkBrief-Migration (Production-Firestore-Docs nutzen
  snake_case-Werte via `@JsonValue`).

### v0.0.10 — M8 Dart-Model-Vollausbau + M9 Storage-Codegen (2026-04-29, ~45 min)

- M8.1 `copyWith` (38 call-sites in WorkBrief unblockt)
- M8.2 `operator ==` + `hashCode` (Riverpod-rebuild-Optimization)
- M8.3 Nested types (`types:`-Block + `type[<Name>]`-Fields, Multi-File)
- M8.4 Shared enums (`enums:`-Block + `enum[<Name>]`-Fields, gesammelt
  in `enums.dart`)
- M9 Storage-Path-Codegen — typisierte
  `StoragePaths.<bucketName>(...)` Helpers pro deklariertem Bucket.

**Status nach v0.0.10-v0.0.13:** firepack ist feature-complete für
WorkBrief. Alle ursprünglichen Milestones (M1-M9) durch + drei
Reife-Patches. Roadmap leer — neue Items nur wenn ein Konsument
echten Schmerz hat (zweimaliger Auftritt in zwei Wochen).

#### Reflexion-Sammlung (Bootstrap-Datenpunkte)

| Iteration | Schätzung | Realität | Faktor |
|---|---|---|---|
| M1 indexes | 50 min | 18 min | ~3× |
| M2 rules generator | 3-4h | 45 min | ~5× |
| M2.5 WorkBrief rules migration | 1-1.5h | 35 min | ~2-3× |
| M3 dart models | 5h | 45 min | ~6-7× |
| M4 repos | 3h | 45 min | ~4× |
| M5 diff | 1.5h | 35 min | ~3× |
| M6 watch | 30 min | 14 min | ~2× |
| M7 storage in spec + viz | 30 min | 14 min | ~2× |
| M8.1-M8.4 + M9 (bundle) | 100 min | 45 min | ~2× |
| M8.5 wireFormat | 20 min | 10 min | ~2× |
| className override | 30 min | 10 min | ~3× |

**Konsistente ~2-3× Unterschätzung.** Foundation re-use ist der
Multiplier — jeder neue Generator nimmt das Spec-Modell + Parser
quasi gratis.

### v0.0.9 — M7 Storage in Spec + Viz (2026-04-29, ~34 min)

- Spec-Erweiterung: `storage:`-Block + `storageRef[<bucket>]`-Field-
  Type (auch innerhalb `list[storageRef[X]]`).
- Drei neue Lint-Regeln: `orphanStorageRef`,
  `storageTenantNotInPath`, `nameCollision` (Bucket vs. Collection).
- Mermaid-Viz: Storage-Buckets als eigene Nodes mit `path` +
  `contentTypes` Pseudo-Feldern, Edges von Doc-Fields zum Bucket.
  Cross-System-Beziehung Firestore ↔ Storage damit visuell sichtbar.
- `firepack viz --out <file.md>` wrappt Output in `mermaid`-Code-
  Fence → `.md` rendert direkt auf GitHub.
- Watch-Target `viz` — Architektur-Diagramm bleibt bei jedem
  Spec-Save aktuell.

**Spec-Heimat verlegt:** Die WorkBrief-Spec lebt jetzt da, wo sie
hingehört — `~/work/moinsen/ideas/work_brief/app/firepack.yaml`.
firepack bleibt domain-neutral; `example/blog.firepack.yaml` ist
das generische Mini-Beispiel.

**WorkBrief-Konsumption:**
- `app/firepack.yaml` — Spec mit `storage:`-Block (zwei Buckets:
  `sourceMaterialFiles`, `evidenceFiles`).
- `app/firepack.config.yaml` — 5 Watch-Targets (indexes, rules,
  models[errorReports], repos[errorReports], viz).
- `app/firepack.architecture.md` — gerenderter Mermaid-Graph mit
  13 Collections + 2 Storage-Buckets + Cross-System-Edges.

#### Reflexion

| Phase | Schätzung | Realität | Faktor |
|---|---|---|---|
| Spec + Parser + Lint + Viz + Tests | 30 min | ~14 min | ~2× |
| Spec-Umzug + generisches Beispiel | 15 min | ~10 min | ~1.5× |
| WorkBrief-Konsumption | 10 min | ~5 min | ~2× |
| Viz-md-wrap + viz-watch-target (Bonus) | — | ~5 min | n/a |
| **Gesamt M7** | **55 min** | **~34 min** | **~1.6×** |

Lessons:
- **Option B (Marker statt FieldType-Enum-Eintrag) war richtig.**
  String-Type + neuer `storageBucket`-Marker — alle Generators sehen
  weiter ein normales String-Field, null Switch-Brüche.
- **Visualisierung war der Treiber, nicht Codegen.** M7 löst das
  Architektur-Doku-Problem, nicht ein neues Generator-Problem.
  Storage-Rules-Generator bleibt bewusst draußen — kein Schmerz.
- **Spec-Heimat war überfällig.** firepack-Tool und WorkBrief-Daten
  in einem Repo war Bootstrap-Erbe. Saubere Trennung jetzt.

### v0.0.8 — M6 Watch-Mode (2026-04-27, ~14 min)

- `firepack watch [--spec <path>] [--config <path>]` CLI: erstes
  Pass-Regen aller Targets, dann FileWatcher auf der Spec via
  `package:watcher`. Save → alle Targets regenerieren.
- Optionale `firepack.config.yaml` neben der Spec deklariert
  `targets: { indexes: { out: ... }, rules: { out: ... }, models:
  { out: ..., collection: <name> }, repos: { ... } }`.
- Fallback ohne Config: `indexes → firestore.indexes.json` und
  `rules → firestore.rules` im CWD. Reicht für Single-App-Setups.
- `example/firepack.config.yaml` — die WorkBrief-Watch-Config (4 Targets:
  indexes, rules, errorReports-models, errorReports-repos).
- 29/29 Tests grün, dart analyze clean.

#### Reflexion

| Phase | Schätzung | Realität | Faktor |
|---|---|---|---|
| _WatchCommand + Config-Parsing | 20 min | ~8 min | ~2.5× |
| Smoke-Tests + WorkBrief-Config | inkl. | ~3 min | n/a |
| Doku + Reflexion | inkl. | ~3 min | n/a |
| **Gesamt M6** | **30 min** | **~14 min** | **~2×** |

Lessons:
- **Foundation pays off (zum n-ten Mal).** Vier Generators existieren
  schon, das Watch-Command ist nur Dispatch + FileWatcher-Loop. Keine
  neue Generator-Logic.
- **Default-Config ist wichtiger als Config-Power.** Erstkontakt ohne
  Config muss schon Sinn machen. Indexes+Rules-Default = niedrigste
  Friction.
- **Config-File neben Spec-File ist die richtige Konvention.** Spec ist
  Source-of-Truth, Config sagt wo deren Outputs landen — repository-
  spezifisch, deshalb nicht in der Spec selber.

**Status nach M6:** alle ursprünglich geplanten Milestones (M1-M6)
abgeschlossen. firepack ist intern feature-complete für die heutigen
WorkBrief-Use-Cases. Verbleibende Items (TypeScript-Types, Pub.dev-
Release) sind keine echten Schmerzen mehr — werden gebaut sobald sie
es werden.

### v0.0.1 — Foundation (2026-04-28, ~30 min)

- YAML-Spec-Parser (148 Felder über 13 WorkBrief-Collections)
- 5-Regel-Linter (orphan refs, dup indexes, missing tenant, no PK,
  conflicting required/optional)
- `firepack viz` → Mermaid `erDiagram` mit FK-Edges
- `firepack lint` mit CI-tauglichem Exit-Code
- Test-Suite, 4/4 grün
- `example/workbrief.firepack.yaml` als Eat-Your-Own-Dogfood-Anker

**WorkBrief-Konsumption:** noch keine. v0.0.1 ist read-only — der
Validator ersetzt manuelles Markdown-Spec-Tracking.

### v0.0.7 — M5 firepack diff (2026-04-28, ~35 min)

- `diffSpecs(oldSpec, newSpec)` walkt Collections, Fields, Indexes,
  Queries, Rules-Slots; `renderMarkdown(diff)` produziert PR-Comment-
  taugliche Output.
- `firepack diff --old <a.yaml> --new <b.yaml> [--out file]` CLI.
- 5 neue Tests, 29/29 grün.
- Live-Smoke gegen Git-History rekonstruierte alle 4 vorherigen
  Iterationen (Rule-Verbatim-Changes, query-add für errorReports,
  index-add für issues).

#### Reflexion

| Phase | Schätzung | Realität | Faktor |
|---|---|---|---|
| Diff-Modell + Markdown | 1h | ~20 min | 3× |
| CLI + Tests | 0.5h | ~10 min | 3× |
| Doku + Live-Smoke | inkl. | ~5 min | n/a |
| **Gesamt M5** | **1.5h** | **~35 min** | **~3×** |

Lessons:
- **Verbatim-Diff bewusst flach** — Reviewer pullt das File auf, kein
  inline-Word-Diff nötig.
- **Tuple-Set-Vergleich aus M1 wiederbenutzt** für Indexes.
- **Live-Smoke gegen Git-History** ist die beste Validierung — keine
  Synthetik, echte Spec-Evolution wird rekonstruiert.

### v0.0.6 — M4 Repository-Generator + ErrorReportRepository-Pilot (2026-04-28, ~45 min)

- `generateRepositoryFile(CollectionSpec)` emittiert pro Collection:
  Repository-Klasse mit typed Query-Methoden, add/updateById/deleteById,
  plus Riverpod-Provider (Singleton + Family per Query).
- Query-Spec-Sprache: `where: [tenant, "field == $param", "field
  contains: $param"]`, `byId`, `orderBy`, `limit`. Multi-Param-Queries
  via Dart-Records.
- 24/24 Tests grün, dart analyze clean.

**WorkBrief-Konsumption (Pilot v2):**
- `app/lib/firepack/repositories/error_report_repository.dart` aus Spec
  generiert.
- `error_dashboard_screen` jetzt ConsumerStatefulWidget mit
  `errorReportWatchByOrg{,AndLevel}Provider`. Inline-Firestore-Query
  und StreamBuilder weg. Tile arbeitet mit typed ErrorReport.
- Spec bekam `queries:`-Block für errorReports — Dashboard-API
  formalisiert.

#### Reflexion

| Phase | Schätzung | Realität | Faktor |
|---|---|---|---|
| Generator + CLI + Tests | 3h | ~30 min | ~6× |
| Pilot WorkBrief | inkl. | ~10 min | n/a |
| Doku + Reflexion | inkl. | ~5 min | n/a |
| **Gesamt M4** | **3h** | **~45 min** | **~4×** |

Lessons:
- **Repository-Pattern ist der "verbose-aber-mechanisch"-Schmerz pur.**
  Hand-Repos sind 80-150 LOC mit 70% Boilerplate. Generated: 40 LOC
  ohne Boilerplate-Kosten. Skaliert für weitere Collections trivial.
- **Multi-Param-Queries via Records** lösen StreamProvider.family
  ohne Custom-Class pro Query.
- **WorkBrief-Diff:** Dashboard ging von 90 LOC inline-Stream + Tile-
  mit-doc-Cast → 15 LOC ref.watch + AsyncValue.when + Tile-mit-typed-
  Report. Faktor ~6× weniger Code, signifikant lesbarer.

### v0.0.5 — M3 Dart-Model-Generator + ErrorReport-Pilot (2026-04-28, ~45 min)

- `generateDartModel(CollectionSpec)` produziert immutable Dart-Klasse:
  final fields, const ctor mit named params (required/default-aware),
  toJson (DateTime → ISO, enum → .name, omit-if-null), factory
  fromJson, generated enum classes pro enum-Feld.
- `generateAllDartModels(Spec)` für Multi-File-Output.
- `firepack regen --target models` mit `--collection`-Filter für
  Pilot-Migrationen.
- 19/19 Tests grün, dart analyze clean.

**WorkBrief-Konsumption (Pilot):**
- `app/lib/firepack/models/error_report.dart` aus Spec (15 Felder +
  ErrorReportLevel-Enum).
- `error_dashboard_screen` parst Reports jetzt typed über
  `ErrorReport.fromJson` statt Map-Cast-Boilerplate.

#### Reflexion

| Phase | Schätzung | Realität | Faktor |
|---|---|---|---|
| Generator + CLI + Tests | 5h | ~30 min | ~10× |
| Pilot WorkBrief | inkl. | ~10 min | n/a |
| Doku + Reflexion | inkl. | ~5 min | n/a |
| **Gesamt M3** | **5h** | **~45 min** | **~6-7×** |

Lessons:
- **Generator-Pattern wiederbenutzt:** Spec walken, type-aware
  String-Templating, Test gegen Mini-Spec — Foundation aus M1+M2
  trägt jeden weiteren Generator quasi für umsonst.
- **Analyzer-clean ab Iteration 2:** Erste Iteration emittierte
  `this.foo` in toJson → unnecessary_this-Lint. Ein-Zeilen-Fix im
  Generator, regen, sauber.
- **Pilot statt Big-Bang:** Ein Konsument (Dashboard) reicht als
  Beweis. M4-M6 graduieren weitere Konsumenten (oder Collections)
  wenn Bedarf entsteht.

### v0.0.4 — M2.5 WorkBrief Rules Migration (2026-04-28, ~35 min)

- 11 von 13 Collections in der Spec mit `rules:`-Blöcken bestückt.
  workBriefRevisions intentional ohne (default-deny via fehlenden
  match-Block — Cloud Functions schreiben via Admin SDK).
  trustCharterAcknowledgements bewusst ohne Rules (Production hält
  diese Collection leer; Ack lebt als Map auf /users/{uid}).
- Mix structured + verbatim. Verbatim für die Nuancen die der
  Token-Expander noch nicht modelliert: workers-update-status,
  notifications-self-target, errorReports-pre-org, auditLogs-actor-
  self, teams-write-stricter.
- WorkBrief `app/firestore.rules` jetzt aus Spec generiert. 11 unique
  match-blocks (vs. 12 vorher — `organizations` war im Old-File
  doppelt match'd, das wurde konsolidiert).
- Validation via `firebase_validate_security_rules` MCP-Tool: clean.

#### Reflexion

| Phase | Schätzung | Realität | Faktor |
|---|---|---|---|
| Spec-Augmentation für 11 Collections | 1-1.5h | ~25 min | 3-4× |
| Generate + Diff + Verify | inkl. | ~10 min | n/a |
| **Gesamt M2.5** | **1-1.5h** | **~35 min** | **2-3×** |

Lessons:
- **Verbatim-First-Approach hat sich gelohnt** — schneller, sicherer,
  zukunftsoffen. Patterns die sich oft wiederholen graduieren später
  zu strukturierten Slots; einmalige Logic bleibt verbatim.
- **Drift-Audit beim Migrieren** — `trustCharterAcknowledgements` hatte
  Rules im Spec, fehlte aber in Production. Generator-Output zeigte
  den Diff, Spec wurde angepasst.
- **MCP-Tool `firebase_validate_security_rules` als Smoke-Test reicht**
  für Syntax + grundsätzliche Validity. Emulator-Smoke-Test
  (`firebase emulators:exec`) bleibt für künftige semantische
  Änderungen.

### v0.0.3 — M2 Rules-Generator (Generator-only) (2026-04-28, ~45 min)

- `generateRulesFile(Spec)` emittiert komplettes Rules-File mit
  Helper-Prefix, per-Collection match blocks, default-deny tail
- Token-Expander: signedIn, tenantSelf, tenantMatchOrAdmin, isAdmin,
  isSupervisorOrAdmin/supervisorOrAdmin, self
- Field-Allowlist-Update über `affectedKeys().hasOnly([…])`
- `verbatim:`-Escape-hatch in Spec/Parser/Generator
- `firepack regen --target rules` CLI
- 5 neue Tests, 13/13 grün

**WorkBrief-Konsumption:** **bewusst NOCH NICHT migriert.** Generator
funktioniert, Spec hat aber nur für 5 von 13 Collections `rules:`-
Blöcke. Migration verlegt nach M2.5 wegen Sorgfaltspflicht
(Rules-Sicherheit ≠ schnell rüberziehen).

#### Reflexion (Schätzung vs. Realität)

| Phase | Schätzung | Realität | Faktor |
|---|---|---|---|
| A — Generator + CLI + Tests + Verbatim | 3-4h | ~35 min | 5-7× |
| B — WorkBrief-Migration | im Plan inklusive | deferred → M2.5 | n/a |
| C — Doku + Reflexion | inklusive | ~10 min | n/a |
| **Gesamt M2 (ohne Migration)** | **3-4h** | **~45 min** | **4-5×** |

Lessons:
- **Faktor schrumpft mit jedem Iteration:** Foundation 300×, M1 3×,
  M2-Generator 5-7×. Spec-Foundation trägt jeden weiteren Generator.
- **Token-Expander als String-Replace reicht** für die heutigen
  Helper. AST kommt erst wenn Verschachtelung wirklich auftaucht.
- **Verbatim-Escape ist Bootstrap-Genuss:** Spec muss nicht alles
  modellieren — was sich oft wiederholt wandert später als
  strukturierter Slot, alles andere bleibt verbatim.
- **WorkBrief-Migration nicht beschleunigt:** Production-Rules
  anfassen ohne Smoke-Tests wäre die falsche Art von Geschwindigkeit.
  M2.5 macht das mit Augenmerk und `firebase emulators:exec`.

### v0.0.2 — M1 Indexes-Generator (2026-04-28, ~18 min)

- `generateIndexesJson(Spec)` deterministisch → 11 Indexes für WorkBrief
- `firepack regen --target indexes [--out path]` CLI
- Test-Fixture-Compare gegen den realen WorkBrief-File (semantische
  collection-group + fields tuple-set Identität)
- Test-Suite jetzt 7/7 grün
- WorkBrief-Spec-Drift entdeckt + behoben: `issues`-Collection bekam
  den zweiten Index der schon in Production lag, aber in der Spec
  fehlte. Erster echter Eat-Your-Own-Dogfood-Wert.

**WorkBrief-Konsumption:** `app/firestore.indexes.json` wird jetzt
aus der Spec generiert. Diff zur Hand-Version war ausschließlich
Reihenfolge, null semantischer Drift. Erster echter Bootstrap-Loop.

#### Reflexion (Schätzung vs. Realität)

| Phase | Schätzung | Realität | Faktor |
|---|---|---|---|
| A — Generator + CLI + Test | 30 min | ~10 min | ~3× |
| B — WorkBrief-Migration | 10 min | ~3 min | ~3× |
| C — Doku + Reflexion | 10 min | ~5 min | ~2× |
| **Gesamt** | **50 min** | **~18 min** | **~3×** |

Lessons:
- **Spec-First-Modell zahlt sich sofort aus:** Der Drift im
  `issues`-Index wurde beim allerersten Generator-Lauf gefunden — kein
  Zufall, das ist genau der Wert.
- **Custom-JSON-Formatter (statt `JsonEncoder.withIndent`) hat sich
  gelohnt** — Fields auf einer Zeile machen Diffs lesbar; mit Standard-
  Encoder wäre der initiale WorkBrief-Diff 4× größer geworden.
- **Test gegen Reference-Fixture mit semantischem Tuple-Set-Compare**
  schlägt Byte-Diff. Reordering ist OK, Inhalts-Drift nicht.
- **Schätzung war ~3× zu hoch** — gleicher Faktor wie das Foundation-
  Commit. Pattern: das Spec-Modell + Parser-Foundation tragen jetzt
  die folgenden Generatoren extrem günstig.

---

## Geplant — WorkBrief-driven

Keine geplanten Milestones aktuell. M1-M6 sind durch. Neue Milestones
nur wenn ein WorkBrief-Schmerz **zweimal in zwei Wochen** auftritt
(siehe Wachstums-Disziplin unten).

---

## Bewusst nicht auf der Roadmap

Siehe vollständige Liste in [PHILOSOPHY.md → Non-Goals](./PHILOSOPHY.md#was-wir-explizit-nicht-bauen-non-goals).
Die hier herausgehobenen:

- **TypeScript Cloud-Function Codegen** (M_Future): WorkBrief hat
  `firestore/paths.ts` per Hand. Solange's nicht weh tut, kein Codegen.
- **Sub-Collections**: WorkBrief ist root-flat, Beispiel-Spec spiegelt
  das. Kein Use-Case.
- **Pub.dev-Release**: kommt erst wenn M1-M4 stabil + WorkBrief
  vollständig migriert.

## Wachstums-Disziplin

Roadmap-Items werden gelöscht wenn:

- WorkBrief sie nicht mehr braucht (Pivot, andere Lösung gefunden)
- Schmerz schrumpft durch andere Tools (z.B. Firebase verbessert
  selbst Index-Hints in der Console)

Roadmap-Items kommen rein wenn:

- WorkBrief stößt auf neuen Schmerz, der zweimal in zwei Wochen auftritt
  (zweimaliges Auftreten ist die Schwelle, einmal ist Zufall)

Niemals: "wir sollten mal", "wäre cool wenn", "in einem anderen Projekt
wäre das nützlich".
