# 授权 V4 Guards 1.2.x onboarding 修复的受保护契约变更

Status: `AUTHORIZATION PR — V4 Guards 1.2.x onboarding repair`

Formal Plan ID: `20261005-v4-guards-1-2-x-onboarding-repair-authorization`。

V4 Guards 1.2.x onboarding 修复需要同步更新五个 approved test，并将它们的新 SHA-256
重绑定到 `integrations/github/ci-contract.json`。这些路径属于受信任裁决面，不能由同一个
candidate PR 自我授权。

本 PR 只增加 single-use 记录
`docs/plans/authorizations/20261005-v4-guards-1-2-x-onboarding-repair-record.json`，不修改测试、
CI 契约、产品实现、版本、baseline 或远端发布状态。独立 consuming Plan
`20261004-v4-guards-1-2-x-onboarding-repair` 必须精确产生以下字节：

| 文件 | base SHA-256 | authorized head SHA-256 |
| --- | --- | --- |
| `integrations/github/ci-contract.json` | `98b6de508a56ae9a9cfc47252baead65e60b0c3d3bfb40b9db8f7dd0644c4674` | `0c12dd450058c01a8de92409b04e7b0179f8dcd31c9d8dc65af11e3a50eaa246` |
| `tests/p4/Test-V4ArchitectureAuthority.ps1` | `e16fcea37d63486dd3a1b17c98706e2a725d7129ceeb02b2cefa22052cca0276` | `7f65b78d475f51bf78e154fab0be560e978ce2a4d2e352412a3c0595684a8d6a` |
| `tests/p4/Test-V4BuildEvidence.ps1` | `1df5432c6308aaad88d5d16c7c4b3e6d133ec8d1a4cdaebd9b2d8dc91a808e5f` | `33f045eba754154848a6d6c7a17b25170ab41ecaf96fb242cf9580822f46af38` |
| `tests/p4/Test-V4ProjectModel.ps1` | `9b981d0d9817ab085e50ae6f03d54b76b3ecde85ceb2215764b258e479dc2d5a` | `7ed79b66fe8fd1d970627dc901b7db824e00a71d65f01afca33a09a6fc87cac0` |
| `tests/p7/Test-V4Distribution.ps1` | `3d5fb570a2b0e603baf3e10a1e5c682378de74655ebc92e89fbccfe4e4012fc2` | `9a6e362a74b8850b56eed6ba03501315e7622d6408dd775e0d2118fda6df617f` |
| `tests/p9/Test-V4WebCompanionSpike.ps1` | `c80cfea180c53926c70abb92b3e28561a4b06936ecd69fd92c23c2cc20f49435` | `9097219b3260d0bb4ba8863db79d291c058189b01440eb4e4a7683570708c82a` |

后续 trust-change PR 必须从合入本记录的 base 读取它，精确匹配全部六个哈希变更，并删除记录
完成单次消费。任何字节偏差、遗漏、记录复用或 candidate 自报权威都应失败关闭。
