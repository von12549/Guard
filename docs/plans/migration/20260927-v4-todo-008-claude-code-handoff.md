# Claude Code handoff — V4-TODO-008 standalone repository extraction

This document is written for the Claude Code instance that will execute
`20260927-v4-todo-008-standalone-repository-extraction` after the user explicitly authorizes
execution. Read the master Plan in full before using this checklist. If this handoff and the master
Plan differ, the master Plan and the latest explicit user instruction win.

## Mission

Preserve the V4 Guards product history from the IFX incubation repository in the existing standalone
Guard repository, make the product build/test/release from its new root, validate it independently,
rebind IFX as a consumer, and clean duplicated product source from IFX only after every trust gate.

Do not activate V4, change IFX required checks/rulesets, pass P10.GATE, or retire V3/V3_ifx.

## Fixed starting identities

Amendment A1 (2026-09-27, master Plan section 2) rebinds the export source. The original values were
`IFX_SOURCE_COMMIT=ba0816321bcb04dba93136beea80f41f237517de`,
`IFX_V4_TREE=e3c359491709ee49b73979276a0143ed52221999` and `IFX_V4_TOUCHING_COMMITS=47`.
Amendment A2 (2026-09-27, master Plan section 2) then rebinds it to the 1.1.4 release-lineage
reconciliation merge. The A1 values were `640c5756…`, `418a1933…`, 174 files and 48 commits.

```text
IFX_WORKTREE=D:\IFX-Root\IFX
IFX_BRANCH=codex/v4-development-base
IFX_SOURCE_COMMIT=80f7b6b65fb06897444a6a36c604c42c93c834e4
IFX_V4_PATH=docs/guards/v4
IFX_V4_TREE=af913836d83c071b9c0a769c6c84da4fb727b971
IFX_V4_TRACKED_FILES=175
IFX_V4_TOUCHING_COMMITS=50

GUARD_WORKTREE=C:\Users\von12\OneDrive\Desktop\Guard
GUARD_REMOTE=https://github.com/von12549/Guard.git
GUARD_DEFAULT_BRANCH=main
GUARD_INITIAL_COMMIT=e75d038
GUARD_WORK_BRANCH=codex/v4-todo-008-standalone

PERSISTENT_EVIDENCE_ROOT=D:\IFX-Root\v4-todo-008-evidence

P10_3_DECISION_SHA256=529e19b567c05619ec054117e2514c579a908a4e614355411fc28b6d52964964
```

Re-resolve full Guard commit IDs at T0 and record them; do not guess the expansion of `e75d038`.

## Mandatory first response to the user

Before changing files, report:

1. that both Plans were read;
2. the exact identities rechecked;
3. whether both worktrees are clean;
4. whether OneDrive is fully hydrated and concurrent synchronization is controlled;
5. the requested execution tranche; and
6. which later steps still require separate remote/deletion authorization.

If the user authorizes only local work, stop before every push, PR, merge, release or IFX deletion.

## Repository instructions and safety

1. Search both roots for `CLAUDE.md` and `AGENTS.md`; obey the applicable instructions.
2. First try ordinary Git access as the interactive owner. Do not add `safe.directory=*`. Only if Git
   actually reports dubious ownership, use the exact command-scoped form:

   ```powershell
   git -c safe.directory=C:/Users/von12/OneDrive/Desktop/Guard -C C:/Users/von12/OneDrive/Desktop/Guard status -sb
   ```

3. Do not use `git reset --hard`, force push, broad recursive deletion, or cross-shell path deletion.
4. Use a new disposable directory created with `New-Item`/`mktemp`; validate its absolute path before
   removing it.
5. Never run subtree extraction against the live IFX `.git`. Use a no-hardlink clone.
6. The operator, not Claude Code, pauses OneDrive and confirms the Guard tree is fully local. Claude
   Code checks/records that attestation and scans for offline/recall placeholder attributes. Do not
   kill, pause or reconfigure OneDrive automatically. Close other Git clients and run
   `git fsck --full --strict` at every checkpoint.
