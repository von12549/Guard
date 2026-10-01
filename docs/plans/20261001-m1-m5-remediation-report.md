# M1–M5 修复后复检报告与 G-REPAIR 结论

Status: `COMPLETE 2026-10-01 — G-REPAIR = GO`

Formal Plan ID: `20261001-m1-m5-remediation-report`。

## 1. 结论摘要

本报告复检审计基线 `56f049a3388ef10d2240fb6f9fb445724047b4ed` 之后的 M1–M5 修复。
最终修复提交为 `fa7ae011b385233bdcaf6192f0971ffbe59aefc1`；修复由 PR #35–#41 顺序合入
`main`，每个 PR 均经 required checks 正常合并，没有绕过保护。

Linux-complete、Windows-full、required 聚合、源码 packageHash 和两个 RID 的本地隔离构建
全部通过。清单 A–E 没有 FAIL、BLOCKED 或 NOT RUN 的必修项，结论为 `G-REPAIR = GO`；
允许进入 1.2.0 升级阶段，但这不等于 `G-RELEASE`，也不表示 1.2.0 已发布。

## 2. 基线、变更链与环境

| 项目 | 记录 |
| --- | --- |
| 审计基线 | `56f049a3388ef10d2240fb6f9fb445724047b4ed` |
| 修复主线 | `fa7ae011b385233bdcaf6192f0971ffbe59aefc1` |
| P0 | PR #35，merge `cedae92b2d78be19a736a225332ab92bd0788afe` |
| P1 / F-01–F-02 | PR #36，merge `8dd840439223699940d7593cd515ca9eeb4ab389` |
| P2 / F-03–F-04 | PR #37，merge `5159a4118830c70e653907452357fd99c1b1415e` |
| P3 / F-05 | PR #38，merge `a3b875ade1458a12c0612eedeaead0bbce11ebc4` |
| P4 / V-01 | PR #39，merge `5f98387400ef0e7fd8fff975392901a94a8067d4` |
| focused CI 授权 | PR #40，merge `782e70e91b8d32b59f166968a44821be1895704d` |
| focused CI 消费 | PR #41，merge `fa7ae011b385233bdcaf6192f0971ffbe59aefc1` |
| 本机 | Windows `10.0.26200`、PowerShell `7.6.6`、.NET SDK `10.0.303`、Git `2.49.0.windows.1`、Docker `29.8.0` |
| Linux 隔离构建 | `ifx-c6c-sdk:10.0.303`，PowerShell `7.6.2`、.NET `10.0.303`、Git `2.43.0` |

开始修复与本报告分支建立前工作树均干净，`main = origin/main`。测试只写明确的临时根和
外部证据根；没有修改用户或机器 PATH、注册表、PowerShell profile。恶意/负向 adapter
只在测试临时根运行，回收范围按测试创建的进程和目录限定。

## 3. Findings 修复与复检

| Finding | 修复方法与代码位置 | 正向/负向证据 | 残余风险 |
| --- | --- | --- | --- |
| F-01 | `core/modules/Invoke-V4ModuleLifecycle.ps1` 清空继承环境、固定 PATH/TEMP、限制 candidate 为显式 synthetic fixture，校验 process/network/writeRoots，timeout 后杀进程树。 | `Test-V4ModuleLifecycle.ps1` 覆盖正常、timeout、挂起子进程、环境泄漏、网络/额外进程、越界 sentinel；Linux/Windows focused suite 通过。 | 没有宣称 OS sandbox；任意不可信 adapter 仍被拒绝，只允许受控 synthetic fixture。 |
| F-02 | 同一生命周期入口对 adapter/profile/config/lock/fixture 及祖先执行 link/reparse 检查；`Safe-Entries`/`Copy-SafeTree` 在递归复制前逐项验证。 | Linux 文件/目录 symlink、Windows junction/reparse、外部 sentinel、可重复打包均由 lifecycle suite 覆盖。 | 平台文件系统仍可能有环境特有语义；失败策略保持 fail closed。 |
| F-03 | `TargetTrustRuntime.cs` 从明确 base/head Git object 读取 policy、authorization、Plan-set 与成员；校验 schema、成员哈希/身份/依赖/union/boundary/compositionHash 和 exact diff。 | governance suite 覆盖伪哈希、缺成员、错误 composition/union、重复身份、遗漏、自授权、candidate-only、重放及工作树漂移；正确单次消费通过。 | 只覆盖当前 Git object 模型；远端消费者仍需自行采用该 policy。 |
| F-04 | `PlanRuntime.cs` 使用临时目录构造 JSON/Markdown/receipt 后目录提交；已存在 finalized 目录拒绝覆盖；receipt 绑定 proposal、base/head、source/generator/policy 和双文件哈希；Markdown 转义控制字符。 | governance suite 覆盖标题/状态/列表/反引号/控制字符注入、单侧篡改、错误 provenance、旧 pair 重放、二次写入。 | 文件系统不提供跨卷原子性，因此实现限定同父目录 rename，并以 receipt 校验最终完整性。 |
| F-05 | README 与 M2/M3/M4/M5 指南区分 latest formal release `1.1.6` 和 main-only 能力，补齐入口与 candidate/adoption/CI/remote 边界。 | documentation、Profile Authority、Application Boundary、Stage Semantics、Governance、Module Lifecycle suite 均通过。 | 1.2.0 尚未发布前，所有这些能力仍只代表 `main`。 |
| V-01 | installed launcher 从 `plugin.json` 派生版本目录；安装器在完整 manifest 校验后恢复两个固定 Linux apphost 的执行位。 | Linux/Windows self-contained 与 installed-launcher 测试通过；缺失/篡改 apphost、PackageRoot 错配、receipt 和 relocation 负向控制通过。 | 本地证据是候选构建，不是正式发行资产；1.2.0 发布提交必须重建。 |
| V-02 | M2–M4 focused suites 纳入受保护 approvedTests；保持 Target/Package 不变、stale/cancel/security 和 local-advisory/trusted-CI 边界。 | PR #41 官方运行与本报告精确主线认证都执行 `tests/p10/Test-V4M2M5Focused.ps1`。 | 多项目、远端启用、性能 cadence 仍延期。 |
| V-03 | PR #40 先添加 base-held single-use authorization，PR #41 消费记录并更新 `ci-contract.json`；wrapper 哈希为 `5653de33…`。 | PR #41 官方 CI 运行 36833867882 全绿；精确主线 Guardrails/Certification 运行见 §4。 | approvedTests 的任何未来变更仍需新的两阶段授权，已消费记录不可复用。 |

