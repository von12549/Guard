# V4 P1B — module registry and authority gate

Status: local implementation checkpoint authorized on `codex/v4-development-base`

Parent roadmap: `docs/guards/v4/plans/01-v4-self-contained-guard-plugin.md`, V4-P1.3,
V4-P1.4 and V4-P1.GATE.

Predecessor: `20260922-v4-p1a-package-authority-skeleton`

## Goal

Close the P1 authority boundary with a strict, hash-bound module registry whose capability ceiling is
independent of each module manifest.

## Scope

- Add a strict module-registry schema and bind it into the frozen contracts manifest.
- Register every installed module by ID, manifest path/hash and maximum granted capabilities.
- Require an exact registry/catalog match and reject duplicate IDs, unknown fields and path escape.
- Reject a module that self-declares an unregistered root, process, network grant or timeout.
- Extend package tests with deliberate registry and capability-injection negatives.
- Preserve the empty-package, mutable-exclusion and all P0/P1A behavior.

## Validation

1. Formal Pre accepts this pair and its exact paths.
2. P0 and P1A suites remain green.
3. P1B registry tests reject unknown fields, duplicate IDs, path escape, manifest hash drift,
   undisclosed modules and capability escalation.
4. Current V3 Validate and `ifx-package-test` remain green.
5. No workflow, ruleset or remote state changes.

## Recovery

The recovery seed is P1A commit `b6f1db18df01529325cf202dc0a3caf4e6634edb`. No persistent V4
state exists, so recovery is a separately authorized revert or branch restore.
