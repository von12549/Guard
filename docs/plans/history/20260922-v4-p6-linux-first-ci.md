# V4 P6 — Linux-first trusted-base CI candidate

Status: local implementation checkpoint authorized on `codex/v4-development-base`; workflow and
remote activation remain unauthorized.

Parent roadmap: `docs/guards/v4/plans/01-v4-self-contained-guard-plugin.md`, V4-P6.1 through V4-P6.GATE.

Predecessor: `20260922-v4-p5-plan-composition`

## Goal

Complete the P6 base-owned CI runner, platform selection, immutable artifact and stable verdict
contracts while the branch remains in `G1_V4_DORMANT_BASE`.

## Scope

- Freeze a strict CI contract containing stable contexts, approved test hashes, V4-only path scope,
  Windows-sensitive patterns, smoke/full suites, minimum permissions and excluded IFX/V3 suites.
- Implement an independently testable base-owned Windows classifier.
- Implement Contract, Linux, Package and Windows trusted-base runner modes. Contract validates base/head
  provenance and exact V4 Plan or plan-set diff; Linux runs approved tests in a scrubbed environment and
  emits one immutable package/host/build-evidence artifact; Package and Windows verify and reuse it.
- Implement a required-verdict aggregator that blocks missing mandatory work and any skipped selected
  Windows coverage.
- Refine the inactive workflow specimen to build/upload once, download/verify in consumers, select
  Windows from base output and keep `v4-required` unconditional.
- Prove the candidate contains no IFX solution, frontend, database or V3 candidate suite invocation.
  Do not materialize `.github/workflows/v4-guards.yml` or change the active V3 workflow.

## Validation

1. Formal Pre accepts this pair and all 17 exact paths.
2. P6 classifier tests cover ordinary, every sensitive pattern, explicit full and forced-skip failure.
3. P6 trusted-base tests use separate base/head repositories to prove provenance, exact Plan diff,
   immutable artifact production/reuse, tamper rejection and candidate test weakening rejection.
4. Workflow contract tests prove stable contexts, artifact flow, no secrets, minimum permissions,
   V4-only suite scope and unchanged inactive/active workflow boundaries.
5. Full V4 P0–P6 regression, V3 Validate, isolated IFX package validation and trusted Diff from P5 pass.

## Recovery

The recovery seed is P5 commit `70ef9125`. P6 changes only dormant repository authorities and tests;
there is no workflow, ruleset or remote state to unwind. Source recovery remains a separately authorized
revert or branch restore.
