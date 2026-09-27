# V4-TODO-014 live trust change (B2.3)

Status: `LIVE ACCEPTANCE — trust-change PR (B2.3)`

This is step B2.3 of Plan `20260928-v4-todo-014-trust-change-authorization`. It consumes the base-held
record `docs/plans/authorizations/20260928-v4-todo-014-live-trust-record.json`, which merged in the
authorization PR, by deleting it in this diff.

It changes exactly the two authorized protected paths, at the authorized head hashes:

- `tests/p0/Test-V4Contracts.ps1`: P0 also checks that the trust policy's authorization schema is a
  bound contract.
- `integrations/github/ci-contract.json`: rebinds only the P0 hash.

Expected verdict: `v4-required` passes, and every runner result carries `trustChange.status =
authorized` and `verdictComponents`.
