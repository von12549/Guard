# V4 architecture decision set

Status: architecture discussion baseline

Date: 2026-09-21
Implementation authorization: none

Architecture view: [02-runtime-architecture.md](02-runtime-architecture.md)

## Decision summary

| ID | Decision | Status |
| --- | --- | --- |
| V4-AD-001 | One self-contained plugin, no `V4_ifx` package | ACCEPTED |
| V4-AD-002 | Operationally self-contained v1 with declared host runtimes | ACCEPTED |
| V4-AD-003 | Immutable plugin authorities separated from mutable state/artifacts | ACCEPTED |
| V4-AD-004 | Profiles contain configuration and module references, not arbitrary executable code | ACCEPTED |
| V4-AD-005 | V4 v1 ships default and synthetic profiles only | ACCEPTED |
| V4-AD-006 | IFX becomes a post-v1 profile/extension practice | DEFERRED |
| V4-AD-007 | Bootstrap, Analysis, Pre and Post are independently runnable local stages | ACCEPTED |
| V4-AD-008 | Git Diff and CI are integrations, not local-stage prerequisites | ACCEPTED |
| V4-AD-009 | Factory reset is manifest-driven, previewed, accepted and path-confined | ACCEPTED |
| V4-AD-010 | JSON Schema is the configuration and future UI contract | ACCEPTED |
| V4-AD-011 | Extension modules are versioned, capability-declared and hash-bound | ACCEPTED |
| V4-AD-012 | Linux-first CI with conditional Windows smoke and milestone full certification | ACCEPTED |
| V4-AD-013 | One root plan or plan-set per PR, with deterministic composition | ACCEPTED |
| V4-AD-014 | V4 incubates on `codex/v4-development-base` as inactive additive code | ACCEPTED |
| V4-AD-015 | CI promotion continues to use a trusted base; head never judges itself | ACCEPTED |
| V4-AD-016 | .NET CLI host plus PowerShell/.NET module adapters | ACCEPTED |
| V4-AD-017 | Web UI starts only after stable CLI/config/report contracts | DEFERRED |
| V4-AD-018 | Fully bundled runtimes and zero-prerequisite distribution | DEFERRED |
| V4-AD-019 | Standalone repository extraction before external stable release | DEFERRED |
| V4-AD-020 | V3/V3_ifx activation cutover and retirement | DEFERRED |
| V4-AD-021 | Four-root execution contract | ACCEPTED |
| V4-AD-022 | Package location never determines the target | ACCEPTED |
| V4-AD-023 | Profiles select registered modules and never declare arbitrary executables | ACCEPTED |
| V4-AD-024 | Host-enforced module capability contract | ACCEPTED |
| V4-AD-025 | Target is read-only by default; mutation is receipted and reversible | ACCEPTED |
| V4-AD-026 | Local-current and CI-trusted-host execution topology | ACCEPTED |
| V4-AD-027 | Co-located v1 incubation with external-run equivalence | ACCEPTED |
| V4-AD-028 | Immutable package and mutable V4-owned data remain separate | ACCEPTED |
| V4-AD-029 | Architecture Conformance is a composite V4 module, not a monolithic LayerGuard rewrite | ACCEPTED |
| V4-AD-030 | Detectors are assigned by evidence source | ACCEPTED |
| V4-AD-031 | ArchUnitNET consumes isolated, explicit and fresh build evidence in Post | ACCEPTED |
| V4-AD-032 | Capability parity is claim-based, layered and non-vacuous | ACCEPTED |
| V4-AD-033 | Plan 06 LayerGuard replacement closes only after IFX cutover and legacy retirement | ACCEPTED |
| V4-AD-034 | Pre uses non-executing project/source inspection; evaluated build evidence is Post-only | ACCEPTED |
| V4-AD-035 | V3 provides a finite genesis bootstrap; established V4 development is V4-governed | ACCEPTED |

## Implementation readiness

No unresolved architecture decision blocks V4-P0. Exact schema fields, internal class boundaries,
package versions and the implementation library used to read or evaluate project models are P0/P4
contract-and-prototype outputs governed by the accepted decisions above, not open product choices.
Deferred decisions remain outside v1 and do not block its implementation.

