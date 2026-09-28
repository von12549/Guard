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

  Revisit after project-instance identity and concurrency are proven. Cover parallel runs, cancellation,
  log streaming and isolated project state without creating a remote control plane by accident.

## Deferred distribution and ecosystem

- [ ] **V4-TODO-007 — Fully bundled runtimes**

  Revisit after v1 portability measurements. Evaluate .NET self-contained publishing and the cost of
  bundling or replacing PowerShell/Node dependencies across supported OS/architecture combinations.

- [ ] **V4-TODO-008 — Standalone V4 repository — IN PROGRESS**

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
  - Remaining: T8 IFX cleanup of the duplicated `docs/guards/v4` (A-IFX-DELETE).

- [ ] **V4-TODO-009 — Profile/module marketplace and signatures**

  Revisit after local install/uninstall/version compatibility is stable. Define discovery, download,
  signatures, revocation, trust roots, offline behavior and capability review before allowing remote
  extension installation.

- [ ] **V4-TODO-010 — Automatic update and downgrade policy**

  Revisit with standalone distribution. Updates must be staged, verified and rollback-capable;
  incompatible downgrade and schema rollback fail closed.

- [ ] **V4-TODO-018 — Build-location-independent Host and Companion builds (checklist O14)**

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

- [ ] **V4-TODO-015 — Trust-change authorization for target projects (evaluate)**

  Guard's own gate now protects its judge with base-held, single-use authorization records
  (V4-TODO-014). Target projects have an analogous exposure in their integration layer:

  - the pinned Guard release (repository, tag and asset SHA-256);
  - their Profile, bundle and review records;
  - their own workflow.

  For IFX, V4-TODO-008 T7 covers the minimum:

  - pin `von12549/Guard` explicitly with an asset hash;
  - keep the Profile, bundle and review inputs in the IFX trust domain;
  - protect the IFX workflow through IFX review and rulesets.

  Evaluate whether V4 should offer the two-step authorization as a product capability, so that a
  target can protect its own Profile and bundle changes. The outcome is to decide scope, the contract
  and whether it belongs in the public CLI.

- [ ] **V4-TODO-016 — Code-owner review for workflow and authorization changes**

  Revisit when Guard has a second maintainer. Add `CODEOWNERS` for `.github/**`,
  `docs/plans/authorizations/**` and `integrations/github/**`, then enable code-owner review in
  `v4-main-autonomy`.

  With one maintainer, a required approval cannot be satisfied, because authors cannot approve their
  own PRs. Review is currently realized in three ways:

  - CI scope: `.github/**` is outside `allowedChangedPatterns`, so it needs the logged admin bypass
    (O19);
  - sole-writer merges;
  - fork-run approval.

- [ ] **V4-TODO-012 — Windows full-run frequency review**

  Revisit after real V4 run-duration data exists. Ordinary CI remains Linux-first with conditional
  Windows smoke; increase or reduce full cadence only with evidence and without weakening release
  certification.

  Run-duration data collection started on 2026-09-28, when the V4 workflow became active on `main`
  (`b022f9e8`). The dispatch certification run times (Linux-complete about 7 minutes, Windows-full about
  8 minutes) are the first data points. The first PR-path Windows smoke that passed (PR #10, run
  36359282105) took 4 minutes 44 seconds.

- [ ] **V4-TODO-013 — Plan-set limits and parallel agent policy**

  Revisit after real multi-plan PRs. Decide member-count/size limits, shared-path policy and whether
  independent member plans may be authored concurrently. Authorization and activation boundaries may
  never be collapsed for convenience.

- [ ] **V4-TODO-017 — Long paths in the runner's post-test `git status` (checklist O8)**

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