7. Preserve user changes. Any dirty worktree at a tranche boundary is a stop unless the changed files
   are exactly the current authorized tranche and already accounted for.

## T0 checklist — identity and environment

Run read-only equivalents of:

```powershell
git -C D:/IFX-Root/IFX status -sb
git -C D:/IFX-Root/IFX rev-parse HEAD
git -C D:/IFX-Root/IFX rev-parse HEAD:docs/guards/v4
git -C D:/IFX-Root/IFX ls-files docs/guards/v4 | Measure-Object

git -C C:/Users/von12/OneDrive/Desktop/Guard status -sb
git -C C:/Users/von12/OneDrive/Desktop/Guard rev-parse HEAD
git -C C:/Users/von12/OneDrive/Desktop/Guard remote -v
git -C C:/Users/von12/OneDrive/Desktop/Guard fsck --full --strict
```

If and only if ordinary Guard commands fail with dubious ownership, repeat each failed command with
`-c safe.directory=C:/Users/von12/OneDrive/Desktop/Guard` and record that the fallback was used.

Also verify the remote Guard repository remains public, defaults to `main`, and has no active ruleset
or workflow unless a newer reviewed Plan explicitly changes that expectation. GitHub GETs are allowed;
GitHub writes are not implied.

Use the fixed durable root `D:\IFX-Root\v4-todo-008-evidence`. Create a timestamped child for each
tranche/run. Record command, exit code, stdout/stderr digest, tool version and resolved path for each
migration command. `%TEMP%` may hold disposable clones only; copy and hash-verify their final records
into the durable root before cleanup. Do not write mutable evidence below the product PackageRoot.

## T1 checklist — manifests before movement

Create these machine-readable records before importing history:

```text
migration-source-inventory.json
migration-path-disposition.json
migration-plan-disposition.json
migration-release-inventory.json
migration-coupling-inventory.json
```

Required fields for each path disposition:

```json
{
  "sourcePath": "docs/guards/v4/...",
  "sourceBlob": "<git blob>",
  "sourceSha256": "<sha256>",
  "owner": "guard-product|ifx-consumer|historical-copy|evidence-retained-in-ifx|obsolete-after-gate",
  "destinationRepository": "Guard|IFX",
  "destinationPath": "<repo-relative path>",
  "action": "extract|copy-exact|move-after-gate|retain|delete-after-gate",
  "reason": "<nonempty>"
}
```

Reject duplicate source rows, duplicate active destination authorities, missing hashes and unknown
dispositions. Report counts by owner/action.

Product/IFX decisions that must not be guessed:

- `proposed-v4-ifx-guardrails.yml` and `ifx-cutover-proposal.json` are IFX-owned even though currently
  nested in the product subtree.
- maintained plans 06–09 are IFX adoption plans;
- maintained plans 00–05 are principally product plans but mixed P10 summaries need an explicit split;
- formal Plan IDs/filenames containing IFX or P10 remain in IFX;
- generic P0–P9 and generic release Plans may be copied exactly into Guard history;
- ignored P10 evidence and accepted bundles are not imported into Guard; and
- old release assets/tags remain authoritative at their original IFX URLs.

The following minimum disposition is already decided and is not an open T1 choice:

| Extracted Guard path | T4 active-tree action | Historical disposition | IFX current successor |
| --- | --- | --- | --- |
| `plans/06-ifx-profile-validation-program.md` | delete | retain in extracted Git history only | `docs/guards/v4-adoption/plans/06-ifx-profile-validation-program.md` |
| `plans/07-p10-0-baseline-acceptance.md` | delete | retain in extracted Git history only | `docs/guards/v4-adoption/plans/07-p10-0-baseline-acceptance.md` |
| `plans/08-p10-1-extension-composition-compatibility.md` | delete | retain in extracted Git history only | `docs/guards/v4-adoption/plans/08-p10-1-extension-composition-compatibility.md` |
| `plans/09-p10-3-cutover-and-rollback-proposal.md` | delete | retain in extracted Git history only | `docs/guards/v4-adoption/plans/09-p10-3-cutover-and-rollback-proposal.md` |
| `integrations/github/ifx-cutover-proposal.json` | delete | retain in extracted Git history only | `docs/guards/v4-adoption/integrations/github/ifx-cutover-proposal.json` |
| `integrations/github/proposed-v4-ifx-guardrails.yml` | delete | retain in extracted Git history only | `docs/guards/v4-adoption/integrations/github/proposed-v4-ifx-guardrails.yml` |

