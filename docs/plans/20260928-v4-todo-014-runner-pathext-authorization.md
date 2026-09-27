# Authorize the trusted-base runner PATHEXT fix

Status: `AUTHORIZATION PR — runner PATHEXT fix (V4-TODO-014 B2, fix step 1)`

The first live Windows smoke run (PR #10, run 36344152342) failed `tests/p1/Test-V4Package.ps1` with
"The term 'git' is not recognized". The trusted-base runner's `Invoke-Isolated` clears the child
environment and restores an allowlist that omits `PATHEXT`, so Windows children cannot resolve bare
commands. `core/certification/Invoke-V4PlatformCertification.ps1` already includes `PATHEXT`, which is
why dispatch certification passed.

This Plan adds one single-use record,
`docs/plans/authorizations/20260928-v4-todo-014-runner-pathext-record.json`, for Plan
`20260928-v4-todo-014-runner-pathext`. The record binds only
`integrations/github/Invoke-V4TrustedBase.ps1` to its exact base and head SHA-256. The fix adds
`'PATHEXT'` to the allowlist and changes nothing else.
