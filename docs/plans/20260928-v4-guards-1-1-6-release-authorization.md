# Authorize the V4 Guards 1.1.6 version bump (G3 R0)

Status: `AUTHORIZATION PR — V4 Guards 1.1.6 R0`

Formal Plan ID: `20260928-v4-guards-1-1-6-release-authorization`.

Adds the single-use record `docs/plans/authorizations/20260928-v4-guards-1-1-6-release-record.json` for Plan `20260928-v4-guards-1-1-6-release`. The 1.1.6 version bump changes
`core/certification/compatibility-baseline.json`, a certification component, because the baseline binds
the SHA-256 of `plugin.json`. The record binds exactly its base SHA-256 (`f2785af9…`) and its head
SHA-256 (`3abaa984…`), the baseline with only the `plugin.json` hash changed from `f99a5409…` to
`01c6aa79…` (`plugin.json` with `version` `1.1.6`). `pluginVersion` and `apiVersion` stay unchanged. The
following trust-change PR (R1) consumes the record.
