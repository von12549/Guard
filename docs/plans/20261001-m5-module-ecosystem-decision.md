# M5 Module lifecycle and ecosystem decisions

Status: `DECISION RECORD — ACCEPTED 2026-10-01; implementation not authorized by this Plan`

Formal Plan ID: `20261001-m5-module-ecosystem-decision`.

## Goal

Resolve D31–D32 by accepting an Agent-independent immutable local Module lifecycle and preserving clear
revisit gates for marketplace/signature and CODEOWNERS work.

## Accepted decisions

### 1. Local Module lifecycle

Guard will provide list/inspect/graph, scaffold, validate, test, diff, deterministic pack, review
preparation, compose and verify operations. Validation covers adapter/config/result schemas, hashes,
dependency locks, Stage/result placement, capabilities, prerequisites, timeouts and Target immutability.
Updating an extension creates a new bundle/composition; updating a built-in Module is a Guard product and
release change.

The UI starts with read-only inventory, provenance, hashes, compatibility, Stage/platform support,
capabilities, prerequisites, Profile usage and dependency graphs. A later schema-driven wizard may edit
metadata/configuration, show diffs, run fixtures and prepare a candidate. Adapter source remains an
IDE/repository concern, and UI/tools cannot create production acceptance.

### 2. Deferred ecosystem and repository review

Marketplace discovery/download, trust roots, signatures, rotation/revocation and remote installation
remain deferred until local lifecycle, compatibility and rollback are stable. Authentic extension bytes
do not prove trustworthy Evidence execution. CODEOWNERS/ruleset work remains conditional on a second
maintainer who can satisfy approval.

## Scope and non-authorization

This Plan records architecture and backlog state only. It installs, edits, packages, composes, publishes
or downloads no Module; changes no UI, marketplace, signature, CODEOWNERS, ruleset, release or remote
state.

## Acceptance

1. V4-AD-047 records the immutable local lifecycle and staged UI scope.
2. V4-TODO-025 tracks lifecycle implementation independently of marketplace work.
3. V4-TODO-009 remains deferred behind lifecycle/compatibility/rollback prerequisites.
4. V4-TODO-016 remains conditional on a second maintainer.
5. The native Plan pair validates and declares the exact maintained documentation paths.

## Recovery

Revert this documentation-only record, remove V4-AD-047/V4-TODO-025 and restore the previous
V4-TODO-009/016 wording. No Module, package, ruleset or remote state requires rollback.
