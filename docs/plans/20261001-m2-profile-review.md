# M2.3 — Profile validation, fixtures and explicit review

Status: `IMPLEMENTATION PLAN — READY 2026-10-01`

Formal Plan ID: `20261001-m2-profile-review`.

Predecessor: `20261001-m2-profile-draft`.

## Goal and acceptance

Add `profile validate` with strict review and validation result contracts. Validation reruns discovery,
rejects stale draft/snapshot/hash bindings, validates the candidate Profile and each selected installed
Module/configuration hash and capability ceiling, requires positive and negative fixture receipts, and
reports non-vacuous coverage/readiness. An accepted portable review must bind exact hashes and record a
human reviewer plus explicit decisions for gates, severities, exceptions, baselines, unsupported
coverage and every ambiguous Module choice.

## Risks, boundaries and dependencies

Depends on M2.2. Candidate output cannot self-authorize, fixture labels cannot replace matching expected
and actual results, and unresolved policy fails closed. Review validation is read-only and does not write
TargetRoot, install/select a composition or activate CI.

## Stop, resume and recovery

Stop on any stale binding, schema/capability/hash drift, missing fixture class, mismatch or unresolved
decision. Resume only with a fresh draft and separately authored review record. Recovery deletes no input;
revert the contracts/runtime changes.
