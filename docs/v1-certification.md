# V4 v1 candidate certification

V4 P8 certifies a local candidate; it does not publish a release or activate repository controls.

The certification boundary requires:

- a native Linux complete report and native Windows full report bound to the same clean commit;
- the clean synthetic Bootstrap, Analysis, Pre, Post and accepted factory-reset lifecycle;
- exact package, archive, dependency-lock and offline-source validation;
- the hash-bound compatibility baseline at `core/certification/compatibility-baseline.json`;
- no `ifx_profile`, active V4 workflow, IFX cutover or V3/LayerGuard runtime dependency; and
- a generated recovery artifact bound to the reviewed P7 source checkpoint.

`Invoke-V4PlatformCertification.ps1` refuses an OS mismatch and runs the exact hash-approved suite.
`Invoke-V4V1Certification.ps1` accepts only matching passing platform reports and the exact deterministic
archive. Its record fixes `releaseAuthorized`, `activeIfxCutover` and `ifxProfileIncluded` to `false`.

Publishing, tagging, workflow/ruleset activation and IFX adoption each require separate authorization.
