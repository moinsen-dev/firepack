# STATE — firepack

> **Frozen:** 2026-04-29 ~22:30
> **Branch:** develop
> **Last commit:** bdf8915 · feat(repos): whereIn support
> **Dirty:** 3 files modified by user (example/firepack.config.yaml,
> test/indexes_generator_test.dart, test/parser_test.dart) — vermutlich
> Anpassung des Beispiel-Setups parallel zu Claude-Arbeit.

## Last work-unit

v0.0.13 published (lokal): feature-complete für WorkBrief-Use-Case.
Letzte Iteration war whereIn-Support in der Query-Sprache:
`"field in [a, b, c]"` und `"field in $param"` — unblockt zwei
WorkBrief-hand-Stellen (issues.watchOpenByOrganization,
notifications.watchByUser). Provider-Family-Type folgt jetzt dem
Param-Typ statt fest String. 4 neue Tests, 49/49 grün.

CHANGELOG + ROADMAP + README sind catch-uped auf v0.0.13.

## Next intended step

**Keine zwingende nächste Stufe.** firepack erreicht den
"feature-complete für WorkBrief"-Status. Weitere Iterationen brauchen
echten Schmerz-Trigger:

- TypeScript-Types-Generator (M10) — geplant in CHANGELOG, kein
  WorkBrief-Schmerz heute (Functions side hand-typed, nicht weh)
- Pub.dev-Release (M11) — wenn zweiter externer Konsument auftaucht
- CI für firepack — nice to have
- timestamp-wireFormat für dateTime-Felder — würde trustCharter-
  Migration in WorkBrief unblocken; nur 1 use-case derzeit
- Hygiene-TODOs (Map non-empty defaults StateError, inline-vs-shared-
  enum-toJson-Inkonsistenz) — dokumentierte Limitierungen, kein
  aktueller Schmerz

## Open friction

- **3 dirty files** aus paralleler User-Arbeit am example/-Setup.
  Vor jeder Aktion `git status` checken, eventuell User fragen ob
  die committed werden sollen.
- **example/-Verzeichnis** wurde zu echter Flutter-App umgebaut
  (von User), inkl. macOS, firebase.json, justfile, CLAUDE.md.
  Das ist jetzt ein Zweit-Konsument neben WorkBrief — möglicherweise
  hilfreich für CI / Doku-Beispiele.

## Live context for the agent

- **firepack-Code:** 13 Iterationen (M1-M9 + 4 Reife-Patches), Tests
  49/49 grün, dart analyze clean.
- **Konsumenten:** WorkBrief (12/13 Collections, 9 generated repos),
  example/ (mini-blog Demo).
- **firepack global aktiviert:** `dart pub global activate --source path
  /Users/udi/work/moinsen/opensource/firepack` — `firepack` CLI auf PATH.
- **Snapshot-Cache-Hinweis:** `firepack`-CLI nutzt einen pre-compiled
  Snapshot. Bei Source-Änderung Snapshot löschen vorm Re-Aktivieren:
  `rm -f .dart_tool/pub/bin/firepack/firepack.dart-3.11.5.snapshot`.
- **User mood:** Pushy aber konsolidierend. Wellen B-E abgelehnt.

## How to resume

User sagt **`weiter`** oder **`wo waren wir`** in firepack-Kontext:

1. Lies diese Datei.
2. Verifiziere:
   ```
   git log -5 --oneline
   git status -s
   dart test 2>&1 | tail -3
   ```
3. Wenn die 3 dirty files immer noch da sind → erst klären
   (committed? reverted? oder absichtlich offen?).
4. 3-4 Sätze an User: "firepack ist auf v0.0.13, feature-complete
   für WorkBrief. Letzte Iteration war whereIn-Support. Es liegen
   noch 3 example-Files dirty. Was als nächstes?"
5. Auf User warten.
