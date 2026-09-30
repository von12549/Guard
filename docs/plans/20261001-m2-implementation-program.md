# M2 implementation program — Profile discovery, draft, review and promotion

Status: `IMPLEMENTATION PROGRAM — IMPLEMENTED 2026-10-01`

Formal Plan ID: `20261001-m2-implementation-program`.

Authority: `20261001-m2-profile-authority-decision`, V4-AD-039 and V4-TODO-020.

## Goal and dependency order

Promote the accepted M2 decision into four separately reviewable checkpoints:

1. `20261001-m2-inert-discovery` adds a deterministic, read-only fact contract and Host CLI.
2. `20261001-m2-profile-draft` stores a snapshot-bound, non-authoritative scaffold below StateRoot.
3. `20261001-m2-profile-review` validates schema, Module/configuration hashes, fixtures, coverage and
   explicit human policy decisions without accepting a draft as authority.
4. `20261001-m2-promotion-candidate` emits a portable, hash-bound extension candidate for the existing
   immutable sibling composer, without changing TargetRoot or selecting the composition.

The JSON Plans intentionally have no native dependency edges because implementation may be delivered as
one reviewed PR. The dependency order in each Markdown Plan governs execution and recovery.

## Global boundaries

Discovery reads only inert allowlisted files. It never builds, restores, downloads or executes Target
code. Drafts remain local mutable StateRoot data and never enter Stage/Profile lookup. Promotion emits a
candidate only: this program does not write `.guard/`, consume a target trust authorization, select an
installed composition, activate CI, modify a workflow/ruleset, publish or merge.

## Validation, stop and resume

Run focused M2 positive/negative tests, affected contract/package/stable-CLI/P10 composition regressions
and the exact base-to-head plan-set diff. Stop on Target drift, link traversal, stale snapshot, unknown
manifest form, unresolved policy, fixture mismatch, capability/hash drift or any request for Target or
remote mutation. Resume from the last verified artifact after correcting the input or revising the exact
Plan; never reuse a stale draft, review or promotion candidate.

## Recovery

Revert the four checkpoints in reverse order. Generated StateRoot drafts and candidate bundles are
non-authoritative disposable local artifacts; no Target, selected installation or remote state changes.

## Implementation result

All four local checkpoints are implemented by the Host and bound contracts. Focused M2, contract,
package, generated-documentation and stable-CLI regressions pass. Target adoption, composition
execution/selection and CI activation remain intentionally unperformed boundaries.
