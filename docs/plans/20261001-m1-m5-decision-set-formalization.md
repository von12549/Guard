# M1–M5 decision-set formalization

Status: `DOCUMENTATION CHECKPOINT — IMPLEMENTED 2026-10-01`

Formal Plan ID: `20261001-m1-m5-decision-set-formalization`.

## Goal

Commit the accepted M1–M5 decision records, their maintained product index/backlog updates and the
ignored discussion-memory boundary as one exact documentation change before any dependent product
implementation begins.

## Scope

- Add the seven accepted milestone decision Plan pairs for M1 through M5.
- Update the architecture decision set, product-plan index and backlog to distinguish accepted decisions
  from implementation that remains open.
- Ignore `memory/` so discussion drafts cannot accidentally become maintained authority.
- Preserve every pre-existing decision document byte-for-byte within this checkpoint.

The milestone decision Plans remain the semantic authority for their respective decisions. This root
Plan exists because those records intentionally update shared product documents and therefore cannot be
composed as one native plan-set with unique path ownership.

## Ordering and boundaries

This documentation checkpoint precedes every M1 implementation Plan. It does not authorize product,
contract, test, workflow, ruleset, consumer, release or remote changes. Later implementation commits
must carry their own exact Plan pairs and must not fold Target trust-change, CI/ruleset activation or
release publication into local implementation.

## Validation

1. The root Plan declares every changed path and no generated `obj/` path.
2. All eight Plan JSON documents validate against `core/contracts/plan.schema.json`.
3. M1 decisions map to V4-AD-036 through V4-AD-038 and V4-TODO-007, 010 and 019.
4. Package and required local validation remain green with no remote mutation.

## Stop and resume

Stop if any existing milestone document must be rewritten, if an unknown worktree path enters the
staged set, or if local validation requires a protected/remote mutation. Resume only from a clean commit
containing exactly the declared documentation paths; unknown `obj/` outputs remain unstaged.

## Recovery

Revert this documentation-only checkpoint. No runtime, Target, consumer or remote data requires
rollback.
