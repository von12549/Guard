# Plan governance and pair authoring

This M5 local foundation is available on `main` after the 1.1.6 release and is not shipped in the 1.1.6
asset. Candidate output and local verification do not establish Target adoption or remote authority.

M5 adds a local deterministic governance layer without changing the frozen v1 Plan or Plan-set schemas.
`core/governance/governance-contract.json` hash-binds the authoring schema, target-trust schemas,
Module-lifecycle result schema and versioned Plan limits.

## Bounded composition

`plan compose` now rejects more than 16 members, a Plan larger than 1 MiB, aggregate Plan input larger
than 8 MiB, dependency depth greater than 8, more than 4,096 unique planned paths, more than 256 unique
validation commands, more than 256 combined risk/decision entries or a composition that exceeds the
30-second certification ceiling. Shared path ownership, cycles, missing dependencies, duplicate
identities, incomplete unions and forbidden boundary combinations continue to fail closed.

The limits are product policy, not machine-tuned heuristics. The Host verifies the hash-bound governance
catalog before composition, scaffolding or finalization.

## Proposal and finalization

Create a non-authoritative proposal below EvidenceRoot:

```text
v4-guards plan scaffold --package-root <path> --evidence-root <path> \
  --id <YYYYMMDD-id> --output <relative-path> [--title <text>] [--goal <text>]
```

Complete the structured proposal and clear `unresolvedQuestions`. Finalization requires the exact
proposal SHA-256, safe base/head Git refs and source/generator/policy identities:

```text
v4-guards plan finalize --package-root <path> --target-root <repository> \
  --evidence-root <path> --input <proposal-relative-path> --output-directory <relative-path> \
  --base-ref <ref> --head-ref <ref> --confirm-proposal-sha256 <sha256> \
  --source-id <id> --generator-id <id> --policy-id <id>
```

The Host computes the base/head diff itself and refuses any mismatch; it never adds a path to obtain a
pass. It writes deterministic `<id>.plan.json` and `<id>.md` candidates below EvidenceRoot. The JSON is
the executable v1 contract and Markdown is its matching review projection. Both still require deliberate
repository adoption and review; generated output, imported prose and Agent/model text are not authority.

Finalization commits a new output directory containing the JSON, injection-safe Markdown and a
`<id>.pair-receipt.json` that binds both hashes plus proposal/base/head/source/generator/policy
provenance. Existing finalized directories are never overwritten. A failed staging write leaves no
finalized half-pair; retry uses a new directory or an operator-reviewed cleanup of an invalid staging
artifact. `plan verify-pair` checks both content hashes, Plan identity and the expected provenance, so
one-sided tampering and stale-pair replay fail closed. Markdown text is rendered as escaped single-line
content; embedded newlines, headings, lists, backticks and control characters cannot create a second
review status or section.

The local Web Companion is unchanged in M5. A future Plan may project this typed lifecycle, but the UI
cannot confirm its own trust boundary or write Plan authority.
