# V4 P0A — trusted host and four-root spike

Status: implementation checkpoint authorized for local development on `codex/v4-development-base`

Parent roadmap: `docs/guards/v4/plans/01-v4-self-contained-guard-plugin.md`, V4-P0.1,
V4-P0.2, the spike portion of V4-P0.4, V4-P0.7 and V4-P0.8.

## Goal

Prove the smallest accepted V4 runtime boundary: a .NET CLI host resolves four explicit roots,
loads one hash-bound synthetic PowerShell adapter from `PackageRoot`, denies unsafe paths and
undeclared capabilities before execution, captures adapter output, and writes a schema-valid result
only to `EvidenceRoot`.

This checkpoint establishes the canonical repository spelling `docs/guards/v4/`. It is a spike, not
the complete P0 schema freeze or a production Stage implementation.

## Scope

- Add a package-local .NET 10 build baseline with no external package dependency.
- Add the `V4.Guards.Host` console project and a `spike run` command.
- Require explicit `PackageRoot`, `TargetRoot`, `StateRoot` and `EvidenceRoot` arguments.
- Canonicalize roots and reject missing roots, links/reparse points, authority overlap, target writes
  and adapter paths outside `PackageRoot`.
- Load a manifest-declared `synthetic-probe` PowerShell adapter, verify its SHA-256, validate its
  declared stages/capabilities and execute it with a sanitized, host-created JSON input.
- Keep the adapter read-only: it emits a JSON payload on stdout; only the host writes the normalized
  result to `EvidenceRoot`.
- Define spike module and result schemas plus stable preliminary exit categories.
- Prove equivalent normalized verdicts when the package is inside the repository and when an exact
  package copy runs outside the target.
- Record the seed commit and non-interference evidence without creating a workflow, ruleset, remote
  branch or required check.

## Explicit exclusions

- No Bootstrap, Analysis, Pre or Post production implementation.
- No profile catalog, `ifx_profile`, Architecture Conformance detector or Build Evidence Provider.
- No V4 workflow, GitHub ruleset, remote operation, activation or current V3/V3_ifx change.
- No target mutation and no package-local mutable default; the spike uses explicit isolated roots.

## CLI and result contract under test

```text
v4-guards spike run
  --package-root <path>
  --target-root <path>
  --state-root <path>
  --evidence-root <path>
  --module synthetic-probe
```

Preliminary exit categories are `0 success`, `10 invalid-input`, `11 unsafe-path`,
`12 integrity-failure`, `13 capability-denied` and `14 adapter-failure`. The result records the
module ID, stage, status, exit category, normalized findings, adapter hash and four canonical roots.
Root paths are evidence, not inputs to the verdict comparison.

## Validation

1. Current V3 Formal Pre accepts this pair and the exact planned paths.
2. `Test-V4HostSpike.ps1` builds outside the source tree and passes positive in-place and separated
   package runs.
3. The test proves normalized verdict equivalence after excluding package/evidence location fields.
4. Negative cases fail closed for hash drift, a target-write capability, path escape, a reparse/link
   root and malformed adapter output.
5. The target fixture and package authority files have identical before/after hashes.
6. Current V3 Validate and `ifx-package-test` continue to pass.
7. No `.github/**`, `docs/guards/V3/**` or `docs/guards/V3_ifx/**` path changes.

## Recovery

Before this checkpoint is committed, record its parent seed SHA. Recovery is deletion of the P0A
paths from a new authorized change or branch reset to that seed before any V4 activation exists. The
spike writes only below caller-supplied isolated state/evidence roots and `artifacts/` build output.
