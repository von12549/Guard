# V4-TODO-008 migration records

This directory records how the V4 Guards product moved from the IFX incubation repository
(`von12549/IFX`, `docs/guards/v4`) into this standalone repository. Like `docs/plans/**`, it is
repository governance and is excluded from package authority.

| File | Contents |
| --- | --- |
| `source-inventory.json` | Every source path at the export commit, with Git blob and SHA-256 |
| `path-disposition.json` | Exactly one owner/action/destination per source path |
| `plan-disposition.json` | Disposition of every V4-named IFX formal Plan file |
| `release-inventory.json` | The immutable IFX-hosted `v4-guards-v1.0.0` … `v1.1.4` releases and assets |
| `coupling-inventory.json` | IFX layout couplings found before normalization, with the planned fix for each |
| `commit-map.json` | Original IFX commit → extracted Guard commit map from `git subtree split` |
| `provenance-index.json` | The IFX-only paths removed from the active tree (blobs, last IFX commit, IFX successor path), moved product Plans and byte-exact Plan copies |
| `migration-receipt.json` | Identities and tranche results bound to this migration |

## Lineage

- Export source: IFX commit `80f7b6b65fb06897444a6a36c604c42c93c834e4`, V4 tree
  `af913836d83c071b9c0a769c6c84da4fb727b971`. This is the reconciliation merge of the published 1.1.4
  release lineage (Amendment A2).
- Export tip: `4609edaeef0cf357fb1a59cb2413850e1367056b` (50 extracted commits; root maps to IFX
  `20c93d521728746e1c227654b32219d94fcdf6bb`).
- Guard merge: `ec9f5eade8596c99081ed2ca1663252b13bc6e49`, with parents Guard initial commit
  `e75d0386492632e4df87230f3b64252086d1bc58` and the export tip. The original Guard README blob was
  `d6e5996b5246743aba98e26e1ee7e7292f26ead8`.

## Historical releases

`v4-guards-v1.0.0` through `v4-guards-v1.1.4` were published from the IFX repository. Those tags,
releases and assets remain immutable authorities at their original IFX URLs. This repository never
recreates or moves them. The first release published from this repository uses a new, unused version
and points back to them.

## IFX-only files in history

Six IFX-owned files are reachable in this repository's history but are not part of the active tree:
plans 06–09, `ifx-cutover-proposal.json` and `proposed-v4-ifx-guardrails.yml`. The extraction kept
their history, and they are not copied into `docs/plans/history`. Their authoritative current versions
belong to IFX (`docs/guards/v4-adoption/`); see `provenance-index.json`.
