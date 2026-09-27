# V4-TODO-008 standalone repository extraction program

Status: `IN PROGRESS — AMENDMENTS A1 AND A2 APPLIED; T0–T5 LOCAL EXECUTION AUTHORIZED; REMOTE GUARD, RELEASE AND IFX PROTECTED TRANCHES NOT AUTHORIZED`

Executor requested by the user: **Claude Code**.

Formal Plan ID: `20260927-v4-todo-008-standalone-repository-extraction`.

Claude Code handoff: `docs/guards/plans/20260927-v4-todo-008-claude-code-handoff.md`.

## 1. Decision

Extract the V4 Guards product from the IFX incubation repository into the existing standalone
repository `https://github.com/von12549/Guard` before V4 becomes an IFX required check and before
V3/V3_ifx retirement. The extraction must preserve auditable provenance, keep all existing releases
immutable, validate the standalone product from its new source authority, rebind IFX as a consumer,
and only then remove duplicated V4 product source from IFX.

This is the implementation program for V4-AD-019 and V4-TODO-008. It does not activate V4 in IFX,
change an IFX ruleset, pass P10.GATE, retire V3/V3_ifx, or authorize a GitHub write.

## 2. Fixed feasibility snapshot

The following snapshot was captured read-only on 2026-09-27 before this Plan was completed.

### Source repository

| Property | Bound value |
| --- | --- |
| Path | `D:\IFX-Root\IFX` |
| Repository | `von12549/IFX` |
| Development branch | `codex/v4-development-base` |
| Source commit | `ba0816321bcb04dba93136beea80f41f237517de` |
| V4 source path | `docs/guards/v4` |
| V4 source tree object | `e3c359491709ee49b73979276a0143ed52221999` |
| Tracked V4 files | 174 |
| Commits touching the V4 subtree | 47 |
| First V4 commit | `20c93d521728746e1c227654b32219d94fcdf6bb` |
| P10.3 decision SHA-256 | `529e19b567c05619ec054117e2514c579a908a4e614355411fc28b6d52964964` |

The source worktree was clean when inspected. Existing V4 Guards 1.1.0–1.1.4 releases and their IFX
repository URLs remain immutable historical authorities. They are not re-tagged or silently moved.

### Amendment A1 — export source rebinding (2026-09-27)

The table above is the original feasibility snapshot and remains unedited. After that snapshot, commit
`6b80fc04` changed three files inside the V4 subtree (`plans/00-architecture-decision-set.md`,
`plans/README.md`, `plans/TODO.md`) to accept V4-AD-019 and start V4-TODO-008. An export from
`ba081632` would omit that decision from the extracted Guard history. In the pre-T0 review, the
operator therefore rebound the export source to the development tip that contains it:

| Property | Original bound value | A1 bound value |
| --- | --- | --- |
| Source commit | `ba0816321bcb04dba93136beea80f41f237517de` | `640c57566688ca1aee683923d53ad6e57fd5f16c` |
| V4 source tree object | `e3c359491709ee49b73979276a0143ed52221999` | `418a1933e985aa17c59307c0a25434e19de4aeba` |
| Tracked V4 files | 174 | 174 |
| Commits touching the V4 subtree | 47 | 48 |
| First V4 commit | `20c93d521728746e1c227654b32219d94fcdf6bb` | unchanged |

From A1 onward, every export, tree-equivalence and old-versus-new comparison identity in this Plan and
in the Claude Code handoff uses the A1 values. `ba081632` remains the historical P10.3 acceptance
checkpoint. This amendment commit changes only `docs/guards/plans`, so the bound export tree
`418a1933…` is unaffected by it. The operator also authorized, on the same date:

- T0–T5 local execution by Claude Code;
- this local IFX amendment commit; and
- pushing `codex/v4-development-base` to `origin`, so the bound source commit is publicly reachable
  provenance (a fast-forward only; no other IFX remote write).

