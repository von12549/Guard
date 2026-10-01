# 授权 V4 Guards 1.2.0 compatibility baseline 重绑定（P5 R0）

Status: `AUTHORIZATION PR — V4 Guards 1.2.0 R0`

Formal Plan ID: `20261001-v4-guards-1-2-0-release-authorization`。

G-REPAIR 已由 PR #42 合入并记录为 GO。操作者在 2026-10-01 明确批准继续完成 1.2.0
版本、认证、tag 与正式 Release。本 PR 只增加 single-use 记录
`docs/plans/authorizations/20261001-v4-guards-1-2-0-release-record.json`，不修改版本、
受保护 baseline 或远端发布状态。

consuming Plan `20261001-v4-guards-1-2-0-release` 将 `plugin.json` 产品版本从 1.1.6 改为
1.2.0。候选 `plugin.json` SHA-256 为
`98cfd11149f26a3a248c593b3b85954d1644c3f917c4f4bbb184224752356857`。因此受保护文件
`core/certification/compatibility-baseline.json` 只把 `plugin.json` 的绑定从 `01c6aa79…`
改为 `98cfd111…`：

| 文件 | base SHA-256 | authorized head SHA-256 |
| --- | --- | --- |
| `core/certification/compatibility-baseline.json` | `3abaa9849e6778681d1addce3958c6dbc1b3f0718cb55d8a449daa61c0657fae` | `66f824cb3546c0aecc0d6262e424fc278f1d19f2531d0fe213300e3709615dbe` |

`pluginVersion` 继续为 1.1.0，`apiVersion` 继续为 1.0；它们表达稳定兼容基线，不是当前
产品发行号。后续 trust-change PR 必须从合入本记录的 base 读取它、精确匹配上述哈希并
删除记录完成单次消费。任何字节偏差、记录复用或 candidate 自报权威都应失败关闭。
