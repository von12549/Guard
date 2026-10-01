# 修复 Target Trust 与 Plan pair 完整性

Status: `IMPLEMENTED AND LOCALLY VALIDATED — stacked PR/CI pending`

Formal Plan ID: `20261001-m1-m5-p2-governance-integrity`.

## Goal

关闭 F-03/F-04。Target Trust 必须从受审 Git revision 的实际字节重算完整 Plan-set；Plan
finalization 必须生成注入安全且可核验的一致 pair，并定义覆盖失败和恢复语义。

## Target Trust boundary

验证器从 head object 读取 Plan-set 和每个成员 Plan，核对 schema 投影、成员 hash/identity、
dependency、canonical order、derived union 和 compositionHash。union 必须与 base/head 完整 diff
精确相等并拥有 Plan-set 自身路径。工作树、候选自报 hash 或未验证 union 不参与裁决。

## Pair protocol

finalization 在 EvidenceRoot 内创建全新 staging 目录，完成 JSON、escaped Markdown 和绑定 receipt
后才以目录 rename 提交；目标目录已存在即拒绝，不静默覆盖 finalized evidence。receipt 绑定两侧
hash 以及 proposal/base/head/source/generator/policy。`plan verify-pair` 用调用者提供的预期
provenance 验证 pair；失败 staging 可明确删除后重试，既有 finalized 目录保持不变。

## Planned paths

- `core/governance/validation/Test-V4GovernanceFoundation.ps1`
- `core/host/V4.Guards.Host/PlanRuntime.cs`
- `core/host/V4.Guards.Host/TargetTrustRuntime.cs`
- `docs/plan-governance.md`
- `docs/target-trust-authorization.md`
- `docs/plans/20261001-m1-m5-p2-governance-integrity.md`
- `docs/plans/20261001-m1-m5-p2-governance-integrity.plan.json`

本阶段不修改 Guard 自身 protected CI/certification components，也不应用或远端启用 Target 变更。
