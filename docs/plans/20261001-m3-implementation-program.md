# M3 implementation program — local application boundary and Workbench

Status: `IMPLEMENTATION PROGRAM — AUTHORIZED 2026-10-01; IMPLEMENTATION IN PROGRESS`

Formal Plan ID: `20261001-m3-implementation-program`.

Authority: `20261001-m3-ui-application-boundary-decision`, V4-AD-040 and V4-TODO-021.

## Goal and dependency order

Promote the accepted M3 decision into four separately reviewable checkpoints:

1. `20261001-m3-application-service-boundary` adds schema-versioned, typed Host operations and a closed
   operation taxonomy for the existing Companion.
2. `20261001-m3-setup-protection-preview` produces read-only Setup guidance and a non-vacuous protection
   status without claiming unverified Target or remote enforcement.
3. `20261001-m3-authority-lifecycle-handoffs` exposes Profile, Plan and Module handoffs plus immutable
   lifecycle previews while keeping apply and activation unavailable.
4. `20261001-m3-companion-workbench` projects those Host results through the existing loopback Companion
   with session, origin, CSRF, size, stale-preview, cancellation and receipt controls.

The JSON Plans intentionally have no native dependency edges because implementation may be delivered as
one reviewed PR. The dependency order in each Markdown Plan governs execution and recovery.

## Global boundaries

Browser input may select only startup-registered project IDs and Host-projected operation or authority
IDs. M3 adds no arbitrary root, executable, working directory, environment, shell text or raw Host
argument gateway. It does not write TargetRoot or `.guard/`, compose or select an installation, modify
workflow/ruleset or approved trusted tests, create a Target pull request, activate remote enforcement,
publish, release or merge. M4/M5 capabilities that do not yet exist remain explicit unavailable
handoffs rather than simulated authority.

## Validation, stop and resume

Run focused positive and negative M3 tests, affected Companion/Host contract, package, documentation,
distribution and compatibility regressions, then trusted validation and the exact base-to-head root
plan-set diff. Stop on Host-result reinterpretation, stale preview acceptance, Target mutation, missing
session/origin/CSRF protection, authority drift or any request for protected or remote mutation. Resume
from the last committed Plan checkpoint after correcting inputs or revising the exact Plan; never reuse
a stale preview token.

## Recovery

Revert the four checkpoints in reverse order. Preview documents and receipts are process-local or
StateRoot/EvidenceRoot-owned test artifacts and grant no Target, selected-installation or remote
authority. No protected state requires rollback.

