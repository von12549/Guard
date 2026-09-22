# V4 v1 — self-contained guard plugin

Status: `V1 RELEASED — V4-P9.1 local Companion spike implemented; P9.2+ and remote activation not authorized`

Development base: `codex/v4-development-base`

Decision authority: `00-architecture-decision-set.md`
Deferred scope: `TODO.md`
Architecture view: [02-runtime-architecture.md](02-runtime-architecture.md)

## 1. Goal

Deliver a generic, operationally self-contained V4 guard plugin with a default profile, a synthetic
profile, independently runnable Bootstrap/Analysis/Pre/Post stages, safe package-local state/reset,
versioned module contracts, deterministic packaging, Linux-first CI and composable plan-sets.

V4 v1 does not implement `ifx_profile`, Web UI, remote module/profile marketplace, fully bundled host
runtimes, V3/V3_ifx cutover or remote activation.

## 2. Product boundary

V4 is not a V3 subdirectory refactor and not an IFX application component. During incubation it is an
inactive additive package on its own development base branch. Existing V3/V3_ifx remains authoritative
for current IFX pull requests.

The package boundary is:

```text
immutable plugin + installed profile/module catalog
                    │
                    ▼
          mutable project instances
                    │
                    ▼
        reports, artifacts and generated data
```

No project-specific sibling package is generated.

## 3. V1 acceptance boundary

V4 v1 must prove:

1. a clean package can create and reset project state without changing package authorities;
2. default and synthetic profiles validate and select only declared modules;
3. Bootstrap, Analysis, Pre and Post each run directly with structured results;
4. generated state and artifacts remain under V4-owned mutable roots;
5. the composite Architecture Conformance and Stage Gate capabilities can be consumed as modules
   without IFX or a V3/LayerGuard runtime dependency;
6. package generation and isolated execution are deterministic on Linux and Windows;
7. a plan-set composes multiple compatible member plans without weakening exact diff accounting; and
8. CI uses Linux for complete normal coverage and Windows only under the accepted selection contract.

## 4. Implemented package shape

```text
docs/guards/v4/                    # canonical source package; distribution is versioned independently
├─ plugin.json
├─ build/
├─ core/
│  ├─ host/
│  ├─ contracts/
│  ├─ runtime/
│  ├─ distribution/
│  └─ certification/
├─ modules/
│  ├─ registry.json
│  ├─ synthetic-probe/
│  ├─ build-evidence-provider/
│  └─ architecture-conformance/
├─ profiles/
│  └─ catalog/
│     ├─ default/
│     └─ synthetic_profile/
├─ integrations/
│  ├─ git/
│  └─ github/
├─ tests/
├─ docs/
└─ plans/
```

Bootstrap, Analysis, Pre and Post are Host orchestration modes rather than package directories. Project
Model, Roslyn and ArchUnitNET detectors are one stable `architecture-conformance` module identity, while
isolated compilation is owned by `build-evidence-provider`. Mutable StateRoot and EvidenceRoot are
explicit external inputs and never live beneath immutable PackageRoot or read-only TargetRoot. The source
path and final standalone distribution path remain different concerns; V1 packaging does not embed
repository-relative IFX paths.

## 5. Workstreams and checkpoints

### V4-P0 — Architecture spike and development-base bootstrap

- [x] **V4-P0.1** Prove the accepted .NET CLI host and PowerShell/.NET adapter boundary with one end-to-end synthetic
  module; this is an implementation-risk spike, not a host-selection comparison. Evidence: P0A host spike and
  `artifacts/guards/v4/p0a/summary.json`.
- [x] **V4-P0.2** Prove the four-root contract, external-target equivalence and isolated CI state/evidence roots.
  Evidence: P0A in-repository/separated-package equivalence and path/capability negative suite.
- [x] **V4-P0.3** Freeze plugin, profile, module, Stage result, state and plan-set schemas. Evidence: P0B
  strict schemas and hash-bound `core/contracts/contracts-manifest.json`.
- [x] **V4-P0.4** Define stable CLI commands and exit categories. Evidence: P0B schema-valid
  `core/contracts/cli-contract.json`; P0A `spike.run` remains explicitly experimental.
- [x] **V4-P0.5** Freeze the Architecture Conformance capability-matrix and rule-execution-plan schemas.
  Evidence: P0B positive, zero-match and missing-fixture contract tests.
