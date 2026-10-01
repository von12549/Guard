# M4.2 — Guard providers and explicit dependency execution

Status: `IMPLEMENTATION PLAN — PLANNED 2026-10-01`

Formal Plan ID: `20261001-m4-provider-dependency-execution`.

## Goal and acceptance

Add one Guard-owned Bootstrap readiness provider and one deterministic Analysis provider, register them
with least privilege, and supply a semantic example Profile. The Host validates result-kind placement.
Direct Bootstrap and Analysis execute only the requested Stage. Direct Pre/Post require eligible exact
provider Evidence and fail closed when it is missing, stale or mismatched. `--with-dependencies` visibly
reuses eligible local advisory provider Evidence or executes only missing/stale providers in Bootstrap,
Analysis and requested-gate order.

Every semantic gate retains non-vacuous coverage, and a provider outcome can never substitute for the
requested gate result. PackageRoot and TargetRoot remain immutable; providers have no network or
TargetRoot write capability.

## Risks, boundaries and dependencies

Depends on `20261001-m4-versioned-stage-contract`. A naive dependency runner could silently preserve a
stale provider or run a gate after provider failure. Identity therefore binds Package, Profile, Module,
configuration, target commit/workspace state, OS/runtime and freshness. Local dependency reuse remains
advisory and cannot satisfy a CI authority decision.

This checkpoint adds no arbitrary executable, cache, Target mutation, CI skip, workflow/ruleset change,
release action or remote operation.

## Stop, resume and recovery

Stop on out-of-order execution, stale/mismatched reuse, provider-to-gate promotion, missing failure
coverage or any root mutation. Resume after invalidating the dependency and re-running the exact provider.
Recovery removes the semantic Profile/providers and reverts the Host branch; v1 execution remains intact.
