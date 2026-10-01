# 授权 M2–M5 focused suites 纳入可信 CI

Status: `AUTHORIZATION CANDIDATE — base-held merge requires human approval`

Formal Plan ID: `20261001-m1-m5-focused-ci-authorization`.

本步骤只添加一次性 record
`docs/plans/authorizations/20261001-m1-m5-focused-ci-record.json`，授权后续 Plan
`20261001-m1-m5-focused-ci-trust-change` 把 `tests/p10/Test-V4M2M5Focused.ps1` 加入
`ci-contract.json` 的 Linux-complete 与 Windows-full approved tests。

record 精确绑定现有 contract hash `d8676c…` 与候选 hash `9e8935…`。新增 wrapper 在 base
contract 中尚不是 approved test，因此现有 runner 的 protected set 只要求 authorization entry
覆盖 `ci-contract.json`；消费 PR 仍会验证 candidate contract 绑定 wrapper 的精确 hash。

本授权不运行、合并或远端启用代码；消费 PR 必须删除 record，且 base hash 漂移时停止重算。
