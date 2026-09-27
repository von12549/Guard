# Guard V4 activation — negative control (step D)

Deliberately invalid change for Plan `20260928-guard-v4-workflow-activation` step D. The root Plan
declares only this Plan pair, but the diff also edits an approved test without a CI-contract change and
adds an undeclared note. The base-owned runner must reject it: `v4-contract` with
"Root Plan paths do not exactly match the candidate diff", and therefore `v4-required`. This PR must never
be merged.
