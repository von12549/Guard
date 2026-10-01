# M4 implementation program — versioned Stage semantics and advisory Evidence

Status: `IMPLEMENTATION PROGRAM — PLANNED 2026-10-01`

Formal Plan ID: `20261001-m4-implementation-program`.

Authority: `20261001-m4-stage-and-evidence-decision`, V4-AD-041 through V4-AD-043 and
V4-TODO-022.

## Goal and dependency order

Promote the accepted M4 decisions into three separately reviewable local checkpoints:

1. `20261001-m4-versioned-stage-contract` extends the existing Profile, Module and Stage-result
   contracts with an explicit semantic version while preserving v1 documents as visible
   `legacy/untyped` compatibility input.
2. `20261001-m4-provider-dependency-execution` adds Guard-owned readiness and deterministic analysis
   providers, validates result-kind placement, and makes Pre/Post dependency execution or refusal
   explicit.
3. `20261001-m4-timing-evidence-diagnostics` records Stage and Module timing plus content, freshness,
   producer and reuse diagnostics while keeping all developer-machine Evidence advisory.

The JSON Plans intentionally have no native dependency edges because implementation may be delivered as
one reviewed PR. The order above governs implementation and reverse-order recovery.

## Global boundaries

M4 does not reinterpret v1 Profiles or Modules, silently execute dependencies, turn provider success
into a gate pass, grant network or TargetRoot write capability, or treat matching local content as a
trusted producer. This program does not modify protected CI, the classifier, runner, workflow, ruleset,
approved-test inventory or release authority. It does not change Windows cadence, skip a required gate,
publish a package, activate a remote system or merge a pull request.

Cross-run authoritative trusted-CI reuse and CI selection remain blocked on provenance policy and the
V4-AD-042 measurement baseline of at least 20 comparable ordinary pull requests. Managed local
attestation remains blocked on a separately accepted threat model.

## Validation, stop and resume

Run focused M4 positive and negative validation, affected contract/package/Stage/query/distribution and
compatibility regressions, the exact base-to-head Plan diff, and the complete trusted Linux/package/
Windows suites. Stop on legacy reinterpretation, provider-to-gate promotion, stale or mismatched
dependency acceptance, missing advisory labelling, Target/Package mutation, protected-component drift or
an optimization that can suppress required coverage. Resume from the last committed checkpoint only
after correcting the exact authority or revising the Plan.

## Recovery

Revert diagnostics, provider execution and contract changes in reverse order. Evidence under test-owned
EvidenceRoot is disposable and never grants CI, Target or remote authority. No remote or protected state
requires rollback.