## V4-AD-001 — Product boundary

V4 is one guard plugin. A project installs or selects a profile inside that plugin; it does not create
a second project-specific package such as `V4_ifx`.

The plugin owns generic runtime, contracts, Stage API, built-in modules, profile registry, state model,
packaging and restore behavior. Project-specific configuration is installed as a profile and optional
extension bundle.

## V4-AD-002 — Meaning of self-contained in v1

V4 v1 is operationally self-contained: its implementation, schemas, default resources, profile model,
dependency locks, reports and reset logic are package-owned. The host may still provide Git,
PowerShell 7, .NET and Node when a selected module declares those prerequisites.

Bundling all language runtimes is deferred. A missing declared runtime fails before Stage execution
with a structured prerequisite report; it never silently disables a gate.

## V4-AD-003 — Authority and mutable-state separation

The installed V4 root has distinct zones:

```text
V4/
├─ plugin.json                   immutable authority
├─ core/                         immutable authority
├─ stages/                       immutable authority
├─ modules/                      immutable authority
├─ profiles/catalog/             immutable installed profile bundles
├─ integrations/                 immutable host adapters
├─ state/                        mutable, ignored
├─ artifacts/                    mutable, ignored
└─ restore/                      immutable factory/default manifests
```

Stage execution may write only below declared state and artifact roots. Package Check rejects writes,
symlinks, reparse points or path traversal that cross an authority boundary.

## V4-AD-004 — Profile versus executable extension

A profile contains project identity, target roots, toolchain declarations, Stage configuration, rules,
policy, baseline references and module selections. It cannot contain an unregistered command path or
arbitrary executable script.

Project-specific executable logic is an extension module under `modules/` or an installed extension
bundle. The profile references its stable module ID and compatible version range. This keeps future UI
configuration changes from implicitly changing trusted executable code.

## V4-AD-005 and V4-AD-006 — First profiles

V4 v1 contains:

- `default`: safe, empty and advisory until reviewed configuration is installed;
- `synthetic_profile`: a project-neutral fixture proving profile loading, module selection, negative
  tests, reset and independent Stage execution.

`ifx_profile` is not a V4 v1 deliverable. It is the first post-v1 dogfood practice and must consume the
published profile/extension API. If IFX requires an undeclared core change, that change is treated as a
V4 compatibility decision rather than hidden inside the profile.

## V4-AD-007 and V4-AD-008 — Stage model

Bootstrap, Analysis, Pre and Post expose one uniform Stage contract:

- schema-valid config and explicit target/project identity;
- declared inputs, outputs, mutability, prerequisites and selected modules;
- structured result/report schema and stable exit categories;
- direct execution without an implicit earlier Stage run;
- optional `--with-dependencies` orchestration that is visible in the result.

Git Diff and GitHub CI consume these Stage APIs through integrations. They are not required for local
Bootstrap, Analysis, Pre or Post.

## V4-AD-009 — Reset and restore

V4 supplies project reset and factory reset:

- Project reset clears one project's mutable state and artifacts.
- Factory reset clears all active project instances and returns selection/configuration to `default`.
- Installed immutable profile and extension bundles remain in the catalog; removal is a separate
  uninstall operation.

Both modes require Preview, an exact deletion/recreation manifest and explicit acceptance. Reset must
refuse authority paths, target-project paths, unresolved roots, links/reparse points, Git worktrees and
anything not claimed by the current state manifest. It records before/after hashes and is idempotent.

## V4-AD-010 — Configuration contract

JSON plus JSON Schema is authoritative. Markdown is generated/read-only. The CLI and future Web UI
consume the same schema, command and result contracts. Unknown fields fail closed until an explicit
schema version and migration supports them.

## V4-AD-011 — Module and extension contract

Every module declares:

- ID, semantic version and compatible V4 API range;
- supported platforms and runtime prerequisites;
- capabilities: filesystem roots, process execution and network requirement;
- configuration and result schemas;
- executable/resource hashes and dependency locks;
- stages and gates it contributes.

