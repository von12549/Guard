# V4 deferred roadmap

This file is the authority for work deliberately excluded from V4 v1. A checked item requires a
separate reviewed decision and formal Plan; appearing here is not implementation authorization.

## Consumer adoption (moved to IFX)

V4-TODO-001 through V4-TODO-004 were the IFX adoption backlog: `ifx_profile` practice, parallel
parity, cutover and rollback design, and V3/V3_ifx freeze or retirement. That work belongs to the IFX
consumer and is maintained in the IFX repository (`von12549/IFX`): the backlog is
`docs/guards/TODO.md` and the adoption records are under `docs/guards/v4-adoption/` (moved there by
V4-TODO-008 T7 on 2026-09-28). The four identifiers stay reserved and are not reused here. When the backlog moved on 2026-09-27, 001, 002 and 003 were
complete (P10.1, P10.2-R2 and the P10.3 design were accepted) and 004 was open. Their full text
remains in this repository's history.

Product defects or capabilities that a consumer's adoption requires are tracked below as ordinary
product items.

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

  V4-AD-040 accepts a phased outcome. Revisit after project-instance identity and Evidence isolation are
  proven. Implement read-only aggregate status first. Parallel execution remains a later increment and
  requires per-project queues, cancellation, isolated logs/state/Evidence and fair CPU/memory/disk
  ceilings without creating non-loopback access or a remote control plane. Keep this item open until the
  implemented scope is certified or a later decision explicitly narrows it further.

- [x] **V4-TODO-021 — Expanded local Setup, status and lifecycle UI — LOCAL IMPLEMENTATION COMPLETE (2026-10-01)**

  Implement V4-AD-040 through typed Host/application-service operations in the existing local Web
  Companion. Cover setup previews, non-vacuous protection status, Profile/Plan/Module handoffs and
  lifecycle previews without adding arbitrary path/command gateways. Target writes, pull requests,
  target trust authorization, remote workflow/ruleset activation and enforcement certification remain
  separate Plans and operations. Every new route requires session/origin/CSRF/size/stale-confirmation
  negatives and exact Host-result identity.

  M3 local implementation completed under `20261001-m3-implementation-program`. The Host now returns
  strict setup, protection, Profile/Plan/Module handoff and immutable lifecycle previews. The existing
  Companion transports those results through session/origin/CSRF-protected routes and confirms only an
  unchanged preview with an `applied: false` receipt. Focused security/identity tests and the affected
  P9 offline distribution suites pass. Target adoption, composition selection, CI candidate/application,
  workflow/ruleset activation, remote enforcement certification, release and merge remain separate
  explicitly unperformed operations.

## Deferred distribution and ecosystem

- [x] **V4-TODO-007 — Runtime distribution strategy — DECISION COMPLETE (2026-10-01)**

  `20261001-m1-foundation-decisions` accepted V4-AD-036: publish RID-specific self-contained .NET Host
  and Web Companion distributions, while PowerShell, Git, Node and language toolchains remain declared
  external Module prerequisites unless separately accepted. The fully bundled, zero-prerequisite
  alternative is rejected. This closes the strategy decision only; measurement and implementation
  remain separately planned and are not complete merely because this item is checked.

