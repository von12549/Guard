# V4 Guards 1.2.2 release

Status: `IN PROGRESS — release source and publication gates pending`.

Formal Plan ID: `20261006-v4-guards-1-2-2-release`.

P04 repair PR #58 merged the 1.2.2 implementation into `main`. Its Contract, Linux, package,
Windows and required jobs passed. The compatibility baseline change consumed the separately merged
authorization from PR #57. This release Plan changes documentation only; its final merge commit becomes
the exact release source.

## 1.2.1 lessons applied

The 1.2.1 release correctly froze one source commit, matched Linux and Windows certification package
hashes, reproduced both RID archives and verified fresh downloads. Later IFX P03 testing found gaps in
the operator path: the first public command omitted `--port`, a proof expired during human review, the
browser retained stale success after refusal, and A1/B3 safety evidence had gaps. PR #55 also needed a
self-contained release Plan correction, and PR #56 needed its Windows selection record aligned.

This release therefore requires the installed public command to pass with omitted port, spaces,
alternate cwd and both PowerShell invocation forms; exact-clock proof expiry/renewal coverage; an
independent preflight before dotnet/install; and complete host/Target checkpoints around build,
installation and cleanup. P03 remains FAIL and its missing evidence is not reconstructed.

## Scope and immutable assets

The fixed matrix is `v4-guards-1.2.2-linux-x64.zip` and `v4-guards-1.2.2-win-x64.zip`, each with one
matching `.sha256` sidecar. Both archives have the sole root `v4-guards-1.2.2/`. Portable and arm64
assets are outside this release. The stable command API remains `1.0`.

## Gates and publication order

1. Merge this documentation-only release-prep PR after all base-owned checks pass. Record the final
   `main` merge commit as the only release source.
2. On that commit, run full Guardrails and native Linux-complete/Windows-full Certification. Both
   platform reports must bind the same clean commit and source `packageHash`.
3. Run the P04 application, preflight and installed-public-launcher regressions under independent
   hash-only host safety checkpoints. Any User/Machine environment, Process PATH, Profile or Target
   drift stops publication.
4. Build each RID twice from independent clean checkouts. Require byte-identical ZIPs, matching
   sidecars, correct single-root contents and repeated-pack determinism.
5. Run candidate/recovery certification for each RID against the two passing platform reports. Require
   exact commit, source package hash, RID identity, complete archive payload and recovery source.
6. Confirm the tag, Release name and asset names remain unused. Create annotated tag
   `v4-guards-v1.2.2` and publish non-draft, non-prerelease `V4 Guards 1.2.2` with exactly four assets.
7. Download all four published assets to new directories. Verify remote bytes and sidecars, then run
   install, public CLI, Companion and verified-uninstall checks on Windows and isolated Linux. A later
   records PR captures exact hashes, runs and download evidence without changing released bytes.

## Stop and recovery

Stop before tagging on any failed or incomplete gate, platform disagreement, non-reproducible archive,
host/Target drift, candidate/recovery failure or occupied release identity. Fix source through a new
reviewed PR and repeat the exact-commit gates. After publication, preserve the tag and assets; any defect
uses a new version.

No release gate adopts IFX, accepts policy, installs `ifx_profile`, writes an IFX Target, activates its CI
or establishes protection. A future human-operated IFX retest requires a fresh run topology and evidence.
