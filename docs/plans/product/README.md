# V4 product planning

This directory holds the maintained product planning authority for V4 Guards. V4 is a standalone
product. It is not a V3 sub-plan and not an IFX application component.

Current documents:

| Document | Role | Status |
| --- | --- | --- |
| [00-architecture-decision-set.md](00-architecture-decision-set.md) | Product, trust, state, profile, stage, CI and planning decisions | Accepted v1 core, gate-audited V4-P9 UI boundary and accepted post-v1 M1–M5 foundation decisions |
| [01-v4-self-contained-guard-plugin.md](01-v4-self-contained-guard-plugin.md) | V4 implementation roadmap | P0–P9 complete; 1.1.4 released; consumer adoption owned by consumers |
| [02-runtime-architecture.md](02-runtime-architecture.md) | Runtime, roots, detector composition, evidence, UI and trust diagrams | Published v1 architecture plus the public extension-composition boundary |
| [03-genesis-bootstrap-and-autonomy.md](03-genesis-bootstrap-and-autonomy.md) | Finite V3 genesis and V4 autonomy transition (incubation period) | Dormant G1; activation not authorized |
| [04-layerguard-provenance.md](04-layerguard-provenance.md) | Architecture-rule provenance and clean-room boundary | Accepted provenance record |
| [05-p9-gate-audit.md](05-p9-gate-audit.md) | P9 certification, authority-boundary and first-release exclusion audit | PASS |
| [TODO.md](TODO.md) | Explicit deferred scope, P9 first-release exclusions and revisit gates | Active backlog |
| [`../migration/`](../migration/) | V4-TODO-008 standalone repository extraction program | In progress; remote tranches not yet authorized |
| [`../history/`](../history/README.md) | Byte-exact generic V4 formal Plans from the IFX incubation period | Historical |

Status meanings:

- `ACCEPTED`: part of the V4 v1 architecture unless a later recorded decision supersedes it.
- `PROPOSED`: must be resolved by the named prototype or review gate before dependent implementation.
- `DEFERRED`: excluded from V4 v1 and tracked in `TODO.md`.
- `REJECTED`: considered and not selected; retained to prevent accidental reintroduction.

V4 implementation checkpoints have their own formal Plan pairs in `docs/plans/`. No document here
authorizes a branch, workflow, ruleset, push, pull request, merge or remote operation.

## IFX adoption (external)

V4 was incubated in the IFX repository (`von12549/IFX`), and IFX is one consumer of V4 Guards. The IFX
adoption program is owned and maintained by IFX and is not copied here. It covers the `ifx_profile`
practice, the P10.0–P10.3 decisions and evidence, the cutover and rollback proposal, and V3/V3_ifx
coexistence and retirement. The former incubation-period documents 06–09 remain reachable in this
repository's history and are listed with their IFX successor locations in
`docs/migration/v4-todo-008/provenance-index.json`.
