# P6 isolated-command regression control

Status: `TRUST-CHANGE PR — P6 isolated-command regression control (V4-TODO-014 B2)`

This PR consumes the base-held record
`docs/plans/authorizations/20260928-v4-todo-014-p6-command-probe-record.json` by deleting it. It changes
exactly the two authorized paths at their authorized head hashes:

- `tests/p6/Test-V4TrustedBase.ps1`: P6's synthetic base gains an approved probe test that resolves `git`
  inside the runner's isolated child environment, and the Linux producer and Windows smoke assertions
  require the probe to have run.
- `integrations/github/ci-contract.json`: rebinds only the P6 hash.
