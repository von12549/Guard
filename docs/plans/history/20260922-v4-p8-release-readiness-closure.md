# V4 P8 release-readiness closure

Status: implemented and audited on `codex/v4-development-base`; V4-P8.6 publication, tagging,
workflow/ruleset activation, push and IFX cutover remain outside this Plan and await separate authorization.

Parent roadmap: `docs/guards/v4/plans/01-v4-self-contained-guard-plugin.md`, release-readiness closure
before V4-P8.6.

Predecessor: `20260922-v4-p8-v1-certification`

## Goal

Close the independent pre-release audit findings by making every stable CLI contract executable,
correcting reset root syntax, including Trusted Base behavior in final certification evidence, aligning
the maintained architecture/status documentation with the as-built package, setting the release version
to `1.0.0`, and limiting declared platform support to certified Linux and Windows.

## Scope

- Implement `version` and `contract validate` as stable structured host commands.
- Add behavior tests for every previously missing stable CLI route and reset syntax.
- Require `--package-root` wherever a stable command consumes PackageRoot.
- Select the Windows-only Trusted Base suite in Windows full certification.
- Set the package/distribution release version to `1.0.0`.
- Remove `osx-arm64` from installed module support declarations and regenerated documentation; macOS
  remains unclaimed and uncertified.
- Replace the conceptual package tree with the maintained as-built tree and refresh planning statuses.
- Regenerate hash-bound contracts, module registry, compatibility baseline, documentation and CI test
  authorities.
- Re-run native Windows full, native Linux complete, package/distribution and final V1 certification,
  then perform an exact Plan-versus-implementation audit.
- Record the successful closure audit beneath V4-P8.6 while leaving V4-P8.6 unchecked and awaiting a
  separate release authorization.

## Validation

1. Formal Pre accepts this exact Plan pair and path set.
2. `version` reports `1.0.0`; `contract validate` accepts a valid document and rejects invalid,
   unregistered-schema and schema-drift cases with stable structured exit categories.
3. Generated command documentation includes PackageRoot for contract/reset commands.
4. No installed module or generated configuration document declares macOS support.
5. Windows full certification executes Trusted Base; Linux complete and Windows full reports bind the
   exact selected test sets and the same clean commit/package hash.
6. Deterministic distribution, lifecycle, supply-chain, compatibility, V3 Validate, isolated IFX
   validation and exact Diff checks pass.
7. The final record remains a local candidate with `releaseAuthorized`, `activeIfxCutover` and
   `ifxProfileIncluded` all false; no remote or active state changes occur.

## Recovery

Restore source checkpoint `dd0ee9e56112cd3f1b311c5b60e8a6ad1c2ee1b4` and rerun the P8 package,
platform and finalization checks. No release, tag, workflow, ruleset or other remote state is created by
this Plan.
