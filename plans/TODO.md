# V4 deferred roadmap

This file is the authority for work deliberately excluded from V4 v1. A checked item requires a
separate reviewed decision and formal Plan; appearing here is not implementation authorization.

## Deferred profiles and adoption

- [x] **V4-TODO-001 — `ifx_profile` practice**

  Revisit after V4-P8. Package current IFX project map, toolchain, policies, baselines and selected
  specialized gates through the published profile/extension API. Treat any required V4 core change as
  an explicit compatibility decision. Do not make V4 v1 release depend on this practice.

  Planning is active under `20260923-v4-ifx-profile-validation-program` / V4-P10. The released 1.1.0
  package is the immutable entry baseline. Because 1.1.0 has no implemented package-external Profile
  installer, P10.0/P10.1 must not edit the installed package; a required composition/loader change is
  handled as the next certified `1.1.x` patch.

  P10.0 local baseline and installed Web UI practice passed on 2026-09-23; see
  `07-p10-0-baseline-acceptance.md`. The separate P10.1 entry-gap compatibility Plan is
  `20260923-v4-p10-extension-composition-compatibility` /
  `08-p10-1-extension-composition-compatibility.md`. P10.1 completed on 2026-09-27 when C6e-R1
  accepted the reviewed IFX 0.4.2 bundle against V4 Guards 1.1.4, including installed-Web-UI clean
  and blocking-violation evidence. Binding decision SHA-256:
  `94a7c01bd991a7b4371f6d3406b43f58830bdb29740c477db7abdaf2bb0ece22`.

- [x] **V4-TODO-002 — IFX parallel parity**

  Revisit after V4-TODO-001. Run V3/V3_ifx and V4+`ifx_profile` against the same fixed corpus and real
  repository commit. Compare blocking verdicts, failure categories, reports, policy hashes, runtime
  prerequisites and every Architecture Conformance claim/evidence kind without activating V4. Include
  clean, deliberate-violation, missing-input and zero-match controls.

  P10.2-R2 completed and was accepted on 2026-09-27. The frozen 52-case matrix closed with zero gaps
  and 15 explicit V4 fail-closed strengthenings while the reference, installation, bundle, C6c corpus
  and Targets remained unchanged. Binding decision SHA-256:
  `7c5ff243ec452958ffbb08ced46ae6e1a8320f586b9fb71ef0d98f2931934516`.

- [x] **V4-TODO-003 — IFX cutover and rollback design**

  Revisit only after parity and a Windows full certification. Define trusted-base activation, GitHub
  required contexts, Architecture Conformance detector-family cutover, recovery, one-time compatibility
  bridges and exact rollback. Remote changes need separate authorization.

  Completed as V4-P10.3 design-only work on 2026-09-27. The inactive proposal, context/detector
  ownership map, coexistence topology, five negative controls and V3-first rollback rehearsal were
  accepted by decision SHA-256
  `529e19b567c05619ec054117e2514c579a908a4e614355411fc28b6d52964964`.
  No workflow, required context, ruleset or cutover was activated; those remote mutations retain a
  separate exact Plan and explicit authorization boundary, and P10.GATE remains open.

- [ ] **V4-TODO-004 — V3/V3_ifx freeze or retirement**

  Revisit only after a stable V4 IFX cutover. Decide whether the old packages remain frozen historical
  sources or are removed through protected deletion. LayerGuard-derived source removal is the last
  migration action. Preserve Plan 06 evidence either way and close Plan 06 §20 only after this item.

## Deferred user experience

- [x] **V4-TODO-005 — Lightweight Web UI**

  Revisit gate met after V4 Guards 1.0.0 stabilized the CLI, JSON Schema, Stage result and state
  transaction contracts. V4-AD-017 is accepted and the work is promoted to V4-P9 by
  `20260922-v4-p9-lightweight-web-ui-planning`. V4-P9.GATE passed under
  `20260923-v4-p9-gate-closure`; the exact evidence is recorded in `05-p9-gate-audit.md`.
  The UI is only an observation window and button panel over allowlisted V4 public contracts. It defines
  no guard capability or verdict, executes nothing outside `v4-guards`, does not directly edit authority
  files and cannot turn an empty/no-op profile into a successful coverage claim.

