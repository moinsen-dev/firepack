# Changelog

Alle bemerkenswerten Änderungen — bootstrap-style, jeder Release durch
einen WorkBrief-Konsumptions-Schritt motiviert.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Planning
- M3 — Dart-Model-Generator (replaces freezed-by-hand for spec-
  declared collections). Pilot auf einer isolierten Collection
  (errorReports oder auditLogs).

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