Remote Guard writes (T6), standalone release publication, IFX consumer rebinding (T7) and protected IFX
cleanup (T8) still require separate authorization. The working execution record is the Guard checklist
`docs/plans/migration/20260927-v4-todo-008-execution-checklist.md`, and durable evidence lives below
`D:\IFX-Root\v4-todo-008-evidence`.

### Amendment A2 — reconcile the 1.1.4 release lineage (2026-09-27)

T1 found that the published `v4-guards-v1.1.4` commit `2185477ba89d7a3cef95c99bfe737bf98a70f39d` is not
an ancestor of the A1 source. Release branch `codex/v4-guards-1.1.4-release` (tip
`3641d81eecea59b00234e804a1c19ccf7ec04982`) had never been merged back. The operator chose to
reconcile in IFX before export, under
`20260927-v4-guards-1-1-4-release-reconciliation` (Plan commit `17a1d56c2e244717f64576059b711e2e5f79480a`).
The merge resolves every conflicting V4 product file to the published 1.1.4 content. Its V4 tree
equals the release tree except for development-only V4 plans and the two IFX cutover files.

| Property | A1 bound value (superseded) | A2 bound value |
| --- | --- | --- |
| Source commit | `640c57566688ca1aee683923d53ad6e57fd5f16c` | `80f7b6b65fb06897444a6a36c604c42c93c834e4` |
| V4 source tree object | `418a1933e985aa17c59307c0a25434e19de4aeba` | `af913836d83c071b9c0a769c6c84da4fb727b971` |
| Tracked V4 files | 174 | 175 (`+docs/1.1.4-release-notes.md`) |
| Commits touching the V4 subtree | 48 | 50 (`+2185477b`, `+80f7b6b6` merge) |
| First V4 commit | `20c93d521728746e1c227654b32219d94fcdf6bb` | unchanged |

From A2 onward, every export, tree-equivalence and old-versus-new comparison identity uses the A2
values. T5 additionally compares the Guard package against the published 1.1.4 release source
`2185477b`. Before the merge commit was created, Windows-full certification passed on a tree-identical
trial merge (tree `97abd4b6405612e5d3bd03f760bda29a6a846f70`), and the live merge reproduces that tree.
Pushing the merge requires separate authorization.

### Destination repository

| Property | Bound value |
| --- | --- |
| Path | `C:\Users\von12\OneDrive\Desktop\Guard` |
| Repository | `von12549/Guard` |
| Visibility | public |
| Default branch | `main` |
| Initial and current commit | `e75d038` (`Initial commit`) |
| Tracking | local `main` equals `origin/main` |
| Tracked content | `README.md` containing `# Guard` |
| Plan directory | `docs/plans` exists and is empty |
| Rulesets | none |
| Workflow directory | absent |
| Integrity | `git fsck --full --strict` passed |
| Worktree | clean |

The directory is an ordinary directory, not a reparse point or symlink. The feasibility audit needed
a command-scoped `safe.directory` override because Codex ran under a sandbox account. Claude Code is
expected to run as the interactive owner and must first try ordinary Git access. Use the exact
command-scoped override only if Git actually reports dubious ownership; never add a broad global
safe-directory wildcard.

The repository is inside OneDrive. It is feasible, but bulk history import must run with the tree
fully hydrated, OneDrive synchronization manually paused by the operator, and all other Git clients
closed. Claude Code may inspect and record attributes/process state but must not kill, pause or
reconfigure OneDrive itself. T0 requires an explicit operator attestation that sync is paused and all
Guard files are locally available, plus an automated scan showing no offline/recall placeholder
attributes. Run `git fsck --full --strict` after each history-changing checkpoint. Any missing
attestation, partial hydration, sync conflict, duplicate file, lock-file resurrection or index drift
is a stop condition; recover from a clean clone instead of repairing ambiguous `.git` bytes in place.

### Persistent evidence root

All durable T0–T8 evidence is written under the fixed external root
`D:\IFX-Root\v4-todo-008-evidence`. Each tranche uses a new child such as
`T0-identity/<run-id>` or `T2-history-export/<run-id>`. `%TEMP%` is permitted only for disposable
clones and scratch output; before removing a disposable directory, copy the final command records,
inventories, commit maps, hashes and summaries into the fixed evidence root and verify their hashes.
The evidence root is never a Git remote, PackageRoot or TargetRoot and is not deleted by the program.

