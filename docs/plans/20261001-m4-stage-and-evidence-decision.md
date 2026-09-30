# M4 Stage, performance and Evidence decisions

Status: `DECISION RECORD — ACCEPTED 2026-10-01; implementation not authorized by this Plan`

Formal Plan ID: `20261001-m4-stage-and-evidence-decision`.

## Goal

Resolve D20–D26 so later implementation Plans have enforceable Stage/result roles, explicit dependency
behavior, a measurable performance method, an evidence-based Windows cadence and a bounded initial
Evidence trust model.

## Accepted decisions

1. Preserve Stage wire names and direct execution while adding a versioned semantic contract:
   Bootstrap readiness, Analysis deterministic read-only Evidence production, Pre pre-build gate and
   Post evaluated/post-build gate.
2. Define readiness-provider, analysis-provider, pre-gate and post-gate result kinds. Provider success
   never equals a policy-gate pass.
3. Direct Stage runs remain non-implicit. `--with-dependencies` visibly runs missing/stale producers;
   direct gates fail closed without eligible dependency Evidence.
4. Instrument before optimizing and collect at least 20 comparable ordinary-PR samples plus defined
   special classes. Use a provisional 30% median ordinary-PR critical-path reduction target with
   coverage equivalence and no meaningful p95 regression.
5. Retain current Linux/Windows cadence until measurements justify change; keep Windows-full at
   milestone, release, runtime/trust and explicit certification boundaries.
6. Initially permit authoritative reuse only from same-run or exact prior trusted CI. Local Evidence is
   advisory; managed local attestation is deferred pending a separate threat model.

## Scope and non-authorization

This Plan changes maintained decisions and backlog state only. It adds no schema, Module, built-in,
Stage behavior, instrumentation, selector, cache, Evidence reuse, UI route, workflow or remote state.
It does not reinterpret an existing v1 Module or authorize skipping any current check.

## Acceptance

1. V4-AD-041 defines versioned Stage roles, result kinds and dependency behavior.
2. V4-AD-042 defines baseline evidence, optimization proof and retained Windows cadence.
3. V4-AD-043 separates content identity, producer trust, local feedback and CI authority.
4. V4-TODO-012 remains open for measured cadence review and V4-TODO-022 tracks implementation.
5. The native Plan pair validates and declares the exact maintained documentation paths.

## Next formal Plans

Promote timing instrumentation before CI optimization. Stage contract/schema work precedes built-in
providers and local execution UI. Evidence provenance/reuse contracts precede any CI skip/reuse path.
Protected classifier, runner or approved-test changes use the existing trust-change authorization.

## Recovery

Revert this documentation-only record and remove V4-AD-041 through V4-AD-043/V4-TODO-022 while restoring
the previous V4-TODO-012 wording. No runtime or CI rollback is required.
