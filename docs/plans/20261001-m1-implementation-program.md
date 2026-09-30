# M1 implementation program — installation, initialization and lifecycle

Status: `IMPLEMENTATION PROGRAM — READY 2026-10-01`

Formal Plan ID: `20261001-m1-implementation-program`.

Authority: `20261001-m1-foundation-decisions`, V4-AD-036 through V4-AD-038, and
V4-TODO-007/010/019.

## Goal and dependency order

Promote the accepted M1 decisions into six independently executable checkpoints:

1. `20261001-m1-runtime-distribution` measures and produces RID-specific self-contained Host and
   Companion inputs without publishing them.
2. `20261001-m1-installed-launcher` consumes that layout and resolves PackageRoot from installed
   launcher location.
3. `20261001-m1-project-initialization` introduces stable project context plus derived external
   StateRoot/EvidenceRoot defaults.
4. `20261001-m1-governance-adoption` adds separate preview/review/apply mechanics for `.guard/`.
5. `20261001-m1-version-lifecycle` adds verified immutable siblings, explicit selection and rollback.
6. `20261001-m1-storage-retention` adds protected-reference-aware cleanup preview/apply and receipts.

The JSON Plans intentionally have no native plan-set dependency edges because each checkpoint is an
exact sequential diff and must validate independently. The predecessor named in each Markdown Plan is
the required committed checkpoint; it is not recomposed into a later diff.

## Commit strategy

This program commit adds only the seven Plan pairs. Each implementation commit updates its own pair from
`READY` to `IMPLEMENTED`, changes every code path declared by that Plan, and changes no undeclared path.
If a discovered requirement needs another path, stop and revise the Plan pair before coding.

## Global boundaries

No checkpoint publishes a release, downloads or activates a package in the background, edits this
repository's workflows/ruleset, changes a consumer Target, pushes adoption output, opens or merges a
consumer PR, or treats an arbitrary external governance directory as authority. Target trust-change,
remote activation and release publication require separate Plans and authorization.

## Validation, stop and resume

Each child runs its focused M1 test, affected legacy suites, contract/package checks and an exact
base-to-head path audit. Stop on protected-path drift, unknown-file overlap, missing offline SDK/runtime
packs, schema incompatibility, or any need for remote mutation. Resume only from the last committed
checkpoint after revising its exact Plan or completing the established authorization flow.

## Recovery

Revert one checkpoint at a time in reverse order. Local test artifacts remain disposable and external;
no checkpoint changes remote or consumer state.
