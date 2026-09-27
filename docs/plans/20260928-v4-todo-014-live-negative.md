# V4-TODO-014 live negative control (B2.1)

Status: `LIVE NEGATIVE CONTROL — expected to fail v4-required; closed unmerged`

This is step B2.1 of Plan `20260928-v4-todo-014-trust-change-authorization`. The pull request edits the
approved test `tests/p0/Test-V4Contracts.ps1` under a `trust-change` root Plan, but no base-held
authorization record exists. The base-owned runner must reject it with "Approved test hash drift
without trust-change authorization".
