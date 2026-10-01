# 授权 V4 Guards 1.2.0 组合负例与 CI contract 原子重绑定（P5 R0.2）

Status: `AUTHORIZATION PR — V4 Guards 1.2.0 R0.2`

Formal Plan ID: `20261001-v4-guards-1-2-0-fixture-contract-authorization`。

PR #46 的受信 contract 证明，只授权
`tests/p10/Test-V4ExtensionComposition.ps1` 不足：任何 approved test 字节变化都必须在同一候选中由
`integrations/github/ci-contract.json` 绑定新 SHA-256。此前记录
`20261001-v4-guards-1-2-0-fixture-record` 因不含 CI contract 条目而无法通过候选绑定检查，
因此不能被成功消费，也不授权任何可合并状态。

本 PR 只增加新的 single-use 记录
`docs/plans/authorizations/20261001-v4-guards-1-2-0-fixture-contract-record.json`。独立
consuming Plan `20261001-v4-guards-1-2-0-fixture-contract-fix` 必须原子修改测试与 CI contract，
并删除新记录完成消费：

| 文件 | base SHA-256 | authorized head SHA-256 |
| --- | --- | --- |
| `tests/p10/Test-V4ExtensionComposition.ps1` | `b99f85ec58edcb058bbeb421f7eff29c89593fb2f99518ed65442a4d7516c334` | `3d375365c1fa12b6213dbe741fe6a87bb977f6aec2b31ab90a48ef13ab4c6500` |
| `integrations/github/ci-contract.json` | `9e893525a48096904f1ad7d24d56276c8c09be7c0e8d79a31c4584afc2365384` | `9fcc0d3cde750581884fe204347d49872b30a1dfc64001f30932d2e8512ffaf6` |

CI contract 只替换该测试的哈希；required contexts、允许路径、Windows 敏感路径、平台选择和其余
approved tests 全部保持不变。任何字节偏差、非原子修改或 candidate 自报权威都应失败关闭。