- [x] **V4-TODO-008 — Standalone V4 repository — COMPLETE (2026-09-28)**

  Revisit before the first external stable release. Extract V4 from the IFX incubation repository or
  record why a monorepo distribution remains preferable. Preserve provenance and deterministic history.

  Formally started on 2026-09-27 under
  `20260927-v4-todo-008-standalone-repository-extraction`. The existing clean public repository
  `von12549/Guard` is feasible as the destination. The program preserves extracted Git history,
  validates the standalone product, publishes only a new immutable version under separate authority,
  rebinds IFX as a consumer and cleans duplicated IFX product source only after that consumer gate.
  Claude Code is the requested executor. Project start does not authorize implementation, remote
  writes, release publication, IFX protected deletion, V4 activation or V3 retirement.

  The authorized local tranches (T0–T5) are carried out in this repository on the branch
  `codex/v4-todo-008-standalone`. The execution record is
  `docs/plans/migration/20260927-v4-todo-008-execution-checklist.md`, and provenance is in
  `docs/migration/v4-todo-008/`. The matching IFX-side TODO entry stays in IFX, which remains the
  canonical source until the canonical-source switch.

  Progress on 2026-09-28:

  - T0–T4 pass.
  - T5 pass. GitHub dispatch certification of the seed head `79596c37` passed Linux-complete 33/33 and
    Windows-full 34/34 on package `491e7eb4…`.
  - T6.1–T6.5 are done: seed PR #1 was merged as `65cf6cde` (Amendment A3 genesis seed).
  - T6.6 was superseded by `20260928-guard-v4-workflow-activation`, whose phase 1 is complete (see
    V4-TODO-011).
  - T6.7 is done. **V4 Guards 1.1.5** was published from this repository on 2026-09-28
    (`https://github.com/von12549/Guard/releases/tag/v4-guards-v1.1.5`): tag `v4-guards-v1.1.5` on `a02ee3c6`, archive SHA-256 `74c371ebca73186d…`,
    package `e8cd32697709e8ca…`. A fresh download was verified with install, four Stages and uninstall.
  - T7 is done (2026-09-28). IFX consumes V4 Guards 1.1.5 from this repository's release (IFX
    `codex/v4-development-base` `fe007b52`). The handoff receipt is
    `docs/guards/v4-adoption/migration/v4-todo-008-ifx-rebinding-receipt.json` in IFX, and this repository
    is the canonical V4 source.
  - T8 is done (2026-09-28): IFX removed the duplicated `docs/guards/v4` (cleanup commit `ae42e11d`,
    receipt `docs/guards/v4-adoption/migration/v4-todo-008-ifx-cleanup-receipt.json` in IFX).
  - Final boundaries: `standaloneSourceAccepted`, `standaloneReleasePublished`, `ifxConsumerRebound` and
    `ifxCoreSourceRemoved` are true; `v4Activated`, `p10GatePassed` and `v3Retired` stay false. Follow-ups
    were V4-TODO-017/018 here (done, V4 Guards 1.1.6) and IFX-V4-001..003 in the IFX backlog.

- [ ] **V4-TODO-009 — Profile/module marketplace and signatures**

  V4-AD-047 confirms this remains deferred until local Module lifecycle, install/uninstall/version
  compatibility and rollback are stable. Before remote installation, separately define authenticated
  discovery/download, signatures, trust roots, rotation/revocation, offline behavior, dependency
  integrity, capability review and malicious-index handling. Extension authenticity is not Evidence
  producer attestation.

- [ ] **V4-TODO-010 — Automatic update and downgrade policy**

  The policy decision was accepted by `20261001-m1-foundation-decisions`: the first implementation uses
  operator-supplied packages with automated verification, immutable sibling staging, explicit selection
  and rollback. It does not perform background discovery, download or activation. Incompatible downgrade
  and destructive schema rollback fail closed. Keep this item open until the lifecycle operations,
  compatibility checks, rollback evidence and documentation are implemented and certified.

- [ ] **V4-TODO-019 — Runtime storage cleanup and retention implementation**

  Implement V4-AD-038's storage classes, active-run leases, protected retention references, pin/archive,
  success cleanup, bounded failed/advisory retention, capacity policy, preview/apply, restart safety and
  deletion receipts. Confirm or revise the provisional age/count/byte defaults with measurements. Prove
  that automatic cleanup reaches bounded steady state and cannot remove active, accepted, pinned or
  externally referenced Evidence. Certification fixtures and retained test clones must be managed
  outside installed runtime data.

- [ ] **V4-TODO-020 — Profile discovery, scaffold and reviewed promotion**

  Implement V4-AD-039 as separately reviewable children: deterministic inert discovery; a
  target-snapshot-bound non-authoritative draft under StateRoot; validation, diff and fixture operations;
  explicit human policy decisions; Target trust authorization for accepted `.guard/` sources; and a new
  immutable sibling composition with rollback selection. Discovery must not execute target code, drafts
  must not run as authority, empty coverage must remain visibly unprotected and CI activation remains a
  separate transaction.

  Local M2 implementation completed on 2026-10-01 under `20261001-m2-implementation-program`: the Host
  now provides strict experimental discovery, StateRoot draft, review validation and promotion-candidate
  operations. The candidate is compatible with the existing immutable sibling composer, but M2 does not
  invoke or select it. This backlog item intentionally remains open for the separately authorized Target
  trust-change capability (`V4-TODO-023`), actual `.guard/` adoption and lifecycle selection evidence.
  Workflow/ruleset activation and enforcement remain separate transactions.

