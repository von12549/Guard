# Guard plans

This directory is the planning authority for the Guard (V4 Guards) product repository. It holds
repository governance, not package content. `core/runtime/Test-V4Package.ps1` excludes `docs/plans/**`
from package authority, so nothing here ships in a release archive.

| Location | Contents | Mutability |
| --- | --- | --- |
| `docs/plans/<id>.md` + `<id>.plan.json` | New Guard formal Plan pairs (V4 native Plan format, `core/contracts/plan.schema.json`) | Maintained |
| [`product/`](product/README.md) | Maintained product decisions, roadmap, runtime architecture, provenance and deferred backlog | Maintained |
| [`history/`](history/README.md) | Byte-exact copies of the generic V4 formal Plans from the IFX incubation period | Read-only history |
| `authorizations/` | Single-use trust-change authorization records (`core/contracts/trust-change-authorization.schema.json`), added only by an `authorization` Plan and deleted by the consuming `trust-change` diff | Transient |
| [`migration/`](migration/) | V4-TODO-008 standalone extraction program: master Plan, handoff and execution checklist | Program record |

IFX adoption material stays in the IFX repository (`von12549/IFX`) and is not maintained here. That
material covers the `ifx_profile` Profile, bundles and reviews, the P10 validation and parity program,
cutover and rollback proposals, and coexistence with V3/V3_ifx. Guard treats IFX as one consumer of its
releases.

Migration provenance (path dispositions, commit map, release inventory and receipt) lives under
[`../migration/v4-todo-008/`](../migration/v4-todo-008/README.md).
