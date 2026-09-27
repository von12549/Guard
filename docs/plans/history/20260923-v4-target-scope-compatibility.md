# V4 P10.1 — IFX TargetRoot scan-scope compatibility

Status: `LOCAL 1.1.2 CANDIDATE CERTIFIED — patch publication not authorized`

The user confirmed that the affected root is `D:\IFX-Root\IFX` as V4 `TargetRoot` and
authorized scope-compatibility repair and subsequent local follow-up. The published
1.1.1 tag, archive and installation remain immutable. This Plan prepares a distinct
1.1.2 local candidate; it does not authorize a new remote release, IFX bundle acceptance,
composition into an operational sibling, UI practice, workflow changes or cutover.

## Defect and compatible contract

The Profile schema already provides `projectIdentity.relativeRoots`, but Stage Host drops
it from the adapter input. Architecture Conformance then enumerates all projects and C#
sources beneath `TargetRoot`. The IFX draft's proposed `src` and `tests` roots therefore
do not exclude `docs/guards/v4`, and its current claim coverage is not trustworthy.

Pass the schema-validated Profile roots from Stage Host to module input. For the
Architecture Conformance adapter, an omitted/empty list or sole `.` retains the legacy
whole-TargetRoot behavior needed by existing Profiles and direct tests. Otherwise require
nonempty, existing directories strictly beneath TargetRoot, reject absolute paths,
traversal, links, case-collisions and overlapping roots, and scan only their union in
ordinal order. A project reference from an included project to a file outside the
declared union must fail the graph-completeness claim rather than silently escape scope.
Keep the complete TargetRoot integrity snapshot used for build evidence unless a separate
reviewed change proves an equivalent scoped integrity contract.

## Validation and boundaries

Add positive and negative direct/Host tests: IFX-like `src`/`tests` inputs, excluded
guard source, missing roots, traversal/absolute/link roots, overlap/case collision and
out-of-scope project references. Keep existing broad-root Profile behavior and all root
immutability checks. Refresh only the affected Package/CI hash bindings and explicit
1.1.2 version assertions, then run the relevant suites, Windows-full and pinned offline
Linux-complete on a clean source commit before any release proposal. Record exact Formal
Pre and Diff. The candidate IFX bundle must be revised for the new base only after the
source checkpoint is frozen, and still cannot be accepted until the missing IFX detector
families and specialized gates are addressed.

Stop on any need to edit 1.1.1 installed bytes, loosen root confinement, add an
unreviewed module capability, or claim that scan scoping alone completes P10.1.

## Clean-source checkpoint (2026-09-23)

The exact local source checkpoint is
`46d1a99fb34c92639d2a484612fab58195903a9d`. Product/Host/Companion are
`1.1.2`, stable API is `1.0`, and the changed Architecture Conformance module is
`1.0.1`. Formal Pre and exact Diff passed for the source and generated-documentation
commits. The new direct/Host scope matrix passed on both platforms, including guard
exclusion, out-of-scope project-reference refusal and unsafe-root refusal. Existing
whole-TargetRoot Profiles and P10 synthetic composition also passed.

Windows-full passed 34 tests and pinned, `--network none` Linux-complete passed 33
tests against that same clean commit. The Linux run mounted the existing locked NuGet
cache read-only; supply-chain checks verified its hashes. Both reports have Package hash
`339becabfd0124aaa8bd5ef2c78dbfc76093bda2c823c7c7d7ce0a787a289bdb`.
The deterministic local `v4-guards-1.1.2.zip` SHA-256 is
`7a6d1582a695d9857149da185aa8b4209addce061ab4976bcc718fbbfdd5901b`.
The candidate certification/recovery aggregation passed with restore commit
`9a876b19427e326b4eafa5e661cfc07749258c4d`,
`releaseAuthorized=false`, `activeIfxCutover=false` and `ifxProfileIncluded=false`.
Evidence is under `artifacts/guards/p10-target-scope/` as `windows-full.json`,
`linux-complete.json`, `certification/v1-certification.json`,
`certification/recovery.json`, `formal-diff/summary-diff.json` and
`docs-diff/summary-diff.json`.

The existing `v4-guards-v1.1.1` tag, GitHub Release and sibling installation were
not changed. This candidate is a local source/archive checkpoint only. The real IFX
bundle still needs complete gate mapping, a published compatible base and its own
separate human-review decision before composition or operator practice.
