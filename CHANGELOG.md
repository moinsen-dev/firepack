# Changelog

Alle bemerkenswerten Änderungen — bootstrap-style, jeder Release durch
einen WorkBrief-Konsumptions-Schritt motiviert.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Planning
- Docs (PHILOSOPHY, ROADMAP, SPEC) — Single-Source-of-Truth Setup
- M1 Indexes-Generator als nächste Iteration

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
