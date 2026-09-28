# V4-TODO-011 phase 2 negative control (C4)

Status: `NEGATIVE CONTROL — expected to fail v4-required and be refused by the ruleset; closed unmerged`

This is step C4 of Plan `20260928-v4-todo-011-phase2-ruleset`. The PR adds this Plan pair and one
undeclared file, `docs/plans/product/v4-todo-011-negative-control-note.md`. The root Plan's
`plannedPaths` therefore do not match the diff exactly. `v4-contract` must fail. A non-admin merge
must then be refused by the `v4-main-autonomy` ruleset.
