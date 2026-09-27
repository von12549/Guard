# V4 P0C — genesis bootstrap and autonomy proposal

Status: local proposal checkpoint authorized on `codex/v4-development-base`; activation is not authorized

Parent roadmap: `docs/guards/v4/plans/01-v4-self-contained-guard-plugin.md`, V4-P0.6 and
V4-P0.GATE.

Predecessor: `20260922-v4-p0b-contract-freeze`

## Goal

Make the finite V3 genesis ceremony and the exact handoff to base-owned V4 governance reviewable
without activating a workflow, changing the current V3 workflow or modifying remote rules.

## Scope

- Record the already authorized local branch identity and the immutable P0 recovery lineage.
- Define the three transition states: V3 genesis bootstrap, dormant V4 base, and V4 autonomy.
- Specify the evidence and separate authorization required to move between states.
- Provide a non-active GitHub Actions proposal with the stable V4 check names.
- Require the previously trusted V4 base to judge a candidate head and prevent head self-judgment.
- Identify the exact future activation paths and remote operations, but do not perform them.
- Prove the proposal remains outside `.github/workflows/` and that the active V3 workflow is unchanged.

## Validation

1. Formal Pre accepts this pair and its exact paths.
2. The proposal test verifies branch, recovery, transition, check-name and trust invariants.
3. The workflow specimen is stored only under the inactive V4 integration tree.
4. Current V3 Validate and `ifx-package-test` remain green.
5. No workflow, ruleset, push, pull request, merge or other remote state changes.

## Recovery

The recovery seed for this checkpoint is P0B commit
`b44c85fcd62d944e245c2782e21ec7f81af22e61`. Recovery requires a separately authorized revert or
branch restoration. The proposal itself is inactive and creates no remote configuration to unwind.
