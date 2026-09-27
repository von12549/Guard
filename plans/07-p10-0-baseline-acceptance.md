# V4 P10.0 — 1.1.0 baseline and installed Web UI acceptance

Date: 2026-09-23 (AEST). Operator: Codex task
`01a0caa0-515b-7381-b8b7-7d1367aa27cf`.

Status: **PASS for local P10.0 baseline and Web UI practice**. This is not IFX Profile
validation, P10 parity, remote activation, or cutover approval. The browser screenshots and
Host query outputs are retained in the operator task transcript; the durable Host run JSON
and prerequisite result are under `D:\IFX-Root\guard-runtime\evidence\p10`. The screenshots
were not separately exported as PNG files.

## Release and root ledger

| Item | Verified value |
| --- | --- |
| Remote annotated tag | `v4-guards-v1.1.0`; peeled commit `a81a12e0d1f476c563497f961fe41fccc53edfb6` |
| GitHub Release | Final, not draft or prerelease; archive `v4-guards-1.1.0.zip` |
| Archive SHA-256 | `d7d3b1ef7f70bab3153c4d1253b8a1e6db2bdea13645fe6597d36c29432c9fbd` (release digest, local archive, sidecar and receipt agree) |
| Installed product/API | `1.1.0` / `1.0` |
| Package Check hash | `cfea69e151f4edcccb51c16f91ce3c1d2651bcdf89323ea133fdff8f37615802` |
| Installation receipt | `D:\IFX-Root\guard-runtime\receipts\v4-guards-1.1.0.install.json`; status `installed`, 126 file entries, all size/hash matches before and after practice; manifest SHA-256 `830f888c4045b11e654a1b17a82b1056f2aa15dfd276ee43c967a615f16b80db` |
| Host / Companion assembly SHA-256 | `fc33cb638c6e40d1c6c2facfaf06e73cce4c99f22f35e0462615f7bcf91550cd` / `0cb5e3b041f0aeec35e238da09052bbd05a0a38e585107eb823bb34b4aceb81f` |
| IFX TargetRoot / commit | `D:\IFX-Root\IFX` / `e94c2084e09ba5ba13eacdabf674840883ecdfc0` (the worktree also had documentation edits) |
| PackageRoot | `D:\IFX-Root\guard-runtime\releases\v4-guards-1.1.0\package` |
| StateRoot / EvidenceRoot | `D:\IFX-Root\guard-runtime\state\p10` / `D:\IFX-Root\guard-runtime\evidence\p10` |
| Profiles | Released `default` and `synthetic_profile`, both version `1.0.0`; no `ifx_profile`. `default` has no enabled Stages; `synthetic_profile` enables Bootstrap, Analysis, Pre and Post. |
| Prerequisites | `query doctor --profile synthetic_profile`: pass; .NET `10.0.303`, PowerShell `7.6.6`; installed Companion prerequisite report: pass |

The matching installed release and external receipt already existed at the start of this
operator session. They were verified, not overwritten or reinstalled. `Test-V4Package.ps1`
passed. The four operational roots were distinct, non-reparse paths; the common parent was
never passed as a root. `D:\IFX-Root\IFX\guard` did not exist. No source-tree Companion or
rebuilt Host substituted for the installed binaries.

## Synthetic corpus and byte invariance

The two Target fixtures were prepared before browser launch. Both contain only `input.txt`,
UTF-8 without BOM:

| Target | Exact bytes | File SHA-256 |
| --- | --- | --- |
| `fixtures\p10-clean` | `synthetic-ok\n` | `03b035400b802461110b426f44247573a04ebefd43bc9c9720a0f95c7c490ed8` |
| `fixtures\p10-violating` | `synthetic-bad\n` | `4eabf441759f08e14cf71cc9b6347d4e69ec0d518d7174595ac37162c725c9a7` |

