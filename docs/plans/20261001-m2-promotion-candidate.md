# M2.4 — Reviewed Profile promotion candidate

Status: `IMPLEMENTATION PLAN — IMPLEMENTED 2026-10-01`

Formal Plan ID: `20261001-m2-promotion-candidate`.

Predecessor: `20261001-m2-profile-review`.

## Goal and acceptance

Add `profile promote` to revalidate the fresh draft/review and atomically emit a portable extension
bundle plus promotion receipt under an operator-selected non-Target output root. The bundle contains the
reviewed Profile and exact installed Module files/hashes needed by the existing
`Compose-V4Extension.ps1` immutable sibling composer. The receipt states that Target adoption,
composition execution/selection and CI activation are still required separate transactions.

## Risks, boundaries and dependencies

Depends on M2.3 and the existing P10 extension bundle/composer contracts. Reject Target/output overlap,
pre-existing output, links, hash drift and anything other than an accepted human review. This checkpoint
does not write `.guard/`, consume target trust authorization, run the composer, select/rollback an
installation, activate CI, publish or change remote state.

## Stop, resume and recovery

Stop on stale validation, output overlap, existing destination, unsupported bundle content or Target
drift. Resume with a fresh review or a new empty output path. Recovery removes only the marker-owned
staging/candidate directory; later immutable composition recovery remains owned by P10 lifecycle.

Implementation evidence: the focused M2 test proves schema-valid atomic candidate output, duplicate
destination rejection, unchanged Target bytes and explicit non-claims for composition/CI state.
