# V4 P4B — non-executing Project Model detector

Status: local implementation checkpoint authorized on `codex/v4-development-base`

Parent roadmap: `docs/guards/v4/plans/01-v4-self-contained-guard-plugin.md`, V4-P4.3 and the
Project Model slice of V4-P4.7/V4-P4.8.

Predecessor: `20260922-v4-p4a-architecture-authority`

## Goal

Run the first Architecture Conformance detector through the V4 Host without executing target-owned
build logic, and aggregate its structured findings and non-vacuity coverage.

## Scope

- Pass validated profile module config to adapters through the explicit Stage input.
- Accept structured module findings and coverage in the Host while retaining synthetic-probe
  compatibility.
- Implement raw XML Project Model inspection for project/package references, target frameworks and
  graph completeness.
- Select Architecture Conformance in the synthetic profile's Pre Stage.
- Add clean, violating, missing-project and zero-match controls without invoking MSBuild.

## Validation

1. Formal Pre accepts this pair and its exact paths.
2. Clean declared projects pass Pre with four non-zero Project Model coverage claims.
3. Forbidden project/package references, unsupported frameworks and unresolved graph edges produce
   layered blocking findings.
4. Missing projects and zero-match evidence fail with structured prerequisite outcomes.
5. P0-P4A and current V3 validation remain green; target files remain unchanged.
6. No workflow, ruleset or remote state changes.

## Recovery

The recovery seed is P4A commit `0424a451`. Test data is confined to ignored artifact roots; source
recovery is a separately authorized revert or branch restore.
