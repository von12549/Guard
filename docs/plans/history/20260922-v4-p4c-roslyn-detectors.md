# V4 P4C — Roslyn syntax and semantic detectors

Status: local implementation checkpoint authorized on `codex/v4-development-base`

Parent roadmap: `docs/guards/v4/plans/01-v4-self-contained-guard-plugin.md`, V4-P4.4.

Predecessor: `20260922-v4-p4b-project-model`

## Goal

Implement package-owned Roslyn syntax and semantic inspection for the five source claims without
building or executing the target repository.

## Scope

- Declare the .NET SDK runtime/process prerequisite used to load its pinned Roslyn compiler API.
- Detect forbidden imports, disabled branches and declaration placement from syntax trees in Pre.
- Detect forbidden bound symbols and public member/payload types from semantic models in Post.
- Emit structured layered findings and non-zero coverage through the existing module result contract.
- Exercise clean, violating and missing-source controls directly against the module adapter.

## Validation

1. Formal Pre accepts this pair and its exact paths.
2. Syntax and semantic clean fixtures pass with non-zero coverage.
3. Each of the five source claims produces a deliberate blocking finding.
4. Missing source produces `prerequisite-missing` and no target `bin/obj` output.
5. P0-P4B and current V3 validation remain green.
6. No workflow, ruleset or remote state changes.

## Recovery

The recovery seed is P4B commit `ee36fa94`. Test data is confined to ignored artifact roots; source
recovery is a separately authorized revert or branch restore.
