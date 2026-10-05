# V4 Guards 1.2.2 final release report

Status: `COMPLETE 2026-10-06 — G-RELEASE = GO`.

Formal Plan ID: `20261006-v4-guards-1-2-2-release-records`.

## Result

V4 Guards 1.2.2 was published from exact main commit
`b56ca17ba60a8e9383931101077ad75cb129257f` after every release gate passed. Annotated tag
[`v4-guards-v1.2.2`](https://github.com/von12549/Guard/releases/tag/v4-guards-v1.2.2) has tag object
`987aa31977f1019098daee652cbe35d0a4a6a5bb` and peels to that commit. The GitHub Release was published
at `2026-10-05T17:54:07Z`, is non-draft and non-prerelease, and contains exactly two self-contained ZIPs
and their matching SHA-256 sidecars.

## Source and certification

| Evidence | Exact record |
| --- | --- |
| P04 repair | [PR #58](https://github.com/von12549/Guard/pull/58), merged as `0fde43c16e2fb92f56c1e9c899b9b2b3333c9f75` after PR #57 supplied the one-use baseline authorization |
| Release preparation | [PR #59](https://github.com/von12549/Guard/pull/59), head `a8808a4`, merge/release commit `b56ca17ba60a8e9383931101077ad75cb129257f` |
| Final Guardrails | [run 37345103566](https://github.com/von12549/Guard/actions/runs/37345103566): contract, Linux, package, Windows and required all passed; Windows completed in 29m44s |
| Final Certification | [run 37345139718](https://github.com/von12549/Guard/actions/runs/37345139718): Linux-complete 35 tests and Windows-full 36 tests passed at the release commit |
| Cross-platform source packageHash | `611b6067892510e9f902cad298255adf8cc37ecd1348b2d0ba6ac52eb594bba0` |
| Recovery restore commit | `6e8d3ec02a8bb2eab4a83131de7d59b59fa4c2f7` (1.2.1 release source) |

The first Windows Certification attempt stopped at a Web Companion readiness timeout. The same test
passed three consecutive local reproductions, and the unchanged release commit then passed a complete
27m51s Windows-full rerun. No source or archive was changed between attempts. Both final native reports
bind the release commit and the same clean source packageHash.

An earlier local preflight identity `8d3e8ef0…` was rejected from the release record after diagnosis
showed two ignored `obj/` directories created by local test restores. Removing only those generated
directories restored the clean 197-file source identity above, matching both CI platforms. Independent
asset builds came from clean detached checkouts and were unaffected. A new clean preflight baseline and
post-publication checkpoint confirmed unchanged User/Machine environment, Process PATH, four PowerShell
profiles and Target ordinary/ignored inventories.

## Published assets

| Asset | Bytes | ZIP SHA-256 | RID packageHash |
| --- | ---: | --- | --- |
| `v4-guards-1.2.2-linux-x64.zip` | 194,592,470 | `addccf339c2be4aca832126edc0dbf9b86b6f1f41dd3897d143181b4af8143f5` | `9a38f113adbf0ccdb4e9216190ac320ffc6d02f0f0781e34fb984725b9b7737b` |
| `v4-guards-1.2.2-win-x64.zip` | 192,955,154 | `fed547587528ab1444a7eebba4b47a78736bb922df95d531cf687f437601890b` | `b3c9763c234e082eae4be5f93c134922cd173e97c9dd97beb2754581a53bcfae` |

For each RID, two independent clean checkouts produced byte-identical ZIPs and sidecars. Both archives
have the sole root `v4-guards-1.2.2/`; their manifests bind the release commit. Candidate/recovery
certification independently matched the source reports, complete archive payload, RID package identity,
ZIP hash and 1.2.1 recovery source before tagging.

## Independent download verification

All four Release assets were downloaded into a new directory after publication. ZIP hashes, sidecar
text, byte counts and GitHub asset digests matched the table above. Downloaded assets, not local build
outputs, were tested.

| Platform | Freshly downloaded asset result |
| --- | --- |
| Windows 10.0.26200 | Installed 1.2.2 with an external receipt; public launcher returned version 1.2.2/API 1.0; Bootstrap, Analysis, Pre and Post passed on the complete Synthetic project; loopback Companion returned `v4-host` authority and four actual roots; verified uninstall marked the receipt `uninstalled` and removed the install root. A separate P04 regression passed `-File` and call-operator launch, omitted port, paths with spaces, alternate cwd, actual roots and host-safety checks. |
| Network-isolated Ubuntu 24.04.5 LTS | In Docker with `--network none`, installed the downloaded Linux asset; version/API 1.0, the same four Stages, loopback Companion and verified uninstall passed. The five locked NuGet packages were copied from a SHA-512-verified cache. Image: `mcr.microsoft.com/dotnet/sdk@sha256:35d40304542c8689331f8cab17c65926cdf48fe711e289321d71924b230a7d29`. |

## Remaining boundary

The 1.2.2 release does not reconstruct the failed IFX P03 result or its missing A1/B3 evidence. It does
not adopt an IFX Target, include `ifx_profile`, select a composition, activate trusted CI or remote
policy, or claim IFX protection. Those transactions remain separately governed. Earlier release tags
and assets were not changed.