### Tooling feasibility

- Git contains the `git-subtree` helper, but it must run in a writable disposable clone. The current
  sandbox correctly refused its attempt to write `.git/subtree-cache` in the source checkout.
- `git filter-repo` is not installed and is not a dependency of this Plan.
- Use `git subtree split` from Git Bash in a disposable clone to retain the history of the
  `docs/guards/v4` subtree. Preserve the subtree cache mapping as evidence before deleting the clone.
- The destination's existing initial commit means the extracted lineage must be merged with
  `--allow-unrelated-histories`; never reset or force-update `main` to the extracted branch.

Feasibility verdict: **PASS WITH CONTROLLED MIGRATION**.

## 3. Authority and non-scope

This master Plan authorizes project definition only. A later explicit instruction to Claude Code is
required before implementation. Even after local implementation begins, these boundaries remain
separate:

1. local history extraction and source refactoring;
2. remote branch push and pull request creation in `von12549/Guard`;
3. merge/default-branch/ruleset changes in `von12549/Guard`;
4. standalone release publication;
5. IFX consumer rebinding and protected source cleanup;
6. IFX workflow/ruleset activation; and
7. V3/V3_ifx freeze or retirement.

Claude Code must stop for explicit authorization before items 2–5. Items 6 and 7 are not part of
V4-TODO-008 at all.

The following are forbidden in this program:

- force-pushing either repository;
- rewriting, moving, deleting or recreating an existing V4 release/tag/asset;
- treating copied files as adequate provenance without a history and byte manifest;
- deleting IFX V4 source before the standalone authority is accepted and independently consumable;
- moving IFX-specific Profile, policy, P10 evidence or adoption authority into the generic V4 product;
- activating a workflow, required context, ruleset or protected setting;
- claiming that the prior 1.1.4 P10 evidence certifies a new standalone-source release; or
- retiring V3/V3_ifx.

## 4. Repository ownership split

The extraction is not a blind move of every path containing `v4`. Build an explicit
`migration-manifest.json` before changing either repository. Every source path receives one of
`guard-product`, `ifx-consumer`, `historical-copy`, `evidence-retained-in-ifx`, or `obsolete-after-gate`.

### Standalone Guard product owns

- V4 Host source, contracts and schemas;
- generic built-in Profiles and modules;
- package, distribution, install/uninstall and composition implementation;
- generic Git/GitHub integrations and trusted-base runner;
- Web Companion source and generic contracts;
- product regression, certification, lifecycle, supply-chain and compatibility tests;
- product documentation and release notes;
- generic V4 architecture decisions, provenance record and product roadmap;
- V4 product TODOs unrelated to one consumer; and
- historical generic P0–P9 and generic release Plan pairs as read-only provenance records.

### IFX remains owner of

- `ifx_profile`, IFX modules, production human review and Bundle publication authority;
- P10.0–P10.3 decisions and all IFX certification/parity evidence;
- IFX target fixtures and target-commit bindings;
- the IFX-specific workflow specimen and cutover proposal;
- coexistence, required-context, rollback and V3/V3_ifx retirement plans;
- all V4 formal Plans whose purpose or ID is IFX/P10-specific; and
- the final IFX consumer pin to a Guard repository release and commit.

### Required split of the current mixed planning tree

The current `docs/guards/v4/plans` tree mixes product and IFX adoption concerns. Split it explicitly:

- move product-maintained plans `00`–`05`, product decisions and product TODO content into
  `Guard/docs/plans/product/`;
- retain IFX adoption plans `06`–`09` in IFX under
  `docs/guards/v4-adoption/plans/`;
- split mixed P10 summaries out of product roadmaps without erasing their historical record;
- place generic historical formal Plan pairs under `Guard/docs/plans/history/` with an index that says
  they are historical and still contain original IFX-relative paths;