Corpus digest of labeled file hashes: `0c9fb9a62d9f9188b1b03b2081d6f193e026759360619ca32f0d00d6aaf600ff`.
Before and after the browser session, each root's sorted `(relative path, byte length,
SHA-256)` inventory was SHA-256 hashed, with LF-delimited lines and a final LF. Counts and
digests were identical:

| Root | Files | Before = after inventory SHA-256 |
| --- | ---: | --- |
| IFX TargetRoot | 4633 | `46ab3f06ff3ecd10b63a734f07316b5f5aefd16996499a7822ea670aafb242e0` |
| PackageRoot | 110 | `72d6d95e8cf7f6cbfc1ef3c1bbf24147ef2b8764c2d83e51724848d98f64b078` |
| Clean synthetic TargetRoot | 1 | `ef403e1336c120cb454f7f5b9fc315a08503f1b3f5186ced7f5a2dd991a61e80` |
| Violating synthetic TargetRoot | 1 | `d25ff1e41456e43d8e55b63cd076c55d838f69a9da16ba7d314df89ed205f3d4` |

This inventory window ended before this acceptance document was written. Browser execution
wrote only to the external StateRoot/EvidenceRoot. The installation receipt's entire file
inventory was checked again after the runs.

## Dated Web UI operator log

1. Launched the installed `core/distribution/Invoke-V4InstalledWebCompanion.ps1` with the
   verified PackageRoot, external mutable roots, and three explicit Targets. It served only
   loopback `http://127.0.0.1:14650`. The browser opened `V4 Guard Console`. The selected
   IFX project ID was `a5b3df9d351acd735dd2a691942d8678`; Host `query project` showed
   `bound: false`, `profileId: null`.
2. On IFX, inspected workspace and Plan Center without running a Stage. The UI and Host
   listed 220 `v3-historical` Plans as `historical-read-only` /
   `v3-compatibility-view`; the displayed Plan detail was read-only. No `guard/**` IFX
   subject appeared. The only selectable published Profiles were `default` and
   `synthetic_profile`.
3. Selected clean synthetic project `d7a5aa1ccdf164e388554d2fe486468d`. Direct
   Bootstrap passed (Host exit `0`, category `success`), run
   `66c9c4b56f254b258081b22b82853b52`. Analysis with the explicit dependency option
   displayed `Bootstrap → Analysis` and passed (Host exit `0`, `success`), run
   `56ed66c0766649138d40fba0f6eb123d`. Both had zero findings and non-vacuous
   `SYNTHETIC.INPUT` coverage (`matched: 1`, `minimum: 1` per executed Stage).
4. Selected violating synthetic project `9de41aa3c8e17583712c9c587bdadd6c`.
   Direct Analysis, without dependencies, remained visibly **failed** (Host exit `16`,
   `findings-blocking`), run `777858048221454d9735e03efc0fb932`. It reported one
   blocking `SYNTHETIC.INPUT` finding on `input.txt` and coverage `matched: 1`,
   `minimum: 1`; the UI did not relabel it as success.
5. Opened the clean and violating runs in the evidence desk and inspected raw Host JSON.
   Installed Host `query runs` and `query evidence` matched the UI's project IDs, run IDs,
   verdicts, executed Stage order, findings, coverage and package hash. Evidence result
   SHA-256 values were respectively `0453f4565b891f29d311e70f2f10193de8e9dc2eaaf1865932bbb342f96b3c1b`,
   `802a7448b1334cea5231a835ea9855d2d6b9a739e1b33d600a087602738c8604`,
   and `15408ebb24413cf43594a6524f6b6b2fac7e0a8d905a0e71e53f424d22149f1d`.
   The three runs retained 2, 3 and 2 evidence files. Workspace, Stage-result and
   evidence-desk screenshots are in the operator task transcript.

No Reset, Git mutation, browser file-path input, remote install, IFX Stage execution, or
package/Target authority edit occurred during the browser exercise.

## P10.1 entry finding

The 1.1.0 public CLI contract has no Profile or extension install/composition command.
`StageRuntime.LoadProfile` reads only `PackageRoot/profiles/catalog/<id>/profile.json`,
while module execution reads only `PackageRoot/modules/registry.json`; `query profiles`
also enumerates the package-owned catalog. Thus P10.1 must first create and approve the
separate compatibility Plan required by the program, then implement/certify/publish a
unique 1.1.x patch with a deterministic, receipted local extension boundary. The
receipted 1.1.0 installation must not be modified to simulate `ifx_profile` support.

Version-ledger tuple for this P10.0 synthetic practice: `(1.1.0,
a81a12e0d1f476c563497f961fe41fccc53edfb6,
cfea69e151f4edcccb51c16f91ce3c1d2651bcdf89323ea133fdff8f37615802,
d7d3b1ef7f70bab3153c4d1253b8a1e6db2bdea13645fe6597d36c29432c9fbd,
synthetic_profile@1.0.0, no external extensions,
e94c2084e09ba5ba13eacdabf674840883ecdfc0,
0c9fb9a62d9f9188b1b03b2081d6f193e026759360619ca32f0d00d6aaf600ff)`.
The IFX commit identifies the read-only repository inspected, not a V4 parity corpus.
