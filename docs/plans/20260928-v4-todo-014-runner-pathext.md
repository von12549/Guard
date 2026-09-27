# Trusted-base runner PATHEXT fix

Status: `TRUST-CHANGE PR — runner PATHEXT fix (V4-TODO-014 B2, fix step 2)`

This PR consumes the base-held record
`docs/plans/authorizations/20260928-v4-todo-014-runner-pathext-record.json` by deleting it in the same
diff. It changes `integrations/github/Invoke-V4TrustedBase.ps1` at exactly the authorized head hash: the
`Invoke-Isolated` environment allowlist gains `'PATHEXT'`, matching
`core/certification/Invoke-V4PlatformCertification.ps1`.

Expected CI: `v4-contract` (`authorized`), `v4-linux` and `v4-package` pass. `v4-windows`, and therefore
`v4-required`, still fails, because the unfixed base runner judges this PR. With operator confirmation,
it is accepted once more under O16, the Plan §9 broken-mechanism clause, on exact-head certification.
Locally, all 15 windowsSmoke tests pass in the fixed isolated environment.
