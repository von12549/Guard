# M1.5 — immutable sibling version lifecycle

Status: `IMPLEMENTATION PLAN — READY; not yet executed`

Formal Plan ID: `20261001-m1-version-lifecycle`.

Predecessor checkpoint: `20261001-m1-governance-adoption`.

## Goal

Extend operator-supplied installation into verified immutable sibling staging, explicit selection,
certification-gated replacement and rollback. No discovery, download, background activation or release
publication is introduced.

## Exact implementation

Add lifecycle selection/receipt contracts and a manager with preview/apply modes. Stage verifies the
archive into a version/RID sibling; select atomically updates an external pointer receipt only after
package/start/capability certification; rollback selects a retained verified sibling. Downgrade checks
context/state schema compatibility and refuses destructive down-migration. The previous selection stays
referenced until replacement certification and pointer application complete.

## Acceptance and tests

`tests/m1/Test-V4VersionLifecycle.ps1` covers first install, sibling update, failed certification,
interrupted pointer apply/recovery, rollback, compatible downgrade, incompatible downgrade refusal,
tamper detection and launcher selection. Re-run P7 lifecycle, P8 compatibility and P10 composition.

## Stop and resume

Stop before network/download behavior, release publication, destructive state migration, implicit
activation or removal of the selected/previous sibling. Resume from the durable transaction receipt and
re-run certification; never infer success from partial filesystem state.

## Recovery

Restore the prior external selection receipt and retained verified sibling. Any source change is reverted
separately; no remote state exists.
