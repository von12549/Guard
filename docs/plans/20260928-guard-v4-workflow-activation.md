# Guard V4 trusted-base workflow activation (03 §6, V4-TODO-011 phase 1)

Status: `PHASE 1 COMPLETE ON MERGE OF THE RECORDS PR — A: PR #2 → 118644e3; B+C: b022f9e8; D: PR #3 rejected as designed; E: records PR (positive control). Phase 2 (ruleset) remains V4-TODO-011`

Formal Plan ID: `20260928-guard-v4-workflow-activation`.

Supersedes step T6.6 of `20260928-v4-todo-008-t6-guard-genesis`. T6.6 assumed a workflow could be
installed on its own. The product's activation contract
(`docs/plans/product/03-genesis-bootstrap-and-autonomy.md` §5–§6) and its dormant-state checks make that
impossible, so activation needs its own reviewed transaction. That transaction is this Plan.

## 1. Starting state

- Guard `main` is `65cf6cde` (the genesis seed, T6.5). The state is `G1_V4_DORMANT_BASE`: a trusted
  seed with no active V4 verdict workflow.
- `.github/workflows/v4-certification.yml` (T6.3) is dispatch-only platform evidence. It is not a verdict.
- Package identity is `491e7eb4…`. Linux-complete 33/33 and Windows-full 34/34 pass on GitHub runners.

## 2. Scope and phasing against the backlog

03 §6 defines `G2_V4_AUTONOMOUS` as an active workflow **plus** a ruleset that requires `v4-required`.
The backlog item V4-TODO-011 ("Remote V4 ruleset activation") defers the ruleset until the V4
development workflow has succeeded repeatedly and the check names are frozen. This Plan therefore does
**phase 1 only**:

| Phase | Content | Resulting state |
| --- | --- | --- |
| **1 (this Plan)** | Activation-ready product refinement; genesis record; active workflow on `main`; negative- and positive-control PRs; backlog update | `G1_V4_WORKFLOW_ACTIVE`: base-owned verdicts run on every PR to `main` but are advisory, with no ruleset |
| 2 (V4-TODO-011, later) | Ruleset requiring the exact `v4-required` context with strict up-to-date checking, after repeated success | `G2_V4_AUTONOMOUS` |

03 §6 item 4 (changing IFX's `v3-ifx-guardrails.yml`) is IFX-only and does not apply to Guard.

## 3. Product refinement (step A, the first post-seed PR)

This changes package authority, so the package identity changes and the change is declared. The public
CLI, runtime schemas, modules and profiles do not change.

1. **Specimen `integrations/github/proposed-v4-guards.yml`**:
   - The target branch becomes `main`, and the path filter gains `.gitattributes`.
   - `v4-linux` and `v4-windows` (the jobs that build; `v4-package` only verifies) get a **base-owned** step that prefetches the hash-locked
     NuGet dependencies before the runner starts. The step reads `dependencies.lock.json` from the
     materialized `V4_BASE`, never from the candidate, and fails unless every `.nupkg.sha512` equals its
     locked value. `build/NuGet.config` stays offline, so a candidate cannot add a source.
   - Check identities, trust direction, failure semantics and Windows selection are unchanged.
2. **Activation-aware dormant checks**: `tests/p0/Test-V4GenesisProposal.ps1`,
   `tests/p6/Test-V4WorkflowContract.ps1` and `core/certification/Invoke-V4V1Certification.ps1` accept
   `.github/workflows/v4-guards.yml` only when it is absent, or when it is byte-identical to the specimen
   except for its first comment line. The active workflow therefore cannot drift from the reviewed
   specimen without a new product Plan.
3. Rebind the CI contract test hashes. `targetBranch` stays a schema constant, recorded as declared
   naming debt (the runner does not read it).
4. **Acceptance while still in G1**: operator review, plus dispatch certification of the exact PR head
   (Linux-complete and Windows-full, one matching `packageHash`), then a merge commit.

## 4. Activation transaction (steps B–E)

| Step | Action | Evidence |
| --- | --- | --- |
| B | Write a schema-valid genesis record (`core/contracts/genesis-record.schema.json`) accepted by `human-review`. It binds the step-A merge commit, its package and contracts-manifest hashes, both certification reports and the recovery point `65cf6cde`. It is stored at `docs/plans/activation/guard-genesis-record.json` (governance, not package). | schema validation |
| C | One operator-authorized commit directly on `main` adds `.github/workflows/v4-guards.yml`, derived from the specimen with only the first comment line changed, plus the genesis record. Workflow changes lie outside `allowedChangedPatterns`, so they can never enter through a candidate PR. | workflow registered and active |
| D | **Negative control**: a PR whose root Plan under-declares its diff, and which also edits an approved test without a contract change. `v4-required` must fail through the base runner (`do not exactly match` / `Approved test hash drift`). The PR is closed without merge. | failing check run URL |
| E | **Positive control**: the records PR described below, with an exact root Plan. `v4-contract`, `v4-linux`, `v4-package` and `v4-required` must pass (Windows as selected by the base classifier). It is merged with a merge commit. | passing check run URL |

## 5. Backlog and records update (carried by the positive-control PR, step E)

On completion, the positive-control PR updates:

- `docs/plans/product/TODO.md`:
  - **V4-TODO-011**: record that phase 1 is complete. List the active workflow commit, the negative- and
    positive-control PR evidence and the frozen check names (`v4-contract`, `v4-linux`, `v4-package`,
    `v4-windows` conditional, `v4-required`). State that repeated-success tracking starts now and that
    creating the ruleset (phase 2, reaching G2) remains a separately authorized remote operation.
  - **V4-TODO-008**: T6 progress (seed merged, T5 pass, activation phase 1 complete, T6.7 release pending).
  - **V4-TODO-012**: real run-duration data collection starts with the active workflow.
- `docs/plans/product/03-genesis-bootstrap-and-autonomy.md`: a Guard adaptation note (state
  `G1_V4_WORKFLOW_ACTIVE`; §6 item 4 not applicable; ruleset deferred to V4-TODO-011).
- The V4-TODO-008 execution checklist and migration receipt: the T5 pass, T6.4 and T6.5 records held back
  so the seed stayed the certified commit, and this Plan's outcome.

## 6. Authorizations requested

A (PR + dispatch certification + merge), C (direct activation commit on `main`), D (negative-control
PR, closed unmerged) and E (positive-control PR + merge). There are no rulesets, required contexts,
tags or releases.

## 7. Stop conditions and rollback

**Stop** on:

- a failed certification or a `packageHash` mismatch between platforms;
- a negative control that passes;
- a positive control that fails;
- any workflow permission beyond `contents: read`, any secret use, or any verdict step taken from the
  candidate head;
- any need for a ruleset.

**Rollback**:

- Before C: close the PR or revert through a reviewed commit.
- After C: a reviewed commit on `main` deletes `.github/workflows/v4-guards.yml`, which returns the state
  to G1 dormant.
- No force push and no history rewrite.