Do not duplicate these files under Guard `docs/plans/history`. Create only a provenance index containing
old paths/blob hashes and the IFX successor paths. Apply the same rule to any additional T1-confirmed
IFX-only path. Product plans 01/02 and README stay in Guard after their live IFX status is replaced by
an external adoption-history link.

## T2 checklist — history export

Use a writable disposable clone. The following is a shape, not permission to execute before T0 passes:

```powershell
$migrationRoot = Join-Path ([IO.Path]::GetTempPath()) ('v4-todo-008-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $migrationRoot | Out-Null
$exportClone = Join-Path $migrationRoot 'ifx-export'
git clone --no-hardlinks D:/IFX-Root/IFX $exportClone
git -C $exportClone checkout --detach 80f7b6b65fb06897444a6a36c604c42c93c834e4
git -C $exportClone status --porcelain=v2 --untracked-files=all
```

Invoke `git subtree split` from Git Bash because the PowerShell invocation in the feasibility audit did
not populate the helper environment correctly. Quote the converted Git-Bash path; do not concatenate
untrusted input. The conceptual command is:

```text
git subtree split --prefix=docs/guards/v4 --branch export/v4-standalone 80f7b6b65fb06897444a6a36c604c42c93c834e4
```

Before deleting the clone:

- capture the export tip;
- convert `.git/subtree-cache` mappings into stable sorted JSON;
- record the mapping JSON SHA-256;
- prove the export-tip root tree has the same path/blob inventory as
  `80f7b6b6...:docs/guards/v4` (Amendment A2);
- prove 175 tracked files and no path outside the subtree;
- scan for credentials/secrets and IFX/V3 application content; and
- run `git fsck --full --strict`.

If subtree history mapping cannot be made deterministic and auditable, stop. Do not fall back to a
squashed copy.

## T3 checklist — Guard lineage merge

Operate only on the Guard work branch:

```powershell
$guard = 'C:/Users/von12/OneDrive/Desktop/Guard'
git -C $guard switch -c codex/v4-todo-008-standalone e75d038
```

Use the command-scoped `$safe` form from T0 only if ordinary Git access produced the documented
dubious-ownership error.

Add the export clone as a temporary local remote, fetch the exact export tip, remove the temporary
remote after fetching, then merge with a non-fast-forward unrelated-history merge. Expect only the
root `README.md` conflict. Any second conflict stops the merge for investigation.

Resolve README in favor of the complete V4 product README and record the original Guard README blob
`d6e5996b5246743aba98e26e1ee7e7292f26ead8` in the receipt. The merge commit must have two parents.

Before layout changes, prove:

- Guard initial commit is still reachable;
- all exported V4 commits are reachable;
- export root inventory matches source inventory;
- no unexpected remote remains;
- worktree is clean after the merge commit; and
- `git fsck --full --strict` passes.

No push is permitted without a new explicit user authorization.

## T4 checklist — standalone normalization

Expected high-risk coupling classes discovered during feasibility inspection:

- tests deriving repository root by walking `../../..` from the old package directory;
- test/evidence defaults under `artifacts/guards/v4`;
- trusted-base allowed patterns for `docs/guards/v4/**` and `docs/guards/plans/**`;
- certification scripts constructing PackageRoot as `docs/guards/v4`;
- Plan test fixtures hard-coding the former repository layout;
- workflows using `${{ github.repository }}` to find a V4 release; and
- IFX-specific proposal/specimen files mixed into the generic integration directory.

Repair these through explicit root parameters and standalone repository-relative contracts. Do not
add compatibility symlinks or duplicate product trees. Keep installed archive structure and public CLI
stable even if source paths move.

