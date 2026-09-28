# V4-TODO-008 execution checklist

Status: `T0–T5 PASS; T6.1–T6.5 DONE (seed merged); T6.6 SUPERSEDED BY THE ACTIVATION PLAN (phase 1 complete); T6.7 DONE — V4 GUARDS 1.1.5 PUBLISHED; T7/T8 NOT AUTHORIZED`

Executor: **Claude Code**. Operator: the repository owner (`von12549`).

This checklist is the working execution record for
`20260927-v4-todo-008-standalone-repository-extraction`. It does not replace the governing Plans. If
this checklist differs from them, the master Plan, then the latest explicit operator instruction, win.
Amendment A1 below is such an operator instruction.

## 1. Governing documents

Bound at IFX commit `640c57566688ca1aee683923d53ad6e57fd5f16c`:

| Document (IFX path) | Git blob | SHA-256 |
| --- | --- | --- |
| `docs/guards/plans/20260927-v4-todo-008-standalone-repository-extraction.md` | `e5d48f103f2d4dbdc81f9efd4eae2d3722630ab5` | `971927fc8fbb74a54d429573d4a6d7d64fde8111f31b8cbbf04aa6770a56c9df` |
| `docs/guards/plans/20260927-v4-todo-008-standalone-repository-extraction.plan.json` | `76dbc95db71c6b977112689e23df06a3b20d8452` | `565d213e411ad3617a08546657436f537786d5d3b298528ac1ae382b7f13632a` |
| `docs/guards/plans/20260927-v4-todo-008-claude-code-handoff.md` | `cff611ab54602cceecf7f80a47d2a7e137ef38d3` | `347e4cebd0b21e2c4c6fce054d8a452a9c62eba5c2c0b116ccc71016356cc8e3` |

SHA-256 values are computed over the committed blob content (`git show <commit>:<path>`), not over
working-tree bytes, because `core.autocrlf=true` is set in both repositories.

