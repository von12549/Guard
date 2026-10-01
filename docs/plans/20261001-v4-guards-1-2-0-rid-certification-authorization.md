# 授权 V4 Guards 1.2.0 RID 候选认证修复

Status: `AUTHORIZATION PR — V4 Guards 1.2.0 certification recovery`

Formal Plan ID: `20261001-v4-guards-1-2-0-rid-certification-authorization`。

1.2.0 发布门禁实跑证明，旧候选认证器把跨平台源码 `packageHash` 与加入
`runtime-manifest.json` 后的 RID packageHash 错误地要求为同一值，因而合法的 `linux-x64` 和
`win-x64` 自包含资产都失败关闭。修复必须保持而不是放宽 provenance：由认证源码 authority 与
归档内经过 schema 验证的 runtime manifest 重建 RID identity，并逐项验证完整归档。

本 PR 只增加 single-use 记录
`docs/plans/authorizations/20261001-v4-guards-1-2-0-rid-certification-record.json`。独立
consuming Plan `20261001-v4-guards-1-2-0-rid-certification-fix` 必须原子修改下表两项，并删除
该记录完成消费：

| 文件 | base SHA-256 | authorized head SHA-256 |
| --- | --- | --- |
| `core/certification/Invoke-V4V1Certification.ps1` | `c617f6c95b2b846aa6487353f6b4e0e972584139e76e9db8f9f9289c63cc2543` | `1014fa73677d8e860f3167c1cf25d87054c45d58c2abd9c12b857da65f600cc8` |
| `integrations/github/ci-contract.json` | `9fcc0d3cde750581884fe204347d49872b30a1dfc64001f30932d2e8512ffaf6` | `98b6de508a56ae9a9cfc47252baead65e60b0c3d3bfb40b9db8f7dd0644c4674` |

全新测试在 trusted base 中还不是受保护路径，不能直接列入授权记录；CI contract 的 authorized
head 字节已精确绑定其 SHA-256 `d4da736516c1d349e38b567db04195b921816018536c93e1b3e84958c92675b5`，
并只增加该测试，选择 Linux、Windows smoke 与 Windows full。任何其他受保护字节、
非原子修改、未消费记录或 candidate 自报权威都应失败关闭。
