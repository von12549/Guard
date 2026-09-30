# M1 foundation decisions — distribution, initialization and lifecycle

Status: `DECISION RECORD — ACCEPTED 2026-10-01; implementation not authorized by this Plan`

Formal Plan ID: `20261001-m1-foundation-decisions`.

Source discussion:

- `memory/draft-plans/01-installation-and-initialization.md`;
- `memory/runtime-storage-retention-todo.md`;
- `memory/formalization-decision-register.md`, D01–D10.

The source files remain ignored discussion memory. This formal pair records the accepted product
decisions in maintained planning authority.

## Goal

Resolve the M1 decisions that block exact implementation Plans: runtime ownership, default mutable-root
placement, Target-owned governance layout, adoption history, receipt placement, external governance,
Init/adoption separation, update/downgrade behavior and runtime cleanup/retention.

## Accepted decisions

### 1. Runtime distribution

Publish RID-specific self-contained .NET Host and Web Companion distributions for supported Windows and
Linux architectures. Keep PowerShell, Git, Node and language toolchains as Module-declared external
prerequisites unless separately accepted. Reject the alternative of bundling every runtime into one
zero-prerequisite product.

### 2. Init defaults and overrides

`guard init --target-root <path>` derives a stable project context and previews OS-specific per-user
StateRoot/EvidenceRoot defaults. Windows uses LocalApplicationData; Linux uses `XDG_STATE_HOME` with a
`~/.local/state` fallback. `--data-root` may relocate the derived project container;
`--state-root`/`--evidence-root` are advanced overrides. All paths receive identical confinement and
ownership validation. The Host still receives four explicit roots on every invocation.

### 3. Governance and history

Active Target-owned governance uses `.guard/`. Portable active sources and low-churn governance records
are schema-classified there; machine-local receipts, state and full Evidence remain external. Existing
adoption directories are historical. Migration is a separate provenance-preserving Target
preview/review/apply operation, not an Init side effect. External governance repositories are deferred
until a separately pinned authority model is accepted.

### 4. Installation lifecycle

The first implementation accepts operator-supplied packages and automates verification, immutable
sibling staging, selection and rollback. No background download or activation is accepted. Downgrade
requires compatible schemas or a reviewed reversible migration; destructive down-migration fails closed.

### 5. Cleanup and retention

Classify installed authority, State, accepted/audit Evidence, advisory Evidence, temporary work, failed
diagnostics, caches and certification fixtures separately. Active leases, accepted/published verdicts,
authorization/release records and explicit pins prevent eviction. Successful work may be removed after
finalization. Cleanup is previewed, path-confined, restart-safe and receipted.

Provisional implementation defaults are five failed runs or 14 days, 20 advisory runs or 30 days,
5 GiB unpinned Evidence per project, 5 GiB global reclaimable cache and a below-1-GiB target for the
installed product plus ordinary State. The age/count rule keeps whichever set is smaller. Measurements
must confirm these numbers before they become a stable compatibility promise.

## Scope and non-authorization

This Plan changes maintained decisions and backlog state only. It does not implement a launcher,
initializer, self-contained build, update channel, migration, cleanup command, UI route, Target change,
network operation, release or remote activation. Each implementation requires an exact child Plan and
the applicable trust/activation boundary.

V4-TODO-007 closes only as a strategy evaluation. V4-TODO-010 remains open until lifecycle behavior is
implemented. V4-TODO-019 records cleanup/retention implementation and certification.

## Acceptance

1. V4-AD-036 records partial self-contained runtime ownership and rejects fully bundled runtimes.
2. V4-AD-037 records exact Init defaults/overrides, four-root preservation and `.guard/` governance.
3. V4-AD-038 records operator-supplied sibling lifecycle and bounded, protected storage retention.
4. V4-TODO-007, 010 and 019 distinguish accepted decisions from incomplete implementation.
5. The native Plan pair validates and declares the exact maintained documentation paths.
6. No product, contract, test, workflow, ruleset, package, consumer repository or remote state changes.

## Next formal Plans

After the remaining cross-mainline prerequisites are accepted, promote separate implementation Plans
for runtime publishing measurements, launcher/PackageRoot resolution, initializer/context schemas,
governance adoption, version lifecycle and cleanup/retention. Do not combine Target trust changes,
remote activation or release publication with those implementation Plans.

## Recovery

Revert this documentation-only decision record and restore V4-AD-018/V4-TODO-007/010/019 to their prior
states. No runtime or consumer data requires rollback because this Plan performs no implementation.
