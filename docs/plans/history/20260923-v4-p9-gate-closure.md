# V4 P9.GATE — Lightweight Web UI boundary closure

Status: gate closure and branch push authorized on `codex/v4-development-base`; pull request, merge,
release/tag publication, workflow/ruleset activation and every other remote mutation remain outside
this Plan.

Parent roadmap: `docs/guards/v4/plans/01-v4-self-contained-guard-plugin.md`, V4-P9.GATE.

Predecessor: `20260922-v4-p9e-offline-ui-certification`

## Goal

Close V4-P9 only after an exact audit proves that the certified Lightweight Web UI remains a local,
non-authoritative surface over public V4 contracts, preserves the four-root boundary and contains none
of the first-release exclusions recorded under V4-TODO-005.

## Scope

- Audit the P9.1–P9.5 implementation and its exact CI inventory without changing package authorities,
  executable code, schemas, dependencies, tests or the certified package hash.
- Bind the gate record to the native Windows-full and pinned network-disabled Linux-complete reports
  produced from the same clean source commit and package hash.
- Record evidence for the single shell-free Host gateway, loopback/origin controls, schema-bound browser
  operations, read-only PackageRoot/TargetRoot behavior and V4-owned mutable roots.
- Review every V4-TODO-005 first-release exclusion against the implemented routes, launcher, browser
  assets and P9 tests; retain all excluded capabilities as deferred work.
- Update the maintained V4 decision, roadmap, architecture, index and deferred-work records to show
  P9.GATE passed.
- Commit the exact gate-only planning diff and push `codex/v4-development-base` to `origin` after
  confirming the remote branch has not diverged.

## Validation

1. The two platform reports are `pass`, bind source commit
   `a7c118b52a639220c5176871e2efa395df6f5b72`, bind package hash
   `e513d7512c8e6786882661192a3e7fe3471b86c61ef795f5b472190e4ff911b5` and exactly match the
   CI-selected Windows-full and Linux-complete suites.
2. Package Check returns the same certified package hash before and after this closure because every
   changed path is planning authority outside the packaged authority roots.
3. The Companion binds only IPv4 loopback, enforces same-origin mutation requests, invokes only the
   fixed V4 Host through structured arguments with shell execution disabled, and has no filesystem
   write primitive.
4. The browser exposes no path, shell, raw-argument, terminal, reset, Git, remote-control, authority-edit
   or Target-mutation surface and uses text-only rendering for Host/Plan content.
5. P9 tests remain hash-approved in the CI contract and the gate record accounts for every exclusion
   under V4-TODO-005.
6. Formal Pre accepts this exact Plan pair and changed-path set; V3 Validate, isolated IFX package and
   relevant V4 package/documentation checks remain passing.
7. The refreshed remote branch is not ahead of the local branch before push; no PR, merge, release/tag,
   workflow/ruleset activation or IFX cutover occurs.

## Recovery

Revert the single P9.GATE closure commit. The certified P9.5 package remains byte-identical and its
ignored platform reports remain reproducible; reverting the planning record does not require package,
installation, workflow, ruleset or release rollback.
