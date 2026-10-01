# 移除 installed launcher 测试中的固定版本路径

Status: `IMPLEMENTED AND LOCALLY VALIDATED — stacked PR/CI pending`

Formal Plan ID: `20261001-m1-m5-p4-version-neutral-launcher-test`.

## Goal

`Test-V4InstalledLauncher.ps1` 从 PackageRoot 的 `plugin.json` 读取并校验 SemVer，再用实际版本
派生安装和 relocation 目录。1.2.0 升级不再依赖修改固定的 `v4-guards-1.1.6` 路径。

本变更不修改产品版本、安装器行为、用户 PATH、注册表、PowerShell profile 或发布资产。
