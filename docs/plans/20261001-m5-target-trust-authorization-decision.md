# M5 target-project trust-change authorization decision

Status: `DECISION RECORD — ACCEPTED 2026-10-01; implementation not authorized by this Plan`

Formal Plan ID: `20261001-m5-target-trust-authorization-decision`.

## Goal

Resolve D27 and V4-TODO-015 by accepting a consumer-neutral target-project authorization capability
without prematurely implementing it or authorizing a consumer Target/workflow change.

## Accepted decision

Guard will adapt its existing base-held, single-use two-step authorization model for targets. Trusted
base policy declares the protected set, including pinned Guard release/archive identity, active
Profile/bundle/review identities, integration workflow/trust policy and optional explicitly declared
verdict components.

An authorization record binds the consuming Plan and exact base/head hashes or add/delete operations.
It is added by an authorization Plan and consumed by a separate trust-change Plan. Candidate-only,
missing, partial, reused, mismatched and self-authorizing records fail. The previously trusted Host and
policy validate the candidate and include judge identity in Evidence.

Active governance, adoption history and operational receipts cannot be confused. Target application,
pull-request delivery and workflow/ruleset activation remain separately planned transactions. External
governance, if later supported, is a separately pinned trust domain.

## Scope and non-authorization

This Plan closes the V4-TODO-015 evaluation only. It adds no schema, CLI, service, protected path,
authorization record, consumer file, workflow, ruleset or remote change. Implementation and negative
certification remain V4-TODO-023.

## Acceptance

1. V4-AD-044 records the public-capability decision, protected-set model and two-step invariants.
2. V4-TODO-015 is marked decision-complete without claiming implementation.
3. V4-TODO-023 records implementation and certification requirements.
4. Target application and remote activation remain separate boundaries.
5. The native Plan pair validates and declares the exact maintained documentation paths.

## Recovery

Revert this documentation-only record, remove V4-AD-044/V4-TODO-023 and restore V4-TODO-015 as an open
evaluation. No Target, authorization or remote state requires rollback.
