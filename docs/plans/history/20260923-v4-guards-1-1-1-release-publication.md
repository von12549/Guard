# V4 Guards 1.1.1 — release publication

Status: `PUBLISHED AND SIDE-BY-SIDE INSTALLED — 2026-09-23; IFX bundle approval pending`

On 2026-09-23 the user explicitly authorized publication of the 1.1.1 compatibility patch,
in sequence before real P10.1 IFX Profile practice. This authorization covers the exact local
source and release workflow below. It does not authorize a real extension bundle, workflow or
ruleset activation, IFX cutover, or V3 retirement.

## Frozen predecessor

The P10.0, composition prototype and 1.1.1 local-candidate commits are `8e3e1c74`,
`c819a6fe` and `fa89f663f47a587e26dc5b1e2f49b6002c520486`. The last is a certified
local candidate, not automatically the publication commit. Its Windows-full 33-test and pinned,
network-disabled Linux-complete 32-test reports passed with Package hash
`dbb05cbdb9d900ad637b6eb17628693228fe74937bb0616869563e2758da4e5d`.
Its candidate archive SHA-256 is
`56b5567b86021dbe9b1334aeab262dcd2723e25ace2d264d61c29016b9a315cb`.
The candidate certification record deliberately retains `releaseAuthorized=false`.

Pre-publication read-only checks found no local or remote `v4-guards-v1.1.1` tag and no
GitHub Release at that tag. The remote `codex/v4-development-base` branch was at
`e94c2084e09ba5ba13eacdabf674840883ecdfc0`, an ancestor of the local candidate.
Recheck immediately before writing any remote reference; abort on a changed branch, tag,
release, version or archive identity.

## Release-safe source checkpoint

The certified candidate's packaged README, 1.1.1 notes, certification guide and Companion
guide still describe 1.1.1 as unpublished or certification as pending. Publishing those bytes
would give installed users a false status. Change only the declared package-documentation
paths to timeless, release-safe descriptions. Preserve the stable API `1.0`, product/Host/
Companion `1.1.1`, built-in component versions, all executable authorities, test hashes and
the immutable 1.1.0 release. Do not claim that a real IFX bundle is approved.

Run Formal Pre before source edits; commit the release-safe source checkpoint and run exact
Formal Diff. Rebuild a deterministic archive from that commit, rerun Windows-full and pinned
`--network none` Linux-complete, require the same Package hash and approved tests, then
generate a new local certification/recovery record. Verify the archive manifest's source
commit and package hash, the sidecar, and installed-path synthetic composition. The prior
candidate's reports and archive cannot certify changed documentation bytes.

## Publication sequence and acceptance

1. Verify the newly certified source commit is clean; local and remote 1.1.1 tag and Release
   remain absent; remote development branch is the expected fast-forward predecessor.
2. Push only the development branch to the exact certified commit. Re-read its remote ref.
3. Create and push an annotated `v4-guards-v1.1.1` tag at that exact commit. Verify the
   remote annotated tag object and peeled commit.
4. Publish a final GitHub Release named `V4 Guards 1.1.1`, with the certified ZIP and its
   SHA-256 sidecar only. Verify its tag, draft/prerelease flags, asset sizes and remote
   digests against the local certification and sidecar.
5. Install the exact released archive under a previously absent
   `D:\IFX-Root\guard-runtime\releases\v4-guards-1.1.1` sibling, with an external receipt
   under `D:\IFX-Root\guard-runtime\receipts`. Verify the complete installed inventory,
   package hash, version and receipt while leaving 1.1.0 untouched.
6. Record exact publication and installation evidence in this Plan, close predecessor
   status text, run Formal Diff for the documentation closure, and push only that closure
   commit. The release tag stays on the certified source commit.

The certified pre-publication record remains immutable and may continue to state
`releaseAuthorized=false`; this Plan carries the separate user authorization and actual
publication evidence. If a remote mutation partially succeeds, stop and report the exact
state. Do not delete or force-move a tag, release or branch without separate approval.

## P10.1 boundary

Publication creates a compatible V4 base, not an `ifx_profile` installation. Xiaolong Feng
(`xiaolong-feng`) still must review an exact future IFX bundle inventory and capability
ceiling in a separate human-review record. Only then may P10.1 compose it into another
receipted sibling and run IFX detector-family and installed Web UI practice. P10.2 parity,
remote governance activation and cutover remain later, separately authorized gates.

## Publication and installation closure (2026-09-23)

The release-safe source checkpoint is commit
`9a876b19427e326b4eafa5e661cfc07749258c4d` on
`codex/v4-development-base`. Formal Pre passed; the Plan and source commits each passed
exact Formal Diff. Windows-full passed 33 tests and pinned, `--network none`
Linux-complete passed 32 tests from that same clean commit. Both reported Package hash
`b6e5f63afa8cf7a37ad559cf2f8a8a8e2488c5bf96bd9984d91024545f5d90d2`.
The candidate certification and recovery records were validated and identify 1.1.0 commit
`a81a12e0d1f476c563497f961fe41fccc53edfb6` as the restore point. The same
Windows-built archive passed installed-path synthetic composition in offline Linux.
Local reports are under `artifacts/guards/p10-release/`: `windows-full.json`,
`linux-complete.json`, `certification/v1-certification.json`, `certification/recovery.json`
and `cross-archive-p10.json`.

The development branch was fast-forwarded to that source commit, then annotated tag
`v4-guards-v1.1.1` was pushed. The remote tag object is
`6e6f5e5d05e6db1c317138805f070fdc760b5211` and peels to the certified commit.
GitHub Release `V4 Guards 1.1.1` is final (neither draft nor prerelease), published at
`2026-09-23T10:26:28Z`:
`https://github.com/von12549/IFX/releases/tag/v4-guards-v1.1.1`.
Its only assets are `v4-guards-1.1.1.zip` (1,060,427 bytes; SHA-256
`c7055382c29f8c39e78114ecbf431e025f7909852c6f22bdf3c597a9a1a15631`)
and `v4-guards-1.1.1.zip.sha256` (86 bytes; SHA-256
`4420d3dca7005aa6e2f916d696b17a5c5387837a7f4914305f6e7ef884480139`).
The remote asset digests and sizes matched local files; the sidecar named the ZIP digest.
The distribution manifest binds version `1.1.1`, the source commit and Package hash above.

That exact ZIP was installed at
`D:\IFX-Root\guard-runtime\releases\v4-guards-1.1.1` with receipt
`D:\IFX-Root\guard-runtime\receipts\v4-guards-1.1.1.install.json`.
The receipt passed its schema; its 134-file list matched the complete installed file set,
each file size and SHA-256, and distribution-manifest SHA-256
`f22b73ba6ddd67efedce025bc38e4c8e6f9422e5ae4379ca4dab2bbf28044271`.
The installed Package Check passed with the certified Package hash. The 1.1.0 receipt
retained SHA-256 `6b41745f400228fcf3521f923cec544307765f0aa3a9a5e2a950291aa9789dc6`,
and all 126 files in its receipt still matched their recorded size and SHA-256.

The candidate aggregator's `releaseAuthorized=false` is a pre-publication artifact,
not a statement about current release status. This Plan records the separate user
authorization and publication. No real IFX bundle was reviewed or composed, and no
workflow, ruleset, remote governance setting, IFX cutover or V3 state was changed.
