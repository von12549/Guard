# M1–M5 审计修复计划与 1.2.0 发布门禁

Status: `COMPLETE 2026-10-02 — G-REPAIR = GO；G-RELEASE = GO；1.2.0 已发布并独立验证`

Formal Plan ID: `20261001-m1-m5-remediation-and-1-2-0-release`.

配套文件：[正式 Plan JSON](20261001-m1-m5-remediation-and-1-2-0-release.plan.json)、
[修复与复检清单](20261001-m1-m5-remediation-checklist.md)。

## 1. 目标与执行承诺

依据 2026-10-01 的 M1–M5 检查结果，修复已识别的安全、治理、证据与文档问题，完成
M1–M5 的修复验证和受影响回归。**修复完成后，必须结合配套清单逐项复检，并再次提供
包含证据、未完成项和发布结论的中文报告。** 未通过、未运行、环境阻塞均不得记为通过。

**待 M1–M5 的修复和测试全部通过、复检报告确认放行后，将产品版本升级为 `1.2.0`，
更新相关文档，对升级后的精确提交重新认证，然后发布 `1.2.0` 并独立验证发布资产。**
任一必需门禁失败或缺少证据，都暂停后续升级或发布，修复后重新验证。

原始交付是计划与清单。修复与 G-REPAIR 已按 §9 完成；版本修改和发布仍由后续阶段执行。
本正式 Plan 的 `plannedPaths` 仅覆盖规划文件与索引；每个实施阶段在修改代码前建立
自己的精确 Plan pair，涉及受保护路径时遵循既有 base-held、single-use authorization 流程。
此程序计划不代替后续 PR 的 exact-diff Plan，也不代替受保护变更的授权记录。

## 2. 审计基线与完成定义

