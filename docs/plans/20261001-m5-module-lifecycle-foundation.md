# M5 immutable local Module lifecycle foundation

Status: `IMPLEMENTATION PLAN — READY 2026-10-01`

Formal Plan ID: `20261001-m5-module-lifecycle-foundation`.

## Goal

Implement V4-AD-047's Agent-independent local Module lifecycle around immutable built-in authority and
extension candidates while reusing the existing reviewed composition and verification authorities.

## Implementation

- Provide deterministic inventory, inspect and dependency graph views for installed Modules.
- Scaffold metadata below StateRoot without generating adapter source.
- Validate candidate schemas, identity, hashes, lock, Stage/result placement, capabilities,
  prerequisites, timeouts and Target immutability.
- Run declared local fixtures, produce a content diff, deterministic pack and review candidate below
  EvidenceRoot, and expose exact handoffs to existing compose and verify authorities.
- Refuse built-in replacement; every extension update produces a new immutable bundle identity.

## Boundaries and recovery

No operation downloads, publishes, remotely installs, selects a composition or edits a built-in
Module. Authentic bytes do not establish Evidence producer trust. Revert the lifecycle script/schema
and discard StateRoot/EvidenceRoot candidates.

