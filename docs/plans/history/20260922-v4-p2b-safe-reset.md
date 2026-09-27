# V4 P2B — safe project and factory reset

Status: local implementation checkpoint authorized on `codex/v4-development-base`

Parent roadmap: `docs/guards/v4/plans/01-v4-self-contained-guard-plugin.md`, V4-P2.3 through
V4-P2.6 and V4-P2.GATE.

Predecessor: `20260922-v4-p2a-state-transactions`

## Goal

Implement manifest-driven project and factory reset with separate Preview/Apply, explicit hash
acceptance, path confinement, race detection, receipts and idempotent replay.

## Scope

- Add a strict reset-manifest schema and hash-bind it in the contract manifest.
- Implement stable `reset project|factory --mode preview|apply` in the .NET host.
- Preview only project claims recorded in state and emit exact file/directory hashes.
- Apply only the accepted, freshly recomputed manifest; changed contents fail closed.
- Refuse package/target paths, traversal, links/reparse points, `.git` worktree/gitlink markers and
  paths outside recorded claims.
- Preserve unclaimed mutable paths, write before/after receipts and make accepted replay idempotent.

## Validation

1. Formal Pre accepts this pair and its exact paths.
2. Project reset deletes only one project's state/evidence; factory reset deletes all bound projects.
3. TargetRoot, PackageRoot and unclaimed mutable paths remain byte-identical.
4. Changed-after-preview, traversal, authority overlap, link/reparse and `.git` negatives fail closed.
5. Reapplying an accepted manifest returns the existing receipt without further deletion.
6. P0/P1/P2A and current V3 validation remain green.
7. No workflow, ruleset or remote state changes.

## Recovery

The recovery seed is P2A commit `d70903e29b65ad1beb83bacdcd6ff690b6c30809`. Reset tests use only
ignored fixture roots; source recovery is a separately authorized revert or branch restore.
