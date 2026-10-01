# V4 Guards 1.2.0 最终发布报告

Status: `COMPLETE 2026-10-02 — G-RELEASE = GO`

Formal Plan ID: `20261002-v4-guards-1-2-0-release-records`。

## 1. 结论

V4 Guards 1.2.0 已从精确主线提交
`cf8a9cb631e120309568f18ac965540e381f8027` 发布。annotated tag `v4-guards-v1.2.0`
剝离后指向该提交；GitHub Release
[`V4 Guards 1.2.0`](https://github.com/von12549/Guard/releases/tag/v4-guards-v1.2.0)
非 draft、非 prerelease，仅含两个 self-contained ZIP 及其 sidecar。

G-REPAIR 与 R-01–R-12 全部 PASS 后才创建 tag/Release；发布后重新下载的两个资产
均在独立 Windows/Linux 环境完成安装、版本、四 Stage、M2–M5、Companion、receipt
和 verified uninstall。R-14–R-20 全部 PASS，本程序完成。

## 2. 提交、PR 与 CI

| 项目 | 精确记录 |
| --- | --- |
| 版本/文档 PR | [#44](https://github.com/von12549/Guard/pull/44)，head `1f79b6ecabb62f1c000ac4746eda4fa63372a65c`，merge `968f6be9dc8a6029e8f5e918c1037ff0569d4436` |
| RID 认证修复 PR | [#49](https://github.com/von12549/Guard/pull/49)，head `b40a9f562073a045ba2568662017ff9143e4f24a`，merge/release commit `cf8a9cb631e120309568f18ac965540e381f8027` |
| 最终 Guardrails | [run 36870395011](https://github.com/von12549/Guard/actions/runs/36870395011)：contract、Linux、package、Windows、required 全部 PASS |
| 最终 Certification | [run 36870399334](https://github.com/von12549/Guard/actions/runs/36870399334)：Linux-complete 35 项，Windows-full 36 项，全部 PASS |
| 源码 packageHash | `9fccf726207fe6674908e0e40a68efb8c6bd68d2fe347bf252b91af0efeced12` |
| recovery restore commit | `7f9651263ccfffeebb86d5df74064b188166189e` |

两个平台报告绑定同一 release commit 与 source packageHash。候选认证保留该跨平台
源码身份，并另行校验加入 RID runtime manifest 后的 archive package identity；不再错误
要求 RID 包哈希等于源码哈希。

## 3. 不可变资产

| RID / 资产 | archive SHA-256 | RID packageHash | 可重复性 |
| --- | --- | --- | --- |
| `v4-guards-1.2.0-linux-x64.zip` | `2404abdcc3f5a94ca0d22487ff1e399d093c9ec8e834ec8127bdf4f7c7c0fb56` | `29bce048ad04a0456a235eb340a28ce780308f7b207e734fda78f5ddb97a7070` | 两干净 checkout 与重复打包字节一致 |
| `v4-guards-1.2.0-win-x64.zip` | `03d0a439add97b59855508d70d6748b9165343806824d40582154befb8164b60` | `6d0443307ece2daa4825f3e19d2589bb997d92211cb5d96fb8de4888c2cd60e2` | 两干净 checkout 与重复打包字节一致 |

每个 ZIP 的本地 SHA-256、`.sha256` 内容、GitHub asset digest 和 candidate/recovery
`archiveSha256` 四者一致。Release 中没有 portable、arm64 或额外资产。

## 4. 发布后独立验证

| 平台 | 环境 | 结果 |
| --- | --- | --- |
| Windows | Windows 10.0.26200，PowerShell 7.6.6，新安装/Target/State/Evidence 目录 | 版本 1.2.0；Bootstrap/Analysis/Pre/Post PASS；Profile Authority、Application Boundary、Stage Semantics、Governance Foundation、Module Lifecycle PASS；Companion 仅在 `127.0.0.1` ready；receipt `uninstalled`，安装目录已移除 |
| Linux | `ifx-c6c-sdk:10.0.303`（Ubuntu 24.04.4）新容器与新挂载目录 | 版本 1.2.0；四 Stage 与同五个 M2–M5 validators PASS；Companion 仅在 `127.0.0.1` ready；receipt `uninstalled`，安装目录已移除 |

验证使用 GitHub Release 的全新下载件，不使用构建输出替代。Target 仅是外部合成 fixture；
测试没有修改用户 PATH、注册表或 PowerShell profile。

## 5. 延期边界

1.2.0 发布的是 M1–M5 local foundations，不代表以下范围完成：

- project initialization、Target governance adoption、版本选择/回滚 UI、storage retention；
- Target `.guard/` 采用、composition selection、trusted CI evidence reuse/activation；
- 多项目 dashboard、并行执行、remote activation、性能/cadence 目标；
- 完整 Plan/Module editor、marketplace/signatures、CODEOWNERS 与 remote installation；
- 任何 IFX 或其他消费者的采用、cutover 或回滚。

上述项目仍为 `DEFERRED`，需要独立的 Plan、实现、评审和证据。已发布 tag 和资产保持
不可变；发布后若发现缺陷，以新版本修复。
