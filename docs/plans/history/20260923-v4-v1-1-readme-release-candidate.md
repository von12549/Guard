# V4 1.1.0 — Project README and release candidate

Status: implementation and local certification authorized on `codex/v4-development-base`; publication
will use a separate exact publication Plan after this candidate is clean and certified.

Predecessor: `20260923-v4-p9-gate-closure`

## Goal

Produce a self-explanatory V4 Guards 1.1.0 candidate that formally includes the completed P9 Web
Companion, ships a root project README as hash-bound package authority and preserves the V4 1.0 stable
CLI/API compatibility boundary.

## Scope

- Add `docs/guards/v4/README.md` as the canonical product entry point with install, CLI, Web Companion,
  four-root, Stage, Profile/module, Reset, validation, support and documentation guidance.
- Make the root README a required package-authority file so deterministic archives and install receipts
  include and hash-bind it.
- Bump the V4 product, Host and Web Companion versions to `1.1.0`; retain unchanged built-in module and
  Profile component versions at `1.0.0` and retain API version `1.0`.
- Record 1.1.0 release notes and update maintained certification/query/Web documentation to describe
  P9 as shipped while preserving all P9.GATE exclusions.
- Remove hard-coded 1.0.0 archive/install roots from lifecycle tests, assert the root README is required
  and distributed, and refresh exact CI test hashes and the compatibility baseline.
- Build a deterministic 1.1.0 archive and pass native Windows-full plus pinned network-disabled
  Linux-complete certification against the same clean candidate commit/package hash.

## Validation

1. Formal Pre and exact Diff accept this Plan and its changed paths.
2. Package Check requires `README.md`, includes it exactly once in `authorityFiles` and changes when its
   bytes change; distribution/install tests prove the README is in the manifest and installed payload.
3. `v4-guards version`, package metadata, Host assembly, Companion assembly and archive root report
   `1.1.0`; API version remains `1.0` and unchanged module/Profile versions remain `1.0.0`.
4. Compatibility, contract, package, documentation, distribution, lifecycle, supply-chain, stable CLI,
   P9 and V1 acceptance tests pass with refreshed exact hashes.
5. Native Windows-full and pinned network-disabled Linux-complete reports bind one clean commit, one
   package hash and the exact CI-selected suites.
6. The deterministic ZIP and sidecar are ready for a separately recorded `v4-guards-v1.1.0` release.
7. No `ifx_profile`, IFX cutover, workflow/ruleset activation, Reset UI expansion or other P9 exclusion
   is introduced by this candidate.

## Recovery

Revert the candidate commit and retain released `v4-guards-v1.0.0` plus the P9 source checkpoints. No
tag, GitHub Release, workflow/ruleset or IFX runtime state is created by this candidate Plan.