- [x] **V4-P0.6** Prepare the exact proposal for `codex/v4-development-base`, the V4-only workflow and the finite
  V3 genesis-bootstrap/exit boundary. Evidence: P0C transition-state proposal, inactive workflow specimen and
  proposal test. The local branch was explicitly authorized; workflow/ruleset/remote activation was not performed.
- [x] **V4-P0.7** Record recovery point and current V3/V3_ifx non-interference checks. Recovery seed:
  `20c93d521728746e1c227654b32219d94fcdf6bb`; current V3 validation remains required before checkpoint commit.
- [x] **V4-P0.8** Define the genesis acceptance record that binds the reviewed seed commit, package/contract hashes,
  deterministic synthetic tests and recovery instructions without allowing the candidate V4 host to trust itself.
  Evidence: P0B `genesis-record.schema.json` and candidate-self-acceptance negative test.

- [x] **V4-P0.GATE** All v1 decisions are `ACCEPTED`; the host spike demonstrates structured results,
  path safety, capability denial and equivalent in-place/separated-target verdicts; the finite V3 bootstrap and
  the exact transition to base-owned V4 governance are reviewable and fail closed.
  Evidence: P0A host boundary suite, P0B contract suite and P0C genesis/autonomy proposal suite. Completing this
  architecture gate does not activate V4 governance; autonomy begins only after the separately authorized P6
  workflow/ruleset transaction.

### V4-P1 — Plugin skeleton and authority checker

- [x] **V4-P1.1** Create plugin manifest, authority roots and package checker. Evidence: P1A
  `plugin.json`, package checker and positive/negative package suite.
- [x] **V4-P1.2** Add default and synthetic profile manifests. Evidence: P1A schema-valid
  `default` and `synthetic_profile` catalogs plus the empty-package fixture.
- [x] **V4-P1.3** Add module registry, capability declarations and schema validation. Evidence: P1B
  strict registry schema, hash-bound manifest entries and independent capability ceilings.
- [x] **V4-P1.4** Reject unknown fields, duplicate IDs, path escape, raw profile executables and undeclared module
  capabilities. Evidence: P1A/P1B injection, drift, catalog and capability-escalation negative suites.
- [x] **V4-P1.5** Ensure state/artifacts are ignored and absent from package hashes. Evidence: P1A
  ignore assertions and package-hash equivalence with mutable noise present.

- [x] **V4-P1.GATE** An empty plugin validates; malformed manifests and profile/module injection fail closed.
  Evidence: P1A empty-package fixture and combined P1A/P1B fail-closed suites.

### V4-P2 — State store, transactions and reset

- [x] **V4-P2.1** Establish project instance identity and canonical target-root binding. Evidence: P2A
  deterministic, idempotent multi-target binding and overlap/path negative tests.
- [x] **V4-P2.2** Implement atomic state writes and incomplete-transaction recovery. Evidence: P2A
  prepared/applied journals, same-directory replacement, recovery positive and hash-drift refusal.
- [x] **V4-P2.3** Implement project-reset and factory-reset Preview/Apply. Evidence: P2B stable reset
  commands, strict reset manifest and scoped positive tests.
- [x] **V4-P2.4** Keep project reset and factory reset inside V4-owned mutable roots; target mutation uses a separate
  receipted Preview/Apply contract. Evidence: P2B claim-only deletion and PackageRoot/TargetRoot invariance.
- [x] **V4-P2.5** Refuse authority deletion, target-root deletion, symlink/reparse traversal, worktree/gitlink deletion
  and unclaimed paths. Evidence: P2B authority-overlap, `.git`, junction/symlink, race and unclaimed-path negatives.
- [x] **V4-P2.6** Record before/after manifests and prove reset idempotency. Evidence: P2B accepted-hash receipts,
  state-schema validation and repeated project/factory Apply tests.

- [x] **V4-P2.GATE** Destructive negative suite passes on Linux and Windows; reset cannot escape V4 mutable roots.
  Evidence: the same P2A/P2B suites pass locally on Windows and in the .NET 10 + PowerShell 7.5 Ubuntu
  validation container, exercising Windows junction and Linux symbolic-link refusal respectively.

### V4-P3 — Independent Stage runtime

- [x] **V4-P3.1** Implement uniform Bootstrap, Analysis, Pre and Post command/result contracts. (`20260922-v4-p3a-direct-stages`)
- [x] **V4-P3.2** Make each Stage resolve its declared inputs directly and report missing prerequisites explicitly. (`20260922-v4-p3a-direct-stages`)
- [x] **V4-P3.3** Add optional visible dependency orchestration; no hidden earlier-stage execution. (`20260922-v4-p3b-stage-orchestration`)
- [x] **V4-P3.4** Port only the generic V3 behavior needed by default/synthetic profiles. (`20260922-v4-p3a-direct-stages`)
- [x] **V4-P3.5** Keep generated outputs under the project instance and artifact roots. (`20260922-v4-p3a-direct-stages`)

