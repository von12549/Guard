# M1.6 — automatic cleanup and bounded retention

Status: `IMPLEMENTATION PLAN — READY; not yet executed`

Formal Plan ID: `20261001-m1-storage-retention`.

Predecessor checkpoint: `20261001-m1-version-lifecycle`.

## Goal

Implement preview/apply cleanup for finalized successful work, failed diagnostics, advisory Evidence and
global reclaimable caches while protecting authority, accepted/audit Evidence, pins, pending
transactions, selected/previous versions and active leases.

## Exact implementation

Add policy/preview/receipt contracts and a path-confined cleanup command. Initial configurable defaults
are newest five failed runs or 14 days, newest 20 advisory runs or 30 days, 5 GiB per-project unpinned
Evidence and 5 GiB global reclaimable cache; age/count keeps the smaller set. Preview records measured
bytes and every keep/delete reason. Apply accepts an exact hash, rechecks references/leases/links,
renames each candidate into an owned tombstone before deletion, survives restart and writes an exact
receipt. Protected data is never evicted to satisfy capacity.

## Acceptance and tests

`tests/m1/Test-V4StorageRetention.ps1` covers each durability class, age/count/capacity ordering,
protected references, active leases, stale preview, link escapes, interrupted tombstones, idempotent
resume and exact receipts. Measurements report installed+ordinary-State size without stabilizing the
provisional numeric defaults as compatibility promises.

## Stop and resume

Stop if a candidate lacks an owned receipt/classification, any canonical path crosses a link, capacity
can only be met by protected data, or an active lease/reference changes. Resume with a fresh preview or
the recorded tombstone transaction; never recursively delete a recomputed broad root.

## Recovery

Before final deletion, restart recovery restores or completes owned tombstones according to the durable
transaction. Finalized disposable data is not reconstructed; protected data must never enter a
tombstone. Source recovery is a revert.
