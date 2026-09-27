# V4 Architecture Conformance provenance

Status: development comparison authority; not a runtime dependency

The V4 claim matrix was derived by classifying the frozen reference behaviors by evidence kind rather
than copying its engine. Development parity may read the following reference sources and tests:

- `docs/guards/V3/stages/post/gates/architecture/dotnet/src/LayerGuard/` for raw project-model,
  source and rule aggregation behavior;
- `docs/guards/V3/tests/Test-V3ArchUnit.ps1` for compiled dependency and implementation-location
  negative controls;
- `docs/guards/V3_ifx/tests/post/Test-IFXAssemblyGuard.ps1` for missing, zero-match and stale compiled
  evidence categories.

The generic V4 module contains no reference path, product identifier or imported source from those
locations. Comparison runs are development evidence only. The V4 package, module registry, Stage
runtime and final verdict remain independently executable.

## Claim groups

| Evidence owner | V4 claims |
| --- | --- |
| Project Model | project reference, package reference, target framework, graph completeness |
| Roslyn syntax | source import, disabled branch, declaration placement |
| Roslyn semantic | forbidden symbol, member/payload |
| ArchUnitNET | type dependency, implementation location, assembly placement |

Each claim is blocking, requires at least one match and owns clean, violating and missing-input
fixtures. Later P4 checkpoints must compare claim identity and evidence category, not byte-for-byte
messages or internal detector implementation.
