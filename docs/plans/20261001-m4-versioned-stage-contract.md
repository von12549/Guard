# M4.1 — Versioned Stage, Module and result contracts

Status: `IMPLEMENTATION PLAN — PLANNED 2026-10-01`

Formal Plan ID: `20261001-m4-versioned-stage-contract`.

## Goal and acceptance

Extend the existing strict Profile, Module and Stage-result schemas with semantic contract version 2.
New Profiles declare the semantic version and dependency freshness policy; new Modules declare exactly
one result kind; semantic Stage results expose role, outcome, execution provenance and timing. Existing
format-version-1 Profiles, Modules and Stage results remain accepted and are reported as
`legacy/untyped`, never inferred or silently upgraded.

The four wire Stage names and the stable `stage run` syntax remain unchanged. Result kinds are exactly
`readiness-provider`, `analysis-provider`, `pre-gate` and `post-gate`; provider success never represents
a policy-gate verdict.

## Risks, boundaries and dependencies

Depends on V4-AD-041 and the frozen v1 compatibility baseline. Extending a schema could accidentally
invalidate released v1 authorities, so positive and negative focused fixtures must prove both versions.
This checkpoint adds no Module execution, Evidence reuse, Target write, network access, CI selection,
workflow change or remote authority.

## Stop, resume and recovery

Stop if a v1 document changes meaning or a semantic Module can be placed in a Stage inconsistent with
its result kind. Resume only with explicit conditional schema rules and unchanged v1 fixtures. Recovery
reverts the additive semantic fields and catalog hashes; no runtime or remote rollback is required.
