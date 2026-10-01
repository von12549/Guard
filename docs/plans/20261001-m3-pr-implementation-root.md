# M3 PR root member — Application contracts, Host, Companion and tests

Status: `PR ROOT MEMBER — IMPLEMENTED 2026-10-01`

Formal Plan ID: `20261001-m3-pr-implementation-root`.

Dependency: `20261001-m3-pr-documentation-root`.

## Goal

Own the exact contract, Host, Companion and test paths implementing the M3 application-service boundary,
setup and protection previews, authority handoffs and lifecycle preview.

## Scope and boundary

Detailed behavior remains in the four child Plans. This root includes strict hash-catalogued experimental
contracts, typed Host routing, loopback session/origin/CSRF/size/staleness/cancellation controls, preview
receipts and the focused M3 matrix. It does not accept arbitrary paths or commands, write TargetRoot,
select a composition, change stable CLI authority, activate CI or a remote system, publish or merge.

## Validation and recovery

Run focused M3 tests plus affected P0/P1/P7/P8/P9/P10 and trusted regressions. Revert this member as one
local product capability; generated previews and non-applied receipts are disposable and non-authoritative.
