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

## Install

Pre-pub-dev release, install from a local clone:

```bash
git clone https://github.com/moinsen-dev/firepack ~/work/firepack   # or wherever
dart pub global activate --source path ~/work/firepack
```

Make sure `~/.pub-cache/bin` is in your PATH:

```bash
export PATH="$PATH:$HOME/.pub-cache/bin"   # add to ~/.zshrc or ~/.bashrc
```

Verify:

```bash
firepack --help
```

When the firepack source updates, just re-run the activate command —
path-source activations track the working tree, so `git pull` is
enough day-to-day.

## CLI

| Command | Effect |
|---|---|
| `firepack lint --spec <path>` | validates the spec (orphan refs, storage refs, missing tenants, …) |
| `firepack viz --spec <path> [--out file.md]` | renders Mermaid `erDiagram`. `.md` wraps in code-fence for inline GitHub render. |
| `firepack regen --target <indexes\|rules\|models\|repos> --spec <path>` | one-shot codegen for one target |
| `firepack watch --spec <path> [--config <path>]` | first-pass regen + watch the spec; re-runs on save. Targets defined in `firepack.config.yaml` next to the spec. |
| `firepack diff --old <a.yaml> --new <b.yaml>` | semantic diff between two specs (PR-comment shape). |

## Status

**Today (v0.0.13):**
- ✅ YAML spec parser + lint
- ✅ Mermaid `firepack viz` output (`.md` auto-wraps in code fence)
- ✅ Indexes generator (`firestore.indexes.json`, deterministic)
- ✅ Rules generator (`firestore.rules`, with verbatim escape hatch)
- ✅ Dart model codegen — immutable class with `copyWith`,
  `operator ==` / `hashCode`, `toJson`/`fromJson`, nested types,
  shared enums with snake_case wireFormat
- ✅ Repository + Riverpod provider codegen (typed queries from spec)
- ✅ Per-Collection `className:` override
- ✅ `firepack diff` (PR-comment-shape semantic diff)
- ✅ `firepack watch` (auto-regen on save, multi-target via config)
- ✅ Storage refs + typed `StoragePaths.<bucket>()` helpers
- ☐ TypeScript-types generator
- ☐ Pub.dev release
- ☐ CI for firepack itself

**WorkBrief consumption today:**
- ✅ `firestore.indexes.json` — generated since v0.0.2
- ✅ `firestore.rules` — generated since v0.0.4
- ✅ `lib/firepack/models/*.dart` — **12 of 13 collections** generated
  (all except `trustCharterAcknowledgements` which is a nested map
  on org/user docs, not its own collection)
- ✅ `lib/firepack/repositories/*.dart` — generated repos for 8
  collections; hand-repos that have mutation logic wrap them
  (Watch-Methoden generated, Mutations bleiben hand)
- ✅ `lib/firepack/storage_paths.dart` — typed Storage-Pfade konsumiert
  von evidence + sourceMaterials Upload-Code (drift-sicher)
- ✅ `firepack.architecture.md` — Mermaid-Graph der ganzen
  Datenarchitektur (13 Collections + 3 Nested Types + 2 Storage-
  Buckets + alle FK / Composition / Storage-Edges)

## Examples

`example/` is a self-contained Flutter + Riverpod app that consumes
firepack-generated code. It contains:

- `example/firepack.yaml` — generic mini-spec exercising every feature
  (collections, indexes, queries, rules, storage refs).
- `example/lib/firepack/**` — generated models, repositories,
  storage paths (committed so `flutter analyze` works on a fresh clone).
- `example/lib/main.dart` — minimal UI consuming the generated
  Riverpod providers.

`flutter analyze` on this app is wired into `just check`, so a
generator change that emits broken Dart fails the build immediately.

The real-world driver is **WorkBrief** — its spec lives in the
WorkBrief repo at `app/firepack.yaml`, not in this repository.
firepack stays domain-neutral; consumers own their own specs.

## License

MIT — see [LICENSE](./LICENSE).