- keep IFX/P10 formal Plan pairs in `IFX/docs/guards/plans/`;
- copy this master Plan and its Claude Code handoff into `Guard/docs/plans/migration/` during the
  destination branch work; and
- create an explicit product/adoption TODO cross-link in both repositories.

Filename matching may prepare a candidate classification, but final disposition must be recorded for
every Plan pair. In particular, a filename containing `v4` does not make an IFX/P10 Plan product-owned.

The history/current-tree rule is exact: `git subtree split` is allowed to preserve IFX-specific bytes
in the extracted Git **history**, because deleting them before extraction would falsify provenance.
They must not remain in the active Guard tree after T4. At minimum, T4 deletes these active Guard
paths while retaining their history and listing their original blob hashes in the migration receipt:

- `plans/06-ifx-profile-validation-program.md`;
- `plans/07-p10-0-baseline-acceptance.md`;
- `plans/08-p10-1-extension-composition-compatibility.md`;
- `plans/09-p10-3-cutover-and-rollback-proposal.md`;
- `integrations/github/ifx-cutover-proposal.json`; and
- `integrations/github/proposed-v4-ifx-guardrails.yml`.

Do not copy these bytes into Guard `docs/plans/history`; their extracted commit history is already the
historical record. Guard may keep only a non-authoritative provenance index naming their former paths,
source blobs and IFX successor locations. Mixed product plans 01/02 and README retain product content
but replace live IFX operational status with a cross-repository historical/adoption link. At T7, the
authoritative current versions are moved inside IFX with `git mv` to `docs/guards/v4-adoption`, before
the remaining product subtree is removed.

## 5. Intended standalone layout

The extracted subtree initially becomes the Guard repository root so the product source is no longer
nested beneath an IFX path. The accepted end-state layout is:

```text
Guard/
├─ .github/
│  └─ workflows/                 # added only by separately authorized remote-CI tranche
├─ core/
├─ integrations/
├─ modules/
├─ profiles/
├─ tests/
├─ docs/
│  ├─ plans/
│  │  ├─ product/
│  │  ├─ history/
│  │  └─ migration/
│  ├─ migration/
│  └─ ... product documentation
├─ README.md
└─ product/build metadata
```

Do not preserve `docs/guards/v4` merely to avoid changing tests. Source tooling must accept an explicit
repository root or derive it safely from the standalone checkout. Runtime behavior must continue to
use explicit `PackageRoot`, `TargetRoot`, `StateRoot` and `EvidenceRoot`; repository extraction must
not weaken the four-root contract.

## 6. Branch and commit topology

### Source IFX

- Bind export to exact source commit `80f7b6b65fb06897444a6a36c604c42c93c834e4` (Amendment A2;
  A1 bound `640c57566688ca1aee683923d53ad6e57fd5f16c`, originally `ba0816321bcb04dba93136beea80f41f237517de`).
- Do not export from a dirty worktree or a moving branch name.
- Do not delete or move source files during the export phase.
- Later IFX cleanup uses its own branch/commit after Guard acceptance.

### Destination Guard

- Start from exact `main` commit `e75d038`.
- Create local branch `codex/v4-todo-008-standalone`.
- Never commit directly to `main`.
- Merge the extracted history with a non-fast-forward unrelated-history merge.
- Resolve the root `README.md` add/add conflict in favor of the full V4 product README, while recording
  the original Guard README blob and initial commit in the migration receipt.
- Keep all work local until a separately authorized push/PR tranche.

### Canonical-source switch

Copying or merging files does not switch authority. The canonical V4 development source changes only
after all of the following are true:

1. Guard migration branch validation passes;
2. Guard default branch contains the reviewed migration commit;
3. Guard CI passes from a previously trusted V4 base rather than the candidate judging itself;
4. a new standalone-source release is published under a separate publication authorization;
5. its release asset, manifest and receipt are independently verified; and
6. IFX records a handoff decision binding the Guard repository, commit, release tag and asset hash.

Until then, `docs/guards/v4` in IFX remains the canonical source and must not be removed.

## 7. Execution tranches

