# V4 Guards 1.1.0 — release publication

Status: published and remotely verified on `codex/v4-development-base`; V4 Guards `1.1.0` is the
fixed initial baseline for the IFX Profile validation program. Workflow/ruleset activation and IFX
cutover remain outside this Plan.

Predecessor: `20260923-v4-v1-1-readme-release-candidate`

## Authorization

The user explicitly authorized the 1.1.0 version upgrade and release on 2026-09-23:

- publish certified candidate `a81a12e0d1f476c563497f961fe41fccc53edfb6`;
- create and push annotated tag `v4-guards-v1.1.0` at that exact commit;
- create GitHub Release `V4 Guards 1.1.0` and upload the certified ZIP plus SHA-256 sidecar;
- verify all remote references and assets; and
- prepare a separate IFX Profile validation Plan covering V4-TODO-001/002/003 without activating
  workflows, rulesets or an IFX cutover.

## Certification evidence

- Candidate commit: `a81a12e0d1f476c563497f961fe41fccc53edfb6`.
- Package hash: `cfea69e151f4edcccb51c16f91ce3c1d2651bcdf89323ea133fdff8f37615802`.
- Windows-full: **PASS**, 32 exact approved tests; report SHA-256
  `e88209fef59354f2b83e8355c2de62b988ddf0c53e46eab57c318710666543e6`.
- Linux-complete: **PASS**, 31 exact approved tests in a network-disabled Ubuntu 24.04.4 container;
  report SHA-256 `d1f1c9d2e1e772e3f42d22e67e2271c997262a4eadb9719021985911c2b36ec0`.
- V1 certification record SHA-256:
  `51d29ac7570eb3f2f0f67dde89734450911c7cb85098d51d61d655b24a534632`.
- Recovery record SHA-256:
  `fab759eb0762e81402f38b421f2c923a060641b0ae8e53efcbd72403d00bc771`; restore commit is released
  V4 1.0.0 commit `2186d0510cbcb3eddaf3dc56ff239f6558b9b115`.

The candidate certification record intentionally remains the immutable pre-publication record and
therefore retains `releaseAuthorized: false`, `activeIfxCutover: false` and `ifxProfileIncluded: false`.
Publication authorization and execution are recorded here rather than rewriting candidate evidence.

## Publication evidence

- Remote branch at publication: `codex/v4-development-base` ->
  `a81a12e0d1f476c563497f961fe41fccc53edfb6`.
- Annotated tag object: `b8b327993e2a0a728b5569984b2f781c46f07112`; remotely peeled target:
  `a81a12e0d1f476c563497f961fe41fccc53edfb6`.
- Release: `V4 Guards 1.1.0`, published at `2026-09-22T15:34:29Z`, neither draft nor prerelease.
- Release URL: `https://github.com/von12549/IFX/releases/tag/v4-guards-v1.1.0`.
- `v4-guards-1.1.0.zip`: 1,009,493 bytes; GitHub digest
  `sha256:d7d3b1ef7f70bab3153c4d1253b8a1e6db2bdea13645fe6597d36c29432c9fbd`.
- `v4-guards-1.1.0.zip.sha256`: 86 bytes; GitHub digest
  `sha256:227cb5b8594880b0b246d7127f75fcff79d55e3974d24109824d49d3cafbf2bb`.
- Supported/certified release targets remain `linux-x64` and `win-x64`; macOS is not declared.

## Validation

1. The remote branch equals the certified candidate commit.
2. The remote annotated tag peels to the same commit.
3. The GitHub Release is public, final, named `V4 Guards 1.1.0` and associated with the expected tag.
4. Both assets are uploaded and their GitHub digests equal the local certified artifacts.
5. Product, Host and Companion are version 1.1.0; stable CLI/API remains 1.0 and unchanged built-in
   module/Profile component versions remain 1.0.0.
6. No workflow/ruleset activation, IFX Profile implementation, IFX cutover or Reset UI expansion is
   part of publication.

## Recovery

The certified source and archive remain reproducible from tag `v4-guards-v1.1.0`. Withdrawing the
Release or deleting its remote tag is a separate destructive action requiring separate explicit
authorization. Any V4 defect found by later IFX Profile testing must be corrected in canonical source,
recertified and published as a `1.1.x` patch rather than hot-patched in an installed test copy.
