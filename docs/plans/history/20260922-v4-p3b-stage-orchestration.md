# V4 P3B — visible Stage dependencies and clean-reset certification

Status: local implementation checkpoint authorized on `codex/v4-development-base`

Parent roadmap: `docs/guards/v4/plans/01-v4-self-contained-guard-plugin.md`, V4-P3.3 and
V4-P3.GATE.

Predecessor: `20260922-v4-p3a-direct-stages`

## Goal

Complete the independent Stage runtime with opt-in, result-visible dependency orchestration and
certify every Stage under direct positive, direct negative and post-reset execution.

## Scope

- Add the architecture-approved optional `--with-dependencies` switch to stable `stage run`.
- Keep direct execution as the default and never infer or run an earlier Stage without that switch.
- Extend the Stage result contract with the exact ordered Stage identities actually attempted.
- Stop orchestration at the first prerequisite, adapter or blocking-finding failure.
- Exercise all four Stages against positive, blocking, missing-input and accepted clean-reset cases.
- Preserve V3/V3_ifx behavior and keep all workflow/ruleset activation out of scope.

## Validation

1. Formal Pre accepts this pair and its exact paths.
2. Direct Post reports only Post, while opt-in Post reports Bootstrap, Analysis, Pre and Post in
   canonical order.
3. An orchestrated dependency failure stops before the requested later Stage and remains visible.
4. Every Stage passes direct positive, blocking, missing-input and post-project-reset execution.
5. Updated results and CLI contracts are schema-valid and their contract-manifest hashes are exact.
6. P0-P3A and current V3 validation remain green with no workflow, ruleset or remote state changes.

## Recovery

The recovery seed is P3A commit `50a52182b767423491f5ee15c89372804da2af3f`. Test data lives
only below ignored artifact roots; source recovery is a separately authorized revert or branch
restore.
