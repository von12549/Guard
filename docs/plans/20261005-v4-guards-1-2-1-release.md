# V4 Guards 1.2.1 release

Status: `IN PROGRESS — G-RELEASE pending`.

Formal Plan ID: `20261005-v4-guards-1-2-1-release`.

PR #51 merged the repaired 1.2.1 source into `main` at
`e7151c9083c2d3b498f5f0f86bece9709065269a`. The earlier trust-change authorizations were consumed
by that PR. This release Plan changes documentation only; it does not change protected CI, certification
or compatibility authority. The release-prep PR's final merge commit becomes the release source commit.

## Scope and assets

Version 1.2.1 delivers the installed onboarding and Profile authoring repairs described in
`docs/1.2.1-release-notes.md`. It preserves API `1.0`, the historical compatibility `pluginVersion`,
the non-authoritative local boundaries and immutable prior releases.

The fixed asset matrix is self-contained `v4-guards-1.2.1-linux-x64.zip` and
`v4-guards-1.2.1-win-x64.zip`, each with a matching `.sha256` sidecar. Both archives have the sole root
`v4-guards-1.2.1/`. Portable and arm64 are outside this release.

## Gates and publication order

1. Merge the reviewed release-prep PR after base-owned Contract, Linux, package, Windows and required
   checks pass. Record the final `main` merge commit as the exact release source.
2. Run full Guardrails and native Linux-complete/Windows-full Certification at that commit. Both passing
   reports must bind the same clean source commit and source `packageHash`.
3. Build each RID in two independent clean checkouts at that commit. Require equal A/B ZIP hashes and
   bytes, correct sidecars, exact package contents and repeated-pack determinism.
4. Run candidate/recovery certification against the passing platform reports and candidate archives.
   Require the release record to bind the exact commit, package hash, RID identity and recovery source.
5. Set `G-RELEASE = GO` only when every gate passes and the tag and Release name are unused. Create
   annotated tag `v4-guards-v1.2.1` on the exact release commit and publish non-draft,
   non-prerelease `V4 Guards 1.2.1` with exactly the four fixed assets.
6. Download the published assets to new directories. Verify their hashes and sidecars, then install,
   run the documented public CLI and Companion smoke, and verified-uninstall on Windows and isolated
   Linux. Complete a later records PR with commit, run, hash, tag and independent-verification evidence.

## Stop and recovery

Stop before tagging if any required check or certification fails, platform reports disagree, package or
archive hashes differ, candidate/recovery certification fails, asset contents are incomplete, or the
tag/Release already exists. Fix source through a new reviewed PR and repeat exact-commit gates. After
publication, preserve the tag and assets; a defect requires a new version rather than overwriting them.

No local candidate or passing release gate authorizes IFX adoption, Target writes, trusted CI activation
or remote changes.