V4 v1 allows only locally installed, manifest-declared modules. Remote marketplace discovery,
downloading and signature infrastructure are deferred.

## V4-AD-012 — CI contract

V4 development uses stable checks:

- `v4-contract`;
- `v4-linux`;
- `v4-package`;
- `v4-required`, which aggregates the required verdict.

Linux runs the full normal candidate suite. A base-owned classifier selects Windows smoke when a
change touches platform abstraction, filesystem/reset, process invocation, packaging or declared
Windows-specific modules. Full Windows runs on milestones, releases and explicit certification.
`v4-required` always appears; a skipped optional job cannot make the required context disappear.

Build/package artifacts are produced once and reused. Superseded runs are cancelled, dependencies are
cached and V4-only PRs do not run IFX solution/frontend/database gates.

## V4-AD-013 — Plan composition

Each PR selects exactly one root execution contract: either a single Plan or a plan-set. A plan-set
hash-binds ordered member plans and deterministically derives their path/risk/validation union.

The future command is conceptually:

```text
v4 plan compose plan-a.plan.json plan-b.plan.json --output bundle.plan-set.json
```

Validation rejects missing/member hash drift, duplicate IDs, dependency cycles, conflicting ownership,
undeclared changed paths and an aggregate that omits member obligations. Authorization and its
consuming change, trust weakening and activation, or engine change and remote activation may not be
co-bundled even when their ordinary path sets are disjoint.

## V4-AD-014 — Development branch

V4 incubates from `codex/guards-principles-plan` on a future `codex/v4-development-base` branch.
Feature branches target that base. V4 remains inactive and additive; incomplete V4 work does not flow
back to the active V3 branch. Stable-branch changes are absorbed one way at reviewed sync points.

The new base may use its own V4 workflow and Plan-set rules, but creating the branch, modifying
workflow triggers or setting GitHub rules remains a separately authorized operation.

## V4-AD-015 — Trust model

Local V4 provides developer feedback, but a PR cannot establish trust in a changed evaluator using
that evaluator's own result. Promotion and activation use the previously trusted V4 base to validate
candidate engines, schemas, modules, profiles and tests. Current V3/V3_ifx remains the active guard
until an explicit V4 cutover.

## V4-AD-016 — Runtime host

A small .NET CLI owns manifest loading, path safety, state transactions, reset,
Stage orchestration and structured results. Existing PowerShell and .NET detectors run behind declared
module adapters instead of being rewritten in v1.

The host is the trusted control plane. Adapters may inspect a target and return schema-valid findings,
but they do not select authorities, grant themselves capabilities, choose the final verdict, write
global state or infer the target from their own location. Thin PowerShell and shell launchers may call
the CLI; they are not alternative policy engines. V1 may require a declared host .NET runtime. Fully
bundled runtimes remain deferred by V4-AD-018.

## Deferred decisions

V4-AD-017 through V4-AD-020 are excluded from v1 and tracked in `TODO.md`. Deferral is not implicit
approval: each item requires its own decision update and Plan before implementation.

## V4-AD-021 — Four-root execution contract

Every invocation resolves four explicit roots before loading a profile or module:

- `PackageRoot`: immutable V4 host, schemas, built-in resources, profile catalog and module catalog;
- `TargetRoot`: the repository being inspected, read-only unless V4-AD-025 authorizes a mutation;
- `StateRoot`: V4-owned project bindings, locks, transactions, caches and reset receipts; and
- `EvidenceRoot`: V4-owned per-run reports, logs and evidence.

All roots are canonicalized before use. A path crossing its declared root, including through a
symlink, reparse point, worktree or gitlink, fails closed. Relative configuration paths are resolved
against their declared root rather than the process working directory.

## V4-AD-022 — Location-independent target

The host accepts `TargetRoot` explicitly. Package location, process working directory and script
location never define the target implicitly. A package inside the target and the same package outside
the target must produce equivalent verdicts for equivalent inputs.

Certification includes a separated-target fixture in which package-owned files are absent from the
target. Negative controls prove that a module which reads package configuration through `TargetRoot`
or derives the target from `PackageRoot` is rejected.

