# V4 Guards

V4 Guards is a self-contained, profile-driven guard package for inspecting repositories through four
independently runnable stages: Bootstrap, Analysis, Pre and Post. Version `1.2.2` is published from
immutable tag `v4-guards-v1.2.2`; the `1.2.1` release and earlier releases remain immutable.
The stable V4 1.0 command API and local, non-authoritative Web Companion are preserved.

Version **1.2.2** repairs proof expiry recovery, stale browser state, the first installed Companion
command and preflight safety evidence. Its exact source, certification and assets are governed by the
[1.2.2 release Plan](docs/plans/20261006-v4-guards-1-2-2-release.md) and
[final release report](docs/plans/20261006-v4-guards-1-2-2-release-report.md). The 1.2.1 release
remains available at its immutable tag `v4-guards-v1.2.1`.
Local success or a promotion candidate is still not consumer adoption, trusted CI enablement or remote
activation. See the [completed remediation and release program](docs/plans/20261001-m1-m5-remediation-and-1-2-0-release.md)
and [final release report](docs/plans/20261002-v4-guards-1-2-0-release-report.md).

V4 Guards is developed in this standalone repository (`von12549/Guard`). It was incubated in the IFX
repository, and its complete history was carried over; see the
[migration records](docs/migration/v4-todo-008/README.md). The product has no runtime dependency on
any consumer repository or on the earlier V3/V3_ifx guards. Consumer adoption, such as IFX's Profile
and cutover program, is owned and tracked by that consumer.

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

The 1.2.2 release uses two self-contained asset names,
`v4-guards-1.2.2-linux-x64.zip` and `v4-guards-1.2.2-win-x64.zip`. Each contains three hash-bound
payloads below the common root `v4-guards-1.2.2/`:

- `package/`: immutable V4 authorities and this README;
- `host/`: the `v4-guards` .NET Host; and
- `companion/`: the offline Web Companion with embedded UI assets.

The certified release targets are `linux-x64` and `win-x64`; portable and arm64 assets are not published.
The self-contained Host/Companion need PowerShell 7.4 or newer but no shared .NET runtime; selected modules
may add declared prerequisites. Installation and verified uninstall use
`core/distribution/Install-V4Distribution.ps1` plus an external receipt.
See [1.2.2 release notes](docs/1.2.2-release-notes.md),
[1.2.1 release notes](docs/1.2.1-release-notes.md),
[1.2.0 release notes](docs/1.2.0-release-notes.md),
[1.1.6 release notes](docs/1.1.6-release-notes.md),
[1.1.5 release notes](docs/1.1.5-release-notes.md),
[1.1.4 release notes](docs/1.1.4-release-notes.md),
[1.1.3 release notes](docs/1.1.3-release-notes.md),
[1.1.2 release notes](docs/1.1.2-release-notes.md),
[1.1.1 release notes](docs/1.1.1-release-notes.md), [1.1.0 release notes](docs/1.1.0-release-notes.md)
and [certification](docs/v1-certification.md).

Version `1.1.1` adds explicit offline Profile/module bundle composition.
It verifies an installed base and separate review record, creates a new sibling installation
with an external composition receipt, and gates Web Companion launch on receipt verification.
Synthetic tests do not approve a real bundle. It does not modify 1.1.0 or authorize IFX use. See the
[1.1.1 release notes](docs/1.1.1-release-notes.md).

Version `1.1.2` additionally passes declared Profile relative roots to
Architecture Conformance and restricts project/source scanning to their validated union.
Legacy empty or sole `.` scopes retain whole-TargetRoot behavior. This patch does not
approve or include the incomplete IFX bundle; see the release notes.

Version `1.1.3` prevents the Build Evidence Provider's isolated .NET CLI home from being
registered in the Windows User PATH. It adds no Profile, module, rule or IFX candidate content.

Version `1.1.6` adds the trusted-base authorization for approved-test and runner changes
(V4-TODO-014), passes `core.longpaths=true` to every trusted-base runner Git command (V4-TODO-017)
and makes independent Host and Web Companion builds of one commit produce a byte-identical archive
(V4-TODO-018). The archive no longer ships the Companion's static web assets manifests. See the
[1.1.6 release notes](docs/1.1.6-release-notes.md).

