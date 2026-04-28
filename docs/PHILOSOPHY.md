# firepack — Philosophie

## Das Prinzip: Bootstrap-Entwicklung

Firepack wird nicht **für** WorkBrief gebaut, sondern **mit** WorkBrief. Wie
früher Compiler — der erste echte Test ist, dass das Tool sich selbst (oder
das Hauptprojekt) bauen kann. Jede Entscheidung im Tool kommt aus einem
realen Schmerz, der gerade in der App auftaucht. Kein Feature wandert in
firepack, bevor WorkBrief es konsumiert.

**Praktisch heißt das:**

1. Wir treffen in WorkBrief auf einen Schmerz (Schema-Drift, Rules-Audit,
   Index-Fail-At-Runtime, Repo-Boilerplate).
2. Wir fragen: *Kann firepack das ohne weiteren Stack-Aufbau lösen?*
3. Wenn ja: wir bauen es in firepack als nächste Iteration und konsumieren
   es in WorkBrief sofort. Zwei Commits — ein Feature in firepack, ein
   Refactor in WorkBrief.
4. Wenn nein: wir bauen es in WorkBrief händisch. Erst beim **zweiten** oder
   **dritten** Auftreten desselben Pains lohnt der Generator.

> Eine Regel fürs Bootstrappen: ein Feature wird nicht spekulativ gebaut.
> Es wird gebaut, weil **gerade heute** in WorkBrief etwas nicht klappt.

## Was wir explizit nicht bauen (Non-Goals)

Diese Liste ist genauso wichtig wie die Roadmap. Sie schützt uns vor
Scope-Creep. Wenn jemand "wäre cool wenn …" sagt, fragen wir: kommt das in
WorkBrief vor? Wenn nein → diese Liste verlängern, nicht einbauen.

| Feature | Warum nicht (jetzt) |
|---|---|
| Sub-Collections (`organizations/{orgId}/users/...`) | WorkBrief ist root-flat mit `organizationId`-Field. Kein Bedarf. |
| Multi-DB / Per-Tenant Firestore-Database | Erst relevant ab ~1000 Pilots (siehe `firebase-stack.md`-Trigger). |
| Postgres / Data Connect / SQL-Backend | WorkBrief ist Firestore-only. |
| Visueller Drag-and-Drop-Editor | Mermaid-Output ist gut genug. YAML-Editor mit Schema-Validation reicht für Solo-Dev-Use-Case. |
| Watch-Mode mit Auto-Regen | `firepack regen` manuell ist scharf genug. build_runner-Style ist ein Goldstein. |
| pub.dev-Release | Erst wenn WorkBrief vollständig migriert ist UND firepack drei Iterationen ohne Bruch durchgehalten hat. |
| Custom Rule-DSL (eigene Syntax statt Firestore-Rule-Pass-Through) | Wir generieren Firestore-Rules, kein eigenes Universum. Helper-Tokens (`tenantSelf`, `isAdmin`) reichen. |
| Migrations-Engine (auto-detect schema diff → migration script) | Firestore ist schemalos. Ein-Mal-Migrations sind Cloud-Function-Code, nicht Tool-Job. |
| AI-assistierte Spec-Generierung aus Existing-Code | Menschen schreiben Specs. Firepack prüft + generiert. Mehr nicht. |
| Schema-Versionierung im Spec-File (Time-Travel) | Git ist die History. Wir verlassen uns darauf. |
| Online-Viewer / hosted Visualization | Mermaid in einem Markdown-File ist überall renderbar. Hosting-Aufwand lohnt nicht. |
| Riverpod-3-Migration-Adapter | WorkBrief ist auf Riverpod 2. Wenn Riverpod 3 kommt, generieren wir für 3. Kein Doppel-Codegen. |
| TypeScript Cloud-Functions Codegen | WorkBrief hat das mit `firestore/paths.ts` per Hand abgedeckt — schmerzfrei genug. Erst aufnehmen wenn TS-Drift wirklich auftaucht. |

## Wie das Bootstrap-Prinzip die Architektur prägt

Drei konkrete Konsequenzen:

**1. Spec-Format ist YAML, nicht eigene DSL.** Eine Custom-DSL würde uns
zwingen, Parser-/Tooling-Aufwand zu treiben, der mit WorkBrief nichts zu
tun hat. YAML hat Tooling überall.

**2. Codegen-Output ist nativer Firestore-Code, kein Wrapper-Layer.** Wenn
firepack stirbt, steht der generierte Code allein. Du kannst den `regen`
einmal laufen lassen, das Tool wegwerfen, und mit dem Output normal
weiterprogrammieren. **Keine Lock-In.** Das ist der wichtigste
Vertrauens-Faktor für ein junges Tool.

**3. Jede Iteration produziert eine WorkBrief-Pull-Request.** Nicht "Feature
landet in firepack v0.0.5, irgendwann nutzen wir's". Sondern "v0.0.5 wird
sofort in WorkBrief eingesetzt, sonst war's nicht gebraucht". Wenn die
Migration sich zäh anfühlt, ist das ein Hinweis dass das Feature
falsch designt ist.

## Wie wir Scope-Drift erkennen

Drei Smell-Signals:

- **"Allgemeingültigkeit":** "Andere Apps könnten das auch brauchen". → Wenn
  WorkBrief es nicht braucht, ist's Spekulation.
- **"Eleganz statt Pragmatik":** "Wir könnten die Spec-Sprache mit
  Vererbung schöner machen". → YAML ist hässlich aber bekannt. Hässlich
  schlägt elegant solange WorkBrief läuft.
- **"Pre-Mature-Optimization":** "Codegen-Performance, parallele
  Generatoren". → Wir generieren <50 Files, das ist immer schnell genug.

Wenn einer von diesen drei Signals auftaucht: pause, frag den Vibe-Check
"Hat WorkBrief das gerade gebraucht?".