Each tranche ends with a committed checkpoint and evidence. A failure stops the program; it does not
authorize repairing a later tranche in place.

### T0 — Re-read authority and freeze identities

1. Read this master Plan and the Claude Code handoff in full.
2. Read repository-local `CLAUDE.md`/`AGENTS.md` instructions in both repositories if present.
3. Verify the source and destination identities in section 2.
4. Verify both worktrees are clean and the destination still has no ruleset/workflow.
5. Obtain and record the operator's OneDrive-paused/fully-hydrated attestation, then independently
   scan the Guard tree for offline or recall placeholders.
6. Record tool versions, filesystem attributes, OneDrive state and whether command-scoped
   `safe.directory` was actually needed.
7. Verify or create `D:\IFX-Root\v4-todo-008-evidence`, then create a new T0 run directory beneath it.

Stop on any commit, tree, remote, default-branch, dirty-worktree or ownership discrepancy. Update this
Plan through review rather than substituting a newer identity silently.

### T1 — Build disposition and provenance manifests

Produce, before extraction:

- complete source path inventory with Git blob IDs and SHA-256 values;
- core/IFX ownership disposition for all 174 tracked V4 files;
- complete classification of V4-named formal Plan pairs outside the subtree;
- old IFX release/tag/asset inventory for 1.1.0–1.1.4;
- active source-path coupling inventory (`docs/guards/v4`, `docs/guards/plans`,
  `artifacts/guards/v4`, `${{ github.repository }}`, IFX release URLs and fixed parent traversal);
- proposed destination path for every moved/copied item; and
- exclusions for P10 evidence, target fixtures and generated/ignored artifacts.

The T1 manifest must apply the exact history/current-tree disposition above: the six listed IFX paths
are `ifx-consumer`, are retained in extracted history, are deleted from the active Guard tree in T4,
and obtain current authoritative successors in IFX only at T7. It must discover and apply the same
rule to any additional IFX-only file; discovery does not weaken the six-path minimum.

The manifest must prove one and only one disposition for every source path. No cleanup may begin with
an `unknown` or duplicate disposition.

### T2 — Extract V4 history in a disposable clone

1. Create a new temporary directory outside both repositories.
2. Clone IFX locally with `--no-hardlinks` so cleanup cannot damage source objects.
3. Detach at the exact source commit.
4. From Git Bash, run `git subtree split --prefix=docs/guards/v4` into a named export branch.
5. Preserve the subtree cache mapping as a machine-readable original-commit → extracted-commit map.
6. Verify the exported root tree matches the source V4 tree byte-for-byte before layout refactoring.
7. Run `git fsck --full --strict` in source clone and export repository.

The export must contain the V4 history only. It must not contain IFX application source, V3/V3_ifx,
secrets, P10 target evidence, ignored artifacts or the source repository remote credentials.

### T3 — Merge history into the Guard migration branch

1. Create `codex/v4-todo-008-standalone` from exact Guard `main`.
2. Fetch the local export branch through a temporary local remote.
3. Merge with `--allow-unrelated-histories --no-ff`.
4. Resolve only the expected root README conflict.
5. Remove the temporary remote after recording its path and fetched commit.
6. Commit the merge before product-path refactoring.
7. Run `git fsck --full --strict`, `git status`, tree inventory and secret scanning.

The merge commit must have both the Guard initial lineage and the extracted V4 lineage as parents.

### T4 — Normalize the standalone source layout

Refactor only after the history merge checkpoint:

- move maintained product plans/TODOs to `docs/plans/product`;
- import reviewed generic historical Plan pairs to `docs/plans/history` without rewriting their bytes;
- copy this Plan/handoff to `docs/plans/migration`;
- delete the six enumerated IFX-only paths, plus any additional T1-confirmed IFX-only path, from the
  active Guard tree while preserving them in extracted history and the provenance index;
