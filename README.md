# V4 Guards

V4 Guards is a self-contained, profile-driven guard package for inspecting repositories through four
independently runnable stages: Bootstrap, Analysis, Pre and Post. Version `1.1.4` adds
opt-in reusable Host workspace evidence; earlier releases remain immutable.
The stable V4 1.0 command API and local, non-authoritative Web Companion are preserved.

V4 is developed inside this repository, but it does not depend on V3/V3_ifx at runtime. The active IFX
guard remains V3/V3_ifx until a separately reviewed parity, cutover and rollback program completes.

## Runtime model

Every command resolves four explicit roots:

| Root | Purpose | Mutability |
| --- | --- | --- |
| `PackageRoot` | Host, contracts, Profiles, modules and documentation | Immutable |
| `TargetRoot` | Repository being inspected | Read-only by default |
| `StateRoot` | Project binding, transactions, locks and reset receipts | V4-owned mutable data |
| `EvidenceRoot` | Stage results, reports and evidence | V4-owned mutable data |

The package location never implies the Target. Paths are canonicalized and link/reparse-point escape,
root overlap and undeclared write capability fail closed.

### Windows child-process environment isolation

The Build Evidence Provider creates a per-run `cli-home` below `StateRoot` and passes it to `dotnet`
as `DOTNET_CLI_HOME`. Every V4 guard, test or fixture that supplies an isolated
`DOTNET_CLI_HOME` must also set `DOTNET_ADD_GLOBAL_TOOLS_TO_PATH=0` in that child process. Without
the opt-out, the .NET SDK can permanently register `<DOTNET_CLI_HOME>\.dotnet\tools` in the Windows
User PATH during first-time initialization. Artifact retention never permits that host-level side
effect.

Guard and test runtime code must not write User/Machine environment variables, registry environment
keys or PowerShell profiles. Isolation belongs in `ProcessStartInfo.Environment` (or the equivalent
child-process environment) and must not replace the User PATH with the current process `$env:PATH`.
The normal user tool path such as `%USERPROFILE%\.dotnet\tools` is outside V4 state and must remain
untouched.

## Distribution and prerequisites

The `1.1.4` archive is named `v4-guards-1.1.4.zip` and contains three hash-bound payloads:

- `package/`: immutable V4 authorities and this README;
- `host/`: the `v4-guards` .NET Host; and
- `companion/`: the offline Web Companion with embedded UI assets.

The supported release targets are `linux-x64` and `win-x64`. The declared host prerequisites are
PowerShell 7.4 or newer and .NET 10.x; selected modules may add declared prerequisites. Installation
and verified uninstall use `core/distribution/Install-V4Distribution.ps1` plus an external receipt.
See [1.1.4 release notes](docs/1.1.4-release-notes.md),
[1.1.3 release notes](docs/1.1.3-release-notes.md),
[1.1.2 release notes](docs/1.1.2-release-notes.md),
[1.1.1 release notes](docs/1.1.1-release-notes.md), [1.1.0 release notes](docs/1.1.0-release-notes.md)
and [certification](docs/v1-certification.md).

Version `1.1.1` adds explicit offline Profile/module bundle composition.
It verifies an installed base and separate review record, creates a new sibling installation
with an external composition receipt, and gates Web Companion launch on receipt verification.
Synthetic tests do not approve a real bundle. It does not modify 1.1.0 or authorize IFX use. See the
[compatibility Plan](plans/08-p10-1-extension-composition-compatibility.md).

Version `1.1.2` additionally passes declared Profile relative roots to
Architecture Conformance and restricts project/source scanning to their validated union.
Legacy empty or sole `.` scopes retain whole-TargetRoot behavior. This patch does not
approve or include the incomplete IFX bundle; see the release notes.

Version `1.1.3` prevents the Build Evidence Provider's isolated .NET CLI home from being
registered in the Windows User PATH. It adds no Profile, module, rule or IFX candidate content.

