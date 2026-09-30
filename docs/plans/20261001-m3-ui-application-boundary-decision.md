# M3 UI application boundary decisions

Status: `DECISION RECORD — ACCEPTED 2026-10-01; implementation not authorized by this Plan`

Formal Plan ID: `20261001-m3-ui-application-boundary-decision`.

Predecessor decision records:

- `20261001-m1-foundation-decisions`;
- `20261001-m2-profile-authority-decision`.

## Goal

Resolve D15–D19 so later UI implementation Plans have an exact topology, operation taxonomy, protection
definition, CI activation boundary and phased multi-project scope.

## Accepted decisions

### 1. UI topology

Expand the existing separately packaged, package-verified local Web Companion. Do not create a second
Setup/Authoring backend product. The Companion remains loopback-only and subordinate to the Host and
typed schema-versioned application services.

### 2. Operation classes and security

Every operation declares one class: query, local-mutable preview, local-mutable apply, Target
trust-change candidate or remote-change candidate. Browser input selects vetted IDs and structured
values, never arbitrary roots, executables, shell text, working directories, environment mutation or raw
Host arguments. Require a loopback-bound session, unpredictable token, origin/host and CSRF checks,
request limits, stale-preview hash refusal, cancellation/recovery and receipts. Remote apply is excluded
from the first expansion.

### 3. Protection status

“Protected” requires initialized context, accepted non-empty Profile, verified immutable composition,
satisfied prerequisites, non-vacuous required Stage coverage, CI pinned to the same authority and a
repository policy requiring the unchanged aggregate verdict. Local-runnable, CI-configured and
CI-enforced remain separate states.

### 4. CI generation and activation

Local tooling may generate and validate an exact CI candidate. Target application, pull-request work,
target trust authorization, remote workflow/ruleset activation and enforcement controls are independent
Plans and explicit operations. Setup performs none of them implicitly.

### 5. Multi-project phasing

After project identity and Evidence isolation exist, implement read-only aggregation first. Defer
parallel execution until per-project queues, cancellation, logging and fair resource ceilings are
contracted and certified. Preserve loopback-only topology.

## Scope and non-authorization

This Plan records architecture and backlog state only. It adds no route, service, command, filesystem
mutation, UI asset, Target change, Git operation, workflow, ruleset, network access or remote state. It
does not reopen the completed V4-P9 first-release gate or claim that its historical exclusions were part
of that release.

## Acceptance

1. V4-AD-040 expands the existing Companion without creating a second engine or backend product.
2. Typed operation classes and browser-input/security ceilings are explicit.
3. Protection cannot be inferred from a no-op Profile, local pass or unrequired workflow.
4. CI candidate generation is separate from Target mutation and remote activation.
5. V4-TODO-006 records read-only-first multi-project phasing and V4-TODO-021 tracks UI implementation.
6. The native Plan pair validates and declares the exact maintained documentation paths.

## Next formal Plans

After the applicable M1/M2/M4/M5 typed contracts exist, promote separate implementation Plans for the
common application-service boundary, Setup Wizard, protection status and lifecycle UI. Target adoption,
CI repository changes and remote activation retain their own authorization Plans. Multi-project
execution remains later-wave.

## Recovery

Revert this documentation-only record and remove V4-AD-040/V4-TODO-021 while restoring the previous
V4-TODO-006 wording. No runtime, Target, UI package or remote state requires rollback.