- add provenance, path-disposition and commit-map records under `docs/migration/v4-todo-008`;
- replace IFX-incubation source path assumptions with standalone-root or explicit-root logic;
- change test/evidence defaults from `artifacts/guards/v4` to a standalone ignored work/evidence root;
- change generic CI allowed-path and Plan discovery rules to standalone paths;
- ensure consumer downloads can name `von12549/Guard` explicitly and do not assume
  `${{ github.repository }}` means the product release repository;
- update documentation links, version statements and build instructions; and
- keep public CLI, schemas, package layout and four-root runtime behavior stable.

Do not combine unrelated feature work, module behavior changes, runtime capability changes or IFX
policy changes with the extraction.

### T5 — Standalone local validation

At a clean exact Guard migration commit, perform at least:

1. JSON/YAML/PowerShell/C# static validation and generated-document consistency;
2. all P0–P9 generic regression suites;
3. Host and Web Companion build/test;
4. package integrity and deterministic distribution build twice from clean worktrees;
5. install, receipt verification, launch and verified uninstall in a fresh external location;
6. trusted-base positive and head-self-judgment negative controls;
7. plan validate/compose and Plan Center path tests under the new plan locations;
8. supply-chain, lifecycle and compatibility-baseline suites;
9. Windows-full platform certification;
10. an external synthetic Target run where PackageRoot and TargetRoot share no parent assumption;
11. repository secret scan and check that no IFX/V3 application source was imported; and
12. post-run clean-worktree plus `git fsck --full --strict`.

Build the old bound IFX source and new Guard source in separate clean worktrees. Compare public CLI,
schemas, module/profile contracts, normalized package manifests and behavioral fixture results. Exact
archive bytes are required only when version/source metadata is identical; otherwise every expected
difference must be enumerated and the executable/package payload must remain reproducible.

T5 has two explicit states. `local-windows-accepted-linux-pending` is a successful local checkpoint
when every local test and Windows-full passes but Linux-complete is unavailable; it is not overall T5
acceptance and cannot authorize publication or canonical-source switch. Overall T5 becomes `pass` only
after an authorized T6 Guard CI run supplies Linux-complete evidence for the same exact Guard commit
and package identity. A Linux mismatch returns T5 to stopped regardless of the Windows result.

### T6 — Remote Guard review and standalone release (separate authorization)

This tranche is not authorized by this master Plan alone.

After explicit authorization:

1. push only the migration branch, never `main`;
2. open a Guard pull request with the migration receipt and exact validation matrix;
3. configure a minimal trusted-base workflow through its own reviewed Plan;
4. complete Linux-complete and Windows-full evidence against one exact commit/package identity;
5. merge only after required review and successful controls;
6. publish the next unused semantic version from Guard through a separate publication Plan; and
7. verify release asset bytes and installation receipt from a clean consumer environment.

Do not recreate tags 1.1.0–1.1.4 in a way that suggests their original IFX release authorities moved.
The first standalone-source release gets a new version and a provenance note pointing back to the
immutable IFX releases.

### T7 — Rebind IFX to the standalone authority

Only after T6 acceptance:

- create an IFX migration receipt binding the old source commit/tree, Guard commit, standalone release
  tag, archive hash, distribution manifest and validation decisions;
- update the inactive IFX workflow specimen to fetch V4 explicitly from `von12549/Guard`;
- keep IFX Bundle/profile/review inputs in the IFX trust domain;
- move IFX-specific P10 plans/proposal/specimen out of the product subtree to
  `docs/guards/v4-adoption`;
- update P10.3 through a successor design/rehearsal for the new repository/release identity;
- run IFX composition, Windows-full, parity/compatibility and rollback rehearsal against the new
  standalone release; and
- keep every V3 required context unchanged.

The accepted 1.1.4 P10 decisions remain historical facts. They cannot be edited to certify the new
standalone release.

### T8 — Clean IFX after the standalone consumer gate

IFX cleanup is the final V4-TODO-008 tranche and requires explicit protected-deletion authorization.

Cleanup may remove the duplicated `docs/guards/v4` product source only after all Guard and IFX
consumer gates pass. It must retain:

