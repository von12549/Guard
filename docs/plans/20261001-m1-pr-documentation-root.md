# M1 PR root member — decision and planning authority

Status: `PR ROOT MEMBER — IMPLEMENTED 2026-10-01`

Formal Plan ID: `20261001-m1-pr-documentation-root`.

## Goal

Own the exact decision, planning and product-index portion of PR #30 so the full multi-commit candidate
has one deterministic root plan-set without changing the semantics of any milestone or child Plan.

## Scope and boundary

This member owns `.gitignore`, every decision/program/child Plan pair added by the branch, the maintained
product documents, its own pair and the root plan-set. It authorizes documentation only. Product changes
belong to the dependent implementation member. Target trust-change, CI/ruleset activation, release
publication and all other remote mutations remain excluded.

## Validation and recovery

The root plan-set union must equal the exact `origin/main...HEAD` diff with no overlap or unchanged path.
Recovery is a revert of the PR; no runtime or remote data is affected by this member.
