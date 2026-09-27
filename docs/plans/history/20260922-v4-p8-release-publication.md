# V4 P8.6 — V1 release publication

Status: published and remotely verified on `codex/v4-development-base`; V4 Guards `1.0.0` is released
from the certified candidate while workflow/ruleset activation, G2 autonomy and IFX cutover remain
outside this Plan.

Parent roadmap: `docs/guards/v4/plans/01-v4-self-contained-guard-plugin.md`, V4-P8.6.

Predecessor: `20260922-v4-p8-release-readiness-closure`

## Authorization

The user explicitly authorized the previously enumerated V4-P8.6 publication scope on 2026-09-22:

- push candidate commit `2186d0510cbcb3eddaf3dc56ff239f6558b9b115` to
  `codex/v4-development-base`;
- create and push annotated tag `v4-guards-v1.0.0` at that exact commit;
- create GitHub Release `V4 Guards 1.0.0` and upload the certified ZIP plus SHA-256 sidecar;
- verify all remote references and assets, then record the evidence and close V4-P8.6;
- do not activate a workflow or ruleset, grant G2 autonomy, add an IFX profile or perform IFX cutover.

## Publication evidence

- Branch at publication: `codex/v4-development-base` ->
  `2186d0510cbcb3eddaf3dc56ff239f6558b9b115`.
- Annotated tag: `v4-guards-v1.0.0`; remotely peeled target:
  `2186d0510cbcb3eddaf3dc56ff239f6558b9b115`.
- Release: `V4 Guards 1.0.0`, published at `2026-09-22T06:49:29Z`, neither draft nor prerelease.
- Release URL: `https://github.com/von12549/IFX/releases/tag/v4-guards-v1.0.0`.
- `v4-guards-1.0.0.zip`: 607880 bytes; GitHub digest
  `sha256:56d49220ef055bfdb2c15777133e7c08bf86bdb34902ba4a905181757f5fd6b8`.
- `v4-guards-1.0.0.zip.sha256`: 86 bytes; GitHub digest
  `sha256:3949ba1edb07a9ba8e2a20ac56f7cb8a935020ab61ffb50cf3b13117fdcb063b`.
- Certified package hash:
  `52c900ff4050826fdd41042d955777c2bff92705f10272b49ac2dea969b91706`.
- Supported/certified release targets remain `linux-x64` and `win-x64`; macOS support is not declared.

## Validation

1. The remote branch equals the authorized candidate commit.
2. The remote annotated tag peels to the same candidate commit.
3. The Release is public, final, named `V4 Guards 1.0.0` and associated with the expected tag.
4. Both assets are in the `uploaded` state and their GitHub digests equal the local certified artifacts.
5. The source package, archive hashes and platform certification evidence remain unchanged.
6. No workflow/ruleset activation, G2 autonomy, IFX profile or IFX cutover is part of this publication.

## Recovery

The certified source and archive remain reproducible from tag `v4-guards-v1.0.0`. Withdrawing the
Release or deleting its remote tag would be a separate destructive action and requires separate explicit
authorization. This evidence record does not perform or pre-authorize either action.
