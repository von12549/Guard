# 修复 installed launcher 的版本路径与 Linux 执行权限

Status: `IMPLEMENTED AND LOCALLY VALIDATED — stacked PR/CI pending`

Formal Plan ID: `20261001-m1-m5-p4-version-neutral-launcher-test`.

## Goal

`Test-V4InstalledLauncher.ps1` 从 PackageRoot 的 `plugin.json` 读取并校验 SemVer，再用实际版本
派生安装和 relocation 目录。1.2.0 升级不再依赖修改固定的 `v4-guards-1.1.6` 路径。

Linux ZIP extraction 不保留 executable bits。安装器在 distribution manifest 的全量文件/hash
验证和 runtime-manifest schema 验证后，只对固定的 self-contained Linux Host/Companion
apphost 恢复 execute bits；文件 bytes、manifest hash 和 receipt hash 仍保持不变。测试显式
断言两个 apphost 可执行，并通过不含 `dotnet` 的 PATH 启动 Host 及完成 relocation。

本变更不修改产品版本、安装器行为、用户 PATH、注册表、PowerShell profile 或发布资产。
