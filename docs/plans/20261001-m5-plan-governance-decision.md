# M5 Plan governance decisions

Status: `DECISION RECORD — ACCEPTED 2026-10-01; implementation not authorized by this Plan`

Formal Plan ID: `20261001-m5-plan-governance-decision`.

## Goal

Resolve D28–D30 by accepting enforceable Plan-set resource/ownership limits and a single structured
Plan-pair authoring authority without allowing concurrent authors or Agent/model output to bypass exact
scope review.

## Accepted decisions

### 1. Plan-set limits

Initial contract constants are 16 members, 1 MiB per Plan, 8 MiB aggregate input, dependency depth 8,
4,096 unique planned paths, 256 validation commands, 256 combined risk/decision entries and a 30-second
validation/composition ceiling under the certification fixture. They are versioned constants, not
machine-dependent heuristics.

### 2. Concurrent authorship

Humans, Agents and mixed teams may author independent members concurrently. Final composition requires
one exact owner per changed path, rejects shared ownership and reconciles each member against the exact
base/head. Existing cycle, identity, dependency and forbidden-boundary checks remain fail-closed.

### 3. Plan-pair authority

One schema-versioned structured model renders both files. JSON is the executable contract; Markdown is
the matching human review document. Proposals may retain explicit unknowns but do not authorize work.
Only operator-confirmed finalized output reconciled to the exact diff may authorize implementation.
Imported prose, embedded instructions and Agent/model output are untrusted suggestions; deterministic
Guard code owns schema, paths, boundaries, root mutability and policy diagnostics.

## Scope and non-authorization

This Plan records architecture and backlog state only. It adds no schema field, limit enforcement,
authoring command, diff analyzer, UI route, Plan finalization, changed-path adoption or implementation
authority. Existing Plan behavior remains unchanged until separately planned implementation.

## Acceptance

1. V4-AD-045 records exact initial limits, exclusive path ownership and concurrent-authoring policy.
2. V4-AD-046 records JSON/Markdown authority, proposal/finalized states and deterministic tool/model
   boundaries.
3. V4-TODO-013 remains open for enforcement and V4-TODO-024 tracks authoring/analysis tooling.
4. The native Plan pair validates and declares the exact maintained documentation paths.

## Recovery

Revert this documentation-only record, remove V4-AD-045/V4-AD-046/V4-TODO-024 and restore the previous
V4-TODO-013 wording. No Plan runtime or repository change requires rollback.
