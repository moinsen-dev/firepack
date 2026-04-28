# firepack — Roadmap

**Bootstrap-Driven.** Jeder Meilenstein löst einen konkreten WorkBrief-
Schmerz. Die Reihenfolge richtet sich nach Schmerzhärte × Aufwand, nicht
nach Architektur-Eleganz. Siehe [PHILOSOPHY.md](./PHILOSOPHY.md).

## Done

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

Jeder Meilenstein hat:
- den **Schmerz**: was in WorkBrief heute nervt
- die **Lösung**: was firepack dafür generiert
- den **Migrations-PR**: was sich in WorkBrief ändert
- einen **Aufwand**: realistische Schätzung

### M3 — Dart-Model-Generator (`freezed`-replacing)

**Schmerz:** Field-Add berührt 9 Files. Letztens am `canBeAssigned`-
Beispiel gezählt: AppUser (Domain) + AppUser.freezed (auto) + AppUser.g
(auto) + role_extensions + 3 Repository-Stellen + Profile-UI-Toggle +
Router. Auto-gen-Files sind 47 Zeilen Diff für 1 Feld.

**Lösung:** `firepack regen --target models` schreibt für jede Collection:
- `lib/firepack/models/<collection>.dart` — Freezed-äquivalente Klasse,
  aber selbst-generiert (nicht via build_runner). Kein `freezed`-Dep.
- Enum-Klassen für `enum`-Felder
- Nested-Type-Klassen für `list[Type]`-Felder

JsonSerializable-Compatible (toJson/fromJson generiert mit), so dass
existing Repos weiter funktionieren.

**Migrations-PR:** WorkBrief startet mit **einer** Collection als Pilot
(`errorReports` — isoliert, keine UI-Konsumenten). Generated Model
ersetzt das hand-geschriebene. Wenn das durchgeht, dann der Rest in
einem zweiten PR.

**Aufwand:** ~5h. Tricky bei nested Freezed-Types (`tasks: list[DraftTask]`).
Pragma: erste Iteration nur Top-Level-Models, nested wird durch
inline-Map-Type abgehandelt; nested-Codegen kommt in M3.5 wenn Bedarf
auftritt.

---

### M4 — Repository-Generator

**Schmerz:** Repo-Pattern ist sauber, aber 13× das gleiche Boilerplate:
constructor mit `_firestore`, `watchByOrg(orgId)`, `watchById(id)`,
`add(model)`, `update(model)`, alles mit den Path-Konstanten + tenant-
Helper aus `core/data/`. ~80-150 Zeilen pro Repo, davon ~70% mechanisch.

**Lösung:** `firepack regen --target repos` liest die `queries:`-Blöcke
und schreibt typisierte Repos:

```dart
// generated for `queries: { watchByOrg, watchById, watchByAssignee }`
class WorkBriefRepository {
  final FirebaseFirestore _firestore;
  WorkBriefRepository(this._firestore);

  Stream<List<WorkBrief>> watchByOrg(String orgId) =>
      _firestore.collection(FirestorePaths.workBriefs)
                .scopedToOrg(orgId)
                .orderBy('createdAt', descending: true)
                .snapshots()
                .map((snap) => snap.docs.map((d) => WorkBrief.fromJson(d.data())).toList());

  Stream<WorkBrief?> watchById(String id) => …;

  Stream<List<WorkBrief>> watchByAssignee(String orgId, String uid) => …;
}
```

Plus die Riverpod-Provider als zweiter Output (Family für argumentierte
Streams).

**Migrations-PR:** Erste Collection (vermutlich `errorReports` wie in M3).
Hand-Repo wird gelöscht, Generated steht; UI/Service zeigt auf
Generated-Provider.

**Aufwand:** ~3h. Templates sind die meiste Arbeit — die Logik ist
mechanisch.

---

### M5 — `firepack diff`

**Schmerz:** PR-Reviewer sehen `firepack.yaml` ändert sich, müssen aber
mental rausfischen "ist das ein neues Feld, ein Type-Change, eine neue
Rule?".

**Lösung:** `firepack diff <old.yaml> <new.yaml>` druckt ein menschen-
lesbares Diff: "+ workBriefs.priority added (enum), - workBriefs.dueDate
required → optional, ~ users update rule allowlist now includes
canBeAssigned". Auch Migration-Hints: "Action required: existing
workBriefs without `priority` → set default `normal`".

**Migrations-PR:** GitHub Action die `firepack diff` zwischen Base + PR-
Branch laufen lässt und das Output als PR-Comment postet. Reviewer
sehen die semantische Änderung sofort.

**Aufwand:** ~1.5h.

---

### M6 — Watch-Mode

**Schmerz:** `firepack regen` manuell zu triggern beim YAML-Editieren
nervt. Dev-Loop bricht.

**Lösung:** `firepack watch` mit `package:watcher`. Triggert `regen`
on-save. Kompatibel mit IDE-Save.

**Aufwand:** ~30min. Letzte Iteration weil M1-M5 die wichtigeren
Schmerzen sind.

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
