# V4 architecture decision set and roadmap — formal planning pair

This documentation-only checkpoint records the Plan 06 layout finding, preserves the cancelled Plan
08 in-place alternative and creates an isolated V4 planning area under `docs/guards/v4/plans/`.

The V4 documents define a new product boundary rather than a V3 directory migration: one
self-contained guard plugin, immutable core and profile catalog, mutable package-local state and
artifacts, independently runnable local stages, project profiles, extension modules, Linux-first CI
and a composable root plan-set contract. V4 v1 contains only default and synthetic profiles;
`ifx_profile`, Web UI, V3/V3_ifx cutover, fully bundled runtimes and remote activation are explicitly
deferred in the V4 TODO.

The accepted runtime boundary uses a small .NET CLI as the trusted host with controlled PowerShell and
.NET module adapters. `PackageRoot`, `TargetRoot`, `StateRoot` and `EvidenceRoot` are explicit;
profiles cannot declare arbitrary executables; target access is read-only by default; local execution
and base-owned CI execution share one CLI contract; and co-located incubation must remain equivalent
to running the package outside the target.

Architecture Conformance is a composite V4 module rather than a monolithic LayerGuard rewrite.
Project Model inspection owns declared graph facts, Roslyn owns source and semantic facts, ArchUnitNET
owns compiled dependency and implementation facts, and the V4 host owns policy, baseline, coverage and
the aggregate verdict. V4 v1 proves generic synthetic parity; IFX parity, production cutover and final
LayerGuard freeze/removal remain deferred and are required before Plan 06 §20 can close. The maintained
runtime and trust diagrams are in the [V4 runtime architecture](../v4/plans/02-runtime-architecture.md).

The intended implementation base is a future `codex/v4-development-base` branch created from
`codex/guards-principles-plan`. It does not yet exist. This checkpoint does not create branches,
workflows, rulesets, V4 runtime files, profiles, authorization records or remote state. Current V3 and
V3_ifx remain the active guard system.

The accepted genesis strategy is minimal V3 bootstrap followed by V4 autonomy. V3 validates only the
bootstrap Plan, exact additive diff, current-guard non-interference, isolation and recovery point. The
candidate V4 host cannot trust itself. After a separately accepted seed becomes
`codex/v4-development-base`, V4-only changes use base-owned V4 Plans, tests and `v4-required`; they do
not depend on the V3 runtime or IFX product suites. This record defines that boundary but does not
authorize creation of the seed branch or workflow.

## Validation

- Formal Pre accepts the exact documentation changed set.
- The Plan sidecar validates against the current canonical Plan schema.
- IFX Validate and Docs Check continue to pass with no current runtime change.
- The Git diff contains only Plan 06/08 record updates, this formal pair and V4 planning documents.