### V4-P9 first-release exclusions memo

The following are deliberately excluded from the first Lightweight Web UI release. Each requires a
later reviewed decision and exact Plan; listing it here is not implementation authorization.

P9.GATE confirmed every item below is absent. The separately authorized repository push of the audited
source branch is a delivery action by the maintainer and does not add a Git operation to the UI.

- editing installed Profile or other package authorities;
- directly editing or saving Plan authorities in `TargetRoot`;
- any Target mutation or generated Target file adoption;
- Git commit, push, pull-request or merge operations;
- GitHub workflow, required-check or ruleset activation;
- Reset Apply (Reset Preview may be considered only after the read/query boundary is stable);
- multi-project dashboard, aggregation or parallel project execution;
- live terminal, arbitrary command input or raw CLI argument forwarding;
- non-loopback or remote Web UI access;
- automatic Profile/module discovery, download or installation;
- IFX-specific Profile, policy, cutover or operational actions.

- [ ] **V4-TODO-006 — Multi-project dashboard**

  Revisit after project-instance identity and concurrency are proven. Cover parallel runs, cancellation,
  log streaming and isolated project state without creating a remote control plane by accident.

## Deferred distribution and ecosystem

- [ ] **V4-TODO-007 — Fully bundled runtimes**

  Revisit after v1 portability measurements. Evaluate .NET self-contained publishing and the cost of
  bundling or replacing PowerShell/Node dependencies across supported OS/architecture combinations.

- [ ] **V4-TODO-008 — Standalone V4 repository**

  Revisit before the first external stable release. Extract V4 from the IFX incubation repository or
  record why a monorepo distribution remains preferable. Preserve provenance and deterministic history.

- [ ] **V4-TODO-009 — Profile/module marketplace and signatures**

  Revisit after local install/uninstall/version compatibility is stable. Define discovery, download,
  signatures, revocation, trust roots, offline behavior and capability review before allowing remote
  extension installation.

- [ ] **V4-TODO-010 — Automatic update and downgrade policy**

  Revisit with standalone distribution. Updates must be staged, verified and rollback-capable;
  incompatible downgrade and schema rollback fail closed.

## Deferred CI and governance

- [ ] **V4-TODO-011 — Remote V4 ruleset activation**

  Revisit after repeated success of the V4 development workflow and final check-name freeze. Creating
  or editing GitHub rulesets remains a separately authorized remote operation.

- [ ] **V4-TODO-012 — Windows full-run frequency review**

  Revisit after real V4 run-duration data exists. Ordinary CI remains Linux-first with conditional
  Windows smoke; increase or reduce full cadence only with evidence and without weakening release
  certification.

- [ ] **V4-TODO-013 — Plan-set limits and parallel agent policy**

  Revisit after real multi-plan PRs. Decide member-count/size limits, shared-path policy and whether
  independent member plans may be authored concurrently. Authorization and activation boundaries may
  never be collapsed for convenience.

## Explicitly not deferred

The following belong to V4 v1 and must not be moved here to shorten implementation:

- authority/state separation;
- path-confined reset with Preview and explicit acceptance;
- default and synthetic profiles;
- independent Bootstrap/Analysis/Pre/Post execution;
- module capability and hash declarations;
- deterministic package/isolation tests;
- Linux complete coverage, conditional Windows smoke and milestone Windows full certification;
- trusted-base promotion and head-self-judgment prevention.
- composite Architecture Conformance with Project Model, Roslyn and ArchUnitNET evidence layers;
- capability-matrix parity and non-vacuous architecture fixtures;
- isolated, explicit and fresh build evidence for compiled architecture checks.
