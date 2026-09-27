# V4-TODO-014 live authorization record (B2.2)

Status: `LIVE ACCEPTANCE — authorization PR (B2.2)`

This is step B2.2 of Plan `20260928-v4-todo-014-trust-change-authorization`. It adds exactly one
single-use record, `docs/plans/authorizations/20260928-v4-todo-014-live-trust-record.json`, for Plan
`20260928-v4-todo-014-live-trust-change`. The record binds two protected paths to exact base and head
SHA-256:

- `tests/p0/Test-V4Contracts.ps1`: P0 additionally checks that the trust policy's authorization schema
  is a bound contract.
- `integrations/github/ci-contract.json`: rebinds only the P0 hash.

Human review accepts the record, and a candidate host verdict cannot. The consuming trust-change PR
must delete the record.
