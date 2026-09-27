# V4 P8 — V1 certification

Status: local v1 candidate certification authorized on `codex/v4-development-base`; release publication,
tagging, workflow/ruleset activation, push and IFX cutover remain separately authorized and are not in scope.

Parent roadmap: `docs/guards/v4/plans/01-v4-self-contained-guard-plugin.md`, V4-P8.1 through V4-P8.GATE,
excluding the publication action in V4-P8.6.

Predecessor: `20260922-v4-p7-packaging-lifecycle`

## Goal

Certify the V4 v1 candidate against the complete acceptance boundary using a real Linux complete run,
a real Windows full run, a clean four-Stage/factory-reset lifecycle, supply-chain checks, frozen
compatibility authorities and a generated recovery artifact without publishing or activating V4.

## Scope

- Define strict platform, v1-candidate, compatibility-baseline and recovery-artifact contracts.
- Add a platform-native certification runner that refuses OS mismatch, verifies the exact approved test
  hashes, runs the complete selected suite in a scrubbed environment and records toolchain provenance.
- Pin the offline Linux certification image by digest; use only the existing local image and no network.
- Exercise Bootstrap, Analysis, Pre and Post on one clean external synthetic project, then Preview/Apply
  factory reset while proving PackageRoot and TargetRoot immutability.
- Validate module dependency locks, package content, offline NuGet policy, archive provenance and absence
  of IFX, V3 or LayerGuard runtime paths from V4 execution authorities.
- Freeze stable CLI, configuration and report authorities in a hash-bound compatibility baseline.
- Finalize matching Linux/Windows reports into a local candidate record and recovery artifact. The record
  must state `releaseAuthorized: false`, `activeIfxCutover: false` and `ifxProfileIncluded: false`.
- Do not publish an archive, create a release/tag, activate a workflow/ruleset, push or mutate remote state.

## Validation

1. Formal Pre accepts this pair and all 24 exact paths, including P0/P1/P4 test portability corrections
   required by the real Linux run.
2. P8 contract, compatibility, supply-chain and lifecycle tests pass on Windows and in the pinned Linux image.
3. Platform reports bind exact test paths/hashes, package hash, commit, OS, architecture and toolchain versions.
4. Finalization accepts only matching passing Linux complete and Windows full reports plus the exact P8 archive.
5. Full V4 P0–P8 regression, V3 Validate, isolated IFX package validation and Diff from P7 pass.
6. Working tree remains clean and no active V4 workflow, release, tag, ruleset or IFX profile appears.

## Recovery

The source recovery seed is P7 commit `18b9d93a442f1b8c7d32f611391631efd4948fb3`. The generated
recovery artifact binds this seed, the certified candidate, package/archive hashes and verification
commands. No remote or active state exists to unwind; applying source recovery remains separately authorized.
