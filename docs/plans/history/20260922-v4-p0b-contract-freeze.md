# V4 P0B — contract and CLI freeze

Status: implementation checkpoint authorized for local development on `codex/v4-development-base`

Parent roadmap: `docs/guards/v4/plans/01-v4-self-contained-guard-plugin.md`, V4-P0.3,
V4-P0.4, V4-P0.5 and V4-P0.8.

Predecessor: `20260922-v4-p0a-host-four-root-spike`

## Goal

Freeze the V4 v1 configuration and result boundary before production Stage or state behavior is
implemented. JSON Schema is authoritative; CLI command identities and exit categories are
machine-readable; a hash manifest binds the complete contract set.

## Scope

- Define strict draft-07 schemas for plugin, profile, module, Stage result, state, Plan, plan-set,
  Architecture Conformance capability matrix, rule execution plan and genesis acceptance record.
- Define a schema-valid CLI contract covering version, contract validation, independent Stage run,
  project/factory reset Preview/Apply, Plan validation and plan-set composition.
- Preserve `PackageRoot`, `TargetRoot`, `StateRoot` and `EvidenceRoot` as explicit Stage inputs.
- Prevent profiles from declaring arbitrary commands, executables, scripts or environment mutation.
- Restrict module writes to `StateRoot` and `EvidenceRoot`; module IDs resolve adapters from the
  trusted registry rather than profile data.
- Require plan-set member hashes, explicit order/dependencies and a derived union that cannot omit
  member paths, risks, decisions or validation commands.
- Require every blocking architecture claim to name evidence kinds, detectors, clean/violating/
  missing-input fixtures and a positive minimum-match count.
- Bind all frozen contracts in `contracts-manifest.json` by SHA-256.
- Add positive and deliberate negative schema tests using PowerShell's local JSON Schema validator.

## Stable CLI boundary

The public executable identity is `v4-guards`. Stable command families are:

```text
v4-guards version
v4-guards contract validate --schema <id> --document <path>
v4-guards stage run --stage <bootstrap|analysis|pre|post> --package-root ... --target-root ... --state-root ... --evidence-root ... --profile <id>
v4-guards reset <project|factory> --mode <preview|apply> ...
v4-guards plan validate --plan <path>
v4-guards plan compose --plan <path>... --output <path>
```

The P0A `spike run` command remains experimental and is not part of the stable v1 CLI.

Stable exit categories are: `success=0`, `invalid-input=10`, `unsafe-path=11`,
`integrity-failure=12`, `capability-denied=13`, `adapter-failure=14`,
`prerequisite-missing=15`, `findings-blocking=16`, `state-conflict=17`,
`reset-refused=18` and `internal-error=19`.

## Validation

1. Formal Pre accepts this pair and its exact paths.
2. Every schema and authority document parses as JSON and rejects unknown top-level fields.
3. Positive fixtures validate for every schema.
4. Negative fixtures reject raw profile executables, TargetRoot writes, unknown exit categories,
   incomplete Plan unions, zero-match blocking claims, missing fixture classes and self-accepted
   genesis records.
5. `contracts-manifest.json` lists every frozen contract exactly once and every SHA-256 matches.
6. Current V3 Validate and `ifx-package-test` remain green.
7. No current workflow, ruleset, V3/V3_ifx authority or remote state changes.

## Recovery

The recovery seed is P0A commit `eba8178211e5bfc995adac53d05d0d1d7dc5c4dd`. Until V4 activation,
recovery is a new authorized revert of this checkpoint or branch restoration to that seed. No schema
migration is needed because no production V4 state exists yet.