- [x] **V4-P3.GATE** Each Stage passes direct positive, negative and clean-reset execution in a synthetic repository. (`20260922-v4-p3b-stage-orchestration`)

### V4-P4 — Composite modules and synthetic profile

- [x] **V4-P4.1** Package generic Stage Gate as a V4 module with declared capabilities and structured results. (`20260922-v4-p4a-architecture-authority`)
- [x] **V4-P4.2** Build the LayerGuard provenance and capability matrix by architecture claim and evidence kind. (`20260922-v4-p4a-architecture-authority`)
- [x] **V4-P4.3** Implement the non-executing Project Model detector for declared project/package/framework
  facts, ownership and graph completeness. (`20260922-v4-p4b-project-model`)
- [x] **V4-P4.4** Implement Roslyn syntax/semantic detectors for source imports, disabled branches,
  declarations, forbidden symbols/text and member/payload claims selected by the matrix. (`20260922-v4-p4c-roslyn-detectors`)
- [x] **V4-P4.5** Implement the ArchUnitNET adapter for compiled dependency, implementation and
  assembly/namespace-placement claims; require explicit assemblies and non-zero matches. (`20260922-v4-p4d-archunitnet-adapter`)
- [x] **V4-P4.6** Implement the isolated Build Evidence Provider and bind its manifest, identities, hashes,
  target frameworks and freshness to the Post run. (`20260922-v4-p4e-build-evidence-provider`)
- [x] **V4-P4.7** Implement the composite rule execution plan, layered finding identity, baseline, severity,
  coverage and aggregate verdict in the V4 host.
- [x] **V4-P4.8** Exercise module selection, configuration, result aggregation and deliberate violating
  fixtures through `synthetic_profile`.
- [x] **V4-P4.9** Compare V4 and the frozen V3 reference by architecture claim without making V3/LayerGuard
  a V4 runtime dependency.
- [x] **V4-P4.10** Prove module failure, stale/missing/zero-match evidence, missing runtime and unsupported
  platform are structured blocking outcomes.

- [x] **V4-P4.GATE** Generic modules contain no IFX identifier or V3/V3_ifx runtime path; every blocking
  architecture claim has clean, violating and missing-input evidence, and in-place/separated execution
  produces equivalent verdicts.

### V4-P5 — Plan and plan-set

- [x] **V4-P5.1** Implement single Plan validation and deterministic plan-set composition. Evidence:
  stable `plan validate`/`plan compose` host commands and the byte-reproducible P5 runtime suite.
- [x] **V4-P5.2** Bind member paths, hashes, ordering and dependencies. Evidence: raw-byte SHA-256
  member bindings, deterministic topological order, and duplicate/missing/cycle negatives.
- [x] **V4-P5.3** Derive the exact union of paths, areas, risks, decisions and validation commands.
  Evidence: sorted, unique derived unions verified against every member by runtime and Git suites.
- [x] **V4-P5.4** Enforce forbidden co-bundling boundaries and negative cases. Evidence: authorization,
  trust and activation pairwise separation plus engine-change/remote-change negative fixtures.
- [x] **V4-P5.5** Keep Git diff consumption in the Git integration rather than the local Stage core.
  Evidence: `integrations/git/Invoke-V4PlanDiff.ps1`; the host Plan runtime contains no Git invocation.

- [x] **V4-P5.GATE** A composed multi-plan fixture is reproducible and exact-diff negative tests fail closed.
  Evidence: P5 runtime output is byte-identical across repeated composition; Git integration passes the
  exact set and rejects undeclared, unchanged, composition-hash-drift and member-hash-drift cases.

### V4-P6 — Linux-first CI and Windows selection

- [x] **V4-P6.1** Add `v4-contract`, `v4-linux`, `v4-package` and `v4-required` workflow contracts on the V4 base.
  Evidence: strict `ci-contract.json`, inactive workflow specimen and workflow-contract negative suite.
- [x] **V4-P6.2** Build/package once and reuse immutable artifacts and bound Build Evidence within a run.
  Evidence: Linux is the only producer; Package and Windows verify the exact manifest/file/hash set before reuse.
