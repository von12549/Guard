# V4 P2A — project identity and state transactions

Status: local implementation checkpoint authorized on `codex/v4-development-base`

Parent roadmap: `docs/guards/v4/plans/01-v4-self-contained-guard-plugin.md`, V4-P2.1 and
V4-P2.2.

Predecessor: `20260922-v4-p1b-module-registry-gate`

## Goal

Implement deterministic project binding, atomic V4-owned state writes and fail-closed recovery of
prepared transactions before reset behavior is introduced.

## Scope

- Add experimental `state bind`, `state put` and `state recover` commands to the .NET host.
- Canonicalize and bind an existing TargetRoot to a deterministic project instance ID.
- Keep StateRoot and EvidenceRoot disjoint from PackageRoot, TargetRoot and each other.
- Write `state.json` and project data through prepared/applied transaction journals and same-directory
  atomic replacement.
- Recover an interrupted prepared transaction only when its temp payload matches the journal hash;
  otherwise mark it incomplete and fail closed.
- Extend the state schema and CLI contract without changing stable command identities.

## Validation

1. Formal Pre accepts this pair and its exact paths.
2. Repeated binding of the same canonical target is idempotent and a different target gets a
   different identity.
3. State writes are confined to the bound project data root and path/link/overlap negatives fail.
4. Prepared transaction recovery applies a valid payload and refuses hash drift.
5. P0/P1 and current V3 validation remain green.
6. No workflow, ruleset or remote state changes.

## Recovery

The recovery seed is P1B commit `b22d84d9fae44e86c00dc64400d5d685a1219aad`. P2A state is test-only
and lives under ignored artifacts; recovery is a separately authorized revert or branch restore.
