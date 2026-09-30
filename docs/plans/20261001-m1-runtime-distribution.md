# M1.1 — RID-specific self-contained distribution and measurements

Status: `IMPLEMENTATION PLAN — READY; not yet executed`

Formal Plan ID: `20261001-m1-runtime-distribution`.

Predecessor checkpoint: `20261001-m1-implementation-program`.

## Goal

Produce deterministic RID-specific self-contained Host and Web Companion publish trees, bind the RID and
deployment model into the distribution manifest, and emit a schema-valid measurement report covering
published bytes, archive bytes, file counts and cold publish/archive/start probes. PowerShell, Git, Node
and language toolchains remain declared external prerequisites.

## Exact implementation

- Add a strict distribution-measurement contract and bind it in the contracts manifest.
- Extend the distribution manifest/builder to require one supported RID and self-contained application
  hosts, while refusing framework-dependent inputs.
- Add an offline-friendly publisher that invokes deterministic `dotnet publish` for Host and Companion,
  then builds and measures the archive without downloading, releasing or installing it.
- Keep trimming, single-file, ReadyToRun and runtime bundling disabled unless separately measured and
  accepted. Supported first-pass RIDs are `win-x64`, `win-arm64`, `linux-x64` and `linux-arm64`.
- Add a new, non-approved-test-path M1 suite so existing base-held approved tests are not silently edited.

## Acceptance and tests

`tests/m1/Test-V4SelfContainedDistribution.ps1` proves the native current RID publishes and starts
without a machine `dotnet` command, rejects framework-dependent inputs/RID mismatch, emits valid
measurements and creates byte-identical archives from identical inputs. Run it with P0 contracts, P7
distribution/lifecycle, P8 supply-chain and package validation.

## Stop and resume

Stop before changing `core/runtime/Test-V4Package.ps1`, an existing approved test, CI/workflows, product
version or release bytes; those require their own authorization or Plan. Also stop if an SDK runtime pack
would require network access. Resume after using an already installed pack or revising this Plan to
record the explicit prerequisite; do not download implicitly.

## Recovery

Revert the contract, publisher, builder and project-property changes. Delete only external test outputs;
no installed version or release exists to unwind.
