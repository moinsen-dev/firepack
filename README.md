# firepack

> Spec-driven Firestore + Flutter codegen. Stop hand-writing the same
> repository / provider / rule fragment / index / TypeScript-type for
> every new collection.

**Status:** v0.0.1 — internal-first. Used as the data-layer generator
for [WorkBrief](https://workbrief.app). Public release planned once the
spec format stabilises (~weeks).

> **Read first:**
> - [docs/PHILOSOPHY.md](./docs/PHILOSOPHY.md) — Bootstrap-Prinzip + Non-Goals.
>   firepack wird mit WorkBrief gebaut, nicht für WorkBrief.
> - [docs/ROADMAP.md](./docs/ROADMAP.md) — Was als nächstes. Jeder
>   Meilenstein löst einen WorkBrief-Schmerz.
> - [docs/SPEC.md](./docs/SPEC.md) — Formale Spec-Reference (v1).

## What you write (one file, `firepack.yaml`)

```yaml
firepack: 1
project: workbrief

collections:
  workBriefs:
    tenant: organizationId       # auto-injects org-scoped queries + rule check
    fields:
      id:               { type: string, primaryKey: true }
      title:            { type: string, required: true }
      status:
        type: enum
        values: [draft, published, inProgress, completed, cancelled]
        default: draft
      createdAt:        { type: dateTime, required: true, serverDefault: now }
      organizationId:   { type: string, required: true }   # tenant target

    indexes:
      - fields: [organizationId, createdAt:desc]

    rules:
      read:   signedIn && tenantMatchOrAdmin
      create: signedIn && supervisorOrAdmin && tenantSelf
      update:
        - role: supervisorOrAdmin && tenantSelf -> all
      delete: false
```

## What you get back (deterministic codegen)

```
your-app/
├─ lib/firepack/
│  ├─ models/work_brief.dart
│  ├─ repositories/work_brief_repository.dart
│  ├─ providers/work_brief_providers.dart
│  └─ paths.dart                   # FirestorePaths.workBriefs etc.
├─ functions/src/firepack/
│  ├─ types/work_brief.ts
│  └─ paths.ts
├─ firestore.rules                 # generated
└─ firestore.indexes.json          # generated
```

Plus: `firepack viz` opens a Mermaid-rendered data-model graph in your
browser. Click a field, see who reads/writes it.

## Why

Adding one field today fans out across nine files (Dart model, freezed
gen, json gen, two repositories, router, two UI screens, security
rules, indexes). The fan-out is mechanical and error-prone — exactly
the shape of work a generator should own. firepack collapses it to one
diff in `firepack.yaml`.

## CLI

| Command | Effect |
|---|---|
| `firepack init` | scaffolds a starter `firepack.yaml` next to your `pubspec.yaml` |
| `firepack lint` | validates the spec (orphan refs, missing tenants, …) |
| `firepack viz` | opens an HTML data-model graph in the default browser |
| `firepack regen` | one-shot codegen of all targets |
| `firepack watch` | re-generates on every save (build_runner-style) |
| `firepack diff` | shows what changed since last regen |
| `firepack rules:audit` | shells into the firestore-security-rules-auditor agent skill |

## Status

**Today (v0.0.3):**
- ✅ YAML spec parser + lint
- ✅ Mermaid `firepack viz` output
- ✅ Indexes generator (`firestore.indexes.json`, deterministic)
- ✅ Rules generator (`firestore.rules`, with verbatim escape hatch)
- ☐ Dart model codegen
- ☐ Repository + provider codegen
- ☐ TypeScript-types generator
- ☐ Watch mode
- ☐ Pub.dev release

**WorkBrief consumption today:**
- ✅ `firestore.indexes.json` — generated from spec since v0.0.2
- ☐ `firestore.rules` — generator built, migration pending (M2.5)

## Eat-your-own-dogfood reference

`example/workbrief.firepack.yaml` is the live data-model spec for
WorkBrief, regenerated and diffed against the production schema.

## License

MIT — see [LICENSE](./LICENSE).
