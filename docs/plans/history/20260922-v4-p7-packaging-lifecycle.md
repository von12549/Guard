# V4 P7 — Packaging, isolation and documentation lifecycle

Status: local implementation checkpoint authorized on `codex/v4-development-base`; publication,
release tagging, workflow activation and remote mutation remain unauthorized.

Parent roadmap: `docs/guards/v4/plans/01-v4-self-contained-guard-plugin.md`, V4-P7.1 through V4-P7.GATE.

Predecessor: `20260922-v4-p6-linux-first-ci`

## Goal

Complete the P7 versioned distribution, isolated install, prerequisite validation, generated
documentation and reversible lifecycle while the branch remains in `G1_V4_DORMANT_BASE`.

## Scope

- Define strict distribution manifest, install receipt, runtime-requirement and prerequisite-report
  contracts, hash-bound by the V4 contracts manifest.
- Produce a deterministic, versioned, no-compression ZIP from an exact immutable package and an
  already-built host, with fixed entry ordering/timestamps, source provenance and SHA-256 sidecar.
- Install only a verified archive into a clean exact root, keep receipts outside immutable package
  authority, refuse drift or unsafe archive paths, and support verified uninstall/reinstall.
- Resolve package and selected-module runtime requirements before host execution, emitting a
  structured report and exit category 15 when any declared prerequisite is absent or incompatible.
- Generate command and configuration Markdown deterministically from V4 JSON contracts and verify
  checked-in documentation byte-for-byte.
- Prove package, install, external run, Preview/Apply reset, uninstall and reinstall under hostile
  parent configuration without consulting IFX or repository-relative configuration.
- Keep distribution outputs under ignored evidence/artifact roots. Do not publish an archive, create
  a release/tag, activate a workflow, alter a ruleset, push or otherwise mutate remote state.

## Validation

1. Formal Pre accepts this pair and all 22 exact paths.
2. Distribution tests prove identical inputs create byte-identical archives and reject traversal,
   payload drift, unexpected files and incompatible prerequisites.
3. Lifecycle tests install outside the repository, run the packaged host against a synthetic target,
   reset only receipted mutable state, uninstall exactly the installed root and reinstall identically.
4. Hostile parent `Directory.Build.*`, `Directory.Packages.props`, `global.json`, `NuGet.config` and
   PowerShell profile fixtures do not affect package contents, install or verdicts.
5. Generated command/configuration documentation matches the authoritative schemas exactly.
6. Full V4 P0–P7 regression, V3 Validate, isolated IFX package validation and trusted Diff from P6 pass.

## Recovery

The recovery seed is P6 commit `6efc601b`. P7 changes only dormant repository authorities, generated
documentation and tests. Local test installs are disposable and confined to ignored artifact roots;
there is no release, workflow, ruleset or remote state to unwind. Source recovery remains a separately
authorized revert or branch restore.
