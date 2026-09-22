# V4 v1 candidate certification

V4 P8 certifies a local candidate; it does not publish a release or activate repository controls.

The release candidate version is `1.0.0`. V1 declares and certifies `linux-x64` and `win-x64` only;
macOS support is not declared.

The certification boundary requires:

- a native Linux complete report and native Windows full report bound to the same clean commit;
- the clean synthetic Bootstrap, Analysis, Pre, Post and accepted factory-reset lifecycle;
- exact package, archive, dependency-lock and offline-source validation;
- the hash-bound compatibility baseline at `core/certification/compatibility-baseline.json`;
- no `ifx_profile`, active V4 workflow, IFX cutover or V3/LayerGuard runtime dependency; and
- a generated recovery artifact bound to the reviewed P7 source checkpoint.

`Invoke-V4PlatformCertification.ps1` refuses an OS mismatch and runs the exact hash-approved suite,
including the P9 Web Companion query, workspace, evidence/Plan and offline distribution checks.
The Windows full selection includes the Windows-only Trusted Base behavioral suite; Linux complete covers
all approved Linux tests. Tests not selected for a platform cannot silently count toward that platform's
coverage.

The P9.5 extension certifies that the offline archive includes a deterministic Companion whose UI
assets are embedded in its hash-bound assembly, that installed operation remains confined to the V4
root model, and that command-injection, path-escape, Markdown-XSS, hostile-parent and lifecycle
negatives pass on Linux and Windows. It does not revise the previously published V4 1.0.0 release or
authorize a new publication.
`Invoke-V4V1Certification.ps1` accepts only matching passing platform reports and the exact deterministic
archive. Its record fixes `releaseAuthorized`, `activeIfxCutover` and `ifxProfileIncluded` to `false`.

Publishing, tagging, workflow/ruleset activation and IFX adoption each require separate authorization.