- 基线提交：`56f049a3388ef10d2240fb6f9fb445724047b4ed`，审计时 `main = origin/main`，工作树干净。
- M1–M5 分别通过 [PR #30](https://github.com/von12549/Guard/pull/30)、
  [#31](https://github.com/von12549/Guard/pull/31)、[#32](https://github.com/von12549/Guard/pull/32)、
  [#33](https://github.com/von12549/Guard/pull/33)、[#34](https://github.com/von12549/Guard/pull/34) 合并。
- 审计确认五个 PR 的 `v4-contract`、`v4-linux`、`v4-package`、`v4-windows`、`v4-required`
  全部成功；对应 Plan-set 的计划路径与实际 merge diff 为 55/55、27/27、38/38、26/26、30/30，
  成员文件哈希一致。此结论不能替代修复提交及 1.2.0 发布提交的测试。
- 审计时最新 release 为 [1.1.6](https://github.com/von12549/Guard/releases/tag/v4-guards-v1.1.6)，
  早于 M1–M5 合并；源码合入、CI 成功、正式发布、消费者安装与远端启用分别记录。
- 审计本地通过 package/documentation、M2 Profile Authority、M3 Application Boundary、
  M4 Stage Semantics、M5 Governance Foundation 和 Module Lifecycle 验证。
- M1 两项发布测试受离线环境缺少 .NET RID runtime packs 阻塞，未取得本地通过证据。

“M1–M5 修复完成”指本计划的必修项全部闭环且测试通过，不等于所有 M1–M5 远期功能完成。
发布说明必须准确描述交付范围；不得把 READY、DECISION COMPLETE、LOCAL FOUNDATION、
候选输出或本地验证写成已采用、已受 CI 信任或已远端启用。

下列原有延期项继续列入 TODO，并在复检报告逐项列明：M1 project initialization、
governance adoption、version lifecycle、storage retention；M2 Target `.guard/` 实际采用和
composition selection；M3 多项目 dashboard/并行执行与远端启用；M4 trusted CI reuse、
性能目标与 Windows cadence 决策；M5 完整 Plan/Module Workbench、marketplace、签名和 CODEOWNERS。
这些延期项不能标成 PASS，也不作为已交付能力进入 1.2.0 宣传。
若后续决定纳入某项，先扩展实施 Plan 与清单，再实现并验证；不得静默扩大范围。

## 3. 修复项目与验收标准

| ID | 优先级 / 范围 | 修复要求 | 必需证据与通过标准 |
| --- | --- | --- | --- |
| F-01 | 高 / M5 Module 执行 | 替换直接 `pwsh -File` 的无约束执行路径；落实 timeout、取消与进程树回收，最小化子进程环境；统一使用明确的 capability 编排入口；禁止无权限执行的候选 adapter。 | 正向 fixture 通过；超时、子进程挂起、取消、额外进程、越界写与网络用例得到预期拒绝；结束后无测试进程遗留，无非授权路径变化。 |
| F-02 | 高 / M5 路径边界 | adapter/profile/config/lock/fixtures/打包输入检查文件本身及全部祖先；拒绝 symlink/reparse/junction 等跨边界入口；递归枚举与复制前逐项验证。 | Linux 文件/目录 symlink 与 Windows reparse/junction 用例均失败关闭；外部 sentinel 未执行、未读取进入包、未修改；普通包仍可重复构建。 |
| F-03 | 中 / M5 Target Trust | 完整验证候选 Plan-set schema、成员 Plan 内容和哈希、compositionHash、derived union、依赖和边界；验证精确候选 diff；读取受审 Git revision 的字节，不使用工作树或候选自报权威。 | 伪造成员哈希、缺失 Plan、错误 compositionHash/union、重复身份、路径遗漏与自授权均拒绝；正确 set 与一次性授权正向通过，保护路径 exact-diff/hash 校验保持有效。 |
| F-04 | 中 / M5 Plan pair | 对 Markdown 各上下文安全渲染，限制控制字符；绑定 JSON/Markdown 与 proposal/source/generator/policy/base/head provenance；定义 pair 提交、覆盖和失败恢复协议。 | 注入标题、伪状态、换行、反引号、列表及控制字符不能伪造审阅结论；故障注入不留下可被视为成功的半 pair；篡改单侧被发现，既有证据不被静默覆盖。 |
| F-05 | 低 / M1–M5 文档 | 标注当前 release 与 main-only 能力；补齐 M2/M3 入口；同步 README、功能指南、TODO 和 Plan 状态；核对 M2 promotion bundle 的 Profile/Module 携带说明与实际输出。 | 所有用户命令和链接可验证；candidate、local advisory、trusted CI、adoption、release、remote activation 描述与实际证据一致；历史 release 文档保持历史事实。 |
| V-01 | 阻断验证 / M1 | 在依赖完整的干净环境重跑 self-contained distribution 和 installed launcher；确认构建/运行前提、安装 receipt 与 PackageRoot 定位；定位需要版本参数化的测试/路径。 | `linux-x64`、`win-x64` 各有同一修复提交上的通过证据；缺包导致的未运行不再存在；没有改写用户 PATH/注册表/配置；1.2.0 不依赖硬编码 1.1.6 安装路径。 |
| V-02 | 回归 / M2–M4 | 验证 Profile discovery/draft/review/promotion、typed application preview、Companion 安全边界、Stage dependency/timing/local advisory reuse；同步完整交付/延期矩阵。 | 对同一修复提交运行必需测试并通过；Target/Package 不变、stale/cancel/security 负向控制有效；本地 evidence 不成为 trusted CI authority。 |
| V-03 | 跨平台与供应链 | 对受影响旧功能运行完整批准测试，并在 Linux/Windows 显式运行新增 focused suites；核对 CI 测试清单是否覆盖这些 suites。 | 旧批准测试 + 新 focused suites 均有实际运行记录；当前 green checks 不能代替未被 CI 收录的新增测试；同一源码 packageHash 对齐，RID 资产哈希分别记录。 |

F-01 的威胁边界必须先复核并写入实施 Plan。现有 V4-AD-024 不承诺所有平台都具有 OS sandbox；
不能将 manifest 声明或执行后哈希比较解释为系统级强制隔离。对可控的编排、路径、环境和
超时落实负向控制；对无法约束的任意 adapter 权限，应拒绝非信任候选执行或采用经认证的
隔离环境。仅修改措辞不能关闭无限挂起、泄漏宿主敏感环境或任意越界执行问题。

F-02 的恶意 adapter 不在真实用户目录运行。测试使用隔离临时根、外部 sentinel 和明确的
进程标识；仅回收本次测试创建的进程及根，保留失败日志与哈希证据。

F-03 的实际实现入口由复现结果决定；验证必须涵盖完整 set 的一致性，不能通过把现有
伪哈希 fixture 改成真哈希而掩盖缺失校验。F-04 的 pair 成功定义必须能检测故障，不要求
底层文件系统支持不存在的双文件原子操作；可用完整目录提交或绑定 receipt 达成。

## 4. 实施顺序与阶段交付

| 阶段 | 输入 / 行动 | 输出 / 放行条件 |
| --- | --- | --- |
| P0 基线复核 | 记录实际 HEAD、工具版本、测试环境；逐项复现 F-01–F-05；区分静态发现、可复现实例和环境限制；建立精确实施 Plans。 | 每个 finding 有固定 ID、触发条件、预期行为、实施路径与清单映射；不得执行无约束恶意 fixture。 |
| P1 高风险修复 | 先完成 F-01、F-02；按最小闭环交付执行器和路径检查。 | 高风险正负测试通过；候选执行/打包边界可验证。 |
| P2 治理修复 | 完成 F-03、F-04，补充针对攻击与故障的测试。 | 完整 Plan-set 与一次性授权校验、审阅内容和 pair 一致性通过。 |
| P3 文档与回归 | 完成 F-05、V-01–V-03；核对五个里程碑状态和 CI 新增 suite 覆盖。 | 必修项全部 PASS，双平台修复验证通过，无未解释回归；延期项清楚标识。 |
| P4 清单复检与报告 | 对最后的修复提交逐项复检，不沿用早期提交的证据。 | 输出修复后中文报告，附证据索引、M1–M5 矩阵、每项结论及 GO/NO-GO；G-REPAIR 全部通过。 |
| P5 1.2.0 升级与文档 | G-REPAIR 通过后修改版本和发行文档，处理 protected compatibility baseline 授权；正常 PR 合入。 | product、Host、Companion 版本一致，文档与实际交付一致；版本提交与最终合入提交测试通过。 |
| P6 精确提交认证 | 在最终发布提交运行 Linux-complete、Windows-full 和全部 M1–M5 focused suites；构建干净资产、验证可重复性、候选与恢复认证。 | G-RELEASE 全部通过，证据绑定 commit/packageHash/每个资产 SHA-256。 |
| P7 发布与独立验证 | 创建 annotated tag `v4-guards-v1.2.0`，发布正式 GitHub Release；重新下载并独立安装、运行、卸载。 | 资产和 sidecar 正确，安装版本 1.2.0，四个 Stage 与交付新功能 smoke 通过；输出最终发布报告并更新记录。 |

若复检发现新问题，保持原 finding ID 并添加新 ID，修复后重跑受影响测试。
更改代码、打包输入、版本或随包文档会改变发布证据；在变更后的提交重新验证。
后续实施 Plan 及清单中增加的必需测试同样是发布门禁。

## 5. 测试入口和证据规则

从仓库根运行以下已存在的 focused suites，分别记录平台、源码提交、命令、退出码、日志
哈希和结果；F-01–F-04 对应新增负向测试由实施 Plan 声明。

```powershell
pwsh -NoProfile -File core/distribution/validation/Test-V4SelfContainedDistribution.ps1
pwsh -NoProfile -File core/distribution/validation/Test-V4InstalledLauncher.ps1
pwsh -NoProfile -File core/profile/validation/Test-V4ProfileAuthority.ps1
pwsh -NoProfile -File core/application/validation/Test-V4ApplicationBoundary.ps1
pwsh -NoProfile -File core/stage/validation/Test-V4StageSemantics.ps1
pwsh -NoProfile -File core/governance/validation/Test-V4GovernanceFoundation.ps1
pwsh -NoProfile -File core/modules/validation/Test-V4ModuleLifecycle.ps1
pwsh -NoProfile -File core/runtime/Test-V4Package.ps1 -PackageRoot .
pwsh -NoProfile -File tests/p7/Test-V4Documentation.ps1
```

完整回归按 `integrations/github/ci-contract.json` 的 Linux-complete/Windows-full 批准清单执行；
至少覆盖 contract、Plan/diff、trusted base、extension composition、distribution/lifecycle、
stable CLI、compatibility/supply-chain 和 Web Companion。批准测试清单、runner、workflow、
certification components 等受保护路径若需变更，必须走既有两阶段授权，不降低检查。

新版 focused suites 若不在批准清单中，P3 必须补齐独立 Linux/Windows 执行证据；如决定收录
CI authority，另列精确 trust-change Plan。不能因旧检查名称绿色就声称新增 suite 已在 CI 运行。

证据放入明确的外部 EvidenceRoot，并建立 SHA256SUMS 索引。报告可保存至
`docs/plans/20261001-m1-m5-remediation-report.md`，由后续报告 Plan 声明路径。
证据标注 PASS / FAIL / BLOCKED / NOT RUN / DEFERRED；仅 PASS 可满足必需门禁。
每个平台报告绑定同一个源码提交与源码 packageHash；不同 RID 的二进制资产各有自己的
SHA-256，不能要求 Linux 与 Windows 二进制 ZIP 相同。

## 6. 复检报告必须包含的内容

修复后必须重新提供报告，且报告本身能独立阅读：

1. 审计基线、修复提交、最终 HEAD、工作树状态和测试环境。
2. F-01–F-05、V-01–V-03 的修复方法、代码位置、正负测试和残余风险。
3. 清单逐项结果与证据位置；未通过或未运行项及其原因。
4. M1–M5 的实现、合并、文档、测试、跨平台、发布及远端采用状态矩阵。
5. 延期项与优化建议，清楚区分必须修复和仍未交付的远期功能。
6. `G-REPAIR` 的 GO/NO-GO，说明是否允许进入 1.2.0 升级阶段。

P7 后再提供最终发布报告，列出 `G-RELEASE` 结果、认证运行、精确 release commit、tag、
Release URL、资产清单与哈希、独立安装/运行/卸载结果和仍延期的范围。

## 7. 1.2.0 版本、文档与发布要求

P5 只在 G-REPAIR 全部通过后开始，至少处理：

- `plugin.json` 产品版本 `1.2.0`。
- Host 和 Web Companion `.csproj` 的版本 `1.2.0`，AssemblyVersion `1.2.0.0`；核对其他
  实际版本来源、硬编码目录、fixture、安装输出和生成文档。
- `core/certification/compatibility-baseline.json` 中相关哈希遵循受保护授权流程更新。
  `apiVersion` 及历史 baseline 字段按实际语义处理，不能机械替换全部 `1.1.x`。
- README 当前版本、安装/运行前提、源码与 release 差异、M2/M3 入口及交付边界。
- `docs/1.2.0-release-notes.md`、`docs/v1-certification.md`、受影响功能指南、
  `integrations/web/README.md`、product TODO 与实施 Plan 状态。
- release notes 描述实际修复、支持平台、升级/恢复步骤、candidate/local advisory 限制，
  显式列出未交付的 M1–M5 子项；不把条件发布写成已发布。

P6 使用 1.1.6 已建立的认证原则：精确 PR head 与最终 merge/release commit 分别验证；
Linux-complete 和 Windows-full 报告具有相同源码 packageHash；同一 RID/输入在两处干净
checkout 构建的资产字节一致；同一构建输入两次打包一致；安装、卸载、供应链与恢复认证通过。
Host/Companion 本次含功能修复，因此不照搬 1.1.6 的“与上一版 IL 仅版本不同”验收条件。

P5 在正式 release Plan 内固定发行模式及资产矩阵。若发布 M1 RID 自包含能力，分别认证并
发布 `linux-x64`、`win-x64` 资产，解决当前 builder 同名 ZIP 的输出目录/命名策略，并核对
安装器兼容性；若保留 portable 发行，也需独立验证并写清 .NET/PowerShell 前提。
不发布或宣传未经认证的 arm64。资产矩阵固定后写入清单和 release notes，不允许静默缩减
必需平台或用未交付资产冒充已发布自包含支持。

P7 的 tag 为 `v4-guards-v1.2.0`，Release 为 `V4 Guards 1.2.0`，正式发布时非 draft、非 prerelease。
每个 ZIP 都有 SHA-256 sidecar，release body 绑定修复、认证、commit 和证据链接。
发布前确认 tag/version 尚未占用，已存在时停止；不覆盖历史 tag 或资产。
重新下载的资产必须匹配认证哈希，在外部 synthetic Target 上验证安装版本、四个 Stage、
实际交付的 M2–M5 smoke、Companion 以及 verified uninstall，并记录 Package/Target 不变证据。

## 8. 停止条件与恢复

必修 finding 未关闭、测试失败/阻塞/未运行、证据提交不一致、未知路径变更、授权不匹配、
非预期 Target/Package/宿主环境变化、不可重复构建、文档夸大、资产缺失或 1.2.0 已占用时
停止对应阶段并记录 NO-GO。

发布前通过 reviewed revert 恢复最近合格 checkpoint；保留失败证据，已消费授权不得重用。
发布后保持 tag/资产不可变；出现问题以新的修复版本处理，并通知消费者。
本程序完成需要：修复复检报告、1.2.0 发布、独立验证和最终发布报告全部完成。

## 9. G-REPAIR 结果（2026-10-01）

PR #35–#41 依次完成计划校准、F-01–F-05、版本中性 launcher/Linux execute-bit 修复以及
focused suite 的 single-use authorization/trust-change。最终修复提交为
`fa7ae011b385233bdcaf6192f0971ffbe59aefc1`。

- V4 Guardrails run 36835743320：contract、Linux、package、Windows-full、required 全部成功；
- V4 Certification run 36835746541：Linux-complete 与 Windows-full 成功，源码 packageHash
  均为 `f2112c4ac5b6c34f093e4a456596f7ab9e07d12991c5424f711cae35bbbc4e6e`；
- `linux-x64` 与 `win-x64` 自包含修复候选的 archiveHash 分别记录，安装/launcher 与 focused
  suites 在两平台通过；
- 清单 A–E 全部 PASS；原有 roadmap 延期项仍明确延期。

独立报告为 [20261001-m1-m5-remediation-report](20261001-m1-m5-remediation-report.md)，证据
索引位于 `evidence/20261001-m1-m5-remediation/`。结论：`G-REPAIR = GO`。允许进入 P5，
但在 G-RELEASE 前不得创建 1.2.0 tag 或正式 Release。

## 10. P5 版本候选

Plan `20261001-v4-guards-1-2-0-release` 将产品、Host 和 Companion 升级为 1.2.0，消费 R0
single-use baseline 授权，并固定 self-contained `linux-x64`/`win-x64` 两 ZIP 加 sidecar 的发行
矩阵。版本 PR 及其精确 head 认证通过前不合并；最终 main merge commit 还必须重新执行 P6。
该阶段状态仅为 release candidate，当时不是发布记录。

## 11. P6/P7 发布结果（2026-10-02）

最终 release commit `cf8a9cb631e120309568f18ac965540e381f8027` 的 Guardrails run 36870395011
与 Certification run 36870399334 全部通过；Linux-complete 35 项、Windows-full 36 项共享
源码 `packageHash` `9fccf726207fe6674908e0e40a68efb8c6bd68d2fe347bf252b91af0efeced12`。

`linux-x64` 与 `win-x64` 资产分别为
`2404abdcc3f5a94ca0d22487ff1e399d093c9ec8e834ec8127bdf4f7c7c0fb56` 与
`03d0a439add97b59855508d70d6748b9165343806824d40582154befb8164b60`；双位置构建、重复打包、
sidecar、candidate/recovery 均通过。`G-RELEASE = GO` 后创建 annotated tag
`v4-guards-v1.2.0` 和正式 Release。重新下载的两个资产在 Windows 与隔离 Linux
分别通过 1.2.0 版本、四 Stage、M2–M5 focused smoke、Companion、receipt 与 verified
uninstall。最终记录见 `20261002-v4-guards-1-2-0-release-report.md`。
