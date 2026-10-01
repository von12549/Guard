# M1–M5 修复、复检报告与 1.2.0 发布检查清单

Status: `COMPLETE 2026-10-02 — G-REPAIR = GO；G-RELEASE = GO；1.2.0 已发布并独立验证`

程序 Plan：[20261001-m1-m5-remediation-and-1-2-0-release](20261001-m1-m5-remediation-and-1-2-0-release.md)。

## 填写规则

每项填写 PASS / FAIL / BLOCKED / NOT RUN / DEFERRED，并引用精确提交、平台、命令、退出码、
日志或 CI URL、证据文件与 SHA-256。只有 PASS 可勾选必需项；不能把审计基线的成功结果
预先填入修复验收。DEFERRED 仅用于明确的延期范围，不能用于逃避本计划必修项。

一个清单条目中的多个要求全部通过才可勾选。复检时在最终修复提交重新确认；1.2.0 版本、
代码或随包文档改变后，在最终发布提交重新确认受影响门禁。

## A. 基线与实施准备

- [x] A-01 记录审计基线 `56f049a3388ef10d2240fb6f9fb445724047b4ed`、实际实施 base/head、工作树状态，保留原有用户修改。
- [x] A-02 为每个实施阶段建立精确 Plan pair / 必要 Plan-set；检查 schema、路径唯一归属、成员哈希和实际 diff。
- [x] A-03 记录 Windows/Linux、PowerShell/.NET 版本、RID packs 和隔离环境；不写用户 PATH、注册表或 profiles。
- [x] A-04 为 F-01–F-05 固定触发输入和预期结果；静态发现若不成立，提供复现实证和替代结论，不直接删项。
- [x] A-05 恶意 adapter 用例在经过确认的隔离环境执行；建立测试根、sentinel、进程标识、日志与回收边界。
- [x] A-06 检查 protected paths / approved tests / compatibility baseline 是否受影响，完成适用的两阶段授权，不复用已消费记录。

## B. 必修缺陷

- [x] F-01a 正常 candidate fixture 通过，执行器遵循 manifest、Stage 输入/结果及退出分类。
- [x] F-01b 强制 timeout，取消与子进程挂起均在规定时间内结束；进程树回收且无测试进程遗留。
- [x] F-01c 子进程环境最小化，非必要宿主敏感变量不传入，无用户级环境副作用。
- [x] F-01d 对 Target/Package/State/Evidence 和外部 sentinel 的越界写有负向证据；不允许只检查 Target/Package 后宣称隔离。
- [x] F-01e 额外进程/网络请求与声明不符时拒绝；无法提供强制约束的平台拒绝非信任 adapter 执行或使用已认证隔离环境，文档准确描述保障边界。
- [x] F-02a adapter/profile/config/lock/fixture 文件自身及全部祖先的 link/reparse 检查通过。
- [x] F-02b 递归 pack/copy 检查每个输入；文件/目录 symlink、Windows junction/reparse 越界均拒绝。
- [x] F-02c 外部 sentinel 不被执行、不进入 ZIP、不被修改；普通包打包结果可重复。
- [x] F-03a 验证完整 Plan-set schema、实际成员 Plan、哈希、compositionHash、derived union、依赖和边界。
- [x] F-03b 伪哈希、缺失成员、重复身份、错误 union/hash、diff 未声明路径和混合自授权负向用例均拒绝。
- [x] F-03c 正确 set 与 authorization 正向通过；base-held policy、单次消费、protected paths exact-diff/hash 验证保持有效。
- [x] F-03d 验证使用明确 base/head revision 字节；工作树差异或候选自报 policy 不能改变裁决。
- [x] F-04a title/goal/criteria/command/source/generator/policy 等字段的 Markdown 注入与控制字符用例通过。
- [x] F-04b JSON 与 Markdown/proposal/provenance 可核验绑定；单侧篡改、旧 pair 重放或错误 base/head 可发现。
- [x] F-04c 第二次写入失败、磁盘/权限故障等不会留下可被判为成功的半 pair；失败保留旧有效 pair 或明确无效 receipt。
- [x] F-04d 已存在的 finalized evidence 不被静默覆盖；重试与恢复语义有测试和文档。
- [x] F-05a README 清楚区分 main-only 与最新正式 release，补齐 M2/M3 命令入口和指南链接。
- [x] F-05b Profile promotion candidate 的 Profile/Module 携带说明、能力保障和实际输出一致。
- [x] F-05c TODO、Plan 状态和功能文档与实现/合并/测试/发布证据一致；历史发布记录不被改写成当前事实。

## C. M1–M5 专项复检

