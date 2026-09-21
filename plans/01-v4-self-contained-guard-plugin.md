# V4 v1 — self-contained guard plugin

Status: `DRAFT — architecture planning only; implementation not authorized`

Intended base: future `codex/v4-development-base`

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

## 4. Planned package shape

```text
docs/guards/v4/                    # canonical incubation spelling; final distribution boundary is deferred
├─ plugin.json
├─ core/
│  ├─ host/
│  ├─ contracts/
│  └─ runtime/
├─ stages/
│  ├─ bootstrap/
│  ├─ analysis/
│  ├─ pre/
│  └─ post/
├─ modules/
│  ├─ architecture-conformance/
│  │  ├─ project-model/
│  │  ├─ roslyn/
│  │  ├─ archunitnet/
│  │  └─ build-evidence/
│  └─ stage-gate/
├─ profiles/
│  └─ catalog/
│     ├─ default/
│     └─ synthetic_profile/
├─ integrations/
│  ├─ git/
│  ├─ github/
│  └─ agents/
├─ restore/
├─ tests/
├─ state/                          # ignored mutable root
└─ artifacts/                      # ignored mutable root
```

The exact incubation path and final standalone distribution path are different concerns. V1 packaging
must not embed repository-relative IFX paths.

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
- [ ] **V4-P0.6** Prepare the exact proposal for `codex/v4-development-base`, the V4-only workflow and the finite
  V3 genesis-bootstrap/exit boundary; do not create or activate either without explicit authorization.
- [x] **V4-P0.7** Record recovery point and current V3/V3_ifx non-interference checks. Recovery seed:
  `20c93d521728746e1c227654b32219d94fcdf6bb`; current V3 validation remains required before checkpoint commit.
- [x] **V4-P0.8** Define the genesis acceptance record that binds the reviewed seed commit, package/contract hashes,
  deterministic synthetic tests and recovery instructions without allowing the candidate V4 host to trust itself.
  Evidence: P0B `genesis-record.schema.json` and candidate-self-acceptance negative test.

- [ ] **V4-P0.GATE** All v1 decisions are `ACCEPTED`; the host spike demonstrates structured results,
  path safety, capability denial and equivalent in-place/separated-target verdicts; the finite V3 bootstrap and
  the exact transition to base-owned V4 governance are reviewable and fail closed.

### V4-P1 — Plugin skeleton and authority checker

- [ ] **V4-P1.1** Create plugin manifest, authority roots and package checker.
- [ ] **V4-P1.2** Add default and synthetic profile manifests.
- [ ] **V4-P1.3** Add module registry, capability declarations and schema validation.
- [ ] **V4-P1.4** Reject unknown fields, duplicate IDs, path escape, raw profile executables and undeclared module
  capabilities.
- [ ] **V4-P1.5** Ensure state/artifacts are ignored and absent from package hashes.

- [ ] **V4-P1.GATE** An empty plugin validates; malformed manifests and profile/module injection fail closed.

### V4-P2 — State store, transactions and reset

- [ ] **V4-P2.1** Establish project instance identity and canonical target-root binding.
- [ ] **V4-P2.2** Implement atomic state writes and incomplete-transaction recovery.
- [ ] **V4-P2.3** Implement project-reset and factory-reset Preview/Apply.
- [ ] **V4-P2.4** Keep project reset and factory reset inside V4-owned mutable roots; target mutation uses a separate
  receipted Preview/Apply contract.
- [ ] **V4-P2.5** Refuse authority deletion, target-root deletion, symlink/reparse traversal, worktree/gitlink deletion
  and unclaimed paths.
- [ ] **V4-P2.6** Record before/after manifests and prove reset idempotency.

- [ ] **V4-P2.GATE** Destructive negative suite passes on Linux and Windows; reset cannot escape V4 mutable roots.

### V4-P3 — Independent Stage runtime

- [ ] **V4-P3.1** Implement uniform Bootstrap, Analysis, Pre and Post command/result contracts.
- [ ] **V4-P3.2** Make each Stage resolve its declared inputs directly and report missing prerequisites explicitly.
- [ ] **V4-P3.3** Add optional visible dependency orchestration; no hidden earlier-stage execution.
- [ ] **V4-P3.4** Port only the generic V3 behavior needed by default/synthetic profiles.
- [ ] **V4-P3.5** Keep generated outputs under the project instance and artifact roots.

- [ ] **V4-P3.GATE** Each Stage passes direct positive, negative and clean-reset execution in a synthetic repository.

### V4-P4 — Composite modules and synthetic profile

