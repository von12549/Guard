# V4 P5 — Plan and plan-set composition

Status: local implementation checkpoint authorized on `codex/v4-development-base`

Parent roadmap: `docs/guards/v4/plans/01-v4-self-contained-guard-plugin.md`, V4-P5.1 through V4-P5.GATE.

Predecessor: `20260922-v4-p4f-composite-architecture-gate`

## Goal

Implement the stable V4 Plan commands, deterministic multi-plan composition and exact Git diff
integration without giving the local Stage core access to repository history.

## Scope

- Validate strict V4 Plan documents, safe repository-relative paths, unique obligations, dependency
  identities and declared boundary markers.
- Compose two or more Plans using a deterministic dependency order, raw-byte SHA-256 member binding
  and exact sorted unions of paths, areas, risks, decisions, validation commands and boundaries.
- Reject missing dependencies, cycles, duplicate Plan IDs/paths and the accepted forbidden combinations:
  trust, authorization and activation remain pairwise separate; engine change and remote activation
  remain separate.
- Put `git diff` consumption in a Git integration that compares its normalized changed-path set with
  the composed `derivedUnion.plannedPaths` and fails closed on either undeclared or unchanged paths.
- Add positive, reproducibility, drift and negative suites and close the P5 roadmap checklist.

## Validation

1. Formal Pre accepts this pair and its exact paths.
2. P5 Plan runtime tests prove strict validation, deterministic output, member binding, exact unions,
   dependency failures, cycle failures and forbidden co-bundling failures.
3. P5 Git integration tests prove an exact diff passes and both under-declared and over-declared
   plan-set paths fail closed.
4. P0-P4 regression tests, V3 Validate, IFX package validation and trusted Diff from P4F pass.
5. No workflow, ruleset, remote state or Stage-core Git behavior changes.

## Recovery

The recovery seed is P4F commit `0ca330a7`. Generated test state and evidence stays under ignored
artifact roots; source recovery is a separately authorized revert or branch restore.
