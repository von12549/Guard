# V4 Guards 1.1.5 — first release from the standalone Guard repository (V4-TODO-008 T6.7)

Status: `APPROVED 2026-09-28 — R1–R5 authorized, including R4 publication (A-RELEASE)`

Formal Plan ID: `20260928-v4-guards-1-1-5-standalone-release`.

Parent: `20260927-v4-todo-008-standalone-repository-extraction` T6 step 6/7 and
`20260928-v4-todo-008-t6-guard-genesis` T6.7.

## 1. Purpose and boundary

Publish **V4 Guards 1.1.5** from `von12549/Guard`. It is the first release whose source authority is
this repository. 1.1.5 is the next unused version: `v4-guards-v1.0.0` through `v4-guards-v1.1.4` stay
immutable at their IFX URLs, and no tag is recreated here.

1.1.5 carries **no runtime behavior change** compared with the published 1.1.4. V4-TODO-008 T5 proved
that the Host and Web Companion binaries built from Guard are byte-identical to the IFX-certified 1.1.4
source once build-location inputs are normalized. The public CLI, schemas, modules, profiles and
four-root contract are unchanged. The release differs from 1.1.4 only in the following, all declared:

- the standalone repository layout: PackageRoot is the repository root, and repository governance
  (`docs/plans/**`, `docs/migration/**`) is excluded from package authority;
- the test, certification and trusted-base runner paths used in the standalone layout;
- the activation-ready trusted-base workflow specimen: targets `main`, prefetches base-locked NuGet
  dependencies, and has activation-aware checks;
- the product metadata version `1.1.5`, the documentation and the new `docs/1.1.5-release-notes.md`.

Out of scope:

- known product issues O8 (the runner's post-test status check without long-path handling) and O14
  (build-location dependence of independent Host builds). They are listed in the release notes and belong
  to later product Plans;
- any IFX change (T7/T8);
- rulesets (V4-TODO-011 phase 2).

## 2. Version bump (R1 — pull request judged by the active V4 workflow)

Change set, declared exactly by the R1 root Plan:

| File | Change |
| --- | --- |
| `plugin.json` | `version` becomes `1.1.5` |
| `core/host/V4.Guards.Host/V4.Guards.Host.csproj`, `integrations/web/V4.Guards.WebCompanion/V4.Guards.WebCompanion.csproj` | `Version` becomes `1.1.5`, `AssemblyVersion` becomes `1.1.5.0` |
| `core/certification/compatibility-baseline.json` | rebind the `plugin.json` hash (`pluginVersion` baseline `1.1.0` unchanged) |
| `tests/p7/Test-V4Distribution.ps1`, `tests/p8/Test-V4StableCli.ps1`, `tests/p10/Test-V4ExtensionComposition.ps1` | expected product/assembly version becomes `1.1.5` |
| `integrations/github/ci-contract.json` | rebind the three test hashes |
| `README.md`, `docs/v1-certification.md` | version statements; the 1.1.5 standalone-release paragraph |
| `docs/1.1.5-release-notes.md` | new |

Acceptance for R1:

- `v4-contract`, `v4-linux`, `v4-package` and `v4-required` pass. `v4-windows` is selected because
  host, certification and integration paths change.
- Dispatch certification of the exact PR head passes Linux-complete and Windows-full with one
  `packageHash`.
- The operator merges with a merge commit.

## 3. Release candidate certification (R2–R3, on the exact release commit)

- **R2.** Dispatch the certification workflow at the `main` merge commit, which becomes the release
  commit. Both platform reports must pass and bind one `packageHash` equal to the PR-head package.
- **R3** (local, clean clone at the release commit, short root):
  1. Build Host and Web Companion once in Release.
  2. Run `core/distribution/New-V4Distribution.ps1` twice from two clean worktrees with that same
     Host/Companion input. The two `v4-guards-1.1.5.zip` archives and their `.sha256` sidecars must be
     byte-identical.
  3. Run `core/certification/Invoke-V4V1Certification.ps1` with the two R2 platform reports, the
     archive and restore commit `ca781ad8…` (current `main` before R1). It produces the candidate and
     recovery records.
  4. Evidence goes to `D:\IFX-Root\v4-todo-008-evidence\T6.7-release\<run>`.

## 4. Publication (R4 — A-RELEASE)

- An annotated tag `v4-guards-v1.1.5` on the exact release commit, with the message naming the
  certification run, `packageHash` and archive SHA-256.
- A GitHub Release `V4 Guards 1.1.5` in `von12549/Guard`, neither draft nor prerelease. Its assets are
  exactly `v4-guards-1.1.5.zip` and `v4-guards-1.1.5.zip.sha256`. The body holds the release notes plus
  provenance links to the IFX-hosted 1.0.0–1.1.4 releases and the V4-TODO-008 records.
- Never overwrite an existing ref or asset. Any mismatch leaves the release unpublished; fix it in a new
  commit, never by moving the tag.

## 5. Independent verification and records (R5)

1. In a fresh directory, download the release assets with `gh release download`. The ZIP SHA-256 must
   equal the sidecar and the R3 archive.
2. Install into a new external location with an external receipt, check the version (`1.1.5`), run all
   four Stages on a synthetic Git Target that shares no parent with the package, then do a verified
   uninstall.
3. A records PR (exact root Plan, judged by V4 Guardrails, merged with a merge commit) updates:
   - V4-TODO-008: T6 complete; T7/T8 are next;
   - the checklist and migration receipt: release tag, asset URL and SHA-256, and
     `standaloneReleasePublished: true` (`standaloneSourceAccepted` stays `false` until the T7 IFX
     handoff decision);
   - this Plan's status.

## 6. Authorizations requested

R1 (PR, dispatch certification, merge), R2 (dispatch), R3 (local), R4 (tag and release, A-RELEASE) and
R5 (download and install verification, records PR and merge).

## 7. Stop conditions and rollback

**Stop** on:

- any failing V4 check or certification;
- a `packageHash` mismatch across platforms or between PR head and release commit;
- a non-identical A/B archive;
- a V1 certification failure;
- an existing tag or release named 1.1.5;
- a download hash mismatch.

**Rollback:**

- Before R4: revert through a reviewed PR.
- After R4: the release stays immutable. Defects are fixed by 1.1.6. The tag and assets are never
  deleted or replaced.
