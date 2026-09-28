# Authorize the trusted-runner long-path fix (V4-TODO-017)

Status: `AUTHORIZATION PR — V4-TODO-017 G1`

Formal Plan ID: `20260928-v4-todo-017-runner-longpaths-authorization`.

Adds the single-use record `docs/plans/authorizations/20260928-v4-todo-017-runner-longpaths-record.json` for Plan `20260928-v4-todo-017-runner-longpaths`. The record binds the exact base and head
SHA-256 of the three protected paths the fix changes: the trusted runner (every Git command gets
`core.longpaths=true`; the isolated clone persists it), the P6 approved test (a long-path regression
case that fails against the unfixed runner) and the CI contract (the P6 hash only). The following
trust-change PR consumes the record.
