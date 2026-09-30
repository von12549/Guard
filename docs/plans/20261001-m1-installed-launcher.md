# M1.2 — installed launcher and PackageRoot resolution

Status: `IMPLEMENTATION CHECKPOINT — IMPLEMENTED AND LOCALLY VALIDATED 2026-10-01`

Formal Plan ID: `20261001-m1-installed-launcher`.

Predecessor checkpoint: `20261001-m1-runtime-distribution`.

## Goal

Ship stable root-level installed launchers that derive their immutable distribution and PackageRoot from
their own verified location, select the RID-native Host/Companion executable and preserve explicit
four-root Host arguments. Callers no longer supply PackageRoot for an ordinary installed invocation.

## Exact implementation

Add source launcher templates, place them at the archive root through the deterministic builder, and
tighten the installed invocation scripts so an optional diagnostic override must equal the canonical
derived PackageRoot. Validate manifest/receipt layout before execution and keep prerequisite checks tied
to the selected Profile. A self-contained package removes only the Host-owned `dotnet` prerequisite;
Module-declared `dotnet` requirements remain enforced. The Companion process boundary accepts either the
legacy Host DLL through the current dotnet executable or the exact installed native Host apphost.
For composed installations, the receipted Companion entry point first verifies the composition/base
receipt and then binds layout resolution to the exact PackageRoot hash returned by that proof. Ordinary
installed launchers remain bound to the root base distribution manifest and expose no receipt bypass;
only the verified receipt path may resolve a composed installation's provenance copy of that manifest.

## Acceptance and tests

`core/distribution/validation/Test-V4InstalledLauncher.ps1` covers relocation, hostile working directory, missing/tampered
layout, override mismatch, argument preservation and both Host/Companion launchers. Re-run P7 distribution
and lifecycle plus P9 offline Companion tests.

## Stop and resume

Stop on any request to search PATH, registry, current directory or arbitrary sibling directories for
authority, or to mutate environment/Target state. Resume only with a canonical receipted layout and a
revised exact Plan if another file is required.

## Recovery

Revert launcher/builder changes; existing explicit script entry points remain available.
