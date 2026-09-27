# V4 P9.2 — Schema-versioned read/query contracts

Status: implemented and locally certified on `codex/v4-development-base`; P9.2 implementation only.
V4-P9.3 through V4-P9.5, push, pull request, workflow/ruleset activation and every remote operation
remain separately planned and authorized.

Parent roadmap: `docs/guards/v4/plans/01-v4-self-contained-guard-plugin.md`, V4-P9.2.

Predecessor: `20260922-v4-p9a-web-companion-spike`

## Goal

Add strict, schema-versioned, Host-owned read/query projections for project binding, installed profiles,
runtime prerequisites, runs, evidence and Plan catalogs without allowing a future UI to read internal
files directly or reinterpret those projections as new authorities.

## Scope

- Add a separate experimental query command contract without changing the released stable CLI contract.
- Implement `query project`, `query profiles`, `query doctor`, `query runs`, `query evidence` and
  `query plans` in the V4 Host.
- Validate PackageRoot before every query and preserve the existing four-root/path/link boundaries.
- Validate state and Stage result authorities against registered schemas before projecting them.
- Return deterministic run/evidence catalogs using IDs and hashes, never file timestamps.
- Classify valid V4-native Plans through the existing V4 Plan runtime; expose current V3-formal pairs
  only as labelled, read-only historical compatibility views.
- Keep all query commands read-only: no binding, transaction recovery, state/evidence output, Plan
  composition or temporary data beneath V4 roots.
- Certify the same query suite on Windows and Linux.

## Validation

1. Every query output satisfies its registered strict draft-07 schema and the query command catalog
   satisfies its own registered contract.
2. Project and profile projections are derived by the Host from validated package/state authorities.
3. Doctor preserves the structured prerequisite report, including missing/incompatible outcomes,
   without converting them into a guard verdict.
4. Run and evidence queries reject schema drift, wrong project/run identity, links and path escape.
5. Plan catalog output distinguishes `v4-native` from `v3-historical`; historical presentation never
   acquires V4-native validity.
6. PackageRoot, TargetRoot, StateRoot and EvidenceRoot hashes remain unchanged by all queries.
7. Windows and pinned network-disabled Linux suites pass; the released stable CLI behavior remains
   unchanged.
8. No UI write flow, Stage Runner, authority edit, Target mutation, reset, Git operation, remote access
   or remote activation is introduced.

## Observed result

- Native Windows (`Microsoft Windows 10.0.26200`) passed the P9.2 suite with a zero-warning,
  zero-error Host build.
- The same suite passed in the pinned, network-disabled Linux container
  (`Ubuntu 22.04.5 LTS`).
- All six positive projections satisfied their registered schemas; root byte-invariance, overlap,
  traversal and tampered Stage-result negatives passed.
- V4 package validation passed with package hash
  `f73fd85577f7fd9c985f72f691e3714fd08f5330a3fbe5d35270ddc98ead9cfb`.
- P0 regression passed with 31 schemas, 11 unchanged stable CLI entries, six experimental read queries
  and 33 bound contracts. Stable CLI 1.0.0 and deterministic documentation regressions passed.
- V3 Validate and the declared isolated `ifx-package-test` passed.
- Formal Pre accepted the Plan pair, and the 21 actual changed paths equal the 21 declared
  `plannedPaths`.

## Recovery

Revert the P9.2 commit. P9.1 and V4 Guards 1.0.0 remain functional because the query command catalog is
additive and separate from the released stable CLI contract.
