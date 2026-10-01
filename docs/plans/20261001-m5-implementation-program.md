# M5 implementation program — local governance and immutable lifecycle

Status: `IMPLEMENTATION PROGRAM — READY 2026-10-01`

Formal Plan ID: `20261001-m5-implementation-program`.

Authority: `20261001-m5-plan-governance-decision`,
`20261001-m5-target-trust-authorization-decision`,
`20261001-m5-module-ecosystem-decision`, V4-AD-044 through V4-AD-047 and
V4-TODO-013/023/024/025.

## Goal and dependency order

Promote the accepted M5 decisions into three separately reviewable local checkpoints:

1. `20261001-m5-plan-governance-foundation` enforces versioned Plan-set resource limits and exclusive
   path ownership, then adds deterministic proposal scaffolding and exact-diff Plan-pair finalization.
2. `20261001-m5-target-trust-validation` adds consumer-neutral protected-set and authorization
   contracts plus base-held, single-use consuming validation and judge identity.
3. `20261001-m5-module-lifecycle-foundation` adds deterministic local inventory, inspection, graph,
   scaffold, validate, test, diff, pack, review preparation, compose handoff and verification operations.

The JSON Plans intentionally have no native dependency edges because implementation may be delivered as
one reviewed PR. The order above governs implementation and reverse-order recovery.

## Global boundaries

M5 does not change frozen v1 schemas, the stable CLI contract, the CI classifier, runner, workflow,
ruleset, approved-test inventory or release authority. Plan proposals and generated pairs remain
EvidenceRoot candidates until deliberately adopted. Target authorization validation does not apply a
Target change, create a pull request or activate remote enforcement. Module tooling does not download,
publish, remotely install, select an installation, edit a built-in Module or treat authenticity as
Evidence producer trust. Marketplace/signature work and CODEOWNERS remain deferred.

## Validation, stop and resume

Run focused positive and negative M5 validation, affected Plan/contract/package/composition/
documentation/stable-CLI regressions, the exact base-to-head root plan-set diff, and complete trusted
Linux/package/Windows validation. Stop on v1 reinterpretation, candidate-controlled base policy,
authorization reuse or self-authorization, TargetRoot mutation, non-deterministic archives, built-in
replacement, protected-component drift or remote mutation. Resume from the last committed checkpoint
after correcting the exact authority or revising this Plan set.

## Recovery

Revert Module lifecycle, target authorization and Plan governance changes in reverse order. Generated
StateRoot/EvidenceRoot candidates and test artifacts are disposable and grant no Target, installation,
CI, release or remote authority.

