# M2 PR root member — Profile authority contracts, Host and tests

Status: `PR ROOT MEMBER — IMPLEMENTED 2026-10-01`

Formal Plan ID: `20261001-m2-pr-implementation-root`.

Dependency: `20261001-m2-pr-documentation-root`.

## Goal

Own the exact contract, Host and test paths implementing M2 inert discovery, non-authoritative drafts,
review validation and promotion candidates.

## Scope and boundary

Detailed behavior remains in the four child Plans. This root includes strict experimental contracts,
registered hashes, Host routing/runtime, the contract-set assertion and the focused M2 matrix. It does
not write TargetRoot, run or select the sibling composer, change stable CLI authority, activate CI,
publish or merge.

## Validation and recovery

Run focused M2 tests plus affected P0/P1/P5/P7/P8/P10 and required regressions. Revert this member as one
local product capability; generated StateRoot/candidate artifacts are disposable and non-authoritative.
