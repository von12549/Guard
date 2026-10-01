# 校正文档中的 main、release、candidate 与采用边界

Status: `IMPLEMENTED AND LOCALLY VALIDATED — stacked PR/CI pending`

Formal Plan ID: `20261001-m1-m5-p3-release-boundary-docs`.

## Goal

关闭 F-05。README 和受影响指南必须区分 1.1.6 正式资产、当前 main 源码、候选输出、本地
advisory evidence、Target adoption、trusted CI 和 remote activation，并补齐 M2/M3 可发现入口。

## Decisions

- 1.1.6 保持最新正式 release，历史 release notes 不改写。
- M1–M5 foundations 在后续版本完成修复、双平台认证和发布前标记为 main-only。
- M2 promotion bundle 实际只携带 candidate Profile，manifest 的 `modules` 为空；Module selections
  依赖单独验证的 base installation，新增 Module bytes 走 M5 lifecycle/review。
- P1/P2 当前仅记录本地通过与堆叠 PR/CI pending，不提前记录合入或发布。

## Validation

运行 documentation、package 与 whitespace 验证，并核对 README 中的命令与实际 Host 合同。
