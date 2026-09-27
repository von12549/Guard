# V4 P9 — Lightweight Web UI planning and decision closure

Status: planning decisions authorized and recorded on `codex/v4-development-base`; implementation of
V4-P9.1 through V4-P9.5 remains separately planned and authorized.

Parent roadmap: `docs/guards/v4/plans/01-v4-self-contained-guard-plugin.md`, V4-P9.

Predecessor: `20260922-v4-p8-release-publication`

## Authorization

The user accepted the Web UI boundary on 2026-09-22: the UI is only an observation window and button
panel for V4. It defines no guard capability, policy, profile, command or verdict, and it may not bypass
`v4-guards` to execute commands. The user authorized this decision/Plan checkpoint and requested that
the first-release exclusions be preserved in the V4 TODO.

## Goal

Promote the deferred Lightweight Web UI into a reviewable post-v1 V4-P9 roadmap while preserving the
released V4 host as the sole execution and decision authority. Freeze the trust boundary, proposed
local topology, minimum feature set, Plan-view compatibility boundary, phased implementation and
first-release exclusions before any UI code is written.

## Accepted decisions

1. The Web UI is a non-authoritative presentation and orchestration surface. Only the V4 host may
   validate authorities, bind project state, execute a Stage, apply baselines, aggregate findings or
   decide a verdict.
2. The UI may invoke only allowlisted, structured public V4 commands or future query contracts. It may
   not accept arbitrary shell text, executables, environment mutation, working directories or raw CLI
   arguments from the browser.
3. The first implementation topology is a separately packaged local Web Companion serving an immutable
   UI on loopback. It is not a second policy engine and does not create a remote control plane.
4. `PackageRoot` remains immutable and host-selected; `TargetRoot` remains read-only; runtime writes
   remain confined to explicit V4-owned `StateRoot` and `EvidenceRoot` paths.
5. P9 first release supports one active Target context at a time, installed-profile selection, manual
   Bootstrap/Analysis/Pre/Post execution, dependency visibility, final structured results, run/evidence
   viewing and read-only Plan viewing. Multi-project aggregation and parallel execution remain deferred.
6. Plan Center distinguishes V4-native Plans from current V3-formal historical Plan pairs. Native Plans
   may use V4 validation/composition; historical pairs are read-only compatibility views and never gain
   V4-native authority by presentation.
7. UI state, query projections and run indexes require explicit schemas and compatibility tests. The UI
   must not infer durable authority from file timestamps, parse human output as a verdict or silently
   reinterpret an empty/no-op profile as meaningful guard coverage.
8. Reset Apply, authority editing, target mutation, Git/PR operations, remote activation, arbitrary
   terminals, automatic extension installation and IFX-specific behavior are excluded from the first
   release and require later decisions and Plans.

## V4-P9 implementation checkpoints

- **V4-P9.1 — Architecture and contract spike:** prove the local companion, loopback session, allowlisted
  host invocation, four-root confinement and one synthetic Target-to-result flow on Windows and Linux.
- **V4-P9.2 — Read/query contracts:** add schema-valid project/profile/doctor/run/Plan catalog projections
  without making the UI read or mutate host internals directly.
- **V4-P9.3 — Workspace and Stage Runner:** add/switch one active Target, show profile/module readiness,
  execute a selected Stage or visible dependency chain and serialize UI-originated runs.
- **V4-P9.4 — Evidence and Plan Center:** show structured results, findings, coverage and authority hashes;
  provide safe Markdown plus JSON views for V4-native and historical Plan pairs.
- **V4-P9.5 — Packaging and certification:** include immutable offline UI assets, command-injection/path
  escape/Markdown-XSS negative controls, deterministic packaging and Linux/Windows certification.

Every implementation checkpoint requires its own exact formal Plan pair and explicit implementation
authorization. This planning checkpoint does not authorize code, dependency, workflow, ruleset or
remote changes.

## Validation

1. V4-AD-017 is accepted with the UI explicitly subordinate to the V4 public execution contracts.
2. The runtime architecture shows a separate local presentation process and preserves all four roots.
3. The parent roadmap contains P9.0–P9.5 and leaves every implementation checkpoint unchecked.
4. V4-TODO-005 references P9 while remaining open until the P9 gate completes.
5. Every first-release exclusion requested by the user appears in the V4 TODO.
6. Planning indexes describe the released v1 and the planning-only P9 status accurately.
7. No executable, package, profile, module, workflow, ruleset or remote state changes.

## Recovery

Revert this documentation-only checkpoint. V4 Guards 1.0.0, tag `v4-guards-v1.0.0`, its released
artifacts and all existing runtime contracts remain unchanged by this Plan.
