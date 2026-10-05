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

## Completed remediation and release program

- [M1–M5 audit remediation and conditional 1.2.0 release program](20261001-m1-m5-remediation-and-1-2-0-release.md)
  with its [verification checklist](20261001-m1-m5-remediation-checklist.md): all required repairs and
  tests passed at `fa7ae011…`; the [post-remediation report](20261001-m1-m5-remediation-report.md)
  records `G-REPAIR = GO`. Exact-release certification, publication and independent verification are
  complete; see the [final release report](20261002-v4-guards-1-2-0-release-report.md).
- [V4 Guards 1.2.0 release Plan](20261001-v4-guards-1-2-0-release.md): consumes the separately merged
  baseline authorization and fixes the `linux-x64`/`win-x64` self-contained asset matrix. It reached
  `G-RELEASE = GO` and published annotated tag `v4-guards-v1.2.0`.

## 1.2.1 release program

- [V4 Guards 1.2.1 release Plan](20261005-v4-guards-1-2-1-release.md): certifies the repaired installed
  onboarding source on the final merge commit, builds reproducible `linux-x64` and `win-x64` assets,
  publishes an immutable release after all gates pass, and records independent verification. It reached
  `G-RELEASE = GO`; see the [final release report](20261005-v4-guards-1-2-1-release-report.md).

## P04 repair and 1.2.2 release

- [P04 onboarding and safety repair Plan](20261006-v4-guards-p04-onboarding-safety-repair.md) maps the
  IFX P03 failure evidence to Guard changes and regressions. PR #58 passed its required checks and
  merged the repair; P03 remains FAIL and IFX protection is not claimed.
- [V4 Guards 1.2.2 release Plan](20261006-v4-guards-1-2-2-release.md) freezes the two-RID matrix,
  exact-commit certification, P04 safety regressions, reproducible archives and fresh-download checks.
  It reached `G-RELEASE = GO`; see the
  [final release report](20261006-v4-guards-1-2-2-release-report.md).
