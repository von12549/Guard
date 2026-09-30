# M1.4 — governance adoption preview/review/apply

Status: `IMPLEMENTATION PLAN — READY; not yet executed`

Formal Plan ID: `20261001-m1-governance-adoption`.

Predecessor checkpoint: `20261001-m1-project-initialization`.

## Goal

Implement a typed local operation that prepares an exact `.guard/` Target change candidate, distinguishes
active governance from historical adoption material, and applies only a reviewed, hash-bound candidate.
Init remains non-mutating and no consumer or remote repository is changed by this checkpoint.

## Exact implementation

Add preview/receipt schemas and `governance adoption preview|apply`. Preview inventories existing
`.guard/` plus optional `docs/guard-adoption/`, classifies add/replace/delete operations, binds provenance
and Target snapshot, and writes the candidate below StateRoot. Apply requires the exact preview hash,
revalidates Target state, confines writes to `.guard/`, refuses links/collisions and writes an external
receipt. Historical material is never silently activated or deleted.

## Acceptance and tests

`tests/m1/Test-V4GovernanceAdoption.ps1` covers empty/existing targets, provenance-preserving migration,
stale review, symlink/reparse refusal, collision, rollback artifact and exact `.guard/` confinement.
Positive/negative tests use disposable synthetic Targets only.

## Stop and resume

Stop before changing any real Target, authorization record, workflow, PR or ruleset. Stop if apply needs
a path outside `.guard/` or cannot preserve prior bytes for recovery. Resume only with a reviewed fresh
preview and, for any real consumer, a separate target trust-change Plan/authorization.

## Recovery

Use the receipt-bound recovery artifact to restore exact prior `.guard/` bytes in the synthetic/local
operation; source recovery is a revert. No remote rollback is part of this Plan.
