# M3.2 — Setup preview and non-vacuous protection status

Status: `IMPLEMENTATION PLAN — AUTHORIZED 2026-10-01; IMPLEMENTATION IN PROGRESS`

Formal Plan ID: `20261001-m3-setup-protection-preview`.

Predecessor: `20261001-m3-application-service-boundary`.

## Goal and acceptance

Add deterministic Host-owned Setup and protection previews for a startup-registered project. Setup
reports current initialization/profile/composition/prerequisite/coverage/CI steps and availability but
performs none of them. Protection is true only when initialized context, accepted non-empty Profile,
verified immutable composition, satisfied prerequisites, non-vacuous required Stage coverage, matching
CI authority and required aggregate enforcement are all positively proven. Unknown or unavailable
proof remains false with explicit reasons; a default/no-op Profile never becomes protected.

## Risks, boundaries and dependencies

Depends on M3.1 plus existing M1 distribution and M2 Profile contracts. Local filesystem hints cannot
prove remote repository policy, so CI enforcement remains `unverified` until separately certified
evidence exists. Setup never writes `.guard/`, adopts a Profile, invokes composition, edits CI, creates a
pull request or changes remote policy.

## Stop, resume and recovery

Stop if protection would require guessing from file presence, trusting browser values or contacting a
remote service. Resume when exact Host-readable evidence or a separately authorized certification
contract exists. Recovery removes the query/preview contract and UI projection; no Setup action has
been applied.

