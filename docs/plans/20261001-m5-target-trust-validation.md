# M5 target trust authorization validation

Status: `IMPLEMENTATION PLAN — IMPLEMENTED 2026-10-01`

Formal Plan ID: `20261001-m5-target-trust-validation`.

## Goal

Implement the local consumer-neutral contracts and validation core of V4-AD-044 while keeping Target
application, pull-request delivery and workflow/ruleset activation separate.

## Implementation

- Add strict target trust policy and single-use authorization schemas bound by the M5 governance catalog.
- Generate an authorization candidate below EvidenceRoot from protected paths and exact base/head bytes.
- Validate a consuming trust-change against policy and authorization read from the trusted base, the
  consuming Plan set, exact changed paths and exact add/change/delete hashes.
- Reject candidate-only, missing, partial, reused, mismatched, self-authorizing and non-protected entries.
- Report the previously trusted Host and policy identity as judge evidence.

## Boundaries and recovery

The Host neither adopts the candidate authorization nor applies the consuming diff. It does not create
a PR, modify a workflow/ruleset or query remote policy. Revert the runtime and schemas; discard local
candidate and validation evidence.
