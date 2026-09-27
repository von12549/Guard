# V4 P4F — composite Architecture Conformance gate

Status: local implementation checkpoint authorized on `codex/v4-development-base`

Parent roadmap: `docs/guards/v4/plans/01-v4-self-contained-guard-plugin.md`, V4-P4.7 through V4-P4.GATE.

Predecessor: `20260922-v4-p4e-build-evidence-provider`

## Goal

Complete P4 with a host-owned composite verdict over policy, finding identity, severity, baseline and
non-vacuous coverage, exercised end to end through `synthetic_profile`.

## Scope

- Make the V4 host consume the hash-bound rule execution plan, normalize and deduplicate layered
  finding identities, apply profile-confined baselines, own severity, and fail closed on insufficient
  coverage or structured module errors.
- Make package validation bind every declared baseline to the strict baseline contract before a
  Stage can execute.
- Select Build Evidence Provider and Architecture Conformance in synthetic Post with a fresh,
  run-bound assembly manifest, while keeping direct Stage behavior and reset replay deterministic.
- Exercise clean and deliberate Pre/Post violations, advisory baseline behavior, missing/stale/zero
  evidence, adapter failure, missing runtime and unsupported platform.
- Compare all twelve V4 claims with a development-only frozen reference map; the reference is test
  input and never a V4 module/runtime dependency.
- Prove equivalent clean verdicts for separated and in-place package/target execution and retain the
  generic-module product/runtime-path isolation check.

## Validation

1. Formal Pre accepts this pair and its exact paths.
2. Contract, package, registry and P0-P4E regressions remain green.
3. Synthetic Pre/Post clean and violating fixtures produce schema-valid aggregate results with
   host-owned coverage, severity, baseline and finding identity.
4. All twelve claims have clean, violating and missing-input evidence and match the frozen reference
   claim semantics without importing that implementation at runtime.
5. Failure matrix cases return structured blocking categories; in-place/separated clean verdicts agree.
6. V3 Validate, IFX package validation and trusted Diff from P4E pass; workflow/ruleset/remote state
   remain unchanged.

## Recovery

The recovery seed is P4E commit `8955be86`. Generated state/evidence remains confined to ignored
mutable roots; source recovery is a separately authorized revert or branch restore.