- [x] M1-01 在依赖完整环境通过 `Test-V4SelfContainedDistribution.ps1`；Linux/Windows 各记录 exact commit 与结果。
- [x] M1-02 两平台通过 `Test-V4InstalledLauncher.ps1`，验证外部安装、receipt、PackageRoot 定位、篡改/缺失负向用例。
- [x] M1-03 分发/测试路径从实际产品版本派生或明确可配置；1.2.0 安装与启动 smoke 不依赖固定 1.1.6 目录。
- [x] M1-04 报告明确 project initialization/governance adoption/version lifecycle/storage retention 的实际完成状态。
- [x] M2-01 两平台通过 `Test-V4ProfileAuthority.ps1`，覆盖 discovery/draft/review/promotion 与负向用例。
- [x] M2-02 验证 Target/Package 未变化；candidate 未被默认视为已采用、selected composition 或 CI active。
- [x] M3-01 两平台通过 `Test-V4ApplicationBoundary.ps1`；setup/protection/lifecycle previews、Host/Companion 边界正确。
- [x] M3-02 stale/cancel/security 负向控制通过；若 UI 有变更，补充浏览器 QA；无变更时记录依据。
- [x] M3-03 多项目/并行执行与 remote activation 在报告中保持准确状态。
- [x] M4-01 两平台通过 `Test-V4StageSemantics.ps1`，验证 dependency/gate/provider/timing、v1/v2 隔离与负向控制。
- [x] M4-02 local advisory reuse 不成为 trusted CI evidence；缺少性能基线和 cadence 证据时不声称目标达成。
- [x] M5-01 两平台通过 `Test-V4GovernanceFoundation.ps1`，覆盖修复后的完整 set/trust/pair 负向矩阵。
- [x] M5-02 两平台通过 `Test-V4ModuleLifecycle.ps1`，覆盖执行权限、timeout、links、结果 schema 与 deterministic pack。
- [x] M5-03 Plan/Module UI、marketplace/signatures、CODEOWNERS 和消费者远端采用分别记录，不因本地测试成功而关闭延期项。

## D. 旧功能、双平台和证据完整性

- [x] D-01 contract/package/documentation、Plan runtime/diff、extension composition、stable CLI 与 affected regressions 全部通过。
- [x] D-02 对最终修复提交运行批准清单 Linux-complete 和 Windows-full，测试集合与 approvedTests 精确对应。
- [x] D-03 所有新增/修复 focused suites 有显式 Linux/Windows 运行记录；核对是否被 CI 调用，不用旧 green checks 替代。
- [x] D-04 `v4-contract`、`v4-linux`、`v4-package`、`v4-windows`、`v4-required` 通过，明确 Windows-full 的实际覆盖。
- [x] D-05 报告 source commit 相同，源码 packageHash 一致；每个 RID 的二进制 archiveHash 分别核验。
- [x] D-06 全部必需日志/报告/输入输出建立证据索引及 SHA256SUMS；无未知 diff、未解释环境/进程副作用。

## E. 修复后报告与 G-REPAIR

- [x] E-01 对最终修复提交结合 A–D 清单逐项复检，填写结果和证据；无必修 FAIL/BLOCKED/NOT RUN。
- [x] E-02 提供新的中文修复报告：每个 finding 的方法、位置、测试、残余风险和清单映射。
- [x] E-03 报告提供 M1–M5 实现/合并/文档/测试/跨平台/发布/远端状态矩阵。
- [x] E-04 报告明确延期项与建议优化，区分修复完成和完整 roadmap 完成。
- [x] E-05 `G-REPAIR = GO`：A–D 的全部必需项和 E-01–E-04 均 PASS；报告明确允许进入 1.2.0 升级。

G-REPAIR 记录：`GO 2026-10-01`。修复提交：
`fa7ae011b385233bdcaf6192f0971ffbe59aefc1`。报告：
`docs/plans/20261001-m1-m5-remediation-report.md`。证据索引：
`docs/plans/evidence/20261001-m1-m5-remediation/evidence-index.json` 与 `SHA256SUMS`。

**只有 G-REPAIR 全部通过后，才执行以下版本升级、文档更新和发布阶段。**

## F. 1.2.0 版本升级与文档

