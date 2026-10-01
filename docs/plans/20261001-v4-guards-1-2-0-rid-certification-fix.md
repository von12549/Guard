# 修复 V4 Guards 1.2.0 RID 候选认证身份绑定

Status: `AUTHORIZED TRUST-CHANGE CANDIDATE`

Formal Plan ID: `20261001-v4-guards-1-2-0-rid-certification-fix`。

1.2.0 的主线 Linux/Windows 报告正确绑定同一个源码 `packageHash`。自包含发布器随后在干净
package 副本中加入 RID 特定的 `runtime-manifest.json`，因此归档清单内的 `source.packageHash`
是 RID package 身份，按设计不等于源码 `packageHash`。旧候选认证器错误地要求两者相等，
导致合法的 `linux-x64` 与 `win-x64` 资产都在归档 provenance 门禁失败。

本修复不放宽来源约束。认证器将：

- 保留平台报告与当前 checkout 的源码 `packageHash` 一致性检查；
- 从当前源码 authority 加上归档中经过 schema 验证的 `runtime-manifest.json` 重建 RID packageHash；
- 要求归档清单声明的 RID packageHash 等于该重建值；
- 精确核验单一版本根、清单声明文件集合、每个文件的 SHA-256/大小、两个 launcher 以及
  Host/Companion DLL provenance；
- 继续让 `v1-certification.json` 与 `recovery.json` 的 `packageHash` 表示跨平台源码身份，
  由各记录的 `archiveSha256` 区分 RID 资产。

新增 P8 回归测试构造一个源码与 RID packageHash 必然不同的最小自包含归档：合法归档必须通过，
把清单伪造回源码 packageHash 的归档必须失败关闭。测试作为 approved test 与 CI contract 原子
重绑定。受保护认证器、测试和 CI contract 的精确目标字节由独立 authorization PR 中的
single-use、base-held 记录授权；本 PR 必须消费并删除该记录。
