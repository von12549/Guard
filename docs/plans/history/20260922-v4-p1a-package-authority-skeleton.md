# V4 P1A — package authority skeleton

Status: local implementation checkpoint authorized on `codex/v4-development-base`

Parent roadmap: `docs/guards/v4/plans/01-v4-self-contained-guard-plugin.md`, V4-P1.1,
V4-P1.2 and V4-P1.5.

Predecessor: `20260922-v4-p0c-genesis-autonomy-proposal`

## Goal

Create the first schema-valid V4 package skeleton and a fail-closed package authority checker without
activating V4 governance or changing the stable P0 CLI identities.

## Scope

- Add `plugin.json` and schema-valid `default` and `synthetic_profile` manifests.
- Promote the synthetic module manifest to the frozen v1 module contract while preserving P0A.
- Add a module configuration schema and a hash-bound empty dependency lock.
- Add a package checker that validates plugin/profile/module schemas, catalog identity, selected
  modules, confined authority paths, adapter/dependency hashes and mutable-root exclusion.
- Add positive, empty-package and deliberate injection/path/hash/capability negative fixtures.
- Ignore V4 mutable state/work directories without changing any current V3 authority.

## Validation

1. Formal Pre accepts this pair and its exact paths.
2. P0A, P0B and P0C suites remain green.
3. P1A package tests pass positive, empty-package and negative cases.
4. Current V3 Validate and `ifx-package-test` remain green.
5. No active workflow, ruleset or remote state changes.

## Recovery

The recovery seed is P0C commit `f846ff6e88b7b94c2a64d3e85bd0e7edf8ccce84`. No persistent V4
state or active integration exists, so recovery is a separately authorized revert or branch restore.
