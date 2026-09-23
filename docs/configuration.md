# V4 configuration reference

Generated from package schemas and module manifests. Do not edit by hand.

## `plugin`

| Property | Required | Shape |
| --- | --- | --- |
| `apiVersion` | yes | constant |
| `contractsManifest` | yes | constant |
| `defaultProfile` | yes | constant |
| `formatVersion` | yes | constant |
| `id` | yes | constant |
| `modulesCatalog` | yes | constant |
| `profilesCatalog` | yes | constant |
| `version` | yes | string |

## `profile`

| Property | Required | Shape |
| --- | --- | --- |
| `baselineRefs` | yes | array |
| `formatVersion` | yes | constant |
| `id` | yes | string |
| `moduleSelections` | yes | array |
| `projectIdentity` | yes | object |
| `rules` | yes | array |
| `stageConfiguration` | yes | object |
| `version` | yes | string |

## `module`

| Property | Required | Shape |
| --- | --- | --- |
| `adapter` | yes | object |
| `authorities` | yes | array |
| `capabilities` | yes | object |
| `compatibleApi` | yes | constant |
| `configSchema` | yes | string |
| `dependencyLock` | yes | object |
| `formatVersion` | yes | constant |
| `id` | yes | string |
| `prerequisites` | yes | array |
| `resultSchema` | yes | string |
| `stages` | yes | array |
| `supportedPlatforms` | yes | array |
| `version` | yes | string |

## `runtime-requirements`

| Property | Required | Shape |
| --- | --- | --- |
| `formatVersion` | yes | constant |
| `requirements` | yes | array |

## Installed modules

| Module | Version | Platforms | Prerequisites | Stages |
| --- | --- | --- | --- | --- |
| `architecture-conformance` | 1.0.1 | linux-x64, win-x64 | pwsh >=7.4; dotnet >=10.0 <11.0 | pre, post |
| `build-evidence-provider` | 1.0.0 | linux-x64, win-x64 | pwsh >=7.4; dotnet >=10.0 <11.0 | post |
| `synthetic-probe` | 1.0.0 | linux-x64, win-x64 | pwsh >=7.4 | bootstrap, analysis, pre, post |