- [x] R-01 `plugin.json` 产品版本升级为 `1.2.0`，Host/Companion Version 为 `1.2.0`、AssemblyVersion 为 `1.2.0.0`。
- [x] R-02 搜索实际版本来源、路径/fixture/输出，消除影响新版本的硬编码；历史版本信息保持历史语义。
- [x] R-03 compatibility baseline 相关哈希通过适用授权更新；不机械修改 apiVersion/历史 baseline 字段，不降低批准测试。
- [x] R-04 更新 README、1.2.0 release notes、认证文档、受影响指南、Web Companion 文档、TODO 和实施状态。
- [x] R-05 release notes 列明修复、实际交付、平台/前提、升级恢复和延期项；文档未将未发布版本说成已发布。
- [x] R-06 固定发行模式、ZIP 名称、RID 与 sidecar 矩阵，验证 builder/installer 命名兼容；只声明获认证的平台。
- [x] R-07 版本/文档 PR #44 正常通过并合入；head `1f79b6ec…`、merge `968f6be9…`；后续认证修复 PR #49 形成最终 release commit `cf8a9cb6…`，未跳过检查。

## G. 精确发布提交认证与 G-RELEASE

- [x] R-08 最终提交 `cf8a9cb6…` 的 Certification run 36870399334：Linux-complete 35 项、Windows-full 36 项，包含 M1–M5 focused suites。
- [x] R-09 Guardrails run 36870395011 的 contract/Linux/package/Windows/required 全绿；两平台源码 packageHash 均为 `9fccf726…`。
- [x] R-10 两个 RID 均在两处干净 checkout 构建字节一致，重复打包一致，sidecar 与 ZIP 一致。
- [x] R-11 Linux/Windows 均完成 candidate、installation、四 Stage、Companion 与 recovery；restore commit `7f965126…`。
- [x] R-12 发布前复检 tag/Release 未占用；commit、运行、packageHash 和双 RID archiveHash 已固定。
- [x] R-13 `G-RELEASE = GO`：G-REPAIR、R-01–R-12 全部 PASS，全部发布证据绑定 `cf8a9cb6…`。

G-RELEASE 记录：`GO 2026-10-02`。发布提交：
`cf8a9cb631e120309568f18ac965540e381f8027`。认证/资产索引：
`docs/plans/20261002-v4-guards-1-2-0-release-report.md`。

## H. 正式发布、独立验证与最终报告

- [x] R-14 annotated tag `v4-guards-v1.2.0` 精确指向 `cf8a9cb6…`；`V4 Guards 1.2.0` 非 draft、非 prerelease。
- [x] R-15 Release 仅含两个 ZIP 与两个 sidecar，body 绑定 commit/认证/哈希，旧发布不变。
- [x] R-16 全部资产在新目录重新下载；GitHub digest、本地 SHA-256、sidecar 和 candidate archiveHash 一致。
- [x] R-17 Windows 10.0.26200 与隔离 Ubuntu 24.04.4 安装返回 1.2.0；四 Stage、M2–M5 五个 focused validators 和 Companion 全部通过。
- [x] R-18 两平台 receipt 最终均为 `uninstalled`，安装目录消失，Target/Package/宿主无非预期变化。
- [x] R-19 发布记录与最终中文报告已更新，包含 URL、tag/commit、哈希、认证、独立验证与延期范围。
- [x] R-20 R-14–R-19 全部完成；本程序标记 `COMPLETE`，发布后缺陷以新版本处理。

## 延期范围核对（不计为已通过能力）

| 里程碑 | 原有延期项 | 本次复检状态 / 证据 |
| --- | --- | --- |
| M1 | 初始化、Target governance adoption、版本选择/回滚、存储 retention | `DEFERRED`；1.2.0 仅发布 local foundation |
| M2 | Target `.guard/` 实际采用、composition selection、CI activation | `DEFERRED`；本地 candidate 与采用分开 |
| M3 | 多项目 dashboard、并行执行、CI/remote activation | `DEFERRED`；本地 preview 与启用分开 |
| M4 | trusted CI reuse、20-sample 基线/30% 目标、Windows cadence | `DEFERRED`；local advisory 不计为 trusted |
| M5 | 完整 Workbench、marketplace/signatures、CODEOWNERS、remote install | `DEFERRED`；local foundation 与生态分开 |

## 逐项证据记录模板

执行时为 A/F/M/D/E/R 各项填表，或提供具有相同字段的证据索引。

| 检查 ID | PASS/FAIL/BLOCKED/NOT RUN/DEFERRED | commit / 平台 | 命令 / 退出码 | 日志、报告或 CI URL / SHA-256 | 结论及残余风险 |
| --- | --- | --- | --- | --- | --- |
| A / F / M / D / E | PASS | `fa7ae011…`; Linux/Windows x64 | Guardrails 36835743320；Certification 36835746541；本地 package/docs/RID 验证均退出 0 | 报告 §2–§6；证据索引和 SHA256SUMS | 必修范围闭环；roadmap 延期项不计作 PASS |

中文复检报告必须给出 G-REPAIR 的 GO/NO-GO；最终发布报告必须给出 G-RELEASE、实际发布和独立验证结果。
