# Changelog

Alle bemerkenswerten Änderungen — bootstrap-style, jeder Release durch
einen WorkBrief-Konsumptions-Schritt motiviert.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Planning
- M2 Rules-Generator als nächste Iteration

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