Version `1.1.5` is published from `von12549/Guard` after the V4-TODO-008 extraction. Its Host and Web
Companion are binary-equivalent to `1.1.4` apart from version metadata; the package differs only by the
standalone repository layout, test and certification paths, and the activation-ready trusted-base workflow
specimen. See the [1.1.5 release notes](docs/1.1.5-release-notes.md).

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
v4-guards plan <scaffold|finalize|verify-pair> ...
v4-guards target-trust <authorize|validate> ...
v4-guards profile <discover|draft|configure|review-template|validate|promote> ...
v4-guards application <preview|setup-progress|setup-action> ...
v4-guards reset <project|factory> --mode <preview|apply> ...
```

Use [commands.md](docs/commands.md) for stable syntax and [queries.md](docs/queries.md) for the
experimental read-only query surface. A Stage can run directly; dependency execution occurs only when
explicitly requested and is reported in order.

The `profile` and `application` entries are experimental M2/M3 surfaces. Version 1.2.2 retains the
typed onboarding operations and authority boundaries while repairing first-use state and recovery. Use the exact Profile syntax in
[Profile discovery and reviewed promotion](docs/profile-authority.md) and the typed preview syntax in
[Local application Workbench](docs/application-workbench.md). Neither surface applies Target changes,
selects a composition or activates CI/remote policy.

The experimental M4 semantic-contract v2 authority adds typed readiness/analysis providers, fail-closed
gate dependencies, timing and explicitly local-advisory Evidence diagnostics without changing the frozen
v1 command contract. See [versioned Stage semantics](docs/stage-semantics.md).

The experimental M5 local-governance surface enforces bounded Plan sets, creates non-authoritative Plan
proposals and exact-diff finalized pair candidates, and validates base-held target trust authorizations.
It writes candidates only below EvidenceRoot and never applies a Target or remote change. See
[Plan governance](docs/plan-governance.md) and
[target trust authorization](docs/target-trust-authorization.md).

## Profiles and modules

Profiles are declarative configuration. They select registered, hash-bound modules and may not provide
arbitrary executable paths or shell commands. The package ships `default` and `synthetic_profile`;
`ifx_profile` is not included in the 1.2.2 candidate or any earlier release. Module capabilities declare
readable/writable roots, permitted processes, network use and timeouts. See
[configuration.md](docs/configuration.md).

Version 1.1.4 defines an optional `workspaceEvidence` Profile capability.
When present, the Host performs one bounded, ordinal and link-safe TargetRoot projection per run,
records its hash in `authorityHashes`, and supplies its path/hash/target-commit binding only to modules
whose reviewed `readRoots` includes `EvidenceRoot`. Callers cannot inject this binding through the CLI.
Profiles that omit the property keep the existing execution path.

`core/modules/Invoke-V4ModuleLifecycle.ps1` provides the experimental M5 local Module lifecycle:
inventory, inspect, graph, metadata scaffold, validate, fixture test, diff, deterministic pack, review
preparation, compose and verify. Built-ins remain immutable, adapter source remains repository/IDE work,
and marketplace, signature, publication, selection and remote installation stay unavailable. See
[Module lifecycle](docs/module-lifecycle.md).

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

For a new project, the primary supported onboarding path is one installed-launcher command followed by
typed browser forms (replace the four local paths):

```powershell
pwsh -NoProfile -File <install>\package\guard-web.ps1 `
  -PrerequisiteReportPath <state>\web-prerequisites.json `
  --target-root <repository> --state-root <state> --evidence-root <evidence> --plan-root plans
