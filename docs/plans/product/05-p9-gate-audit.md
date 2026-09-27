# V4-P9 Lightweight Web UI gate audit

Status: `PASS`

Audit date: 2026-09-23

Closure Plan: `20260923-v4-p9-gate-closure`

Certified source commit: `a7c118b52a639220c5176871e2efa395df6f5b72`

Certified package hash: `e513d7512c8e6786882661192a3e7fe3471b86c61ef795f5b472190e4ff911b5`

## Certification binding

The native Windows-full report passed all 32 selected tests and the pinned network-disabled
Linux-complete report passed all 31 selected tests. Each report's ordered path/hash inventory exactly
matches its selection in `integrations/github/ci-contract.json`; both reports bind the source commit
and package hash above.

The gate closure changes only formal and maintained planning files. `plans/` is intentionally outside
the package authority roots enumerated by `core/runtime/Test-V4Package.ps1`, so the closure record does
not alter the certified executable package. Package Check confirmed the package hash before the gate
record and must confirm the same hash after it.

## Contract and authority audit

| Gate property | Result | Evidence |
| --- | --- | --- |
| Presentation is not policy or verdict authority | PASS | The browser labels and renders Host projections/results; `Test-V4EvidencePlanCenter.ps1`, `Test-V4WorkspaceStageRunner.ps1` and `Test-V4WebCompanionSpike.ps1` cover unchanged Host status and no empty/no-op success reinterpretation. |
| Public V4 contracts are the only execution path | PASS | `Program.cs` has one `Process.Start` site, fixes the Host assembly, sets `UseShellExecute = false` and constructs `ArgumentList`; the two POST routes are workspace selection and Stage run only. |
| Local-only transport | PASS | Kestrel binds `IPAddress.Loopback`; Host and Origin validation reject non-loopback or cross-origin requests; immutable assets contain no remote fetch or streaming endpoint. |
| PackageRoot and TargetRoot stay read-only | PASS | The Companion has no file/directory write primitive; Plan content is bounded, link-checked, hash-matched and read-only; P9 root-invariance and hostile-parent tests pass on both platforms. |
| Mutable writes stay V4-owned | PASS | Stage execution remains delegated to the Host four-root contract; only StateRoot and EvidenceRoot are mutable, with package/target invariance covered by the P9 and lifecycle suites. |
| Browser content remains inert | PASS | `app.js` creates DOM nodes and assigns `textContent`; it has no `innerHTML`, `outerHTML`, `insertAdjacentHTML`, WebSocket or EventSource sink; Markdown-XSS tests pass. |

## First-release exclusion audit

| V4-TODO-005 exclusion | Result | Gate evidence |
| --- | --- | --- |
| Installed Profile/package authority editing | ABSENT | No authority-write route or Companion filesystem write primitive. |
| Plan editing/saving in TargetRoot | ABSENT | Plan Center exposes catalog/detail GET operations only and verifies Host-projected hashes. |
| Target mutation/generated Target adoption | ABSENT | Browser cannot submit paths; Stage and query contracts preserve read-only TargetRoot. |
| Git commit/push/PR/merge operations | ABSENT | No Git route, command or browser control exists. The separately authorized repository push of this source branch is not a UI capability. |
| Workflow/required-check/ruleset activation | ABSENT | UI contains no GitHub or remote administration surface. |
| Reset Apply | ABSENT | No reset route or control exists. |
| Multi-project dashboard/aggregation/parallel execution | ABSENT | One active Target is selected in process memory and one non-blocking run gate serializes UI runs. |
| Live terminal/arbitrary command/raw CLI arguments | ABSENT | Fixed route models become allowlisted Host arguments; shell execution is disabled. |
| Non-loopback/remote Web UI | ABSENT | Listener, Host validation and Origin validation are loopback-only. |
| Automatic Profile/module discovery/download/install | ABSENT | Only installed Host projections are displayed; no network, install or discovery route exists. |
| IFX-specific Profile/policy/cutover/actions | ABSENT | Package and UI remain project-neutral; supply-chain and isolation checks reject V3/IFX runtime coupling. |

## Conclusion

V4-P9.GATE passes. P9.1–P9.5 remain an observation/control surface over public V4 contracts, add no
policy or execution bypass, write only through Host-governed V4 mutable roots and implement none of the
first-release exclusions. This conclusion does not authorize a pull request, merge, release/tag,
workflow/ruleset activation, remote UI access, IFX profile work or V4 cutover.
