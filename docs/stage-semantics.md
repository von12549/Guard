# Versioned Stage semantics and local Evidence diagnostics

M4 adds an experimental semantic-contract version 2 beside the frozen v1 Stage authorities. The stable
four wire names and `stage run` syntax do not change. Profiles under `profiles/catalog/` remain v1 and
are reported and executed as legacy/untyped; the opt-in example authority is
`core/stage/profiles/semantic_profile.json`.

## Roles and outcomes

| Stage | Role | Result kind | Success | Failure |
| --- | --- | --- | --- | --- |
| Bootstrap | readiness | `readiness-provider` | `ready` | `not-ready` |
| Analysis | deterministic read-only analysis | `analysis-provider` | `complete` | `incomplete` |
| Pre | pre-build policy gate | `pre-gate` | `pass` | `fail` |
| Post | evaluated/post-build policy gate | `post-gate` | `pass` | `fail` |

The first two providers are Host-owned, have no process, network or write capability, and cannot emit a
gate verdict. The example Pre/Post gates are Host-owned dependency gates with non-vacuous coverage;
they prove the dependency mechanics but do not claim target-specific policy coverage.

## Direct and dependency execution

Direct Bootstrap or Analysis executes only the requested provider. Direct Pre/Post does not run another
Stage: it requires fresh exact provider Evidence and fails with `prerequisite-missing` when Bootstrap or
Analysis Evidence is missing, stale, content-mismatched or tampered.

`--with-dependencies` checks Bootstrap then Analysis. It visibly reuses eligible local provider Evidence
or executes only the missing/stale/mismatched provider, then executes the requested gate. The result's
`executedStages`, `stageExecutions` and dependency decisions preserve that order and source.

Example:

```text
v4-guards stage run --stage pre --package-root <path> --target-root <path> --state-root <path> --evidence-root <path> --profile semantic_profile --with-dependencies
```

## Identity, timing and trust

Reuse identity binds the target commit, normalized workspace tree, dirty/untracked state, package,
semantic Profile, provider catalog, platform, runtime and semantic version. Provider Evidence hashes are
rechecked before reuse. Timing is recorded separately for the total operation, each Stage and each
provider/gate, and never enters content identity.

Every current v2 result states:

```json
{
  "producerClass": "local-advisory",
  "authoritative": false
}
```

Matching content does not create trusted producer identity. Local Evidence can support local advisory
execution and diagnostics only; it cannot satisfy a required CI gate.

## Local inspection

The experimental read-only inspector validates a stored v2 result against its isolated schema and exact
Evidence path, then returns it unchanged:

```text
v4-guards stage inspect --package-root <path> --evidence-root <path> --project <32-hex-id> --run <32-hex-id>
```

The inspector accepts no Target path, command, environment, trust decision or mutation request.

## Deliberately unavailable

This implementation does not change the stable v1 CLI contract, CI classifier, trusted-base runner,
workflow, ruleset, approved tests, Windows cadence or required coverage. It does not implement a remote
cache, cross-run trusted-CI authority, managed local attestation or a gate-skipping optimization. Those
steps require the V4-AD-042 measurement baseline, explicit provenance/revocation policy and—where a
protected component changes—the existing single-use trust-change authorization flow.
