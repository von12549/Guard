# Authorize the build-location regression control (V4-TODO-018)

Status: `AUTHORIZATION PR — V4-TODO-018 G2`

Formal Plan ID: `20260928-v4-todo-018-deterministic-builds-authorization`.

Adds the single-use record `docs/plans/authorizations/20260928-v4-todo-018-deterministic-builds-record.json` for Plan `20260928-v4-todo-018-deterministic-builds`. The record binds the exact base and head
SHA-256 of the two protected paths that the fix changes: the P7 approved test (a second clone at
another location must build the same archive; it fails against the unfixed build) and the CI
contract (the P7 hash only). The product change itself (Host and Companion project files) is not a
protected path. The following trust-change PR consumes the record.