The IFX amendment commit `286e453d5db66b9283c8432d81030717799b84cb` ("docs(guards): rebind V4
extraction source (A1)") records A1 in the governing documents. These amended versions are the ones T4
copies byte-exact into `docs/plans/migration/`:

| Document | Git blob at `286e453d` | SHA-256 |
| --- | --- | --- |
| master Plan `.md` | `582b433c3163ff1046195896e88c41b66fa48691` | `087a421b660628047e22bec3b871c5ec5aa4c875ad03d8f1f14d0438d30ae127` |
| master Plan `.plan.json` | `7b5a3c9fa752bce07a33335d9ab9246d81c4791d` | `5f17ae260b4f7839badbceb90ed15a692f601759cc9a85b5ea89e29e90acd43f` |
| handoff `.md` | `abdd831abb9c718a9dc9570878dc3646c169f4e8` | `7072132e4194d918257602292f393f1aceea7e41dd4111508273e054fb237c10` |

## 2. Amendment A1 — source commit rebinding

Decided by the operator on 2026-09-27 (option 1 of the pre-T0 review).

The master Plan bound the export to `ba0816321bcb04dba93136beea80f41f237517de`. Commit
`6b80fc04` ("docs(guards): start V4 standalone repository program") then changed three files inside
the V4 subtree (`plans/00-architecture-decision-set.md`, `plans/README.md`, `plans/TODO.md`:
V4-AD-019 accepted, V4-TODO-008 started). Exporting from `ba081632` would omit that decision from
Guard history. The export is therefore rebound to the current development tip:

| Property | Master Plan value (superseded) | A1 bound value |
| --- | --- | --- |
| Source commit | `ba0816321bcb04dba93136beea80f41f237517de` | `640c57566688ca1aee683923d53ad6e57fd5f16c` |
| V4 source tree object | `e3c359491709ee49b73979276a0143ed52221999` | `418a1933e985aa17c59307c0a25434e19de4aeba` |
| Tracked V4 files | 174 | 174 (unchanged) |
| Commits touching the V4 subtree | 47 | 48 (`+6b80fc04`) |
| First V4 commit | `20c93d521728746e1c227654b32219d94fcdf6bb` | unchanged |

Rules that follow from A1:

- Every master Plan and handoff reference to `ba081632…`/`e3c35949…` as the **export** identity reads
  as `640c5756…`/`418a1933…`. References to `ba081632` as the accepted P10.3 checkpoint stay
  historical facts.
- The T5 old-vs-new comparison builds the IFX source at `640c5756`. The only V4 difference from
  `ba081632` is documentation in `plans/`.
- `640c5756` was local-only when A1 was decided. It is now public: `codex/v4-development-base` was
  fast-forwarded on `origin` (`6b80fc04..286e453d`), closing O1.
- A1 is recorded in IFX by `286e453d`, which changes only `docs/guards/plans`.
  `286e453d:docs/guards/v4` is still `418a1933…` (O2 closed). The export stays bound to
  `640c5756`, not to `286e453d`.

## 2a. Amendment A2 — reconcile the 1.1.4 release lineage before export

Decided by the operator on 2026-09-27, during T1 ("Reconcile in IFX first (A2)"). The decision also
authorized the local IFX merge commit. Pushing the merge needs a separate authorization.

T1 found that the published `v4-guards-v1.1.4` (`2185477b`) is **not** an ancestor of `640c5756`.
V4 Guards 1.1.4 was cut on `codex/v4-guards-1.1.4-release` (tip `3641d81e`) from the 1.1.3 tag
`90aa87b5` and never merged back. The development branch carries the pre-release form of the same
workspace-evidence feature (`87a12b1f`). It lacks these release-only corrections:

- empty-config strict-mode safety in the synthetic adapter;
- the P0 spike EvidenceRoot capability;
- per-child `core.longpaths=true` clones;
- the TargetScope evidence-root narrowing;
- the 1.1.4 metadata, integrity records, release notes and release Plan.

Exporting `640c5756` would give Guard a product source older than its latest release.

A2 execution:

1. IFX Plan pair `20260927-v4-guards-1-1-4-release-reconciliation` was committed as
   `17a1d56c2e244717f64576059b711e2e5f79480a` (docs only; V4 native `plan validate` passed).
2. The scripted merge (`_tools/merge-114-release.sh`) asserts the exact conflict set and resolves
   every conflict to the published 1.1.4 content. The conflicts are all in `docs/guards/v4`:
   `README.md`, `modules/registry.json`, `modules/synthetic-probe/adapter.ps1` and `module.json`. In
   each, the whole development-versus-release difference is the release correction or its hash.
   The script refuses any product drift from the release tree.
3. Trial merge in a disposable clone: `9c4e1ef6`, tree `97abd4b6405612e5d3bd03f760bda29a6a846f70`,
   V4 tree `af913836d83c071b9c0a769c6c84da4fb727b971`, 175 V4 files. The merged package authority
   equals the 1.1.4 release source (`packageHash 30b2571c…`) plus exactly the two IFX-only files that
   T4 removes. There are 0 differing authority files.
4. The first Windows-full attempt from a 43-character `%TEMP%` clone root failed in P6 with
   `Filename too long` (O8). The re-run from the short root `D:\v4t\a2-fe1175` **passed**: 34 tests,
   `packageHash 2970bac5…`, Windows 10.0.26200.
5. The live merge in IFX is `80f7b6b65fb06897444a6a36c604c42c93c834e4`, with parents `17a1d56c` and
   `3641d81e`. It reproduces tree `97abd4b6…` exactly. IFX `fsck --full --strict` passed.
6. The A2 amendment commit `af2bd603a31be362128a881f684847e40bb7ce5a` rebinds the master Plan,
   `.plan.json` and handoff to `80f7b6b6` (V4 native `plan validate` passed). T4 copies these
   `af2bd603` versions into `docs/plans/migration/`. They supersede the §1 `286e453d` blobs.
7. Not pushed: `17a1d56c`, `80f7b6b6` and `af2bd603` are local (O13).

Evidence: `T1-A2-reconciliation/20260927T101043Z` (`SHA256SUMS` `cec17c9b…`).

## 2b. Amendment A3 — Guard genesis seed (2026-09-28)

Guard `main` holds no V4 runner, and the IFX runner cannot judge the Guard layout, so no previously
trusted V4 base exists for the migration PR. Following the IFX genesis precedent (V4-AD-035), the
migration PR is a genesis seed. The operator accepts it on the recorded evidence: T5, structured and
binary equivalence, and GitHub-hosted exact-commit Linux-complete plus Windows-full certification.
Trusted-base CI verdicts apply from the first post-seed change. The governing Plan is
`docs/plans/20260928-v4-todo-008-t6-guard-genesis.md`.

## 3. Bound identities (effective after A2; A1 values 640c5756… / 418a1933… / 174 / 48)

```text
IFX_WORKTREE=D:\IFX-Root\IFX
IFX_BRANCH=codex/v4-development-base
IFX_SOURCE_COMMIT=80f7b6b65fb06897444a6a36c604c42c93c834e4
IFX_V4_PATH=docs/guards/v4
IFX_V4_TREE=af913836d83c071b9c0a769c6c84da4fb727b971
IFX_V4_TRACKED_FILES=175
IFX_V4_TOUCHING_COMMITS=50
IFX_V4_FIRST_COMMIT=20c93d521728746e1c227654b32219d94fcdf6bb

GUARD_WORKTREE=C:\Users\von12\OneDrive\Desktop\Guard
GUARD_REMOTE=https://github.com/von12549/Guard.git
GUARD_DEFAULT_BRANCH=main
GUARD_INITIAL_COMMIT=e75d0386492632e4df87230f3b64252086d1bc58
GUARD_INITIAL_README_BLOB=d6e5996b5246743aba98e26e1ee7e7292f26ead8
GUARD_WORK_BRANCH=codex/v4-todo-008-standalone

PERSISTENT_EVIDENCE_ROOT=D:\IFX-Root\v4-todo-008-evidence
P10_3_DECISION_SHA256=529e19b567c05619ec054117e2514c579a908a4e614355411fc28b6d52964964
```

Pre-T0 observations (read-only, 2026-09-27; T0 must re-verify all of them):

- IFX worktree clean, HEAD `640c5756`, `ahead 1` of origin.
- Guard worktree clean, HEAD = `origin/main` = `e75d0386…`, sole tracked file `README.md`,
  `git fsck --full --strict` passed, ordinary Git access worked (no `safe.directory` fallback).
- V4 subtree top level: `README.md build core docs integrations modules plans plugin.json profiles tests`.
  It has a `docs/` directory but no `docs/plans/`, so this checklist's path cannot collide in T3.
  The only expected T3 conflict is still root `README.md`.
- No `.gitattributes` in the V4 subtree. `core.autocrlf=true` in both repositories.
- Repository instructions: `D:\IFX-Root\IFX\CLAUDE.md` exists (IFX application guidance). There is no
  `AGENTS.md` in either repository and no `CLAUDE.md` in Guard.
- Tags present in IFX: `v4-guards-v1.0.0` and `v4-guards-v1.1.0` … `v4-guards-v1.1.4`. All of them are
  immutable. T1 inventories v1.0.0 as well.
- `docs/guards/plans` at `640c5756`: 676 files, 288 with `v4` in the filename. This is the T1 Plan
  classification workload.
- Git `2.49.0.windows.1`. `gitleaks` and `trufflehog` are not installed (open item O3).
- Evidence root `D:\IFX-Root\v4-todo-008-evidence` does not exist yet.

## 4. Guard working-tree accounting

This file is the only intentional untracked path in Guard before T3. At every boundary before T3, the
clean-worktree check passes only if `git status --porcelain=v1 --untracked-files=all` lists exactly
`?? docs/plans/migration/20260927-v4-todo-008-execution-checklist.md` and nothing else. T0 records this
file's SHA-256 in evidence.

In T3 the file is committed as its own docs-only commit, immediately after the two-parent merge
commit and before the T3 clean/fsck proof. After that, each tranche's checkpoint commit updates this
checklist. It is never committed to `main`, and it is never committed before the merge, so the merge
commit's first parent stays exactly `e75d0386…`.

## 5. Operator attestations

| ID | Attestation | Status |
| --- | --- | --- |
| P-1 | OneDrive synchronization manually paused by the operator | **Attested in chat on 2026-09-27** |
| P-2 | All other Git clients (IDE, GUI, other shells/agents) closed for both repositories | **Attested in chat on 2026-09-27** |
| P-3 | All Guard files are locally available (fully hydrated, not online-only) | **Attested in chat on 2026-09-27**; automated scan found 0 placeholders |
| P-4 | OneDrive stays paused until T3 closes and its fsck passes | **Attested in chat on 2026-09-27** |

T0 observation: the first process scan found VS Code with the Guard folder open, plus 4 Codex
processes. The operator closed them, and the rescans (`040-git-client-recheck-2`) found none. No
OneDrive process was running at T0.

Claude Code never pauses, kills or reconfigures OneDrive. It only records process and attribute state.

## 6. Authorization ledger

| Boundary | Scope | Status |
| --- | --- | --- |
| A-LOCAL | T0–T5 local work: evidence root, disposable clones, local Guard branch and commits | **Authorized 2026-09-27** ("授权执行T0–T5本地部分") |
| A-IFX-AMEND | Local IFX commit recording A1 outside `docs/guards/v4` (O2) | **Authorized 2026-09-27** ("O2：在IFX做一个本地修订提交"); done `286e453d` |
| A-TOOL | Install a secret scanner (O3) | **Authorized 2026-09-27** ("O3：批准安装"); done, gitleaks 8.30.1 |
| A-PUSH | Push `codex/v4-todo-008-standalone` to `von12549/Guard` | **Authorized 2026-09-28** (T6 Plan `20260928-v4-todo-008-t6-guard-genesis`, "Approve; do T6.1–T6.4") |
| A-PR | Open/update the Guard migration pull request | **Authorized 2026-09-28** (T6.2) |
| A-CI | Add the minimal trusted-base Guard workflow through its own Plan | A-CI-1 (dispatch-only certification workflow committed directly on `main`, plus its dispatch at the PR head) **authorized 2026-09-28** (T6.3/T6.4). A-CI-2 (trusted-base PR workflow activation, T6.6) is not authorized |
| A-MERGE | Merge the Guard PR / update Guard `main` | **Authorized 2026-09-28** ("授权T6.5合并和T6.6激活"); PR #1 merged as `65cf6cde` |
| A-ACT | Activation Plan `20260928-guard-v4-workflow-activation` steps A, C, D and E | **Authorized 2026-09-28** ("授权执行A、C、D、E"). A: PR #2 → `118644e3`; C: `b022f9e8`; D: PR #3 rejected; E: records PR |
| A-RELEASE | Create a tag/release/asset for the new standalone version | **Authorized 2026-09-28** ("授权执行R1–R5"). Tag `v4-guards-v1.1.5` → `a02ee3c6`; release https://github.com/von12549/Guard/releases/tag/v4-guards-v1.1.5 |
| A-IFX-REBIND | T7 IFX consumer rebinding commits | Not authorized |
| A-IFX-REMOTE-O13-O5 | O13: push `codex/v4-development-base` (`286e453d..af2bd603`). O5: push, PR and merge its two-step V3_ifx fix into `codex/v4-development-base` | **Authorized 2026-09-28** ("授权执行O13/O5的推送，PR和合并"; then "关闭 PR，改为直接推送两个分支到开发分支"). O13 done. O5 done: PR von12549/IFX#108 closed without merge; the operator merged `707b3019` and `42b666ac` directly and pushed them |
| A-IFX-PUSH (O1) | Fast-forward push of `codex/v4-development-base` to IFX `origin` | **Authorized 2026-09-27** ("O1：授权推送"); done `6b80fc04..286e453d`. Any further IFX push needs new authorization |
| A-IFX-DELETE | T8 protected removal of `docs/guards/v4` from IFX | Not authorized |
| Out of scope | V4 activation, IFX workflow/ruleset/required-context change, P10.GATE, V3/V3_ifx retirement | Never under V4-TODO-008 |

One approval never implies the next. Record each approval here with its date and exact wording.

## 7. Global rules for every tranche

- [ ] Evidence goes to `D:\IFX-Root\v4-todo-008-evidence\<Tn-name>\<run-id>`, with `run-id` in the form
      `yyyyMMddTHHmmssZ` (UTC). For every migration command, record the command, the resolved paths,
      the exit code, SHA-256 digests of stdout/stderr, and the tool version.
- [ ] `%TEMP%` holds disposable clones only. Copy the final records to the evidence root and verify
      their hashes before removing any disposable directory. Validate the absolute path before
      removing it.
- [ ] Byte identity is checked by Git blob ID and by SHA-256 of blob content, never by working-tree
      bytes (because of autocrlf).
- [ ] Forbidden: `git reset --hard`, force push, broad recursive deletion, `safe.directory=*`,
      `subtree split --rejoin`, `git filter-repo`, and any operation on the live IFX `.git` other than
      read-only commands and the no-hardlink clone.
- [ ] Run `git fsck --full --strict` after every history-changing checkpoint.
- [ ] A failure stops the program. It is not repaired in a later tranche.
- [ ] At the end of each tranche, send the handoff's required final report (§11 template).

## 8. Tranche checklists

### T0 — Re-read authority and freeze identities

Evidence: `T0-identity/<run-id>`.

- [x] A-LOCAL granted and recorded in §6.
- [x] Re-read the master Plan and handoff, and verify their blobs and SHA-256 values against §1.
- [x] Read `D:\IFX-Root\IFX\CLAUDE.md` and record any rule relevant to migration. Confirm there is
      still no `AGENTS.md` in either repository and no `CLAUDE.md` in Guard.
- [x] IFX: `status -sb` is clean; `rev-parse 640c5756` resolves; `640c5756:docs/guards/v4` is
      `418a1933…`; `ls-tree -r` gives 174 files; `rev-list --count 640c5756 -- docs/guards/v4` is 48;
      the first V4 commit is `20c93d52…`.
- [x] Guard: `status -sb` shows only this checklist untracked (§4); HEAD = `origin/main` =
      `e75d0386…`; the remote is exactly `origin https://github.com/von12549/Guard.git`; tracked
      files are only `README.md` with blob `d6e5996b…`; `fsck --full --strict` passes.
- [x] Record whether the `safe.directory` fallback was needed. Expected: not needed.
- [x] GitHub GET only: `von12549/Guard` is public, the default branch is `main`, there are no
      rulesets, and there is no `.github/workflows`.
- [x] P-3 and P-4 attested and recorded.
- [x] Scan the Guard tree (including `.git`) for OneDrive placeholder attributes: `Offline` (0x1000),
      `RecallOnOpen` (0x40000), `RecallOnDataAccess` (0x400000), and unexpected `ReparsePoint`.
      Expected count: 0. Also scan for `*-<MACHINE>*`/conflict-copy duplicates and stray
      `.git/*.lock` files.
- [x] Record the OneDrive process state (read-only) and the Guard directory attributes.
- [x] Record tool versions: git, Git Bash, `git subtree` availability, pwsh, dotnet, node/npm, and
      any secret scanner. Record `core.autocrlf` and `core.longpaths` for both repositories.
- [x] Create `D:\IFX-Root\v4-todo-008-evidence` and the T0 run directory. Write
      `t0-identity.json` plus the command log, with hashes.

Exit: every row matches; otherwise the tranche is `stopped`.

**T0 result: `pass`** — evidence `T0-identity/20260927T090305Z` (`SHA256SUMS` `a8e48d90…`, `t0-identity.json` `e375e9b7…`); 48 recorded commands, all non-zero exits explained.

### T1 — Disposition and provenance manifests

Evidence: `T1-manifests/<run-id>`. No repository is modified.

- [x] `migration-source-inventory.json`: all 175 paths at `80f7b6b6:docs/guards/v4` (A2), with blob ID and
      blob SHA-256.
- [x] `migration-path-disposition.json`: exactly one row per source path, using the handoff field
      schema (`sourcePath, sourceBlob, sourceSha256, owner, destinationRepository, destinationPath,
      action, reason`).
- [x] The six fixed rows are set to `ifx-consumer` / delete from the active Guard tree at T4 / retained
      in history / IFX successor under `docs/guards/v4-adoption/...`:
  - [x] `plans/06-ifx-profile-validation-program.md`
  - [x] `plans/07-p10-0-baseline-acceptance.md`
  - [x] `plans/08-p10-1-extension-composition-compatibility.md`
  - [x] `plans/09-p10-3-cutover-and-rollback-proposal.md`
  - [x] `integrations/github/ifx-cutover-proposal.json`
  - [x] `integrations/github/proposed-v4-ifx-guardrails.yml`
- [x] Search for additional IFX-only files (IFX Profile/Bundle/P10/target-fixture content) and apply
      the same rule. Each addition must carry a reason.
- [x] Mixed product documents (`plans/00`, `01`, `02`, `plans/README.md`, `plans/TODO.md`,
      `05-p9-gate-audit.*`, root `README.md`) get a product disposition plus a recorded list of the
      IFX-status passages that T4 replaces with adoption-history links.
- [x] `migration-plan-disposition.json`: every V4-named formal Plan pair in `docs/guards/plans`
      (292 files at `80f7b6b6`) is classified as generic `historical-copy` → Guard
      `docs/plans/history/` byte-exact, or as IFX/P10 retained in IFX. A filename containing `v4` alone
      never makes a Plan product-owned. This master Plan and the handoff are `copy-exact` →
      `docs/plans/migration/`.
- [x] `migration-release-inventory.json`: tags `v4-guards-v1.0.0`, `v1.1.0` … `v1.1.4` with target
      commit, release URL, asset names, sizes and SHA-256 (GitHub GET only). All are marked immutable.
- [x] `migration-coupling-inventory.json`: every occurrence of `docs/guards/v4`, `docs/guards/plans`,
      `artifacts/guards/v4`, `${{ github.repository }}`, IFX release URLs, and fixed `..` parent
      traversal, with file:line locations and the planned T4 fix.
- [x] Exclusions list: P10 evidence, target fixtures, accepted bundles, ignored/generated artifacts.
- [x] Zero-gap check: no `unknown`, no duplicate source rows, no duplicate active destination
      authorities, no missing hashes. Report counts by owner and by action.
- [x] Hash every manifest into `t1-manifest-index.json`.

**T1 result: `pass`**. Evidence `T1-manifests/20260927T102631Z` (`SHA256SUMS` `acb96d21…`). Counts:

- paths: 175, of which 169 are guard-product/extract and 6 are ifx-consumer/move-after-gate (the fixed six; 0 additional IFX-only paths);
- plan files: 292 (147 IDs), of which 77 are historical-copy/copy-exact (37 history IDs + 2 migration) and 215 are ifx-consumer/retain;
- releases: 6, all immutable, all ancestors of the source;
- coupling entries: 267 across 9 categories;
- 0 unknown or duplicate dispositions, 0 missing hashes.

Review notes: `t1-review.json`.

### T2 — History export in a disposable clone

Evidence: `T2-history-export/<run-id>`.

- [x] Create `$migrationRoot` under `%TEMP%` as `v4-todo-008-<guid>`, then run
      `git -c core.longpaths=true clone --no-hardlinks D:/IFX-Root/IFX <root>/ifx-export` (O6). Because of O8, the
      disposable root is the short directory `D:\v4t\t2-…`, outside both repositories, instead of `%TEMP%`.
- [x] In the clone: `checkout --detach 80f7b6b65fb06897444a6a36c604c42c93c834e4` (A2); the worktree is
      clean (`status --porcelain=v2 --untracked-files=all` is empty).
- [x] Remove the `origin` remote from the export clone, or record that it only points at the local
      path. Confirm no credentials appear in the clone config.
- [x] From Git Bash, with the converted path quoted:
      `git subtree split --prefix=docs/guards/v4 --branch export/v4-standalone 80f7b6b65fb06897444a6a36c604c42c93c834e4`
      (no `--rejoin`).
- [x] Record the export tip. Convert `.git/subtree-cache/*` into sorted JSON
      `commit-map.json` (original → extracted) and record its SHA-256. Explain any difference between
      the mapped commit count and 48.
- [x] Tree equivalence: `export-tip^{tree}` equals `418a1933…`, and the path/blob inventory equals the
      T1 source inventory (174 files, no path outside the subtree).
- [x] Check that the root commit of the export history maps to `20c93d52…`.
- [x] Scan the full export history for secrets (O3 tool or the recorded fallback) and for IFX
      application/V3/V3_ifx content.
- [x] Run `git fsck --full --strict` in the source clone and in the export.
- [x] Copy the records to the evidence root and verify their hashes. Keep the clone until T3 has
      fetched from it. (Clone kept at `D:\v4t\t2-3dc631` for T3.)
- [x] Stop if the mapping is not deterministic and auditable. Never fall back to a squashed copy.

**T2 result: `pass`**. Evidence `T2-history-export/20260927T102819Z` (`SHA256SUMS` `ad7ab74a…`). Results:

- export tip `4609edaeef0cf357fb1a59cb2413850e1367056b`, with tree `af913836…` equal to the source V4 tree;
- 50 exported commits, one for each of the 50 source commits touching the prefix;
- 258 commit mappings, plus git-subtree's `latest_old` marker and 842 `notree` commits;
- export root `d10ce30f` maps to `20c93d52`;
- 175 history paths, none outside the subtree;
- gitleaks: 0 findings in the history and 0 in the tip tree;
- fsck passed; 0 remotes; 0 credential entries.

### T3 — Guard lineage merge

Evidence: `T3-merge/<run-id>`.

- [x] Re-confirm P-1/P-2/P-4 and the Guard §4 status.
- [x] `git switch -c codex/v4-todo-008-standalone e75d0386492632e4df87230f3b64252086d1bc58`
- [x] `git remote add v4-export <export clone path>`; fetch `export/v4-standalone`; verify the
      fetched tip equals the T2 export tip; `git remote remove v4-export`; record the path and tip.
- [x] `git merge --allow-unrelated-histories --no-ff <export tip>`. The only conflict allowed is
      `README.md` (add/add). Any other conflict aborts the merge and the tranche stops.
- [x] Resolve `README.md` to the V4 product README (the export blob). Record the original Guard
      README blob `d6e5996b…`.
- [x] Commit the merge. Verify it has two parents: `e75d0386…` and the export tip.
- [x] Commit this checklist as a separate docs-only commit (§4).
- [x] Prove: `e75d0386` is reachable; all mapped export commits are reachable; the merge tree minus
      this checklist equals the export inventory with the resolved README; `git remote -v` shows only
      `origin`; the worktree is clean; `fsck --full --strict` passes; the secret scan passes.
- [x] Copy the evidence. Then remove the disposable clone after validating its path. No push.

**T3 result: `pass`**. Evidence `T3-merge/<run>` (see the progress log). Results:

- merge `ec9f5eade8596c99081ed2ca1663252b13bc6e49` has parents `e75d0386` and `4609edae`;
- its tree `af913836…` equals the export tree;
- the only conflict was README (add/add), resolved to the V4 product README;
- the checklist was committed as `031c6519`;
- 50/50 exported commits and the initial commit are reachable;
- the only remote is `origin`, and `main` is unchanged;
- fsck passed; gitleaks found 0 in 51 commits;
- no IFX, V3 or workflow paths;
- disposable clones removed after their evidence was copied;
- nothing pushed.

### T4 — Standalone normalization

Evidence: `T4-normalize/<run-id>`. One or more commits, separate from the merge.

- [x] Delete the six fixed IFX-only paths and any other T1-confirmed IFX-only path from the active tree.
- [x] Add `docs/migration/v4-todo-008/`: provenance index (former paths, source blobs, IFX successor
      paths), path disposition, commit map, migration receipt.
- [x] Move product plans 00–05 and TODO into `docs/plans/product/` with `git mv`. Replace their live
      IFX operational status with adoption-history cross-links. Add the product/adoption TODO
      cross-link.
- [x] Import the reviewed generic historical formal Plan pairs into `docs/plans/history/` byte-exact,
      with an index stating that they are historical and contain IFX-relative paths.
- [x] Copy the master Plan, `.plan.json` and handoff (the §1 blobs) into `docs/plans/migration/`
      byte-exact.
- [x] Fix every T1 coupling entry through explicit-root or standalone-root logic. No symlinks and no
      duplicate trees.
- [x] Test/evidence defaults move from `artifacts/guards/v4` to a standalone ignored work root, with a
      matching `.gitignore`.
- [x] Generic CI allowed-path and Plan-discovery rules use standalone paths.
- [x] Consumer download logic names `von12549/Guard` explicitly and never uses `${{ github.repository }}`.
- [x] Update documentation links, version statements and build instructions.
- [x] The public CLI, schemas, package layout and four-root runtime contract are unchanged. The commit
      message and receipt list the intentional public-contract differences (normally none).
- [x] Clean worktree and `fsck --full --strict`.

**T4 result: `pass`**. There are five normalization commits after the T3 checkpoint `c6ec84d`:

| Commit | Scope |
| --- | --- |
| `a4f9b1e` (T4a) | Deletes the 6 IFX-only paths. Moves 9 product plans to `docs/plans/product/` with `git mv`. Adds 74 byte-exact historical Plan files (37 IDs) and the 3 A2-amended migration documents; all 77 blobs equal their IFX source blobs. Adds the `docs/migration/v4-todo-008/` provenance records. |
| `4d61dac` (T4b) | PackageRoot is the repository root. Adds the external work root `<TEMP>/v4-guards-work/<sha256(PackageRoot)[:12]>`. Package authority excludes `docs/plans/**` and `docs/migration/**` (O10). The CI contract, trusted-base Plan discovery (`docs/plans/*.plan.json`) and inactive specimen use standalone paths. IFX-only assertions become opt-in consumer/reference roots (O12). Adds `.gitattributes` (`* text eol=lf`) and `.gitignore`. V1 recovery commands use standalone paths. |
| `2bf2fd8` (T4c) | README and product plans: live IFX/P10 status is replaced by IFX-owned pointers. V4-TODO-001..004 move to IFX with their identifiers reserved. |
| `f2e5cf3` (T4d) | The external test work root becomes a Git repository with one synthetic commit, which restores the IFX-era implicit Git context for fixture Targets. P3A binds the expected Target commit to the work root HEAD. Found by the first T5 Windows-full attempt. |

Declared intentional differences from the published 1.1.4 package authority (7 files): `README.md`,
`core/runtime/Test-V4Package.ps1`, `core/certification/Invoke-V4PlatformCertification.ps1`,
`core/certification/Invoke-V4V1Certification.ps1`, `integrations/github/Invoke-V4TrustedBase.ps1`,
`integrations/github/ci-contract.json` and `integrations/github/proposed-v4-guards.yml`. There are 0
public-contract differences: CLI, query and schema contracts, modules, profiles and `plugin.json` are
byte-identical. The schema `$id` values stay `https://ifx.local/v4/...` (O11). `targetBranch` and
`excludedSuites` stay as schema constants; the Guard branch model is deferred to the T6 workflow Plan.

### T5 — Standalone local validation

Evidence: `T5-validation/<run-id>`. Discover the exact commands from the migrated source first.

| Gate | Required | Result |
| --- | --- | --- |
| PowerShell parser / JSON schemas / YAML / generated docs | clean | clean: 54 PS and 123 JSON files; YAML identical to the IFX specimen after the declared substitutions; generated docs checked by P7 |
| Host build and test | pass | pass (Release, warnings as errors) |
| Web Companion build and test | pass | pass (P9 suites) |
| P0–P9 generic suites | pass | 34/34 (P0–P10) |
| Package integrity | pass | pass, `packageHash 491e7eb4…` |
| Trusted-base positive case | pass | pass (P6) |
| Candidate self-judgment negative controls | rejected | rejected: tamper, under-declaration, test weakening, provenance (P6) |
| Plan validate / compose / Plan Center at new paths | pass | pass: P5, `plan validate` on migration/history, Plan Center 37+1 |
| Distribution build A/B from clean worktrees | reproducible | same Host input produces a byte-identical archive `05e44168…`; independent Host builds differ only by build location (O14) |
| Fresh external install / receipt / launch / verified uninstall | pass | pass |
| Supply-chain, lifecycle, compatibility baseline | pass | pass (P7/P8) |
| Windows-full at the exact Guard commit | pass | **pass**: 34/34 at `f2e5cf3`, Windows 10.0.26200 |
| External synthetic target, no shared parent between PackageRoot and TargetRoot | pass | pass: 4 Stages; workspace evidence commit = Target HEAD |
| Secret and IFX/V3-content scan | zero | zero: gitleaks tree/56 commits; no IFX, V3 or workflow paths |
| Old (`80f7b6b6`, A2) and published 1.1.4 vs new structured diff: CLI, schemas, contracts, normalized manifests, fixture verdicts | no undeclared difference | 0 undeclared, 7 declared, public surface unchanged; Host/Companion binaries byte-identical after build-location normalization |
| Linux-complete at the same commit/package | pass (T6 CI) | **pending T6 CI**; a supporting local run passed 33/33 in the pinned image with `--network none`, same commit and package |
| Post-run clean status and `fsck --full --strict` | clean / pass | clean / pass |

- [x] Local outcome recorded as `local-windows-accepted-linux-pending` (or `stopped`). This is not
      overall T5 `pass`. Stop before any remote action.

**T5 result: `local-windows-accepted-linux-pending`** at Guard `f2e5cf32397b392a212ffb4a4c87c9f1eb5e3e32`,
package `491e7eb4bd3fbdaec5619601c334414f2820998aedaec529c21be004a027d3ee`. The first Windows-full attempt,
at `2bf2fd85`, failed in P3B and was fixed by T4d. Evidence: `T5-validation/20260927T104523Z` (`t5-decision.json`).
Later commits touch only `docs/plans/**` and `docs/migration/**`, which are not package authority, so the
certified package identity is unchanged at the branch tip.

### T6 — Remote Guard review and release (each item separately authorized)

- [x] A-PUSH: push only `codex/v4-todo-008-standalone`, never `main` (`79596c37`).
- [x] A-PR: open the PR with the migration receipt and the validation matrix.
- [x] A-CI: minimal trusted-base workflow through its own reviewed Plan. The candidate never judges itself.
- [x] Linux-complete and Windows-full against one exact commit/package identity. T5 becomes `pass`
      only then; record both decision hashes.
- [x] A-MERGE: merge after the required review and controls (seed PR #1 → `65cf6cde`, operator acceptance under A3).
- [x] A-RELEASE: next unused semantic version (after 1.1.4) through a separate publication Plan, with
      a provenance note pointing to the immutable IFX releases. Never recreate the `v4-guards-v1.*` tags.
- [x] Verify the release asset bytes and the install receipt from a clean consumer environment.

**T6 status**: T6.1–T6.5 done. Seed `65cf6cde` (A3) and the certification workflow `73a0653` are on
`main`. The trusted-base workflow is active since `b022f9e8` (activation phase 1; the ruleset follows
V4-TODO-011). T6.7 release is pending a separate publication Plan.

### T7 — IFX consumer rebinding (A-IFX-REBIND)

- [ ] Create an IFX successor Plan and migration receipt with the Guard repository, commit, tag,
      archive hash, distribution manifest and decisions.
- [ ] `git mv` the IFX-owned plans 06–09 and the two integration files to `docs/guards/v4-adoption/`.
- [ ] Make the inactive IFX workflow specimen fetch explicitly from `von12549/Guard`.
- [ ] Add a P10.3 successor design/rehearsal. Do not edit the accepted P10.1–P10.3 decisions.
- [ ] Run IFX composition, Windows-full, parity/compatibility and rollback rehearsal against the new release.
- [ ] V3 required contexts and V3 source stay unchanged.

### T8 — IFX cleanup (A-IFX-DELETE)

- [ ] Remove only paths classified `obsolete-after-gate`.
- [ ] Verify there is no live reference to `docs/guards/v4` outside historical records and evidence.
- [ ] Verify V3 and IFX application build/tests are unchanged, IFX consumes the exact Guard release
      from a clean environment, and the P10.3 successor rollback still works.
- [ ] Commit a cleanup receipt with retained/deleted inventories and the rollback commit.

## 9. Stop conditions (quick reference)

Stop on any of the following: identity drift from §3; an unaccounted dirty worktree; a OneDrive
conflict, a placeholder, an unexpected reparse point, or a lock/index anomaly; an incomplete path or
commit map; any second merge conflict; imported IFX application, V3, secret or ignored-evidence
content; undeclared public-contract drift; candidate self-judgment; a missing exact-commit
Windows-full or Linux-complete result before publication; reuse or rewrite of a release tag; IFX
cleanup before release and consumer revalidation; a remote write without its §6 authorization; or any
activation/retirement proposal. If the Guard `.git` state becomes ambiguous, recover from a clean
clone. Never repair it in place.

## 10. Open items

| ID | Item | Status |
| --- | --- | --- |
| O1 | Make `640c5756` publicly reachable on IFX `origin`. | Closed: pushed `6b80fc04..286e453d` |
| O2 | Record A1 in the IFX master Plan/`.plan.json`. | Closed: `286e453d`. V4 native `plan validate` (installed 1.1.4) passed |
| O3 | Secret scanner. | Closed: gitleaks 8.30.1 official release at `D:\IFX-Root\tools\gitleaks\8.30.1\gitleaks.exe` (zip SHA-256 `d29144de…` matches both the release checksums file and the API digest; exe SHA-256 `17157e2e…`) |
| O4 | P-3 and P-4 attestations. | Closed |
| O5 | **Closed 2026-09-28**: IFX `codex/v4-development-base` `42b666ac` (merges of `1b768c96` and `946b9d3a`) registers the record, and V3_ifx `Validate` passes with 0 manifest problems. V4 tree `af913836` is unchanged. Original finding: pre-existing IFX V3_ifx `Validate` failure: `docs/guards/V3_ifx/shared/decisions/history/20260924-v4-ifx-c2d-g03-current-documentation.json` is not registered in `shared/policy-config.json`. The failure reproduces identically on unmodified `640c5756`, so A1 did not cause it. This is outside V4-TODO-008 scope, because V3 stays unchanged. | Reported to the operator; not fixed here |
| O6 | Disposable IFX clones fail checkout with "Filename too long" unless `core.longpaths=true` is set at command scope (`git -c core.longpaths=true clone …`). T2 uses that form. | Mitigation adopted |
| O7 | Published 1.1.4 (`2185477b`) was not in the development lineage (see A2). | Closed by A2 (`80f7b6b6`); all six release tags are now ancestors of the export source |
| O15 | V3 IFX Guardrails CI is structurally red for PRs targeting IFX `codex/v4-development-base`. The trusted-base run failed on the O5 defect itself, and the candidate Architecture suite's `Test-CutoverPreservation` (docs/guards top level = plans, V3, V3_ifx) fails while the V4 incubation directories exist. Operator decision 2026-09-28: commits on that branch go directly, after local verification, not via PR. The 03-genesis plan's intended V3 workflow exclusion for that branch was never implemented. | Recorded (policy) |
| O17 | Improvement point from PR #5: "Approved test hash drift: tests/p7/Test-V4Distribution.ps1". The check is correct and must stay. The base runner validates candidate approved tests against the **base** CI contract, which is the protection against candidate test weakening. Two gaps made a routine release fail it. (a) There is no authorization channel for legitimate changes to approved tests, the CI contract or the runner. (b) P7/P8/P10 hard-code the product version, so every version bump edits protected tests. Resolution: V4-TODO-014 adds single-use base-held authorization records bound to exact candidate hashes (analogous to V3 P11), and version assertions read `plugin.json`. It must precede V4-TODO-011 phase 2, because a ruleset requiring `v4-required` would otherwise block every trust change. Until then O16 applies. | **Closed 2026-09-28** by V4-TODO-014 (bootstrap PR #7; live acceptance PRs #8–#10) |
| O16 | Operator-acceptance rule for approved-test, CI-contract and runner changes while V4-TODO-014 is open. Accept only when: the drift is exactly the declared test paths and every other contract field is unchanged; `v4-contract` passes; exact-head dispatch certification passes Linux-complete and Windows-full with one `packageHash`; and the operator confirms on the PR. Applied to PR #5 (1.1.5 R1), PR #7 (V4-TODO-014 bootstrap) and PR #12 (runner `PATHEXT` fix, under the Plan §9 broken-mechanism clause, because the unfixed base runner judged it). | **Retired 2026-09-28**: V4-TODO-014 is complete. Protected changes now use authorization records; any further operator override needs a new, explicitly recorded decision |
| O18 | The first PR-path Windows smoke (PR #10, run 36344152342) exposed a pre-existing runner defect. `Invoke-V4TrustedBase` `Invoke-Isolated` restored an environment allowlist without `PATHEXT`, so Windows children could not resolve `git` (P1 failed). Certification was unaffected because `Invoke-V4PlatformCertification` includes `PATHEXT`. Earlier Guard PRs had never run `v4-windows`. | **Closed 2026-09-28**: fixed by PRs #11/#12 (authorization, then trust change, accepted under O16 once). P6 probe regression control added by PRs #13/#14 |
| O14 | Pre-existing (1.1.x) build-location dependence: an independent Host build embeds its PDB path, and the Companion's `staticwebassets.runtime.json` embeds the absolute source `wwwroot` path. Archives are byte-identical for the same Host/Companion input, which is the established 1.1.x release contract. Independent builds therefore differ in 3 archive entries. A later product Plan may add PathMap/deterministic source paths. This migration does not change it. | Recorded |
| O13 | The IFX commits `17a1d56c`, `80f7b6b6` and `af2bd603` were local only; the extracted Guard history maps to `80f7b6b6`. | Closed 2026-09-28: fast-forward push `286e453d..af2bd603` to `origin/codex/v4-development-base`. All three commits are publicly reachable |
| O8 | Latent V4 defect, present in released 1.1.4 and unchanged by the migration: `Invoke-V4TrustedBase` Linux mode clones the target with `core.longpaths=true`, but its post-test `git status` on the target does not. On a deep IFX path below a longer root, the status check reports a false `M` ("Filename too long") and certification fails. Mitigation: run certification from a short root. A product fix is out of V4-TODO-008 scope (no behavior change) and belongs to a later Guard product Plan. | Recorded; mitigated |
| O9 | The imported 1.1.4 release Plan pair is V3-format (`areaIds`). V4 native `plan validate` rejects it as "unknown property: areaIds". This is its published form, byte-identical from the release branch, so it is treated as a V3-historical Plan. | Recorded |
| O10 | T4 design constraint: `Test-V4Package.ps1` treats every file under `docs/` as package authority, and `New-V4Distribution.ps1` ships every authority file. Under the planned layout, `docs/plans/**` and `docs/migration/**` would therefore enter the package hash and the release archive. T4 must exclude these repository-governance subtrees from package authority. The exclusion is backward-compatible because neither subtree exists in any IFX-layout package, and it must be declared. | For T4 |
| O11 | T4 design constraint: the public schema `$id` namespace `https://ifx.local/v4/...` (44 occurrences) stays unchanged, so schemas remain stable. This is declared naming debt for a later Plan. | For T4 |
| O12 | T4 design constraint: IFX-coupled test assertions. `Test-V4GenesisProposal`/`Test-V4WorkflowContract` hash-check the IFX `.github/workflows/v3-ifx-guardrails.yml`. `Test-V4ArchitectureAuthority` hashes the frozen V3_ifx LayerGuard source files at the repository root. `Test-V4TrustedBase` reads IFX formal Plan paths. In Guard, these checks must move behind an explicit consumer/reference root, or be restated for the standalone layout, with each change declared. | For T4 |

## 10a. Remaining work (in order)

| # | Item | Depends on | Authorization |
| --- | --- | --- | --- |
| 1 | ~~V4-TODO-014 Plan: trusted-base authorization for approved-test and runner changes; version assertions read `plugin.json` (O17)~~ **Done 2026-09-28** (PRs #7–#12, #13, #14) | none | Done |
| 2 | V4-TODO-011 phase 2: ruleset on `main` requiring `v4-required`, strict up-to-date checking and review of `.github/**`, `docs/plans/authorizations/**` and other authority changes (reaches `G2_V4_AUTONOMOUS`) | #1 (done) plus repeated workflow success | Separate remote authorization |
| 3 | T7: IFX consumer rebinding to V4 Guards 1.1.5, with the handoff decision, P10.3 successor, composition/parity/rollback rehearsal and `docs/guards/v4-adoption` moves. It sets `standaloneSourceAccepted` and `ifxConsumerRebound` | Release 1.1.5 (done) | A-IFX-REBIND |
| 4 | T8: protected IFX cleanup of the duplicated `docs/guards/v4` product source (`ifxCoreSourceRemoved`) | #3 | A-IFX-DELETE |
| 5 | Product follow-ups: O8 (runner post-test `git status` without long paths) and O14 (build-location-dependent Host/Companion builds) | none | Separate product Plans |

## 11. Tranche report template

```text
Tranche / status:         Tn / pass | stopped | blocked
Source / destination:     IFX 640c5756… / Guard <commit>
Commits created / pushed: <list> / none
Evidence:                 D:\IFX-Root\v4-todo-008-evidence\Tn-…\<run-id> (+ SHA-256 index)
Validation:               <matrix rows>
Provenance counts:        paths by owner/action; commits mapped
Remote/protected changes: none | <authorized item>
Blockers / next auth:     <…>
standaloneSourceAccepted=false  standaloneReleasePublished=false  ifxConsumerRebound=false
ifxCoreSourceRemoved=false      v4Activated=false                 p10GatePassed=false
v3Retired=false
```

## 12. Progress log

| Date (UTC+local) | Tranche | Event | Evidence |
| --- | --- | --- | --- |
| 2026-09-27 | pre-T0 | Plans read. Read-only identity check. A1 rebinding decided. P-1/P-2 attested. Checklist created (untracked). | — |
| 2026-09-28 | T6 | T6.1 push `79596c37`; T6.2 PR #1; T6.3 dispatch-only certification workflow on `main` `73a0653`; T6.4 run 36326273549 passed Linux 33/33 and Windows 34/34 (package `491e7eb4`), so T5 overall is pass; T6.5 seed merged as `65cf6cde` (A3). | `T6-remote/<run>` |
| 2026-09-28 | V4-TODO-014 | B1: PR #7 accepted under O16 and merged as `0b29783`. Exact-head certification run 36342238399 passed Linux 33/33 and Windows 34/34 (package `79d12a1b`); the local Windows-full sweep passed 34/34. B2: live negative PR #8 was rejected ("Approved test hash drift without trust-change authorization") and closed; authorization PR #9 merged; trust-change PR #10 was first blocked by the `PATHEXT` defect (O18). Fix: authorization PR #11, then trust change PR #12, accepted under O16 (Plan §9) on certification run 36358564876 (package `19c9c7f0`). PR #10 then re-ran green, including Windows smoke (run 36359282105), and merged. P6 probe: PRs #13/#14 (run 36360790400). | `TODO-014/<run>` |
| 2026-09-28 | T6.7 | R1 PR #5 accepted under O16 and merged as `a02ee3c6`. R2 run 36331614650: Linux 33/33, Windows 34/34, package `e8cd3269`. R3: A/B archive `74c371eb` byte-identical; V1 candidate and recovery certification pass. R4: tag `v4-guards-v1.1.5` and release published. R5: fresh download is byte-identical; install, four Stages and uninstall pass. | `T6.7-release/<run>` |
| 2026-09-28 | Activation | Step A PR #2 certified (run 36328329765, package `4c8b45c0`) and merged as `118644e3`; C: genesis record and active `v4-guards.yml` at `b022f9e8`; D: negative-control PR #3 rejected (run 36329134054); E: this records PR is the positive control. | `G2-activation/<run>` |
| 2026-09-28 | O13/O5 | O13 pushed `286e453d..af2bd603`. O5: PR #108 closed (structural V3 CI red, O15); the operator merged `707b3019` and `42b666ac` directly and pushed; Validate passes. | `O13-O5-remote/20260927T140256Z` |
| 2026-09-27 | T5 | Windows-full 34/34 and local Linux-complete 33/33 at `f2e5cf3`; structured and binary equivalence, A/B, external Target, scans and fsck pass. Status: local-windows-accepted-linux-pending. Stopped before T6. | `T5-validation/20260927T104523Z` |
| 2026-09-27 | T4 | Normalization commits `a4f9b1e`, `4d61dac`, `2bf2fd8` and `f2e5cf3`. Declared differences only; public contracts unchanged. T4 pass. | `T4-normalize/<run>` |
| 2026-09-27 | T3 | `codex/v4-todo-008-standalone` created from `e75d0386`. Unrelated-history merge `ec9f5ead`; checklist commit `031c6519`. OneDrive pause obligation (P-4) satisfied. T3 pass. | `T3-merge/20260927T103329Z` |
| 2026-09-27 | T2 | Subtree split at `80f7b6b6` in `D:\v4t\t2-3dc631`; export tip `4609edae`; all checks pass. T2 pass. | `T2-history-export/20260927T102819Z` |
| 2026-09-27 | T1/A2 | 1.1.4 lineage gap found. The operator chose A2. The reconciliation Plan `17a1d56c` and merge `80f7b6b6` (tree equals the certified trial; Windows-full 34/34) were committed, then the A2 amendment `af2bd603`. T1 manifests generated. T1 pass. | `T1-A2-reconciliation/20260927T101043Z`, `T1-manifests/20260927T102631Z` |
| 2026-09-27 | T0 | A-LOCAL, A-IFX-AMEND, A-TOOL and O1 push authorized; P-3/P-4 attested. Identities verified; hydration scan pass; Git clients closed; gitleaks installed; IFX A1 commit `286e453d` pushed (fast-forward). T0 pass. | `T0-identity/20260927T090305Z` |