During T4, delete the six IFX-only active-tree paths listed above after their source blobs and future
IFX destinations are recorded. Their prior commits remain reachable by design. Do not wait until T7
to remove these active Guard copies; T7 creates/moves the authoritative current IFX successors.

Move plan content according to the master Plan. Historical formal Plan JSON that names old IFX paths
must remain byte-exact and be labeled historical; do not edit it until it validates against a false past.

Commit normalization separately from the history merge. The commit message and receipt must enumerate
all intentional public-contract differences; normally the list is empty.

## T5 checklist — validation matrix

Discover the exact commands from the migrated source, then record and run them. At minimum include:

| Gate | Required result |
| --- | --- |
| PowerShell parser/JSON schemas/YAML | clean |
| Host build and test | pass |
| Web Companion build and test | pass |
| P0–P9 generic suites | pass |
| Package integrity | pass |
| Trusted-base positive case | pass |
| Candidate self-judgment controls | rejected |
| Plan validate/compose/Plan Center | pass at new paths |
| Distribution build A/B | reproducible |
| Fresh install/receipt/launch/uninstall | pass |
| Supply-chain and lifecycle | pass |
| Windows-full | pass at exact Guard commit |
| Linux-complete | pass at the same commit/package identity |
| External synthetic target | pass with separate roots |
| Secret and IFX/V3-content scan | zero prohibited content |
| Post-test status and fsck | clean/pass |

If Linux cannot run locally, finish T5 locally as
`local-windows-accepted-linux-pending`. This is an expected checkpoint, not a release pass. Stop before
publication/canonical switch. Overall T5 becomes `pass` only when authorized T6 CI supplies
Linux-complete for the identical Guard commit and package identity; record both decision hashes.

Compare a clean build of the bound old source and the new source. Produce a structured difference
report; do not use a prose assertion in place of manifests. Version/source/provenance fields may differ
only when declared. Public schemas, CLI contracts and behavioral fixture verdicts must not weaken.

## Remote boundary checklist

Before any of the following, stop and ask the user with the exact branch/repository/action:

- `git push` to Guard or IFX;
- creating/updating a pull request;
- merging a pull request or updating `main`;
- creating a workflow or ruleset;
- creating a tag/release or uploading an asset; or
- removing `docs/guards/v4` from IFX.

Approval for one item does not authorize the next.

## T7/T8 IFX rebinding and cleanup checklist

After the standalone release exists and is verified:

1. Create an IFX-side successor Plan with exact Guard repository, commit, release tag and hashes.
2. Move IFX-owned proposal/specimen/plans to `docs/guards/v4-adoption` without losing history.
3. Make the IFX workflow fetch the product from `von12549/Guard`, never implicitly from the current
   target repository.
4. Compose the exact reviewed IFX bundle with the new standalone release in a fresh sibling install.
5. Re-run product certification required by the release, IFX Windows-full, compatibility/parity and
   local rollback rehearsal.
6. Keep V3 contexts unchanged and keep the V3 source.
7. Obtain explicit protected-deletion authorization.
8. Remove only paths classified `obsolete-after-gate`.
9. Verify no live reference to `docs/guards/v4` remains outside historical records/evidence.
10. Commit an IFX cleanup receipt with retained/deleted inventories and rollback commit.

Do not rewrite the accepted P10.1–P10.3 decision files. Add successor decisions.

## Required final report from Claude Code

At the end of every tranche, report:

- tranche and status (`pass`, `stopped`, `blocked`);
- exact source and destination commits;
- commits created and whether anything was pushed;
- evidence paths and SHA-256 values;
- validation matrix results;
- path/commit provenance counts;
- protected or remote mutations performed (normally none until authorized);
- open blockers and next required authorization; and
- boundary booleans:
  `standaloneSourceAccepted`, `standaloneReleasePublished`, `ifxConsumerRebound`,
  `ifxCoreSourceRemoved`, `v4Activated`, `p10GatePassed`, `v3Retired`.

Never summarize a partial local extraction as completed V4-TODO-008.