```

Omitting `--port` selects an available loopback port. The ready report prints the actual address and
the four fixed roots. The installed public `guard-web.ps1` accepts the same command from another working
directory and when paths contain spaces.

Before installation, run the verified `core/distribution/Invoke-V4Preflight.ps1` from the extracted
package with an explicit absolute, already existing RunRoot, expected version and published package
hash. For a fresh external run directory (replace these three absolute paths and the published hash):

```powershell
$runRoot = 'C:\guard-runs\first-run'
$packageRoot = 'C:\downloads\v4-guards-1.2.2-win-x64\package'
$targetRoot = 'C:\projects\my-project'
pwsh -NoProfile -File (Join-Path $packageRoot 'core\distribution\Invoke-V4Preflight.ps1') `
  -Mode Prepare -RunRoot $runRoot -PackageRoot $packageRoot -TargetRoot $targetRoot `
  -StateRoot 'state' -EvidenceRoot 'evidence' -ReceiptPath 'receipts\install.json' `
  -ReportPath 'evidence\preflight-report.json' -ExpectedVersion '1.2.2' `
  -ExpectedPackageHash '<published package SHA-256>'
```

`Preview` validates package identity and topology without preparing directories; `Prepare` creates
only fresh StateRoot, EvidenceRoot and receipt parent and writes the report. The package and Target
must be outside RunRoot's mutable State/Evidence directories and pairwise disjoint.
Run `Checkpoint` with that baseline report after installation, every operation that may invoke dotnet,
and cleanup. Every invocation uses a new report path, records explicit booleans and hashes only, and
stops on host or Target drift. The UI displays the report's location and hash separately from its current
Host safety proof. See [1.2.2 repair notes](docs/1.2.2-release-notes.md).

The **First onboarding** stepper verifies installation, then captures a current hash-only
User/Machine-environment, Process-PATH and PowerShell-profile proof bound to the package, project and
Target before roots/discovery may pass. The proof has a visible ten-minute expiry; renewal is an explicit
action that archives the old bytes and requires a new Preview. It creates a Draft, validates a separate candidate, and writes
an intentionally incomplete human-review template below StateRoot. Project-reference checks require
an explicit non-empty forbidden-reference policy; graph-completeness checks require resolved project
references, and target-framework checks require an explicit framework policy. The browser cannot
submit raw paths, Host arguments, shell text, environment values, Target writes, activation, remote
changes or human acceptance. The public Host launcher no longer accepts a wrapper `-Profile` trick
for discovery or drafting.

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
Changes require an exact formal Plan (`docs/plans/<id>.plan.json`). In this repository, PackageRoot
is the repository root. Tests therefore write mutable output to a work root outside the checkout
(`<TEMP>/v4-guards-work/...`), never below immutable package authorities.

Pull requests are judged by the base-owned runner `integrations/github/Invoke-V4TrustedBase.ps1`. The
runner reads approved tests, the CI contract and its other verdict and certification components from
the base, as listed in `integrations/github/trust-policy.json`. Changing any of them needs a
single-use authorization record, which a separate `authorization` Plan adds and the `trust-change` diff
consumes. Every verdict records the hashes of the components that produced it. See
[genesis and autonomy §8.1](docs/plans/product/03-genesis-bootstrap-and-autonomy.md).

## Documentation map

- [Plans and repository governance](docs/plans/README.md)
- [Architecture decisions](docs/plans/product/00-architecture-decision-set.md)
- [Implementation roadmap](docs/plans/product/01-v4-self-contained-guard-plugin.md)
- [Runtime architecture](docs/plans/product/02-runtime-architecture.md)
- [Deferred work](docs/plans/product/TODO.md)
- [Plan governance](docs/plan-governance.md)
- [Target trust authorization](docs/target-trust-authorization.md)
- [Module lifecycle](docs/module-lifecycle.md)
- [Command reference](docs/commands.md)
- [Configuration reference](docs/configuration.md)
- [Query contracts](docs/queries.md)
- [Versioned Stage semantics and local Evidence](docs/stage-semantics.md)
- [Web Companion guide](integrations/web/README.md)
- [V4-P9 gate audit](docs/plans/product/05-p9-gate-audit.md)
- [Standalone migration records](docs/migration/v4-todo-008/README.md)

## Versioning and support

V4 uses semantic product versions. Releases `1.0.0` through `1.1.4` were published from the IFX
incubation repository, and they remain immutable at their original IFX release URLs. The first release
published from this repository uses a new, unused version. Defects found by consumers, including IFX's
Profile practice and parity program, are fixed in this repository and released as new versions.
Consumer testing does not itself activate V4 in any consumer.
