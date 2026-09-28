# V4-TODO-017 — long paths in the trusted runner (O8)

Status: `TRUST-CHANGE PR — V4-TODO-017 G1`

Formal Plan ID: `20260928-v4-todo-017-runner-longpaths`.

Product phase G1 of the post-V4-TODO-008 sequence: Guard product defects first (V4-TODO-017, V4-TODO-018),
then release 1.1.6 as the stable base for IFX.

## Defect

`integrations/github/Invoke-V4TrustedBase.ps1` passed `core.longpaths=true` only to the single `git clone`
command of the isolated target. Git does not persist a command-scope setting, so every later Git
command on Windows ran without long-path support:

- the `checkout --detach` of the isolated target;
- the HeadRoot tracked-file check (`git status`);
- the post-test tracked-drift check on the isolated target;
- any Git command run by an approved test inside the target.

A tracked path longer than MAX_PATH then reads as deleted (` D <path>`), and the runner fails with
"HeadRoot tracked files do not match HeadSha" or "Approved tests modified tracked candidate files".
Reproduced 2026-09-28: a 313-character tracked path reads as ` D` in a clone made the old way, and as
clean when the setting is persisted.

## Fix

- `Invoke-Git` and `Get-ChangedPaths` pass `-c core.longpaths=true` to every Git command.
- The isolated clone persists the setting with `--config core.longpaths=true`, and the checkout passes it
  explicitly.

`core.longpaths` has no effect outside Windows.

## Regression control

`tests/p6/Test-V4TrustedBase.ps1` adds a candidate with a tracked path of about 300 characters under a
HeadRoot clone that has **no** persisted long-path setting, and runs the Linux producer on it. On Windows
the test first asserts that the isolated target path exceeds MAX_PATH, so the control cannot become
vacuous. P6's own Git helper also passes the setting.

Red first: the new P6 against the unfixed runner fails only on this case with
`HeadRoot tracked files do not match HeadSha:  D docs/plans/product/long-path-segment-…/deep-candidate.md`.
Green: the full P6 passes with the fixed runner.

## Trust change

The runner is a verdict component and P6 is an approved test, so this change uses the V4-TODO-014
two-PR flow. The base-held record
`docs/plans/authorizations/20260928-v4-todo-017-runner-longpaths-record.json` binds exactly:

| Path | Base SHA-256 | Head SHA-256 |
| --- | --- | --- |
| `integrations/github/Invoke-V4TrustedBase.ps1` | `121a50cb…` | `88b60a77…` |
| `tests/p6/Test-V4TrustedBase.ps1` | `0df49baf…` | `872da519…` |
| `integrations/github/ci-contract.json` (P6 hash only) | `d2b0b081…` | `12991185…` |

This PR consumes the record by deleting it. It changes the package hash (the runner is package
authority), so the fix ships in V4 Guards 1.1.6 (G3).

## Acceptance

- `v4-required` passes through the consumed authorization;
- exact-head dispatch certification passes Linux-complete and Windows-full with one `packageHash`;
- merged normally under `v4-main-autonomy`, without bypass.
