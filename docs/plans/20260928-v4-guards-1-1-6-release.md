# V4 Guards 1.1.6 — stable base release with V4-TODO-017 and V4-TODO-018 (G3)

Status: `A1 — release notes corrected before R4 (R0 #26, R1 #27 merged; no tag or release yet)`

Formal Plan ID: `20260928-v4-guards-1-1-6-release`.

Product phase G3 of the post-V4-TODO-008 sequence. G1 (V4-TODO-017, PRs #22/#23) and G2 (V4-TODO-018,
PRs #24/#25) are merged. 1.1.6 publishes them as the stable Guard base on which IFX is later rebound
(I1). Every step below needs its own operator authorization.

## 1. Purpose and boundary

Publish **V4 Guards 1.1.6** from `von12549/Guard`. 1.1.6 is the next unused version; `v4-guards-v1.1.5`
and all earlier tags stay immutable.

Compared with 1.1.5, 1.1.6 contains exactly (corrected by Amendment A1, §8):

- **V4-TODO-014**, merged after 1.1.5 was released (PRs #7–#15): trusted-base authorization for
  approved-test and runner changes. It adds `integrations/github/trust-policy.json` and
  `core/contracts/trust-change-authorization.schema.json`, adds `verdictComponents` to
  `core/contracts/ci-artifact-manifest.schema.json`, and fixes the runner's `PATHEXT` handling for
  Windows children.
- **V4-TODO-017 (O8)**: every trusted-runner Git command passes `core.longpaths=true`, and the isolated
  clone persists it. P6 has a long-path regression case.
- **V4-TODO-018 (O14)**: Host and Web Companion builds are build-location independent. The Host is built
  without debug information and with a repository-root `PathMap`. The Companion has a repository-root
  `PathMap` and no static web assets manifests. P7 builds a second clone elsewhere and requires the same
  archive.
- **Version metadata** `1.1.6`, the documentation and the new `docs/1.1.6-release-notes.md`.

The public CLI contract, query contracts, modules, Profiles and the four-root contract are unchanged.
Stable API stays `1.0`. The only contract changes are the repository CI contracts listed above; the
Host does not read them. Host and Companion source code is unchanged since 1.1.5; only their project files
changed (G2).

User-visible archive change: the archive has 141 entries, and 1.1.5 had 140.

- Removed: `companion/v4-web-companion.staticwebassets.runtime.json` and `…staticwebassets.endpoints.json`.
  The Companion serves its UI from embedded resources only.
- Added: `package/integrations/github/trust-policy.json`,
  `package/core/contracts/trust-change-authorization.schema.json` and
  `package/docs/1.1.6-release-notes.md`.

Out of scope:

- all other roadmap items (V4-TODO-006/007/009/010/012/013/015/016), by operator decision;
- any IFX change. IFX rebinds to 1.1.6 later (I1) under its own Plan.

## 2. Why this release needs two pull requests

`core/certification/compatibility-baseline.json` binds the SHA-256 of `plugin.json`, and
`core/certification/**` is a certification component in `integrations/github/trust-policy.json`. A version
bump therefore changes a protected path and uses the V4-TODO-014 two-PR flow. Version assertions in the
approved tests read `plugin.json` (O17), so no approved test and no `ci-contract.json` hash changes.

### R0 — authorization PR

Adds `docs/plans/authorizations/20260928-v4-guards-1-1-6-release-record.json` and its Plan pair
`20260928-v4-guards-1-1-6-release-authorization`. The record binds exactly:

| Path | Base SHA-256 | Head SHA-256 |
| --- | --- | --- |
| `core/certification/compatibility-baseline.json` | `f2785af9…` | `3abaa984…` |

The head value is the baseline with only the `plugin.json` hash changed from `f99a5409…` to `01c6aa79…`
(the hash of `plugin.json` with `version` `1.1.6`). `pluginVersion` `1.1.0` and `apiVersion` `1.0` stay
unchanged.

Acceptance for R0: the base-owned runner returns `authorization-added`, `v4-required` passes, and the PR
is merged normally.

### R1 — version bump (trust-change PR, this Plan)

Change set, declared exactly by this Plan's `plannedPaths`:

| File | Change |
| --- | --- |
| `plugin.json` | `version` becomes `1.1.6` |
| `core/host/V4.Guards.Host/V4.Guards.Host.csproj`, `integrations/web/V4.Guards.WebCompanion/V4.Guards.WebCompanion.csproj` | `Version` becomes `1.1.6`, `AssemblyVersion` becomes `1.1.6.0` |
| `core/certification/compatibility-baseline.json` | rebinds the `plugin.json` hash (authorized by R0) |
| `docs/plans/authorizations/20260928-v4-guards-1-1-6-release-record.json` | deleted (consumed) |
| `README.md` | current version, archive name, the 1.1.6 paragraph and the release-notes link |
| `docs/v1-certification.md` | version statement |
| `docs/1.1.6-release-notes.md` | new |
| `docs/plans/20260928-v4-guards-1-1-6-release.md`, `.plan.json` | this Plan |

Before pushing R1, the local checks are:

- the Windows full sweep;
- the local trusted-base Contract with the R0 merge as base (`authorized`);
- native `plan validate`.

Acceptance for R1:

- `v4-contract`, `v4-linux`, `v4-package`, `v4-windows` and `v4-required` pass;
- exact-head dispatch certification passes Linux-complete and Windows-full with one `packageHash`;
- the PR is merged normally with `--match-head-commit`, without bypass.

## 3. Release candidate (R2–R3, on the exact release commit)

- **R2.** Dispatch certification at the R1 `main` merge commit, which becomes the release commit. Both
  reports pass and bind one `packageHash`, equal to the certified R1 head.
- **R3** (local, clean clones at the release commit):
  1. Build Host and Web Companion in Release from clean clone A and make the archive
     `v4-guards-1.1.6.zip`.
  2. **New in 1.1.6:** build again from clean clone B at a different location with its own artifacts path.
     The two archives and `.sha256` sidecars must be byte-identical. In 1.1.5 identity was required only for
     the same Host/Companion input.
  3. Run `New-V4Distribution.ps1` twice on the clone A input. The outputs must be byte-identical (the
     established contract).
  4. Compare with 1.1.5:
     - the Host and Companion IL are unchanged apart from version metadata;
     - the archive entry set is 1.1.5's set minus the two static web assets manifests, with the root
       directory renamed.
  5. Run `core/certification/Invoke-V4V1Certification.ps1` with the two R2 reports, the archive, the release
     commit and restore commit `243cdc8…` (current `main` before R0). It writes the candidate and recovery
     records.
  6. Evidence goes to `D:\IFX-Root\v4-todo-008-evidence\G3-release\<run>` with a SHA256SUMS index.

## 4. Publication (R4 — A-RELEASE)

- An annotated tag `v4-guards-v1.1.6` on the exact release commit. Its message names the certification run,
  `packageHash` and archive SHA-256.
- A GitHub Release `V4 Guards 1.1.6`, neither draft nor prerelease. Its assets are exactly
  `v4-guards-1.1.6.zip` and `v4-guards-1.1.6.zip.sha256`. The body holds the release notes and provenance
  links (G1/G2 PRs, certification runs).
- Never overwrite an existing ref or asset.

## 5. Independent verification and records (R5)

1. Download the release assets into a fresh directory with `gh release download`. The ZIP SHA-256 must
   equal the sidecar and the R3 archive.
2. Install into a new external location with an external receipt. Check the version (`1.1.6`), run all
   four Stages on a synthetic Git Target that shares no parent with the package, then do a verified
   uninstall.
3. A documentation-only records PR (Plan `20260928-v4-guards-1-1-6-release-records`, judged by V4 and
   merged normally) updates:
   - `docs/plans/product/TODO.md`: V4-TODO-017 and V4-TODO-018 marked done, each with its PRs, the
     certification run and release 1.1.6;
   - the V4-TODO-008 checklist: rows O8 and O14 closed, §10a row 5 done;
   - the status lines of the G1 and G2 Plans and of this Plan.

## 6. Authorizations requested (one per step)

| Step | Remote actions |
| --- | --- |
| R0 | push branch, open PR, merge after operator-confirmed CI |
| R1 | push branch, open PR, dispatch certification, merge after operator-confirmed CI |
| R2 | dispatch certification at the release commit |
| R3 | none (local) |
| R4 | tag and GitHub Release (A-RELEASE, irreversible) |
| R5 | release download (read), records PR and merge |

## 7. Stop conditions and rollback

**Stop** on any of:

- a failing V4 check or certification;
- a `packageHash` mismatch across platforms or between the R1 head and the release commit;
- non-identical A/B archives (same input or independent locations);
- an IL difference from 1.1.5 other than version metadata;
- a V1 certification failure;
- an existing tag or release named 1.1.6;
- a download hash mismatch.

**Rollback:**

- Before R4: revert through a reviewed PR. A consumed authorization is not reused; a new attempt needs a
  new R0 record.
- After R4: the release is immutable. Defects are fixed by 1.1.7. The tag and assets are never deleted or
  replaced.

## 8. Amendment A1 — scope correction before R4 (2026-09-28)

R3 at the first release commit `d3f5e92` compared the archive with the published 1.1.5 archive
(`74c371eb…`). The comparison showed that the R1 release notes and §1 of this Plan understated the scope:

- they listed only V4-TODO-017 and V4-TODO-018, but V4-TODO-014 was also merged after 1.1.5 was released;
- they gave the archive size as "140 instead of 142". That count compared with `b757b79`, not with 1.1.5.

Everything else at `d3f5e92` passed:

- R2 run 36415348900: Linux 33 and Windows 34, `packageHash` `61912a6b…`;
- the independent-location, same-input and A/B archives are byte-identical (`b7722e19…`);
- Host and Companion IL are identical to 1.1.5.

Because the release notes ship inside the archive and a release is immutable, R4 was not run. A
documentation-only PR under Plan `20260928-v4-guards-1-1-6-release-notes-correction` corrects
`docs/1.1.6-release-notes.md`, `README.md` and this Plan. These are not protected paths.

The correction changes package authority, so its `main` merge commit becomes the release commit. R2 and
R3 are repeated there, with the same acceptance and stop conditions. The `d3f5e92` evidence stays on file,
marked superseded, and is not used for publication. Restore commit `243cdc8…` is unchanged.