## V4-AD-023 — Profiles do not execute arbitrary commands

Profiles declare project identity, roots, rules, parameters and version-constrained module IDs. They
must not supply an arbitrary executable, script path, command line or environment mutation. The
trusted module registry resolves a module ID to an adapter and validates all parameters before the
adapter starts.

This restriction applies equally to built-in, synthetic and future project profiles. A project
profile can select installed capabilities but cannot create a new execution capability by data alone.

## V4-AD-024 — Module capability contract

Every module manifest declares its supported stages, readable roots, writable roots, process
requirements, network requirement, timeout, input/result schemas, executable/resource hashes and
dependency locks. The host grants only those declared capabilities, supplies a sanitized environment,
captures stdout/stderr and normalizes cancellation, timeout, failure and finding results.

V1 does not claim operating-system sandboxing where the platform cannot provide it. Its enforceable
contract is deny-by-default orchestration, path confinement, manifest verification and testable
negative controls. A module cannot determine the aggregate gate verdict.

## V4-AD-025 — Target mutation and reset boundary

Bootstrap, Analysis, Pre and Post inspect `TargetRoot` read-only by default. A future target mutation
uses a distinct Preview/Apply operation, explicit acceptance and an exact receipt containing the
created or replaced paths and before/after hashes. Rollback may touch only a receipted V4-owned path
whose current state still satisfies the receipt preconditions.

Project reset and factory reset clear only V4-owned mutable state by default. They never infer target
files to delete. CI/workflow installation or removal is a separately planned integration mutation,
not an implicit effect of stage execution or reset.

## V4-AD-026 — Local and CI host topology

Local runs use the explicitly selected installed V4 host for developer feedback. Pull-request verdicts
come from the previously trusted base host and trusted base authorities while the head checkout is
only the target. A changed head host, module, schema or profile receives candidate validation and
parity coverage but cannot produce the required verdict for its own change.

The public CLI and structured result contract are identical in local and CI use. CI adds trusted-base
selection, immutable input revisions and isolated state/evidence roots; it does not create a second
gate implementation.

## V4-AD-027 — Co-located incubation, external-run equivalence

V4 v1 may live in the IFX repository on `codex/v4-development-base` to reduce incubation and review
cost. Co-location is a source-management choice, not an application dependency: IFX production code
must not reference V4, and V4 must not depend on an IFX-relative location.

Every release candidate must also run from outside the target against synthetic fixtures. Standalone
repository extraction remains deferred, but the runtime and package contracts must not block it.

## V4-AD-028 — Immutable package versus mutable V4 data

"Artifacts live in V4" means they belong to a V4-owned namespace; it does not permit runtime writes
to immutable or Git-tracked package authorities. Local defaults may place ignored mutable data under
`V4/.work`, split by project binding and run ID. CI places `StateRoot` and `EvidenceRoot` under an
isolated runner-temporary V4 namespace so the trusted package worktree remains clean.

Package hashes exclude mutable data. Reset manifests, cache cleanup and retention operate only below
the resolved mutable roots and cannot weaken or replace `PackageRoot` authorities.

## V4-AD-029 — Composite Architecture Conformance module

V4 v1 provides one stable `architecture-conformance` module identity, but it does not recreate the
LayerGuard-derived engine as a new monolith. The module is a V4-owned composition boundary over
separately declared detectors, a rule execution plan and host-owned result aggregation.

The stable contract names the capability rather than ArchUnitNET, Roslyn, LayerGuard or another
implementation. V4 owns module configuration, capability selection, rule IDs, evidence normalization,
baseline application and the final structured result. Detector libraries remain replaceable internals.

## V4-AD-030 — Evidence-source detector allocation

Architecture claims are allocated by the facts needed to prove them:

- a Project Model detector owns declared project/package/framework references, project identity,
  module/ring ownership and graph completeness;
- Roslyn syntax/semantic detectors own source imports, disabled branches, declarations, forbidden
  symbols/text and member/payload rules;
- an ArchUnitNET adapter owns compiled type dependencies, interface implementation and compiled
  assembly/namespace placement; and
