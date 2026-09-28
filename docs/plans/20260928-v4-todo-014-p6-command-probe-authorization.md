# Authorize the P6 isolated-command regression control

Status: `AUTHORIZATION PR — P6 isolated-command regression control (V4-TODO-014 B2)`

This Plan adds one single-use record for Plan `20260928-v4-todo-014-p6-command-probe`. The record binds
`tests/p6/Test-V4TrustedBase.ps1` and `integrations/github/ci-contract.json` to exact base and head
SHA-256.

The consuming change adds an approved probe test to P6's synthetic base. The probe resolves `git`
inside the runner's isolated child environment, and both the Linux producer and Windows smoke run it.
Locally, P6 passes with the fixed runner and fails at the probe when `PATHEXT` is removed from the
allowlist.
