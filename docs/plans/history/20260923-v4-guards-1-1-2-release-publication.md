# V4 Guards 1.1.2 — scope compatibility patch publication

Status: `PUBLISHED AND SIDE-BY-SIDE INSTALLED — 2026-09-23; IFX gates pending`

On 2026-09-23 the user authorized publication of the 1.1.2 patch. This Plan is
limited to the certified TargetRoot scan-scope change and release-safe package
documentation. It does not approve the incomplete IFX bundle, compose an IFX
installation, activate a workflow/ruleset, cut over from V3, or retire 1.1.1.

## Frozen predecessor and release-safe source

The local 1.1.2 candidate source checkpoint is
`46d1a99fb34c92639d2a484612fab58195903a9d`. Windows-full passed 34 tests
and pinned, network-disabled Linux-complete passed 33 tests with Package hash
`339becabfd0124aaa8bd5ef2c78dbfc76093bda2c823c7c7d7ce0a787a289bdb`.
Its local archive SHA-256 is
`7a6d1582a695d9857149da185aa8b4209addce061ab4976bcc718fbbfdd5901b`.
The 0.2.0 IFX draft is a later documentation-only commit and remains unaccepted.

The packaged README and candidate notes still say 1.1.2 is uncertified or unpublished.
Replace those statements with release-safe text and release notes while preserving
the API, product/module versions, implementation, contracts and built-in Profiles.
The packaged release must explicitly exclude any real `ifx_profile` and avoid
suggesting that scope repair closes the remaining IFX gates.

Formal Pre must pass on the exact paths before edits, followed by a clean source
commit and exact Formal Diff. Rebuild from that commit and rerun Windows-full and
pinned, `--network none` Linux-complete. Require identical Package hashes across
both platforms, deterministic ZIP output, manifest/source/version bindings,
sidecar correctness and candidate certification/recovery evidence. Prior candidate
reports do not certify changed package documentation.

## Remote publication and sibling installation

Immediately before each remote write, recheck the remote development branch is an
ancestor of the release source, and that the `v4-guards-v1.1.2` tag and Release are
absent. Do not force-update any remote ref. Push the exact certified source commit
to `codex/v4-development-base`, create/push an annotated tag at that commit, then
publish a final GitHub Release containing only the certified ZIP and SHA-256 sidecar.
Verify remote tag peel, release flags, asset names/sizes/digests and source manifest.

Install the exact released archive into a previously absent
`D:\IFX-Root\guard-runtime\releases\v4-guards-1.1.2` sibling with an external receipt
at `D:\IFX-Root\guard-runtime\receipts\v4-guards-1.1.2.install.json`.
Verify receipt schema, complete file inventory and Package hash. Preserve the
existing 1.1.0 and 1.1.1 installations and receipts byte-for-byte.

Record publication/installation evidence in this Plan in a separate documentation
closure commit, pass exact Formal Diff for that closure, and push it without moving
the release tag. On partial remote failure, report the exact state; do not delete,
move or overwrite a tag, release or installation without separate authorization.

The pre-publication certification may continue to say `releaseAuthorized=false`:
it is an immutable candidate proof, and this Plan records the separate human
authorization. P10.1 composition requires a final complete IFX bundle and an
independent Xiaolong Feng review of its exact manifest/inventory/capability ceiling.

## Publication and installation closure (2026-09-23)

The release-safe source commit is
`5bc176f61508fd01ddceb2d4e33ee34136493a35`. Formal Pre and exact Diff
passed. Windows-full passed 34 tests and pinned `--network none` Linux-complete
passed 33 tests on that same clean commit. Both reports have Package hash
`922196c12917436b087c9c09361ca3669103992694eb5aa0ca8f2873ecc11a8d`.
The candidate certification/recovery aggregation passed and names published
1.1.1 commit `9a876b19427e326b4eafa5e661cfc07749258c4d` as the restore point.
Evidence is under `artifacts/guards/p10-scope-release/`: `windows-full.json`,
`linux-complete.json`, `certification/v1-certification.json`,
`certification/recovery.json`, `formal-pre/summary-pre.json` and
`formal-diff/summary-diff.json`. The declared isolated `ifx-package-test` passed.

The development branch fast-forwarded from
`a0bb723dc8030fc5ebabda44ffe0a2f000e55dac` to the certified source commit.
The annotated remote `v4-guards-v1.1.2` tag object is
`e709172cadf5b091e9b9c550073af7d273500def` and peels to that commit.
The final, non-prerelease GitHub Release was published at
`2026-09-23T11:54:13Z`:
`https://github.com/von12549/IFX/releases/tag/v4-guards-v1.1.2`.
Its only assets are `v4-guards-1.1.2.zip` (1,069,199 bytes; SHA-256
`12270a26f923a86f49be4ee0d003f5493b2562891fd1484a4fac079f02b73c95`)
and `v4-guards-1.1.2.zip.sha256` (86 bytes; SHA-256
`7578b408e08ec69b22e69dc51151aab358575b41bec7d70081d31552847d7c92`).
Remote asset digests and sizes matched local files and the sidecar named the ZIP
digest. The distribution manifest binds 1.1.2, the source commit and Package hash.

That exact ZIP was installed under
`D:\IFX-Root\guard-runtime\releases\v4-guards-1.1.2`, with the external receipt
`D:\IFX-Root\guard-runtime\receipts\v4-guards-1.1.2.install.json` (SHA-256
`c052354ff6c068d740c7b7d8893da9eefbfee929bd0e396e4458741218d4a153`).
The receipt schema and complete 136-file inventory passed size/SHA-256 checks;
the installed Package check returned the certified hash. A synthetic-only P10
composition test against this receipted installation passed, including launcher,
Host/UI queries, deterministic composition and negative controls. It did not
compose or approve the real IFX bundle. The 1.1.0 and 1.1.1 receipt hashes remained
`6b41745f400228fcf3521f923cec544307765f0aa3a9a5e2a950291aa9789dc6`
and `3ecb7523348452688e551d0795c5759b2cf56bbec111bafc6b14932d4b710876`;
their 126 and 134 files, respectively, matched their receipts before publication.

The pre-publication certification's `releaseAuthorized=false` remains a historical
candidate property; this Plan records the user's later publication authorization.
No IFX bundle was human-accepted or operationally composed, and no V4 workflow,
ruleset, IFX cutover or V3 state changed.