- the V4 host owns policy authority, rule execution plans, severity, baseline, non-vacuity, evidence
  aggregation and verdicts.

One claim may require multiple evidence kinds. A clean compiled-type result cannot override a
forbidden but unused project reference, and a permitted project edge cannot authorize a forbidden
compiled dependency.

## V4-AD-031 — Isolated build evidence for ArchUnitNET

ArchUnitNET runs only when Post receives an explicit, reviewed assembly manifest and fresh build
evidence. Expected assembly identities, source projects, configurations, target frameworks, paths,
hashes and minimum matched types are bound into the run. Missing, stale, unexpected or zero-match
inputs fail closed.

A declared Build Evidence Provider produces assemblies under `StateRoot`, not the checked target or
`PackageRoot`, and emits a hash-bound build manifest. It has a distinct process-execution capability,
sanitized environment, timeout and network declaration. CI runs it without secrets and with minimum
repository permissions. Other consumers may reuse its immutable evidence within the same bound run.

## V4-AD-032 — Claim-based parity and layered findings

Migration parity compares architecture claims, failure categories and evidence coverage rather than
requiring byte-identical LayerGuard and V4 reports. The capability matrix records for every claim its
authority, evidence kinds, Stage, detector, positive/negative fixtures, minimum matches, known limits
and parity rule.

Findings retain `ruleId`, subject, `evidenceKind` and `detectorId`. The host may group related findings
for presentation but cannot erase one evidence layer because another passed. Every blocking claim has
a deliberate violation, clean fixture and missing/zero-input negative control.

## V4-AD-033 — Replacement and retirement boundary

V4 v1 completes the generic composite module and synthetic capability parity without using V3 or the
LayerGuard-derived engine as a runtime dependency. The frozen V3 engine may be invoked only by
development parity tests and remains the active IFX production reference during incubation.

Plan 06 section 20 is not closed by V4 v1 alone. Closure requires the deferred `ifx_profile`, real IFX
parallel parity, trusted-base cutover, rollback proof and authorized removal or historical freezing of
the LayerGuard-derived implementation. Retirement is the last migration action, never a prerequisite
for generic V4 development.

## V4-AD-034 — Static Pre and evaluated Post boundary

Pre performs non-executing inspection of declared project XML and source syntax. It does not run an
MSBuild target, analyzer, generator or target-owned executable. This preserves fast feedback and
prevents project evaluation from silently acquiring process capability.

Condition/import-aware or compiled claims that require evaluated target state belong to Post and use
the isolated Build Evidence Provider. The capability matrix must state whether a result describes raw
declarations, evaluated build state or compiled semantics. Unsupported evaluation remains explicit;
it cannot be reported as clean coverage.

## V4-AD-035 — Minimal V3 bootstrap followed by V4 autonomy

Because V4 initially incubates in the same repository as the active V3/V3_ifx system, its genesis
cannot silently bypass the repository's existing exact-diff, protected-change and non-interference
controls. V3's role is nevertheless finite and narrow: it validates the formal bootstrap Plan pair,
the exact additive changed set, current-guard non-interference, package isolation and the recorded
recovery point. It does not become a V4 runtime dependency, interpret V4 policy or require IFX product
tests as evidence that V4 behavior is correct.

The genesis checkpoint records the reviewed seed commit, V4 package and contract hashes, deterministic
synthetic tests, recovery instructions and the proposed development-base/workflow configuration. A
candidate V4 host or workflow may provide supplemental results during genesis but cannot establish its
own trusted verdict. Creating `codex/v4-development-base`, installing its workflow or changing remote
rules remains separately authorized.

V4 autonomy begins only after an explicitly accepted seed is the immutable base of
`codex/v4-development-base` and a base-owned V4 runner can evaluate a head checkout as its target.
After that boundary, V4-only feature changes use V4 Plans or plan-sets, V4 contract/package/platform
tests and the stable `v4-required` verdict. They do not run the IFX solution, frontend, database or V3
candidate suites. V3/V3_ifx continues to protect the active IFX system independently until the
deferred IFX cutover; it is not the ongoing parent gate for V4 development.
