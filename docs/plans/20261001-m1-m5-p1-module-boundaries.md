# 修复候选 Module 执行与链接路径边界

Status: `IMPLEMENTED AND LOCALLY VALIDATED — stacked PR/CI pending`

Formal Plan ID: `20261001-m1-m5-p1-module-boundaries`.

## Goal

关闭 F-01/F-02。候选 Module 默认不执行；只有显式 `AllowSyntheticFixture` 的隔离测试可以进入
受控进程入口。入口负责最小环境、manifest timeout、失败/取消时的进程树回收，并在任何递归
读取或复制前拒绝文件、目录及其祖先上的 symlink/reparse point。

## Threat boundary

- candidate manifest 是非信任请求，不是 capability enforcement，也不是 OS sandbox；`network=false`
  或执行后 tree hash 不能证明任意 adapter 没有访问宿主资源。
- 本阶段因此拒绝生产/普通候选执行。合成 fixture 只用于 Guard 自身测试，位于隔离临时根，
  使用外部 sentinel、唯一进程标识和有界 timeout；测试只回收自己创建的进程树。
- 允许的合成执行仍只接受 `pwsh`、`network=false`、无 Target 写权限，并清空继承环境后加入
  必需运行变量。Target、candidate Package 与 State 的校验是检测层，不表述为强制隔离。
- path validation 检查最终对象本身及所有现存祖先；pack 不使用未经逐项验证的递归复制。

## Planned paths

- `core/modules/Invoke-V4ModuleLifecycle.ps1`
- `core/modules/validation/Test-V4ModuleLifecycle.ps1`
- `docs/module-lifecycle.md`
- `docs/plans/20261001-m1-m5-p1-module-boundaries.md`
- `docs/plans/20261001-m1-m5-p1-module-boundaries.plan.json`

## Acceptance and validation

- 正常 fixture 通过，宿主秘密环境变量不泄漏。
- 未授权、网络/额外进程请求在启动前拒绝；timeout 和子进程 fixture 在规定时间内终止且不留下
  延迟 sentinel。
- adapter/profile/config/lock/fixture 自身链接以及递归 pack 输入链接均失败关闭；外部内容不进入包。
- 两次普通 pack 字节一致，运行既有 package 验证和 `git diff --check`。

本 Plan 不修改 approved tests、CI contract、certification components 或远端激活状态。