## 4. 精确主线认证与资产证据

精确主线运行：

- Guardrails：[run 36835743320](https://github.com/von12549/Guard/actions/runs/36835743320)。
- 双平台 Certification：[run 36835746541](https://github.com/von12549/Guard/actions/runs/36835746541)。
- Linux 报告：Ubuntu 24.04.5、x64、PowerShell 7.6.6、.NET 10.0.401、Git 2.55.0；
  34 项 approved tests 全部通过。
- Windows 报告：Windows 10.0.26100、x64、PowerShell 7.6.6、.NET 10.0.401、
  Git 2.55.0.windows.5；35 项 approved tests 全部通过。
- 源码 `packageHash`：`f2112c4ac5b6c34f093e4a456596f7ab9e07d12991c5424f711cae35bbbc4e6e`。
- CI contract SHA-256：`9e893525a48096904f1ad7d24d56276c8c09be7c0e8d79a31c4584afc2365384`。

RID 自包含候选在同一源码提交上分别构建；它们包含不同原生二进制和 RID runtime manifest，
因此 ZIP 哈希应不同，不能要求跨 RID 字节相同：

| RID | archive SHA-256 | 内嵌 source commit | 结果 |
| --- | --- | --- | --- |
| `linux-x64` | `1373e2a00249d14c5502d41e9f055ccd13711eecc42241b4f34d295e3320c52a` | `fa7ae011…` | PASS |
| `win-x64` | `5cdd5ff8e2a9e4b00bde244df3ff026b9679fc951120ad13b02fd55cdb783fd6` | `fa7ae011…` | PASS |

CI report 的跨平台源码 packageHash 必须相同；RID 包内因生成 `runtime-manifest.json` 后重新计算
的包哈希是 RID 特定值，不替代上述源码 packageHash。证据文件、来源 URL、文件 SHA-256 和
本地外部 EvidenceRoot 记录在 `evidence/20261001-m1-m5-remediation/evidence-index.json` 与
`SHA256SUMS`。

## 5. M1–M5 状态矩阵

| 里程碑 | 实现/合并 | 文档 | 双平台测试 | 正式发布 | 远端采用 / 延期 |
| --- | --- | --- | --- | --- | --- |
| M1 | main 已实现 self-contained、安装 receipt、launcher；修复 PR #39 | 已同步 | PASS | 尚未进入 1.2.0 | project initialization、governance adoption、version lifecycle、retention 延期 |
| M2 | Profile discovery/draft/review/promotion local foundation 已合入 | 已同步 | PASS | 1.1.6 不含；计划进入 1.2.0 | Target `.guard/` adoption、composition selection、CI activation 延期 |
| M3 | typed application preview 与 Companion 边界已合入 | 已同步 | PASS | 1.1.6 不含；计划进入 1.2.0 | 多项目 dashboard、并行执行、remote activation 延期 |
| M4 | v2 dependency/gate/provider/timing 与 local advisory reuse 已合入 | 已同步 | PASS | 1.1.6 不含；计划进入 1.2.0 | trusted CI reuse、20-sample/30% 目标、Windows cadence 延期 |
| M5 | Plan/Module local foundation、trust authorization、pair 与 lifecycle 修复已合入 | 已同步 | PASS | 1.1.6 不含；计划进入 1.2.0 | 完整 Workbench、marketplace/signatures、CODEOWNERS、remote install 延期 |

“PASS”仅指本计划定义的实现和测试；不表示延期 roadmap、消费者采用或远端启用完成。M3
本次没有 UI 代码变化，因此无需新增浏览器视觉 QA；既有 Companion 安全边界由 approved tests
和 Application Boundary suite 回归。

## 6. 清单与发布边界

配套清单 A–E 的逐项状态以本报告最终提交为准。P1/P2/P4 与 approvedTests 变更都各自使用
精确 Plan pair；PR #40/#41 完成受保护 CI 变更的 authorization/trust-change 两阶段流程。
没有未知 diff，也没有复用已消费授权。

延期项不是本次必修 finding，保持 `DEFERRED`，不得进入 1.2.0 的已交付宣传。下一阶段仍需：

1. 新建 1.2.0 baseline rebind 的单次授权 PR；
2. 另一个 trust-change PR 消费它，升级产品/Host/Companion 版本并更新 release 文档；
3. 在最终 merge commit 重跑双平台认证、双位置可重复构建、candidate/recovery；
4. G-RELEASE 通过后才创建 annotated tag 和正式 Release。

## 7. G-REPAIR

`G-REPAIR = GO`（2026-10-01）。清单 A–D 与 E-01–E-04 全部 PASS，E-05 已满足。
允许开始 P5 的 1.2.0 授权、版本和文档工作。发布仍需 R-01–R-13 全部通过并取得独立的
`G-RELEASE = GO`；本报告中的 1.1.6 RID 候选不得直接作为 1.2.0 发布资产。
