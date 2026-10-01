# M5 Plan governance foundation

Status: `IMPLEMENTATION PLAN — IMPLEMENTED 2026-10-01`

Formal Plan ID: `20261001-m5-plan-governance-foundation`.

## Goal

Enforce V4-AD-045's versioned resource limits in the existing Plan runtime and implement V4-AD-046's
deterministic proposal scaffold and exact-diff Plan-pair finalization without changing the protected v1
Plan schemas or stable CLI surface.

## Implementation

- Bind limits and new authoring schemas through an isolated governance catalog.
- Reject more than 16 members, a Plan over 1 MiB, aggregate input over 8 MiB, dependency depth over 8,
  more than 4,096 owned paths, 256 validation commands, 256 combined risks/decisions or composition
  exceeding the 30-second certification ceiling.
- Scaffold a non-authoritative structured proposal below EvidenceRoot.
- Finalize only an operator-confirmed proposal whose planned paths exactly equal the base/head diff;
  render deterministic executable JSON and matching Markdown below EvidenceRoot.
- Preserve exclusive ownership, cycle, dependency, identity, union and forbidden-boundary checks.

## Boundaries and recovery

No generated output is written into TargetRoot or becomes authority automatically. No model or imported
text can approve a pair. Revert the isolated contracts/catalog and Plan runtime changes; discard
EvidenceRoot candidates.