Version `1.1.4` lets a Profile opt into one Host-generated workspace evidence document per
stage run. Eligible modules reuse its deterministic, schema-bound inventory and hashes instead
of repeating repository traversal. Profiles that omit the declaration keep the prior behavior.

## CLI

The Host returns structured JSON and stable exit categories. Its principal commands are:

```text
v4-guards version
v4-guards contract validate ...
v4-guards stage run --stage <bootstrap|analysis|pre|post> ...
v4-guards query <project|profiles|doctor|runs|evidence|plans> ...
v4-guards plan <validate|compose> ...
v4-guards reset <project|factory> --mode <preview|apply> ...
```

Use [commands.md](docs/commands.md) for stable syntax and [queries.md](docs/queries.md) for the
experimental read-only query surface. A Stage can run directly; dependency execution occurs only when
explicitly requested and is reported in order.

## Profiles and modules

Profiles are declarative configuration. They select registered, hash-bound modules and may not provide
arbitrary executable paths or shell commands. The package ships `default` and `synthetic_profile`;
`ifx_profile` is not included in the 1.1.4 base or earlier releases. Module capabilities declare readable/writable roots, permitted
processes, network use and timeouts. See [configuration.md](docs/configuration.md).

Version 1.1.4 defines an optional `workspaceEvidence` Profile capability.
When present, the Host performs one bounded, ordinal and link-safe TargetRoot projection per run,
records its hash in `authorityHashes`, and supplies its path/hash/target-commit binding only to modules
whose reviewed `readRoots` includes `EvidenceRoot`. Callers cannot inject this binding through the CLI.
Profiles that omit the property keep the existing execution path.

## Reset safety

Project and factory reset are Host CLI operations over V4-owned StateRoot and EvidenceRoot data. Apply
requires the exact manifest hash returned by Preview, records recovery evidence and refuses authority,
Target, worktree, link or unclaimed paths. The 1.1.1 Web Companion does not expose Reset Preview or
Reset Apply.

## Local Web Companion

The Web Companion listens only on IPv4 loopback, serves immutable embedded assets and calls the fixed
V4 Host through structured arguments with shell execution disabled. It provides one-active-Target
selection, readiness, manual Stage execution, evidence inspection and a read-only Plan Center.

It is a presentation/control surface, not a policy or verdict authority. It provides no browser path
input, authority or Plan editing, Target mutation, Reset, Git/PR operation, terminal/raw arguments,
remote access, automatic extension installation, multi-project parallelism or IFX-specific action.
See the [Web Companion guide](integrations/web/README.md).

## Validation and development

The package is deterministic and offline-buildable. Package integrity can be checked from a source or
installed package root:

```powershell
pwsh -NoProfile -File core/runtime/Test-V4Package.ps1 -PackageRoot .
```

The source checkout additionally provides the complete regression suite, including:

```powershell
pwsh -NoProfile -File tests/p7/Test-V4Distribution.ps1
pwsh -NoProfile -File tests/p8/Test-V4SupplyChain.ps1
```

Release certification requires the exact hash-approved Linux-complete and Windows-full suites against
one clean commit and package hash. Generated documentation is checked rather than silently rewritten.
Changes require an exact formal Plan; mutable output belongs under the repository `artifacts/` tree,
never below immutable package authorities.

## Documentation map

- [Architecture decisions](plans/00-architecture-decision-set.md)
- [Implementation roadmap](plans/01-v4-self-contained-guard-plugin.md)
- [Runtime architecture](plans/02-runtime-architecture.md)
- [Deferred work](plans/TODO.md)
- [Command reference](docs/commands.md)
- [Configuration reference](docs/configuration.md)
- [Query contracts](docs/queries.md)
- [Web Companion guide](integrations/web/README.md)
- [V4-P9 gate audit](plans/05-p9-gate-audit.md)

## Versioning and support

V4 uses semantic product versions. The `1.1.x` line is the baseline for the planned IFX Profile
practice and parity program; defects found by that program are fixed in this source package first and
released as `1.1.x` patches. Profile testing does not itself activate V4 for IFX.
