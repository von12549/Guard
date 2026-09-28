# V4-TODO-011 phase 2 — `main` ruleset and `G2_V4_AUTONOMOUS`

Status: `COMPLETE 2026-09-28 — G2_V4_AUTONOMOUS; see §8`

Formal Plan ID: `20260928-v4-todo-011-phase2-ruleset`.

This Plan completes the backlog item V4-TODO-011 in `docs/plans/product/TODO.md`. It implements 03 §6 items 6–8
for Guard (§8), and follows phase 1 (`20260928-guard-v4-workflow-activation`). Its prerequisite,
V4-TODO-014, was completed on 2026-09-28.

## 1. Preconditions (verified 2026-09-28)

- **Active workflow.** `.github/workflows/v4-guards.yml` has been active on `main` since `b022f9e8`.
- **Frozen check names.** The check names are frozen. Every check run comes from the GitHub Actions app
  (`github-actions`, integration id `15368`).
- **Repeated success.** `v4-required` passed on PRs #4, #6, #9, #10, #11, #13, #14 and #15. The
  base-selected Windows smoke passed on #10 and #14.
- **Trust changes.** Trust changes can pass `v4-required` through authorization records (V4-TODO-014),
  so requiring the check does not block legitimate judge changes.
- **Repository.** The repository is public and user-owned, with one collaborator (`von12549`). `main`
  has no ruleset or branch protection. The default `GITHUB_TOKEN` permission is `read`, and the fork
  PR approval policy is `first_time_contributors`.

## 2. Design

### 2.1 Ruleset specimen

The reviewed specimen is `docs/plans/activation/guard-main-ruleset.json`, and it is applied
byte-for-byte through the REST API. It targets `~DEFAULT_BRANCH` and is `active`.

| Rule | Setting | Purpose |
| --- | --- | --- |
| `required_status_checks` | exactly `v4-required` from integration `15368`; `strict_required_status_checks_policy: true` | Only the aggregate base-owned verdict decides, and only GitHub Actions can satisfy it. Strict mode makes the judged base equal the current `main`, so base-held authorization records are current |
| `pull_request` | 0 approvals; `allowed_merge_methods: ["merge"]` | Every change reaches `main` through a PR. With strict mode, a merge commit preserves the certified head tree |
| `non_fast_forward`, `deletion` | on | No force-push or deletion of `main` |
| bypass | Repository admin, `bypass_mode: pull_request` | Only an explicit, logged admin merge of a PR can override. Direct pushes stay blocked even for the admin |

The conditional checks `v4-linux`, `v4-package`, `v4-windows` and `v4-contract` are not listed
separately. `v4-required` aggregates them and rejects a selected Windows job that did not succeed
(03 §4).

### 2.2 Review of workflow and authority changes (single maintainer)

03 §6 asks for "reviewed workflow/authority changes". The earlier TODO-014 records added
`.github/**` and `docs/plans/authorizations/**` to that scope. A required approving review cannot be
satisfied in a repository with one maintainer, because GitHub does not let authors approve their own
PRs. The review is therefore realized mechanically:

- **`.github/**`.**
  - `allowedChangedPatterns` excludes it, and the workflow `paths` filter does not watch it. So
    `v4-required` fails or never reports for such a PR, and only the logged admin bypass can merge it.
    That bypass is the review.
  - The fork-PR approval policy changes to `all_external_contributors`. A workflow modified in a fork
    then cannot run at all until the operator approves the run. This closes G3 (the merged workflow
    definition) for outside contributors.
- **`docs/plans/authorizations/**`.** Only an `authorization` Plan may add records (runner-enforced).
  Only the sole writer can merge them, and every merge is an explicit operator act.

When a second maintainer exists, a follow-up adds `CODEOWNERS` and code-owner review for both paths.
Step C5 adds this to the backlog.

### 2.3 Known fail-closed behaviour

- **PR outside the watched paths.** A PR that touches no watched path (today only `.github/**`) gets
  no `v4-required` and cannot merge without the bypass. This is intended.