- [x] **V4-P6.3** Implement a base-owned change classifier for Windows-sensitive paths. Evidence:
  `Get-V4WindowsSelection.ps1` and one positive fixture for every declared sensitive pattern.
- [x] **V4-P6.4** Run ordinary full coverage on Linux; make Windows smoke conditional and Windows full explicit for
  milestones/releases. Evidence: hash-approved Linux/full and Windows smoke/full suites; manual dispatch is
  certification-only and requires full Windows coverage.
- [x] **V4-P6.5** Ensure V4-only PRs do not run IFX solution, frontend, database or V3 package candidate suites.
  Evidence: the P6 candidate workflow/runner contract rejects paths outside V4 and names all excluded suites;
  active V3 trigger exclusion remains part of the separately authorized activation transaction.
- [x] **V4-P6.6** Run target builds without secrets, with minimum permissions and isolated StateRoot outputs.
  Evidence: child environments are allowlisted, workflow permission is `contents: read`, credentials are not
  persisted, and candidate execution occurs in a StateRoot clone rather than HeadRoot.

- [x] **V4-P6.GATE** Required context never disappears; forcing a Windows-sensitive change to skip Windows fails.
  Evidence: `v4-required` is unconditional and the required-verdict negative suite rejects skipped selected
  Windows work. P6 is activation-ready in `G1_V4_DORMANT_BASE`; it does not itself activate the workflow/ruleset.

### V4-P7 — Packaging, isolation and documentation

- [x] **V4-P7.1** Produce a deterministic versioned V4 archive with source/provenance manifest and hashes. (`20260922-v4-p7-packaging-lifecycle`)
- [x] **V4-P7.2** Install into a clean isolated directory without IFX or repository parent configuration. (`20260922-v4-p7-packaging-lifecycle`)
- [x] **V4-P7.3** Validate declared host prerequisites before execution. (`20260922-v4-p7-packaging-lifecycle`)
- [x] **V4-P7.4** Publish generated command/config documentation from schemas. (`20260922-v4-p7-packaging-lifecycle`)
- [x] **V4-P7.5** Verify package, install, run, reset, uninstall and reinstall lifecycle. (`20260922-v4-p7-packaging-lifecycle`)

- [x] **V4-P7.GATE** Identical inputs produce identical package contents; hostile parent configuration has no effect. (`20260922-v4-p7-packaging-lifecycle`)

### V4-P8 — V1 certification

- [x] **V4-P8.1** Run the complete Linux suite and Windows full certification. (`20260922-v4-p8-v1-certification`)
- [x] **V4-P8.2** Run clean synthetic project Bootstrap/Analysis/Pre/Post and factory reset. (`20260922-v4-p8-v1-certification`)
- [x] **V4-P8.3** Run supply-chain, dependency-lock and package-content checks. (`20260922-v4-p8-v1-certification`)
- [x] **V4-P8.4** Freeze CLI/config/report compatibility baseline and recovery artifact. (`20260922-v4-p8-v1-certification`)
- [x] **V4-P8.5** Confirm V4-native Architecture Conformance requires no V3/LayerGuard runtime path. (`20260922-v4-p8-v1-certification`)
- [x] **V4-P8.6** Publish V4 v1 only after a separate release authorization.
  Release-readiness closure audit (`20260922-v4-p8-release-readiness-closure`): **PASS** on the
  implemented candidate commit `c7d2b0865d7b2195d176b538801f93bf6bbc5eb0`. Package and bundled
  modules are version `1.0.0`; declared/certified platforms are `linux-x64` and `win-x64` only. Stable
  `version` and `contract validate` behavior, PackageRoot-complete reset syntax, generated docs,
  contract/module/compatibility hashes and negative cases pass. Native Linux complete is 26/26;
  native Windows full is 27/27 and includes Trusted Base. Package hash is
  `52c900ff4050826fdd41042d955777c2bff92705f10272b49ac2dea969b91706`. Formal Pre, exact Diff from
  the prior P8 checkpoint, V3 Validate and isolated IFX package validation pass. The candidate record
  still states `releaseAuthorized: false`, `activeIfxCutover: false` and `ifxProfileIncluded: false`.
  This candidate record is preserved as pre-authorization evidence and was not rewritten after publication.
  The separate authorization was subsequently granted and executed under
  `20260922-v4-p8-release-publication`.

  Release publication audit (`20260922-v4-p8-release-publication`): **PASS**. The remote branch and the
  peeled annotated tag `v4-guards-v1.0.0` both identify certified candidate
  `2186d0510cbcb3eddaf3dc56ff239f6558b9b115`. GitHub Release `V4 Guards 1.0.0` was published at
  `2026-09-22T06:49:29Z` as a final release:
  `https://github.com/von12549/IFX/releases/tag/v4-guards-v1.0.0`. The uploaded archive is 607880 bytes
  with GitHub digest `sha256:56d49220ef055bfdb2c15777133e7c08bf86bdb34902ba4a905181757f5fd6b8`;
  its 86-byte sidecar has digest
  `sha256:3949ba1edb07a9ba8e2a20ac56f7cb8a935020ab61ffb50cf3b13117fdcb063b`.
  Publication did not activate a workflow/ruleset, grant G2 autonomy, add `ifx_profile`, perform IFX
  cutover or declare macOS support.

