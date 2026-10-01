# M4 PR root member — Versioned Stage runtime and Evidence diagnostics

Status: `PR ROOT MEMBER — IMPLEMENTED 2026-10-01`

Formal Plan ID: `20261001-m4-pr-implementation-root`.

Dependency: `20261001-m4-pr-documentation-root`.

## Goal

Own the exact Host, isolated v2 contract, Profile, provider and focused validation paths implementing the
M4 local Stage/Evidence foundation.

## Scope and boundary

Detailed behavior remains in the three child Plans. This root includes the hash-bound v2 authority
catalog, opt-in semantic Profile, least-privilege Host providers, fail-closed dependency validation,
timing, content/freshness/tamper diagnostics and read-only inspection. Stable v1 authorities are
byte-identical and continue through the legacy runtime branch.

This root does not change protected CI, the trusted-base runner/classifier, approved tests, workflow,
ruleset, Windows cadence, required coverage, release authority or remote state. Local Evidence is always
non-authoritative.

## Validation and recovery

Run the focused M4 suite, affected v1 regressions, package/distribution and complete trusted validation.
Revert this member as one local product capability; test Evidence is disposable and grants no authority.
