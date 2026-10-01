# 授权 V4 Guards 1.2.0 版本无关负例修复（P5 R0.1）

Status: `AUTHORIZATION PR — V4 Guards 1.2.0 R0.1`

Formal Plan ID: `20261001-v4-guards-1-2-0-fixture-authorization`。

1.2.0 候选在 PR #44 的 Linux Guardrails 与精确 head Certification 中暴露出同一问题：
`tests/p10/Test-V4ExtensionComposition.ps1` 将不兼容基准版本硬编码为 `1.2.0`。产品版本
提升至 1.2.0 后，该值不再是不兼容负例，测试因此在错误边界失败。

本 PR 只增加 single-use 记录
`docs/plans/authorizations/20261001-v4-guards-1-2-0-fixture-record.json`，不修改测试、
版本、baseline 或远端发布状态。独立 consuming Plan
`20261001-v4-guards-1-2-0-fixture-fix` 将负例值改为
“当前基准主版本 + 1”，使断言对未来版本保持不兼容且不削弱覆盖：

| 文件 | base SHA-256 | authorized head SHA-256 |
| --- | --- | --- |
| `tests/p10/Test-V4ExtensionComposition.ps1` | `b99f85ec58edcb058bbeb421f7eff29c89593fb2f99518ed65442a4d7516c334` | `3d375365c1fa12b6213dbe741fe6a87bb977f6aec2b31ab90a48ef13ab4c6500` |

后续 trust-change PR 必须从合入本记录的 base 读取它、精确匹配上述哈希并删除记录完成
单次消费。任何字节偏差、记录复用或 candidate 自报权威都应失败关闭。
