# 将 M2–M5 focused suites 纳入可信 CI

Status: `TRUST-CHANGE CANDIDATE — consumes a base-held single-use authorization`

Formal Plan ID: `20261001-m1-m5-focused-ci-trust-change`.

本步骤消费并删除
`docs/plans/authorizations/20261001-m1-m5-focused-ci-record.json`。该 record 把
`integrations/github/ci-contract.json` 从 SHA-256 `d8676c…` 精确授权到 `9e8935…`；候选 contract
再把 `tests/p10/Test-V4M2M5Focused.ps1` 精确绑定到 SHA-256 `5653de…`。

wrapper 只负责顺序运行已有的五个 focused suites：M2 Profile Authority、M3 Application Boundary、
M4 Stage Semantics、M5 Governance Foundation 与 M5 Module Lifecycle。它在 Linux-complete 与
Windows-full 中运行，不进入 Windows smoke。

M1 的 `win-x64` / `linux-x64` 自包含分发与安装启动测试仍是发布认证步骤。它们需要先把对应 RID
runtime packs 预取到隔离缓存，再进行离线 publish，因此不加入普通 approved-test wrapper，避免把
联网/缓存前置条件伪装成 runner 内的离线能力。
