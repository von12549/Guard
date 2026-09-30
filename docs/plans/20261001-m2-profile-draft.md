# M2.2 — Snapshot-bound non-authoritative Profile draft

Status: `IMPLEMENTATION PLAN — IMPLEMENTED 2026-10-01`

Formal Plan ID: `20261001-m2-profile-draft`.

Predecessor: `20261001-m2-inert-discovery`.

## Goal and acceptance

Add `profile draft` to atomically persist a deterministic scaffold below
`StateRoot/profile-drafts/<project>/<draft>/`. The strict draft binds project identity, Target snapshot,
discovery identity and generator identity. It contains a schema-valid conservative Profile candidate,
labelled recommendations and explicit unresolved policy choices. Empty coverage is `unprotected` and the
draft path is never read by Stage execution, Profile catalog lookup or composition.

## Risks, boundaries and dependencies

Depends on M2.1 facts. Reject root overlap, stale discovery, link traversal and conflicting existing
bytes. Recommendations never select Modules, gates, rules, severities, baselines or exceptions. No
Target write, review acceptance, installed authority or remote action occurs.

## Stop, resume and recovery

Stop on stale snapshot, unsafe StateRoot, conflicting deterministic draft or non-schema-valid candidate.
Resume by rediscovering or selecting a safe external StateRoot. Recovery removes only the generated
draft directory after verifying its ownership marker; TargetRoot remains unchanged.

Implementation evidence: the focused M2 test proves schema-valid atomic/idempotent StateRoot storage,
conservative defaults and explicit `unprotected` coverage without Target mutation.
