# M1 PR root member — distribution and launcher implementation

Status: `PR ROOT MEMBER — IMPLEMENTED 2026-10-01`

Formal Plan ID: `20261001-m1-pr-implementation-root`.

Dependency: `20261001-m1-pr-documentation-root`.

## Goal

Own the exact product and test paths implementing M1.1 self-contained RID publishing/measurement and
M1.2 installed launcher/PackageRoot resolution in PR #30.
This includes preserving the existing receipted Companion path for composition packages by binding its
launch to the package hash produced by successful receipt verification.

## Scope and boundary

The detailed acceptance, tests, stop/resume and recovery conditions remain in
`20261001-m1-runtime-distribution` and `20261001-m1-installed-launcher`. This wrapper adds no capability.
It excludes M1.3–M1.6 implementation, Target changes, release publication, workflow/ruleset changes and
remote activation.

## Validation and recovery

Run both distribution-local M1 validation scripts and affected P0/P7/P8/P9/package regressions. Revert M1.2 then M1.1 if
recovery is required; only external disposable test artifacts exist.
