# M4.1 — Versioned Stage, Module and result contracts

Status: `IMPLEMENTATION PLAN — IMPLEMENTED 2026-10-01`

Formal Plan ID: `20261001-m4-versioned-stage-contract`.

## Goal and acceptance

Add isolated strict Profile, built-in provider and Stage-result schemas for semantic contract version 2.
New Profiles declare the semantic version and dependency freshness policy; new providers declare exactly
one result kind; semantic Stage results expose role, outcome, execution provenance and timing. Existing
format-version-1 Profiles, Modules and Stage results remain accepted and are reported as
`legacy/untyped`, never inferred or silently upgraded.

The four wire Stage names and the stable `stage run` syntax remain unchanged. Result kinds are exactly
`readiness-provider`, `analysis-provider`, `pre-gate` and `post-gate`; provider success never represents
a policy-gate verdict.

## Risks, boundaries and dependencies

Depends on V4-AD-041 and the frozen v1 compatibility baseline. Mixing authorities could accidentally
invalidate released v1 contracts, so positive and negative focused fixtures must prove their isolation.
This checkpoint adds no Module execution, Evidence reuse, Target write, network access, CI selection,
workflow change or remote authority.

## Stop, resume and recovery

Stop if a v1 document changes meaning or a semantic provider can be placed in a Stage inconsistent with
its result kind. Resume only with isolated schema rules and unchanged v1 fixtures. Recovery
reverts the additive semantic fields and catalog hashes; no runtime or remote rollback is required.

Implementation evidence: `core/stage/` contains a strict hash-bound v2 catalog, Profile, provider and
result schemas. The frozen `core/contracts/` v1 authorities remain byte-identical and continue through
the legacy runtime path.