- **Strict mode.** A PR must be brought up to date with `main` before it merges, which starts a new
  run against the new base. The trust-change flow already expects this: its record must bind the
  current base.

### 2.4 Bypass rule (O19, replaces the retired O16)

The admin bypass may be used only for:

1. a PR limited to `.github/**`, or to other paths outside V4 CI scope, after operator review;
2. recovery under TODO-014 §9, when the verdict mechanism itself is broken.

Each use requires:

- explicit operator confirmation on that PR;
- for code changes, exact-head dispatch certification (Linux-complete and Windows-full with one
  `packageHash`);
- a record in the checklist.

Claude never uses `--admin` without that per-PR confirmation.

## 3. Steps

| Step | Action | Remote effect |
| --- | --- | --- |
| C1 | PR with this Plan pair and the ruleset specimen (documentation only); merge when green | PR and merge |
| C2 | Set the Actions fork-PR approval policy to `all_external_contributors`; verify by GET | Repository setting |
| C3 | Create the ruleset from the merged specimen; verify with GET `rulesets/<id>` and GET `rules/branches/main` that the returned rules equal the specimen | Ruleset (G2 transition) |
| C4 | **Negative control.** A documentation PR whose root Plan paths do not match the diff. It must fail `v4-contract` and `v4-required`, and a normal (non-admin) `gh pr merge` must be refused by the ruleset (`mergeStateStatus: BLOCKED`). Close it unmerged | PR, refused merge attempt, close |
| C5 | **Positive control and records.** A records PR that is green and `CLEAN`, merged normally without bypass. It records: V4-TODO-011 complete; `G2_V4_AUTONOMOUS` in 03 §8 and the activation Plan; checklist §10a row 2 done and O19 added; a backlog note for code-owner review; migration receipt remote writes | PR and merge |

No tag, release, workflow change or product change is made.

## 4. Acceptance

- The GET results equal the specimen: the rules, `v4-required` from integration `15368`, strict mode,
  merge-only, and the admin `pull_request` bypass.
- The fork-PR approval policy is `all_external_contributors`.
- C4 shows a ruleset refusal. The evidence must be the refused merge together with
  `mergeStateStatus: BLOCKED`, not only a red check.
- C5 merges without bypass.

## 5. Rollback

Set the ruleset `enforcement` to `disabled`, which is recorded and reversible, or delete it. Restore
the fork-PR approval policy to `first_time_contributors`. Both actions are recorded. The system then
returns to `G1_V4_WORKFLOW_ACTIVE` (03 §7). The rollback touches no product code.

## 6. Stop conditions

Stop if any of the following occurs:

- the API rejects the specimen or returns different rules;
- the negative control can be merged without bypass;
- the positive control is blocked;
- the check source cannot be pinned to integration `15368`;
- anything would require a workflow, product or trust change.

## 7. Authorizations requested

- **C1–C5** as listed in section 3.
- **Out of scope:** tags, releases, bypass use, workflow edits, and T7 or T8.

## 8. Outcome (2026-09-28)

| Step | Result |
| --- | --- |
| C1 | PR #16 was green (run 36374092003) and merged as `b40db5b` |
| C2 | The fork-PR approval policy changed from `first_time_contributors` to `all_external_contributors` (GET readback) |
| C3 | The ruleset `v4-main-autonomy` was created (id `24096101`) from the merged specimen (SHA-256 `a32361a6…`). Every specimen field reads back identically. `rules/branches/main` lists exactly deletion, non_fast_forward, pull_request and required_status_checks from `24096101`. The API also returned two server defaults that are not in the specimen: `required_reviewers: []` and `require_extra_approval_for_unattributed_changes: true` |
| C4 | Negative control PR #17 failed `v4-contract` ("Root Plan paths do not exactly match the candidate diff") and `v4-required` (run 36374899561). It reported `mergeStateStatus: BLOCKED`, and `gh pr merge` without `--admin` was refused ("the base branch policy prohibits the merge"). Closed unmerged |
| C5 | This records PR was the positive control. It was green and `CLEAN`, and merged without bypass |
