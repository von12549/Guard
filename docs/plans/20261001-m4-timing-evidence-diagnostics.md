# M4.3 — Stage timing and local Evidence diagnostics

Status: `IMPLEMENTATION PLAN — PLANNED 2026-10-01`

Formal Plan ID: `20261001-m4-timing-evidence-diagnostics`.

## Goal and acceptance

Record monotonic total, per-Stage and per-Module wall time for semantic execution. Emit a normalized
content identity, explicit `local-advisory` producer class, freshness decision, dependency source and
reason for each executed or reused provider. Queries preserve those fields through the existing strict
Stage-result contract so local users can inspect why Evidence was or was not reusable.

Timing data is diagnostic input only. This checkpoint does not define a stable performance threshold,
select CI coverage, change Windows cadence, or claim the V4-AD-042 sample baseline is complete.

## Risks, boundaries and dependencies

Depends on the semantic contract and provider checkpoints. Wall-clock timestamps can vary, so identity
hashes exclude timing values and use only normalized authority/content fields. Matching content never
changes the local producer into trusted CI. No key, machine identity, signature, remote cache or managed
local attestation is introduced.

## Stop, resume and recovery

Stop if elapsed time enters a reuse key, if stale or mismatched Evidence reports reusable, or if a local
producer is reported authoritative. Resume after regenerating diagnostics from monotonic timing and exact
identity inputs. Recovery reverts the additive semantic result fields and documentation; Evidence remains
non-authoritative and disposable.
