# M1.1 — RID-specific self-contained distribution and measurements

Status: `IMPLEMENTATION CHECKPOINT — IMPLEMENTED AND LOCALLY VALIDATED 2026-10-01`

Formal Plan ID: `20261001-m1-runtime-distribution`.

Predecessor checkpoint: `20261001-m1-implementation-program`.

## Goal

Produce deterministic RID-specific self-contained Host and Web Companion publish trees, bind the RID and
deployment model into the distribution manifest, and emit a schema-valid measurement report covering
published bytes, archive bytes, file counts and cold publish/archive/start probes. PowerShell, Git, Node
and language toolchains remain declared external prerequisites.

## Exact implementation

- Add strict runtime/measurement schemas below distribution authority. Generate an exact runtime manifest
  inside the clean staged PackageRoot so the unchanged v1 distribution manifest binds it through the
  package hash.
- Extend the distribution builder to require one supported RID and self-contained application hosts,
  while refusing framework-dependent inputs.
- Add an offline-friendly publisher that invokes deterministic `dotnet publish` for Host and Companion,
  then builds and measures the archive without downloading, releasing or installing it.
- Keep trimming, single-file, ReadyToRun and runtime bundling disabled unless separately measured and
  accepted. Supported first-pass RIDs are `win-x64`, `win-arm64`, `linux-x64` and `linux-arm64`.
- Add a distribution-local validation script outside the base-discovered `tests/**` approved set so
  existing base-held approved tests and `ci-contract.json` are not silently changed.

## Acceptance and tests

`core/distribution/validation/Test-V4SelfContainedDistribution.ps1` proves the native current RID publishes and starts
without a machine `dotnet` command, rejects framework-dependent inputs/RID mismatch, emits valid
measurements and creates byte-identical archives from identical inputs. Run it with P0 contracts, P7
distribution/lifecycle, P8 supply-chain and package validation.

## Stop and resume

Stop before changing `core/runtime/Test-V4Package.ps1`, an existing approved test, CI/workflows, product
version, the compatibility-baseline-protected v1 contract set or release bytes; those require their own
authorization or Plan. Also stop if an SDK runtime pack
would require network access. Resume after using an already installed pack or revising this Plan to
record the explicit prerequisite; do not download implicitly.

## Recovery

Revert the contract, publisher, builder and project-property changes. Delete only external test outputs;
no installed version or release exists to unwind.

Implementation note: the initial attempt to extend `distribution-manifest.schema.json` correctly failed
the protected compatibility baseline. This checkpoint therefore preserves that public schema byte-for-byte
and uses the package-hash-bound staged runtime manifest; a public contract-version change remains a
separate authorization/trust-change.
