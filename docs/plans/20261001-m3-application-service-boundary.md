# M3.1 — Typed application-service boundary

Status: `IMPLEMENTATION PLAN — IMPLEMENTED 2026-10-01`

Formal Plan ID: `20261001-m3-application-service-boundary`.

## Goal and acceptance

Add a strict application-service contract and Host operation that classifies every exposed action as a
query, local-mutable preview, local-mutable apply, Target trust-change candidate or remote-change
candidate. The first M3 implementation exposes only queries and deterministic previews. Results bind
operation ID, project identity, package/Target snapshots and exact payload hashes. Unknown fields,
operations and browser-selected roots or commands fail before any execution.

## Risks, boundaries and dependencies

Depends on V4-AD-040 and the existing Host project/profile/plan/prerequisite contracts. A generic
gateway could bypass root and capability safety, so the Host owns a closed allowlist and constructs all
arguments internally. This checkpoint adds no Target write, composition apply/selection, Git operation,
workflow/ruleset change, network access or remote action.

## Stop, resume and recovery

Stop if an operation needs arbitrary paths, commands, environment or a contract not yet implemented by
M1/M2/M4/M5. Resume only after narrowing the operation to typed existing authority or a separate
authorized dependency Plan. Recovery reverts the Host dispatcher and contracts; preview reads have no
state to roll back.

Implementation evidence: `application preview --operation <setup|protection|authorities|lifecycle>`
accepts only the six fixed roots/options, validates a hash-bound experimental contract catalog and
returns deterministic schema-valid Host documents. The focused test proves unknown operation, option
and command injection refusal plus unchanged PackageRoot and TargetRoot.

