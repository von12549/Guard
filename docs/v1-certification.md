# V4 1.x candidate certification

The V4 certification pipeline certifies a local candidate; it does not publish a release or activate
repository controls.

Version `1.1.4` includes the completed P9 Web Companion, hash-bound root project README,
P10.1 local composition contract and opt-in Host workspace evidence while preserving
stable API version `1.0`. V4 declares and certifies
`linux-x64` and `win-x64` only; macOS support is not declared.

The certification boundary requires:

- a native Linux complete report and native Windows full report bound to the same clean commit;
- the clean synthetic Bootstrap, Analysis, Pre, Post and accepted factory-reset lifecycle;
- exact package, archive, dependency-lock and offline-source validation;
- the hash-bound compatibility baseline at `core/certification/compatibility-baseline.json`;
- no `ifx_profile`, active V4 workflow, IFX cutover or V3/LayerGuard runtime dependency; and
- a generated recovery artifact bound to the reviewed P7 source checkpoint.

`Invoke-V4PlatformCertification.ps1` refuses an OS mismatch and runs the exact hash-approved suite,
including the P9 Web Companion query, workspace, evidence/Plan and offline distribution checks,
and the self-contained P10 synthetic composition matrix.
The Windows full selection includes the Windows-only Trusted Base behavioral suite; Linux complete covers
all approved Linux tests. Tests not selected for a platform cannot silently count toward that platform's
coverage.

The published 1.1.0/P9 baseline certified that the offline archive includes a deterministic Companion whose UI
assets are embedded in its hash-bound assembly, that installed operation remains confined to the V4
root model, and that command-injection, path-escape, Markdown-XSS, hostile-parent and lifecycle
negatives pass on Linux and Windows. It also requires `README.md` as package authority and proves that
the README is present in the archive and installed payload. The previous V4 1.0.0 release remains an
immutable historical release.
The 1.1.1 and later certification additionally requires the installed receipted composition launcher, four
hash-bound composition contracts, external base/composition receipts and cross-platform negative
controls. Synthetic certification evidence is not real-bundle approval.
`Invoke-V4V1Certification.ps1` accepts only matching passing platform reports and the exact deterministic
archive. Its record fixes `releaseAuthorized`, `activeIfxCutover` and `ifxProfileIncluded` to `false`.

Publishing/tagging and IFX adoption use separate exact Plans. Workflow/ruleset activation remains a
separately authorized operation.
