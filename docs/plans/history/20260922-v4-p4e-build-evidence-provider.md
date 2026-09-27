# V4 P4E — isolated Build Evidence Provider

Status: local implementation checkpoint authorized on `codex/v4-development-base`

Parent roadmap: `docs/guards/v4/plans/01-v4-self-contained-guard-plugin.md`, V4-P4.6.

Predecessor: `20260922-v4-p4d-archunitnet-adapter`

## Goal

Produce fresh, explicit and hash-bound compiled evidence under V4-owned mutable roots without writing
build output into the target or package.

## Scope

- Add a separately registered `build-evidence-provider` Post module with explicit process, read and
  write capabilities.
- Snapshot the target into a run-owned `StateRoot` location, reject links, and build only explicitly
  configured projects with a sanitized environment and network-free NuGet configuration.
- Emit a project-owned manifest that binds run/project identity, target snapshot, source project,
  configuration, target framework, assembly identity, StateRoot path and SHA-256.
- Pass StateRoot, EvidenceRoot, project ID and run ID through the Stage adapter input.
- Require the Architecture Conformance adapter to validate manifest freshness and all declared
  bindings before ArchUnitNET consumes assemblies.

Synthetic profile selection and complete composite aggregation remain in the following P4 checkpoint.

## Validation

1. Formal Pre accepts this pair and its exact paths.
2. An isolated synthetic build produces schema-valid, fresh evidence beneath StateRoot/EvidenceRoot.
3. Architecture Conformance consumes that evidence and preserves non-zero compiled coverage.
4. Stale run identity, target drift, assembly drift, missing project and link traversal fail closed.
5. TargetRoot and PackageRoot remain byte-identical and contain no generated `bin/obj`.
6. The P1 package regression fixture recognizes the newly registered provider and still proves the
   empty-package and undisclosed-module cases.
7. P0-P4D and current V3 validation remain green; no workflow, ruleset or remote state changes.

## Recovery

The recovery seed is P4D commit `15b50ce4`. Build/state/evidence data is confined to ignored mutable
roots; source recovery is a separately authorized revert or branch restore.