- [x] **V4-P8.GATE** V4 v1 meets §3 without `ifx_profile` or any active IFX cutover; Plan 06 §20
  remains open until the deferred IFX parity/cutover/retirement work completes.

### V4-P9 — Lightweight Web UI

- [x] **V4-P9.0** Accept the non-authoritative UI boundary, local Web Companion topology, phased roadmap
  and first-release exclusions. (`20260922-v4-p9-lightweight-web-ui-planning`)
- [x] **V4-P9.1** Prove the local companion, loopback session, allowlisted V4 invocation, four-root
  confinement and a synthetic Target-to-result flow on Linux and Windows.
  (`20260922-v4-p9a-web-companion-spike`)
- [ ] **V4-P9.2** Add schema-versioned read/query contracts for project, profile, prerequisite, run,
  evidence and Plan catalog projections without exposing host internals as UI authority.
- [ ] **V4-P9.3** Implement one-active-Target workspace selection and the manual Stage Runner, including
  profile/module readiness, visible dependency execution and serialized UI-originated runs.
- [ ] **V4-P9.4** Implement structured result/evidence viewing and a read-only Plan Center that clearly
  separates V4-native Plans from current V3-formal historical Plan pairs.
- [ ] **V4-P9.5** Package immutable offline UI assets and pass command-injection, path-escape,
  Markdown-XSS, hostile-parent, deterministic lifecycle, Linux complete and Windows full checks.

- [ ] **V4-P9.GATE** The UI remains only an observation/control surface over V4 public contracts, adds
  no policy or execution bypass, writes only V4-owned mutable roots and includes none of the first-release
  exclusions recorded under V4-TODO-005.

V4-P9.2 through V4-P9.5 each require a separate exact Plan pair and explicit checkpoint
authorization. Completing V4-P9.0 or V4-P9.1 does not authorize later source, dependency, package or
remote changes.

## 6. PR and CI strategy

Implementation checkpoints receive exact formal Plan pairs. Compatible local work may use a plan-set,
but trust/authorization/activation boundaries remain separate. Expected V4 v1 scale:

- 15–24 pull requests;
- 11–17 focused implementation days;
- approximately 300–650 private-repository Actions minutes under the proposed V4 workflow;
- two or three Windows full milestone certifications rather than Windows full on every PR.

These are planning estimates, not execution authorization or delivery commitments.

Before the V4 development base exists, the current V3 gate is used only for the genesis checkpoint's
formal Plan, exact additive diff, current-guard non-interference, isolation and recovery evidence. The
reviewed seed is established through a separately accepted genesis record; candidate V4 output is
supplemental and cannot trust itself. Once that seed is the development base, V4-only pull requests are
judged by the previously trusted V4 base and `v4-required`, not by V3 candidate or IFX product suites.

## 7. Migration and non-interference

Until a deferred IFX practice and cutover plan is approved:

- no current command, required check, ruleset or workflow points to V4;
- V3 participates only in the finite V4 genesis bootstrap described by V4-AD-035 and is not a V4
  runtime dependency or ongoing V4 feature gate;
- no V3/V3_ifx file is moved or removed for V4 convenience;
- V4 tests use synthetic repositories and profiles;
- V4 cannot write current V3/V3_ifx authorities; and
- failure or deletion of the V4 incubation tree cannot weaken the active IFX guards.

## 8. Deferred work

The following are deliberately outside V4 v1 and appear in `TODO.md`:

- `ifx_profile` and IFX extension practice;
- lightweight Web UI;
- fully bundled language runtimes;
- remote profile/module marketplace and signing service;
- standalone repository extraction and public release topology;
- V4 remote ruleset activation;
- IFX cutover, V3/V3_ifx retirement and historical migration.
