# V4 Guards 1.1.4 release lineage reconciliation

Status: `AUTHORIZED 2026-09-27 — LOCAL MERGE ONLY; PUSH NOT AUTHORIZED`

Formal Plan ID: `20260927-v4-guards-1-1-4-release-reconciliation`.

Parent program: `20260927-v4-todo-008-standalone-repository-extraction` (V4-TODO-008), where this Plan
is recorded as Amendment A2.

## Problem

V4 Guards 1.1.4 was published from the release branch `codex/v4-guards-1.1.4-release`. That branch
starts at the immutable `v4-guards-v1.1.3` commit `90aa87b5c5a8e866db3384564518377d50fe997c`. Its
tagged commit is `2185477ba89d7a3cef95c99bfe737bf98a70f39d`, and the branch tip is
`3641d81eecea59b00234e804a1c19ccf7ec04982` ("docs(guards): close v4 guards 1.1.4 release"). The
branch was never merged back into `codex/v4-development-base`.

The development branch carries the pre-release form of the same workspace-evidence capability
(`87a12b1f`). It lacks the release-only corrections: empty-config strict-mode enumeration in the
synthetic adapter, the P0 spike EvidenceRoot read capability, per-child
`core.longpaths=true` clones, the TargetScope evidence-root narrowing, the 1.1.4 product metadata,
integrity records and release notes, and the 1.1.4 release Plan pair.

As a result, V4-TODO-008 would extract a Guard history whose product source is older than the latest
published release, and no Guard commit would correspond to 1.1.4.

## Decision

Merge the release branch tip `3641d81e` into `codex/v4-development-base` with a non-fast-forward
merge, before the V4-TODO-008 history export.

- Resolve every conflicting V4 product file in favor of the published 1.1.4 release. The four
  conflicting files are `README.md`, `modules/registry.json`, `modules/synthetic-probe/adapter.ps1`
  and `modules/synthetic-probe/module.json`, all below `docs/guards/v4`. In each one, the whole
  development-versus-release difference is the release correction or its integrity hash, so no
  development-only content is lost.
- Keep the development-only planning and IFX adoption content unchanged: V4 `plans/`,
  `integrations/github/ifx-cutover-proposal.json` and
  `integrations/github/proposed-v4-ifx-guardrails.yml`.
- Required result: the merged `docs/guards/v4` tree equals the `3641d81e` tree for every path except
  those development-only files.
- Do not rewrite, re-tag or republish any release. `v4-guards-v1.1.4` stays at `2185477b`.
- Do not change V3/V3_ifx, IFX application source, workflows or rulesets.

V4-TODO-008 Amendment A2 then rebinds the history export to this merge commit, so Guard history contains
both the development lineage and the published 1.1.4 release lineage.

## Validation

Validate a tree-identical merge in a disposable clone before creating the live commit:

1. `git fsck --full --strict` on the merged clone;
2. `core/runtime/Test-V4Package.ps1` package integrity;
3. Windows-full platform certification (`Invoke-V4PlatformCertification.ps1 -Platform windows`) at the
   clean trial merge commit;
4. V4 native `plan validate` for this Plan and for the imported 1.1.4 release Plan;
5. IFX V3_ifx `Validate`, which is expected to show only the pre-existing
   `20260924-v4-ifx-c2d-g03-current-documentation.json` registration failure (V4-TODO-008 item O5);
   and
6. proof that the live merge commit tree equals the validated trial tree object.

Linux-complete is not available locally. It is not claimed here and remains part of the V4-TODO-008 T6
exact-commit certification.

## Authority

The operator selected this reconciliation on 2026-09-27 and authorized the local IFX merge commit.
Pushing the result to `origin` needs a separate explicit authorization.
