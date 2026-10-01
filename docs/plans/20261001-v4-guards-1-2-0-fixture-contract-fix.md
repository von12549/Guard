# V4 Guards 1.2.0 组合负例与 CI contract 原子重绑定

Status: `IMPLEMENTATION PR — authorized atomic trust change`

Formal Plan ID: `20261001-v4-guards-1-2-0-fixture-contract-fix`。

PR #44 的 Linux Guardrails 和 Linux/Windows 精确 head Certification 均发现
`incompatible-base-version` 负例把预期不兼容值硬编码为 `1.2.0`。产品版本提升到 1.2.0
后，该值与基准相同。PR #46 的第一版随后证明，approved test 的字节变化还必须在同一候选中
由 `integrations/github/ci-contract.json` 绑定新 SHA-256。

本修复原子完成两项不可分割的变更：

- 将负例版本确定性地设为当前基准主版本加一；
- 仅把 CI contract 中该 approved test 的 SHA-256 从旧值重绑定到新值。

required contexts、允许路径、Windows 敏感路径、平台选择和其余 approved tests 全部保持不变。
受保护字节由 PR #47 合入 main 的 single-use 记录
`20261001-v4-guards-1-2-0-fixture-contract-record` 精确授权；本 PR 删除该记录完成消费。
此前 test-only 记录不含 CI contract 条目，无法通过 candidate binding，保留为失败关闭的历史记录，
不授权任何可合并状态。

完成条件：

- 新授权记录的两个 base/head SHA-256 与候选精确匹配；
- `Test-V4ExtensionComposition.ps1` 在 Linux 与 Windows 均通过；
- contract、完整 Linux、package、完整 Windows 和 required checks 全部通过；
- 正常合并到受保护 main 后，1.2.0 候选分支合入该 main commit 并重新认证。