- [x] **V4-TODO-018 — Build-location-independent Host and Companion builds (checklist O14) — COMPLETE (2026-09-28), V4 Guards 1.1.6**

  Plan: `docs/plans/20260928-v4-todo-018-deterministic-builds.md`.

  - The Host is built without debug information and with a repository-root `PathMap`.
  - The Companion has a repository-root `PathMap` and no static web assets manifests.
  - P7 builds a second clone at another location and requires the same archive.
  - PRs #24 (authorization) and #25 (trust change, `243cdc8`). Certification run 36407934314.
  - Released in 1.1.6: the archive is byte-identical when built from two clean clones at different
    locations.

  Original entry:

  An independent Host build embeds its PDB path, and the Companion's `staticwebassets.runtime.json`
  embeds the absolute source `wwwroot` path. Archives are byte-identical for the same Host and
  Companion input, which is the 1.1.x release contract, but two independent builds differ in three
  archive entries. Evaluate PathMap and deterministic source paths so that independent builds from
  the same commit produce the same archive. A change alters release bytes, so it needs its own product
  Plan and a new version.

## Deferred CI and governance

- [x] **V4-TODO-011 — Remote V4 ruleset activation — COMPLETE (2026-09-28), `G2_V4_AUTONOMOUS`**

  **Phase 2 complete (2026-09-28)** under `20260928-v4-todo-011-phase2-ruleset`:

  - **Ruleset.** The ruleset `v4-main-autonomy` (id `24096101`, https://github.com/von12549/Guard/rules/24096101) is active on `main`. It
    was created byte-for-byte from the reviewed specimen `docs/plans/activation/guard-main-ruleset.json`:
    - `v4-required` is required, from GitHub Actions only (integration 15368), with strict up-to-date
      checking;
    - a PR is required, with 0 approvals and merge commits only;
    - deletion and force-push of `main` are blocked;
    - the only bypass is the repository admin, and only when merging a pull request.
  - **Fork workflow runs.** The Actions fork-PR approval policy is `all_external_contributors`. A
    workflow modified in a fork cannot run without the operator's approval.
  - **Negative control.** PR #17 failed `v4-contract` ("Root Plan paths do not exactly match the
    candidate diff") and `v4-required`. It reported `mergeStateStatus: BLOCKED`, and a non-admin merge
    was refused ("the base branch policy prohibits the merge"). It was closed unmerged.
  - **Positive control.** The records PR that updated this entry merged without bypass.
  - **Bypass use.** Governed by V4-TODO-008 checklist O19.

  Original scope (kept for history):

  Revisit after repeated success of the V4 development workflow and final check-name freeze. Creating
  or editing GitHub rulesets remains a separately authorized remote operation.

  **Phase 1 complete (2026-09-28)** under `20260928-guard-v4-workflow-activation`:

  - `.github/workflows/v4-guards.yml` has been active on `main` since `b022f9e8`. It is the reviewed
    specimen with only its first comment line changed; the P0C/P6 tests and V1 certification enforce
    that byte-identity.
  - Genesis record: `docs/plans/activation/guard-genesis-record.json` (seed `118644e3`, package
    `4c8b45c0…`, accepted by human-review).
  - Negative control: PR #3 was rejected (`v4-contract` findings-blocking "Root Plan paths do not exactly
    match", `v4-required` failed; run 36329134054).
  - Positive control: the records-update PR that added this entry.
  - Frozen check names: `v4-contract`, `v4-linux`, `v4-package`, `v4-windows` (selected by the base
    classifier) and `v4-required`.
  - Repeated-success tracking starts with that positive control.

  Until phase 2, verdicts are advisory. A red PR can still be merged. Workflow edits are outside
  `allowedChangedPatterns`, but GitHub runs a PR's merged workflow definition. Phase 2 must therefore add
  a `main` ruleset that requires `v4-required`, enforces strict up-to-date checks, and requires review
  of workflow and authority changes. Phase 2 reaches `G2_V4_AUTONOMOUS` and remains separately authorized.
  Phase 2 was blocked by V4-TODO-014. That prerequisite is satisfied: V4-TODO-014 was completed on
  2026-09-28, so approved-test, CI-contract and runner changes now pass `v4-required` through
  authorization records. The phase 2 ruleset must also require review of:

  - `.github/**`, because GitHub runs a pull request's merged workflow definition and the runner cannot
    protect it;
  - `docs/plans/authorizations/**`, because authorization records are human-review authority.

- [x] **V4-TODO-014 — Trusted-base authorization for approved-test and runner changes — COMPLETE (2026-09-28)**

  Plan: `docs/plans/20260928-v4-todo-014-trust-change-authorization.md`.

  - The base-owned `integrations/github/trust-policy.json` protects three tiers:
    - verdict components;
    - certification components;
    - every approved test.
  - A change to a protected path needs two PRs:
    1. a single-use record under `docs/plans/authorizations/`, added by an `authorization` Plan;
    2. a `trust-change` diff that consumes the record with exact base and head hashes.
  - Every verdict carries `verdictComponents`.
  - P7, P8 and P10 read the version from `plugin.json`.
  - Bootstrap: PR #7 (`0b29783`), the last planned O16 acceptance.
  - Live acceptance on GitHub:
    - PR #8, an unauthorized approved-test edit, was rejected and closed;
    - PR #9 added the authorization;
    - PR #10, the consuming trust change, passed every check including Windows smoke.
  - The first live Windows smoke exposed a pre-existing runner defect. The runner allowlist omitted
    `PATHEXT`, so Windows children could not resolve `git`.
    - PRs #11 and #12 fixed it through the new mechanism. PR #12 was accepted once under O16, by the
      Plan §9 broken-mechanism clause, because the unfixed base runner judged it.
    - PRs #13 and #14 added a P6 regression probe through the mechanism, all green.
  - O16 is retired and O17 is closed.

- [x] **V4-TODO-015 — Target-project trust-change authorization — DECISION COMPLETE (2026-10-01)**

  Guard's own gate now protects its judge with base-held, single-use authorization records
  (V4-TODO-014). Target projects have an analogous exposure in their integration layer:

  - the pinned Guard release (repository, tag and asset SHA-256);
  - their Profile, bundle and review records;
  - their own workflow.

  For IFX, V4-TODO-008 T7 covers the minimum:

  - pin `von12549/Guard` explicitly with an asset hash;
  - keep the Profile, bundle and review inputs in the IFX trust domain;
  - protect the IFX workflow through IFX review and rulesets.

  `20261001-m5-target-trust-authorization-decision` accepts V4-AD-044: Guard will provide a
  consumer-neutral, base-held, single-use two-step authorization capability for protected target
  governance. This closes the evaluation only. Public contracts, CLI/service behavior, target-neutral
  fixtures and negative certification remain open under V4-TODO-023.

- [ ] **V4-TODO-022 — Versioned Stage semantics, timing and trusted Evidence reuse**

  Implement V4-AD-041 through V4-AD-043 as separately reviewable children: versioned Stage/result kinds,
  Guard-owned readiness and analysis providers, dependency execution, timing instrumentation, measured
  CI optimization, trusted-CI Evidence reuse and local advisory Evidence inspection. Preserve legacy
  compatibility visibly, fail closed on stale/missing dependencies and prove that optimization cannot
  suppress a relevant required gate. Managed local attestation remains deferred.

  Local M4 foundation completed on 2026-10-01 under `20261001-m4-implementation-program`: isolated v2
  authorities preserve the frozen v1 contracts, Guard-owned readiness and deterministic analysis
  providers enforce result-kind placement, direct gates fail closed, and `--with-dependencies` visibly
  executes or reuses exact local provider Evidence. Results expose non-vacuous coverage, Stage/Module
  timing, content identity, freshness and tamper diagnostics, and always label developer-machine
  Evidence `local-advisory`/non-authoritative. The experimental read-only inspector validates stored v2
  Evidence without adding a mutation or trust gateway.

  Keep this item open. The 20-sample V4-AD-042 baseline, coverage-selection optimization, Windows cadence
  decision, base-policy trusted-CI provenance/revocation contract, authoritative same/prior-CI reuse and
  any protected runner/classifier/approved-test changes remain separately planned. Managed local
  attestation remains deferred.

- [ ] **V4-TODO-023 — Target-project trust-change authorization implementation**

  Implement V4-AD-044's public schemas, base-policy protected-set declaration, authorization-record
  creation/validation/consumption, CLI/service operations, judge identity and consumer-neutral fixtures.
  Require missing, partial, candidate-only, reused, hash-mismatch and self-authorization negatives.
  Target application, pull-request delivery and workflow/ruleset activation remain separate operations.

- [ ] **V4-TODO-016 — Code-owner review for workflow and authorization changes**

  V4-AD-047 confirms this remains conditional. Revisit only when Guard has a second maintainer who can
  satisfy approval. Add `CODEOWNERS` for `.github/**`,
  `docs/plans/authorizations/**` and `integrations/github/**`, then enable code-owner review in
  `v4-main-autonomy`.

  With one maintainer, a required approval cannot be satisfied, because authors cannot approve their
  own PRs. Review is currently realized in three ways:

  - CI scope: `.github/**` is outside `allowedChangedPatterns`, so it needs the logged admin bypass
    (O19);
  - sole-writer merges;
  - fork-run approval.

- [ ] **V4-TODO-012 — Windows full-run frequency review**

  V4-AD-042 accepts the measurement and decision method while retaining the current cadence until the
  required baseline exists. Ordinary CI remains Linux-first with conditional Windows smoke; Windows-full
  remains required for milestones, releases, runtime/trust changes and explicit certification. Increase,
  reduce or schedule additional full runs only with evidence and without weakening release certification.

  Run-duration data collection started on 2026-09-28, when the V4 workflow became active on `main`
  (`b022f9e8`). The dispatch certification run times (Linux-complete about 7 minutes, Windows-full about
  8 minutes) are the first data points. The first PR-path Windows smoke that passed (PR #10, run
  36359282105) took 4 minutes 44 seconds.

- [ ] **V4-TODO-013 — Plan-set limits and parallel agent policy**

  V4-AD-045 accepts initial limits and generalizes “parallel agent” to concurrent authorship. Implement
  and certify: 16 members, 1 MiB per Plan, 8 MiB aggregate input, dependency depth 8, 4,096 unique paths,
  256 validation commands, 256 combined risk/decision entries and a 30-second certification-fixture
  ceiling. Authors may work concurrently, but every finalized changed path has exactly one owner and
  every member is reconciled to the exact base/head. Keep this item open until schemas/runtime/negative
  tests and guidance enforce the limits. Authorization and activation boundaries remain separate.

- [ ] **V4-TODO-024 — Plan-pair scaffold, analysis, finalize and Workbench**

  Implement V4-AD-046 using one schema-versioned structured authoring model that renders executable JSON
  and matching review Markdown. Support explicit proposal and finalized states, deterministic diagnostics,
  exact-diff reconciliation and operator confirmation. Imported prose and Agent/model output remain
  untrusted suggestions; Guard code owns schema, path, boundary, root-mutability and policy checks. The
  UI cannot approve its own trust boundary or silently add changed paths.

- [ ] **V4-TODO-025 — Agent-independent local Module lifecycle**

  Implement V4-AD-047's immutable list/inspect/graph, scaffold, validate, test, diff, deterministic pack,
  review preparation, compose and verify operations. Begin UI work with read-only inventory; later
  schema-driven metadata/config editing may prepare candidates and run fixtures. Adapter source remains
  repository/IDE work, extension updates create new compositions and built-in changes require a Guard
  release. Marketplace work remains V4-TODO-009.

- [x] **V4-TODO-017 — Long paths in the runner's post-test `git status` (checklist O8) — COMPLETE (2026-09-28), V4 Guards 1.1.6**

  Plan: `docs/plans/20260928-v4-todo-017-runner-longpaths.md`.

  - Every runner Git command passes `core.longpaths=true`, and the isolated clone persists it.
  - P6 has a long-path regression case that fails against the unfixed runner.
  - PRs #22 (authorization) and #23 (trust change, `b757b79`). Certification run 36397069502.
  - Released in 1.1.6.

  Original entry:

  Latent defect, present since 1.1.4. `Invoke-V4TrustedBase` Linux mode clones the Target with
  `core.longpaths=true`, but its post-test `git status` on the Target does not. On a deep Target path
  below a long root, the status check reports a false `M` ("Filename too long") and certification
  fails. Current mitigation: run certification from a short root. Fix it by applying the same long-path
  setting to every Git command the runner issues on the Target. The runner is a verdict component, so
  the fix goes through the trust-change authorization of V4-TODO-014 and needs a P6 regression
  control.

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
