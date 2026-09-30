# M2.1 — Deterministic inert Profile discovery

Status: `IMPLEMENTATION PLAN — IMPLEMENTED 2026-10-01`

Formal Plan ID: `20261001-m2-inert-discovery`.

## Goal and acceptance

Add a strict discovery document and `profile discover` Host operation. It inventories only allowlisted
repository/project/package manifests, source/test roots, declared languages/frameworks, installed
Modules and prerequisites. Every observation binds source path, normalized value, detector/version and
the content-derived Target snapshot. Results and ordering are deterministic; ambiguity and unsupported
forms remain explicit. Positive and negative tests prove Target bytes are unchanged and executable,
build, restore, download and Target mutation inputs are unavailable.

## Risks, boundaries and dependencies

Depends on the accepted M2 decision and package-validated Module catalog. Recursive discovery risks link,
size and path traversal; reject links and enforce file/count/size allowlists. This checkpoint is read-only
and adds no draft, policy inference, Target file, composition, CI or remote action.

## Stop, resume and recovery

Stop on a link/reparse point, unreadable allowlisted file, limit breach, Target drift or need to execute a
Target tool. Resume after removing the unsafe input or revising this Plan. Recovery is a code/contract
revert; discovery writes nothing.

Implementation evidence: `tests/p11/Test-V4ProfileAuthority.ps1` proves byte-deterministic facts,
allowlist limits, target-execution denial and unchanged Target bytes.
