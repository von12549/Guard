# V4 Guards P04 compatibility baseline authorization

Status: `PENDING BASE REVIEW`.

Formal Plan ID: `20261006-v4-guards-p04-trust-authorization`.

The P04 repair reserves unused patch version 1.2.2. Changing `plugin.json` to 1.2.2 requires rebinding
its exact SHA-256 in `core/certification/compatibility-baseline.json`. That baseline is a protected
certification component under `integrations/github/trust-policy.json`.

This authorization-only change adds one single-use base-held record for the exact baseline bytes. It
does not edit the protected file, product code, CI policy, tests, tags or releases. The consuming P04
repair Plan will declare `trust-change`, delete this record in its diff, and prove the exact head hash
under the trusted base runner. If the candidate baseline bytes change, a new reviewed authorization is
required. The user authorized the P04 repair and new patch publication on 2026-10-06; the record's
acceptedBy field represents that human instruction, not a candidate Host verdict.
