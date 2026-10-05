# V4 Guards 1.2.1 final release report

Status: `COMPLETE 2026-10-05 — G-RELEASE = GO`.

Formal Plan ID: `20261005-v4-guards-1-2-1-release-records`.

## Result

V4 Guards 1.2.1 was published from exact main commit
`6e8d3ec02a8bb2eab4a83131de7d59b59fa4c2f7` after every release gate passed. Annotated tag
[`v4-guards-v1.2.1`](https://github.com/von12549/Guard/releases/tag/v4-guards-v1.2.1) peels to that
commit. The GitHub Release is non-draft, non-prerelease and contains exactly two self-contained ZIPs
and their matching SHA-256 sidecars.

## Source and certification

| Evidence | Exact record |
| --- | --- |
| Onboarding repair | [PR #51](https://github.com/von12549/Guard/pull/51), merged as `e7151c9083c2d3b498f5f0f86bece9709065269a` |
| Release preparation | [PR #55](https://github.com/von12549/Guard/pull/55), head `e9111629460900e451f828c9929b160ea1c2ea9b`, merge/release commit `6e8d3ec02a8bb2eab4a83131de7d59b59fa4c2f7` |
| Final Guardrails | [run 37276209500](https://github.com/von12549/Guard/actions/runs/37276209500): contract, Linux, package, Windows and required all passed |
| Final Certification | [run 37276209649](https://github.com/von12549/Guard/actions/runs/37276209649): Linux-complete 35 tests and Windows-full 36 tests passed |
| Cross-platform source packageHash | `701a535945315c954f5e4fafb11b4b06da53d4f8e9c710803a0d210903ac1ae7` |
| Recovery restore commit | `cf8a9cb631e120309568f18ac965540e381f8027` (1.2.0 release source) |

Both native platform reports bind the exact release commit and the same source packageHash. The clean
certification checkout reproduced that hash. Candidate/recovery certification passed separately for
each RID and checked the complete archive payload and RID-specific package identity.

## Published assets

| Asset | ZIP SHA-256 | RID packageHash |
| --- | --- | --- |
| `v4-guards-1.2.1-linux-x64.zip` | `ab10bb07a1ad6f2cd01a071d3c3656da17b9c2cae34be70d7e304ae3c133fc25` | `4ea3d6c2a686aecd468afdb707a4084808821277a1a1dbd4daf4c8a66dbcba3c` |
| `v4-guards-1.2.1-win-x64.zip` | `bb981f443bb42bca12e36c087840de214aec33615ddc3f8a3d4ef6a5724fe7a2` | `255d52c53ca4f3e36a4f7d2c08ee42a605302e9d207c34d7994c9c504c013d9c` |

For each RID, two independent clean checkouts produced byte-identical ZIPs and sidecars. Repacking
the same inputs reproduced those bytes. The sidecar text, local ZIP SHA-256, GitHub asset digest and
candidate/recovery `archiveSha256` agree. No portable or arm64 asset was uploaded. Both archives have
the sole root `v4-guards-1.2.1/`.

## Independent download verification

All four Release assets were downloaded into a new directory after publication. Their ZIP hashes and
sidecar text matched the table above. The downloaded assets were tested, not substituted with local
build outputs.

| Platform | Freshly downloaded asset result |
| --- | --- |
| Windows | Installed 1.2.1 with external receipt; public launcher returned API `1.0`; Bootstrap, Analysis, Pre and Post passed on a synthetic project; loopback Companion returned `v4-host` session authority and embedded UI; verified uninstall set the receipt to `uninstalled` and removed the install root. |
| Isolated Linux | Installed 1.2.1 with external receipt; public launcher returned API `1.0`; the same four Stages passed on an isolated synthetic project; loopback Companion returned `v4-host` session authority and embedded UI; verified uninstall set the receipt to `uninstalled` and removed the install root. |

Linux Post used the locked ArchUnitNET 0.13.4 dependency closure after all five NuGet SHA-512 values
were verified. That closure is a declared synthetic Stage test prerequisite, not a shared runtime
requirement for the self-contained Host or Companion. Temporary workspace fixtures and their generated
files were removed after verification.

## Remaining boundary

The 1.2.1 release does not adopt a consumer Target, include `ifx_profile`, select a composition,
activate trusted CI or remote policy, or authorize IFX P03. Those transactions remain separately
governed. Earlier release tags and assets were not changed.
