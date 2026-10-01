# V4 Guards 1.2.0 版本无关负例修复

Status: `IMPLEMENTATION PR — authorized fixture repair`

Formal Plan ID: `20261001-v4-guards-1-2-0-fixture-fix`。

PR #44 的 Linux Guardrails 和 Linux/Windows 精确 head Certification 均发现
`incompatible-base-version` 负例把预期不兼容值硬编码为 `1.2.0`。产品版本提升到 1.2.0
后，该值与基准相同，导致测试未在 `Bundle/review/base identity mismatch` 边界拒绝。

本修复将负例版本确定性地设为当前基准主版本加一，保持 schema 合法、保证与当前基准
不同，并避免未来产品版本再次撞上固定值。它不改变生产代码、发行资产或通过条件。

受保护测试字节变更由 PR #45 合入 main 的 single-use 记录
`20261001-v4-guards-1-2-0-fixture-record` 精确授权；本 PR 删除该记录完成消费。

完成条件：

- 授权记录的 base/head SHA-256 与测试文件精确匹配；
- `Test-V4ExtensionComposition.ps1` 在 Linux 与 Windows 均通过；
- PR 的 contract、完整 Linux、package、完整 Windows 和 required checks 全部通过；
- PR 正常合并到受保护 main 后，1.2.0 候选分支再合入该 main commit 并重新认证。
