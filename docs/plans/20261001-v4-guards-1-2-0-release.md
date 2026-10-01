# V4 Guards 1.2.0 — M1–M5 repaired local foundations release（P5–P7）

Status: `P5 RELEASE CANDIDATE — 未发布`

Formal Plan ID: `20261001-v4-guards-1-2-0-release`。

G-REPAIR 在 PR #42 后为 GO。1.2.0 是下一未使用版本；`v4-guards-v1.1.6` 及更早 tag、
Release 和资产保持不可变。版本/tag 名称已只读检查为未占用。

## 1. 范围

1.2.0 发布 M1–M5 已合入并完成审计修复的本地基础：self-contained 安装与 launcher、Profile
discovery/reviewed promotion、typed application previews、v2 Stage semantics/local advisory evidence、
revision-bound Plan/target-trust/Plan-pair 与 Module lifecycle。精确交付边界、审计修复和延期项见
`docs/1.2.0-release-notes.md`；不把 local foundation 写成消费者采用、trusted CI 或远端启用。

## 2. R0/R1 两阶段 baseline 授权

R0 Plan `20261001-v4-guards-1-2-0-release-authorization` 增加一次性记录，绑定：

| protected path | base SHA-256 | head SHA-256 |
| --- | --- | --- |
| `core/certification/compatibility-baseline.json` | `3abaa9849e6778681d1addce3958c6dbc1b3f0718cb55d8a449daa61c0657fae` | `66f824cb3546c0aecc0d6262e424fc278f1d19f2531d0fe213300e3709615dbe` |

R1（本 Plan）删除该记录完成消费，将产品/Host/Companion 版本改为 1.2.0，并把 baseline 中
`plugin.json` 哈希改为 `98cfd11149f26a3a248c593b3b85954d1644c3f917c4f4bbb184224752356857`。
`pluginVersion=1.1.0`、`apiVersion=1.0` 保持不变。任何其他 protected path 变更均不在本授权内。

## 3. 固定资产矩阵

本 release 不发布 portable 或 arm64。只发布：

1. `v4-guards-1.2.0-linux-x64.zip` 与 `.sha256`；
2. `v4-guards-1.2.0-win-x64.zip` 与 `.sha256`。

两者均为 self-contained，ZIP 内唯一根为 `v4-guards-1.2.0/`。`New-V4Distribution.ps1` 仅在
self-contained 模式给文件名添加 RID；portable builder 的既有名称合同保持不变。安装器根据
manifest 和根目录验证内容，不依赖外部 ZIP 文件名。

## 4. 门禁顺序

- **R1 / PR head：** local package/documentation/version/Plan 验证；base-owned CI 的
  contract/Linux/package/Windows/required；精确 PR head 双平台 Certification。只有全部通过才正常合并。
- **R2 / release commit：** 在最终 main merge commit 重新 dispatch full Guardrails 与双平台
  Certification；Linux/Windows 报告必须绑定同一 commit 和源码 packageHash。
- **R3 / assets：** 每个 RID 从两个不同干净 checkout 构建；A/B ZIP 和 sidecar 字节一致；
  同一输入的重复打包一致；运行 candidate/recovery 认证，restore commit 为 R0 前已通过
  G-REPAIR 的主线 `7f9651263ccfffeebb86d5df74064b188166189e`。
- **G-RELEASE：** 清单 R-01–R-13 全部 PASS 后才允许 R4。
- **R4：** 创建 annotated tag `v4-guards-v1.2.0` 指向精确 release commit；发布
  `V4 Guards 1.2.0`，非 draft、非 prerelease，只含四个固定资产。
- **R5：** 新目录重新下载；Windows 和隔离 Linux 分别验证哈希、安装版本、四 Stage、实际
  M2–M5 smoke、Companion、receipt 和 verified uninstall；随后以文档 records PR 完成程序。

## 5. 停止和恢复

任一 required check/认证失败、源码 packageHash 不一致、同 RID A/B archiveHash 不一致、
sidecar 错误、candidate/recovery 失败、资产矩阵缺失、tag/release 已存在或下载验证失败时停止。
发布前通过新 reviewed PR 修复并重新认证；已消费授权不复用。发布后不删除、不移动 tag，
不覆盖资产，缺陷由后续版本修复。
