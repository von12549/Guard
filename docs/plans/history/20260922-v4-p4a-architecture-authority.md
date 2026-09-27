# V4 P4A — Architecture Conformance authority package

Status: local implementation checkpoint authorized on `codex/v4-development-base`

Parent roadmap: `docs/guards/v4/plans/01-v4-self-contained-guard-plugin.md`, V4-P4.1 and
V4-P4.2.

Predecessor: `20260922-v4-p3b-stage-orchestration`

## Goal

Package the generic Architecture Conformance Stage Gate and freeze its claim/evidence matrix,
execution plan, fixtures and hashes before detector behavior is introduced.

## Scope

- Extend module manifests with package-validated authority-file bindings.
- Register the generic `architecture-conformance` module for Pre and Post with deny-by-default
  capabilities and pinned dependencies.
- Define the complete v1 architecture claim matrix across project-model, syntax, semantic and
  compiled-assembly evidence.
- Bind a one-to-one blocking rule execution plan and generic clean/violating/missing fixture catalog.
- Record development-only provenance to the frozen reference outside the generic module package.
- Keep the module unselected until P4B provides its first non-executing detector.

## Validation

1. Formal Pre accepts this pair and its exact paths.
2. Package validation rejects authority path, hash and registry drift.
3. Every matrix claim has one execution rule, valid evidence/detector allocation and all three fixture
   classes.
4. The module directory contains no IFX identifier or V3/V3_ifx runtime path.
5. Existing P0-P3 and current V3 validation remain green.
6. No workflow, ruleset or remote state changes.

## Recovery

The recovery seed is P3B commit `f60248c3`. The new module remains unselected; source recovery is a
separately authorized revert or branch restore.