- [ ] **V4-P4.1** Package generic Stage Gate as a V4 module with declared capabilities and structured results.
- [ ] **V4-P4.2** Build the LayerGuard provenance and capability matrix by architecture claim and evidence kind.
- [ ] **V4-P4.3** Implement the non-executing Project Model detector for declared project/package/framework
  facts, ownership and graph completeness.
- [ ] **V4-P4.4** Implement Roslyn syntax/semantic detectors for source imports, disabled branches,
  declarations, forbidden symbols/text and member/payload claims selected by the matrix.
- [ ] **V4-P4.5** Implement the ArchUnitNET adapter for compiled dependency, implementation and
  assembly/namespace-placement claims; require explicit assemblies and non-zero matches.
- [ ] **V4-P4.6** Implement the isolated Build Evidence Provider and bind its manifest, identities, hashes,
  target frameworks and freshness to the Post run.
- [ ] **V4-P4.7** Implement the composite rule execution plan, layered finding identity, baseline, severity,
  coverage and aggregate verdict in the V4 host.
- [ ] **V4-P4.8** Exercise module selection, configuration, result aggregation and deliberate violating
  fixtures through `synthetic_profile`.
- [ ] **V4-P4.9** Compare V4 and the frozen V3 reference by architecture claim without making V3/LayerGuard
  a V4 runtime dependency.
- [ ] **V4-P4.10** Prove module failure, stale/missing/zero-match evidence, missing runtime and unsupported
  platform are structured blocking outcomes.

- [ ] **V4-P4.GATE** Generic modules contain no IFX identifier or V3/V3_ifx runtime path; every blocking
  architecture claim has clean, violating and missing-input evidence, and in-place/separated execution
  produces equivalent verdicts.

### V4-P5 — Plan and plan-set

- [ ] **V4-P5.1** Implement single Plan validation and deterministic plan-set composition.
- [ ] **V4-P5.2** Bind member paths, hashes, ordering and dependencies.
- [ ] **V4-P5.3** Derive the exact union of paths, areas, risks, decisions and validation commands.
- [ ] **V4-P5.4** Enforce forbidden co-bundling boundaries and negative cases.
- [ ] **V4-P5.5** Keep Git diff consumption in the Git integration rather than the local Stage core.

- [ ] **V4-P5.GATE** A composed multi-plan fixture is reproducible and exact-diff negative tests fail closed.

### V4-P6 — Linux-first CI and Windows selection

- [ ] **V4-P6.1** Add `v4-contract`, `v4-linux`, `v4-package` and `v4-required` workflow contracts on the V4 base.
- [ ] **V4-P6.2** Build/package once and reuse immutable artifacts and bound Build Evidence within a run.
- [ ] **V4-P6.3** Implement a base-owned change classifier for Windows-sensitive paths.
- [ ] **V4-P6.4** Run ordinary full coverage on Linux; make Windows smoke conditional and Windows full explicit for
  milestones/releases.
- [ ] **V4-P6.5** Ensure V4-only PRs do not run IFX solution, frontend, database or V3 package candidate suites.
- [ ] **V4-P6.6** Run target builds without secrets, with minimum permissions and isolated StateRoot outputs.

- [ ] **V4-P6.GATE** Required context never disappears; forcing a Windows-sensitive change to skip Windows fails.

### V4-P7 — Packaging, isolation and documentation

- [ ] **V4-P7.1** Produce a deterministic versioned V4 archive with source/provenance manifest and hashes.
- [ ] **V4-P7.2** Install into a clean isolated directory without IFX or repository parent configuration.
- [ ] **V4-P7.3** Validate declared host prerequisites before execution.
- [ ] **V4-P7.4** Publish generated command/config documentation from schemas.
- [ ] **V4-P7.5** Verify package, install, run, reset, uninstall and reinstall lifecycle.

- [ ] **V4-P7.GATE** Identical inputs produce identical package contents; hostile parent configuration has no effect.

### V4-P8 — V1 certification

- [ ] **V4-P8.1** Run the complete Linux suite and Windows full certification.
- [ ] **V4-P8.2** Run clean synthetic project Bootstrap/Analysis/Pre/Post and factory reset.
- [ ] **V4-P8.3** Run supply-chain, dependency-lock and package-content checks.
- [ ] **V4-P8.4** Freeze CLI/config/report compatibility baseline and recovery artifact.
- [ ] **V4-P8.5** Confirm V4-native Architecture Conformance requires no V3/LayerGuard runtime path.
- [ ] **V4-P8.6** Publish V4 v1 only after a separate release authorization.

- [ ] **V4-P8.GATE** V4 v1 meets §3 without `ifx_profile` or any active IFX cutover; Plan 06 §20
  remains open until the deferred IFX parity/cutover/retirement work completes.

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
