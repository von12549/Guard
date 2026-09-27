# V4 P4D — ArchUnitNET compiled-assembly adapter

Status: local implementation checkpoint authorized on `codex/v4-development-base`

Parent roadmap: `docs/guards/v4/plans/01-v4-self-contained-guard-plugin.md`, V4-P4.5.

Predecessor: `20260922-v4-p4c-roslyn-detectors`

## Goal

Implement the package-owned ArchUnitNET evidence adapter for the three compiled architecture claims,
using only an explicit hash-bound assembly manifest supplied to Post.

## Scope

- Pin ArchUnitNET and its runtime dependency closure in the module dependency lock.
- Load only explicitly named assemblies beneath `EvidenceRoot`, verify their SHA-256 hashes and
  managed assembly identities, and reject missing, escaping, duplicate or unexpected inputs.
- Detect forbidden compiled type dependencies, implementation placement and assembly/namespace
  placement through ArchUnitNET.
- Emit structured compiled-assembly findings and non-zero per-claim coverage.
- Exercise clean, violating, missing-dependency, missing-assembly and zero-match controls without
  building or executing the target repository.

Build-manifest production, target-framework/freshness binding and isolated target compilation remain
owned by P4.6 and are not implemented in this checkpoint.

## Validation

1. Formal Pre accepts this pair and its exact paths.
2. Clean explicit assemblies pass all three claims with non-zero coverage.
3. Deliberate dependency and placement violations produce blocking layered findings.
4. Missing ArchUnitNET runtime packages, missing/changed assemblies and zero matches fail closed.
5. The adapter leaves `TargetRoot` unchanged and creates no target `bin/obj` output.
6. P0-P4C and current V3 validation remain green; no workflow, ruleset or remote state changes.

## Recovery

The recovery seed is P4C commit `b0364f0b`. Test data is confined to ignored artifact roots; source
recovery is a separately authorized revert or branch restore.
