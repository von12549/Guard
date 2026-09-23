# V4 planning

This directory is the planning authority for the V4 guard plugin. V4 is a new product boundary, not a
V3 sub-plan and not an IFX application component.

Current documents:

| Document | Role | Status |
| --- | --- | --- |
| [00-architecture-decision-set.md](00-architecture-decision-set.md) | Product, trust, state, profile, stage, CI and planning decisions | Accepted v1 core and gate-audited V4-P9 UI boundary; remaining roadmap items deferred |
| [01-v4-self-contained-guard-plugin.md](01-v4-self-contained-guard-plugin.md) | V4 implementation roadmap | P0–P8 released as 1.0.0; P9 implemented and gate-audited |
| [02-runtime-architecture.md](02-runtime-architecture.md) | Runtime, roots, detector composition, evidence, UI and trust diagrams | Published v1 architecture plus completed P9 local UI boundary |
| [03-genesis-bootstrap-and-autonomy.md](03-genesis-bootstrap-and-autonomy.md) | Finite V3 genesis and V4 autonomy transition | Dormant G1; activation not authorized |
| [04-layerguard-provenance.md](04-layerguard-provenance.md) | Architecture-rule provenance and clean-room boundary | Accepted provenance record |
| [05-p9-gate-audit.md](05-p9-gate-audit.md) | P9 certification, authority-boundary and first-release exclusion audit | PASS |
| [06-ifx-profile-validation-program.md](06-ifx-profile-validation-program.md) | 1.1.x IFX Profile practice, parity and cutover-readiness program | In progress; P10.0 passed, activation not authorized |
| [07-p10-0-baseline-acceptance.md](07-p10-0-baseline-acceptance.md) | Released 1.1.0 baseline and installed Web UI operator evidence | Local P10.0 pass |
| [08-p10-1-extension-composition-compatibility.md](08-p10-1-extension-composition-compatibility.md) | Separate P10.1 entry-gap repair design and gates | 1.1.1 patch published; real IFX bundle and detector-family gates pending |
| `20260923-v4-p10-1-candidate-version-certification` (formal Plan pair under `docs/guards/plans/`) | Historical 1.1.1 local candidate and certification gate | Superseded by exact published release checkpoint |
| `20260923-v4-guards-1-1-1-release-publication` (formal Plan pair under `docs/guards/plans/`) | Authorized 1.1.1 publication and side-by-side installation | Published and installed; IFX bundle approval pending |
| [TODO.md](TODO.md) | Explicit deferred scope, P9 first-release exclusions and revisit gates | Active backlog |

Status meanings:

- `ACCEPTED`: part of the V4 v1 architecture unless a later recorded decision supersedes it.
- `PROPOSED`: must be resolved by the named prototype or review gate before dependent implementation.
- `DEFERRED`: excluded from V4 v1 and tracked in `TODO.md`.
- `REJECTED`: considered and not selected; retained to prevent accidental reintroduction.

V4 implementation checkpoints have their own formal Plan pairs. This directory does not relax
the current V3 trusted-base or protected-change rules, and no document here authorizes a branch,
workflow, ruleset, push, pull request, merge or remote operation.

The active system remains `docs/guards/V3` plus the dependent `docs/guards/V3_ifx` overlay until an
independent V4 promotion plan proves coexistence, parity, rollback and activation.

V4 genesis uses the minimum existing V3 governance needed to validate its formal Plan, exact additive
diff, non-interference and recovery boundary. After a separately accepted seed establishes
`codex/v4-development-base`, V4 development is governed by its own base-owned contracts and checks;
V3 is neither a V4 runtime dependency nor its ongoing feature gate.