- IFX-specific adoption plans, profiles, bundles, review records and P10 evidence;
- migration and provenance receipts;
- historical links to the original IFX commits/releases;
- the V3/V3_ifx implementation and rollback capability; and
- the inactive/active IFX integration owned by IFX.

After cleanup, prove:

- no live build, test, workflow or documentation link expects product source at `docs/guards/v4`;
- no duplicate mutable V4 product authority remains in IFX;
- V3 guard execution and IFX application build/tests are unchanged;
- IFX can consume the exact Guard release from a clean environment;
- P10.3 successor rollback still restores the V3 protection before removing any V4 context; and
- the IFX worktree is clean and passes its existing trusted guard checks.

Historical Plan text and evidence may mention old paths. Such references must be indexed as historical,
not bulk-rewritten to fabricate a different past.

## 8. Validation evidence and decisions

Create distinct tranche/run directories below `D:\IFX-Root\v4-todo-008-evidence`. Disposable-clone
evidence does not count until copied to that root and hash-verified. The final migration decision must
bind:

- original IFX source commit and V4 subtree tree object;
- exported history tip and commit-map hash;
- Guard initial commit, merge commit, accepted default-branch commit and source tree;
- path-disposition manifest hash and zero unknown/duplicate paths;
- both repositories' clean status and `git fsck` result;
- Windows-full and Linux-complete certification identities;
- deterministic package/distribution hashes;
- standalone release tag, asset URL and SHA-256;
- IFX Bundle/profile/review identities used for consumer revalidation;
- IFX cleanup commit and retained-path inventory;
- negative controls for candidate self-judgment, wrong release repository, missing asset, hash drift,
  missing bundle, source-path fallback and premature cleanup; and
- explicit booleans for `standaloneSourceAccepted`, `ifxConsumerRebound`, `ifxCoreSourceRemoved`,
  `v4Activated`, `p10GatePassed` and `v3Retired`.

For V4-TODO-008 completion, the first three may become true only with their evidence. The last three
remain false unless completed later under their own Plans.

## 9. Rollback model

- Before Guard branch push: delete only the disposable clone or abandon the local migration branch;
  Guard `main` and IFX remain untouched.
- After Guard branch push but before merge: close the PR and retain evidence; do not force-push a
  replacement history.
- After Guard merge but before release: revert through a reviewed Guard commit; IFX remains canonical.
- After standalone release but before IFX cleanup: keep the standalone release immutable and issue a
  successor patch for defects; IFX still retains its original source.
- After IFX cleanup: revert the exact IFX cleanup commit to restore incubated source, while leaving the
  Guard repository and releases intact. Re-run consumer validation before any further cutover work.

Never roll back by deleting or replacing an immutable release/tag or by rewriting either default
branch.

## 10. Stop conditions

Stop immediately on:

- source or destination identity drift from section 2;
- dirty source/target before a tranche;
- OneDrive conflict, partial hydration, unexpected reparse point or Git lock/index anomaly;
- failure to produce a complete path and commit provenance map;
- import of IFX application/V3/secrets/ignored evidence into Guard;
- public contract or runtime behavior drift not explicitly planned;
- candidate-head self-judgment in Guard CI;
- missing Linux-complete or Windows-full exact-commit evidence before publication;
- attempt to reuse or rewrite a historical release tag;
- IFX cleanup before standalone release and consumer revalidation;
- need for a remote write without separate explicit authorization; or
- any proposal to activate V4 or retire V3 as part of V4-TODO-008.

## 11. Completion criteria

V4-TODO-008 is complete only when:

1. Guard holds an auditable V4 history rooted in the IFX incubation provenance;
2. its product source, docs, plans and TODOs use standalone paths;
3. generic tests and full platform/release certification pass against one Guard commit;
4. a new immutable standalone release is independently verified;
5. IFX is rebound as a consumer using explicit repository/version/hash identities;
6. IFX-specific adoption material and evidence remain in IFX;
7. duplicated V4 product source is removed from IFX through a separately authorized cleanup commit;
8. both repositories have clean integrity reports and migration receipts; and
9. no workflow/ruleset activation, P10.GATE claim or V3 retirement is implied.
