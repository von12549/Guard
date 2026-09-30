# V4 architecture decision set

Status: accepted V4 v1 baseline; post-v1 V4-P9 UI implemented; post-v1 M1–M5 foundation decisions accepted

Date: 2026-10-01
Implementation authorization: V4-P9.0 through V4-P9.GATE completed; later UI expansion and remote
activation remain separately planned and authorized. V4-AD-036 through V4-AD-047 are decision records;
their product implementation remains separately planned and authorized.

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
| V4-AD-017 | Lightweight Web UI is a non-authoritative local surface over V4 public contracts | ACCEPTED |
| V4-AD-018 | Fully bundled runtimes and zero-prerequisite distribution | REJECTED |
| V4-AD-019 | Standalone repository extraction before IFX activation and V3 retirement | ACCEPTED |
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
| V4-AD-036 | Self-contained .NET product runtime with declared external Module prerequisites | ACCEPTED |
| V4-AD-037 | Init derives external mutable roots and separates active governance from adoption history | ACCEPTED |
| V4-AD-038 | Explicit sibling version lifecycle with bounded, receipted storage retention | ACCEPTED |
| V4-AD-039 | Read-only discovery produces non-authoritative Profile drafts with reviewed promotion | ACCEPTED |
| V4-AD-040 | Existing local Web Companion expands only through typed, classified operations | ACCEPTED |
| V4-AD-041 | Versioned Stage roles and result kinds refine the uniform direct-execution contract | ACCEPTED |
| V4-AD-042 | Measure critical paths before optimization and retain evidence-based Windows cadence | ACCEPTED |
| V4-AD-043 | Only policy-accepted trusted-CI Evidence may satisfy required gates initially | ACCEPTED |
| V4-AD-044 | Targets may use base-held single-use authorization for protected governance changes | ACCEPTED |
| V4-AD-045 | Plan-set resources are bounded and every composed changed path has one owner | ACCEPTED |
| V4-AD-046 | One structured authoring model renders executable JSON and matching review Markdown | ACCEPTED |
| V4-AD-047 | Immutable local Module lifecycle precedes marketplace and expanded authoring UI | ACCEPTED |

## Implementation readiness

No unresolved architecture decision blocks the released V4 v1 core. V4-AD-017 governed the completed
V4-P9 implementation, and `05-p9-gate-audit.md` records that the shipped boundary remains local,
non-authoritative and confined to public V4 contracts. Remaining deferred decisions and every later UI
expansion stay outside V4-P9 unless a reviewed decision and exact Plan authorize them.

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
the CLI; they are not alternative policy engines. V1 may require a declared host .NET runtime. Post-v1
distribution evolution follows V4-AD-036; V4-AD-018's fully bundled, zero-prerequisite alternative is
rejected.

## V4-AD-017 — Lightweight Web UI boundary

The post-v1 Lightweight Web UI is an observation window and button panel over V4. It defines no guard
capability, command, profile, policy, rule, baseline, finding or verdict. The released V4 host remains
the only execution and decision authority.

The UI calls only allowlisted, structured public V4 commands and future schema-versioned read/query
contracts. Browser input cannot select an arbitrary executable, provide shell text, inject raw command
arguments or bypass the host to execute a Stage. The UI may present host-produced results but cannot
reinterpret an error, empty profile or missing coverage as a successful guard verdict.

The initial topology is a separately packaged local Web Companion serving immutable assets on a
loopback-only endpoint. Keeping presentation outside the core host avoids turning HTTP, Markdown and UI
dependencies into policy authorities. The companion is package-verified, but it remains subordinate to
the CLI and cannot become a second engine or remote control plane.

`PackageRoot` stays immutable and host-selected. `TargetRoot` stays read-only. All UI-originated mutable
data remains below explicit V4-owned `StateRoot` and `EvidenceRoot` paths. Plan viewing is read-only:
V4-native Plans retain V4 validation semantics, while current V3-formal historical pairs are clearly
labelled compatibility views and do not acquire V4-native authority.

The first release is limited to one active Target context, installed-profile selection, manual and
visible Stage execution, structured result/evidence viewing and Plan viewing. Authority editing, Plan
editing, target mutation, Reset Apply, Git/PR actions, remote activation, multi-project parallelism,
terminals, remote access, automatic extension installation and IFX-specific behavior remain excluded.
The exact exclusions and revisit boundaries are maintained in `TODO.md`.

## V4-AD-019 — Standalone repository before IFX activation

V4-TODO-008 is accepted as the next trust-boundary program after P10.3 design completion and before
remote V4 activation or V3/V3_ifx retirement. The canonical product source will move from the IFX
incubation subtree to `von12549/Guard` through a history-preserving, receipt-bound extraction.

The move is not a bulk transfer of IFX authority. Generic V4 product source, tests, documentation and
product Plans belong in Guard; IFX Profile/Bundle/review authority, P10 evidence, consumer integration,
coexistence and rollback plans remain in IFX. Existing 1.1.0–1.1.4 releases remain immutable at their
original authority. The first Guard-hosted release receives a new version and exact provenance.

Repository extraction, remote Guard review, release publication, IFX consumer rebinding and protected
IFX cleanup are separate authorization tranches. V4 activation, P10.GATE and V3 retirement are not
authorized by the extraction program.

## Deferred decisions

V4-AD-020 remains excluded from v1 and tracked in `TODO.md`. Deferral is not implicit approval: it
requires its own decision update and Plan before implementation. V4-AD-018's fully bundled,
zero-prerequisite alternative is rejected and superseded by V4-AD-036. V4-AD-017 is a post-v1 accepted
boundary implemented through the completed, separately authorized V4-P9 checkpoints; V4-AD-019 is
governed by `20260927-v4-todo-008-standalone-repository-extraction`. None of these decisions authorizes
another excluded follow-on capability.

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
repository extraction is now accepted under
`20260927-v4-todo-008-standalone-repository-extraction`; the runtime and package contracts must remain
location-independent throughout the move.

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

## V4-AD-036 — Post-v1 runtime distribution ownership

Guard will publish RID-specific self-contained .NET Host and Web Companion distributions for supported
Windows and Linux architectures. PowerShell, Git, Node and language toolchains remain external,
manifest-declared Module prerequisites unless a later Module-specific decision accepts their inclusion.
Missing prerequisites continue to fail before Stage execution with a structured report.

This decision rejects the V4-AD-018 alternative of bundling every runtime into a zero-prerequisite
archive. Implementation must first measure archive size, cold installation/startup, deterministic build
bytes, security servicing, supported architecture coverage, offline behavior and downgrade cost. The
decision does not itself change release bytes or close implementation work.

## V4-AD-037 — Project initialization, roots and governance layout

`guard init` takes an explicit `TargetRoot`, creates a stable project context identity and derives safe
per-user external mutable locations. On Windows the default base follows the LocalApplicationData known
folder. On Linux it follows `XDG_STATE_HOME`, falling back to `~/.local/state`. The project container has
sibling `state/` and `evidence/` directories; caches and temporary work remain StateRoot-owned children,
not additional execution roots. Init previews these values and permits a relocated derived container or
independent StateRoot/EvidenceRoot overrides only after the same canonical-path, ownership, overlap,
permission and link/reparse-point checks. The low-level Host always receives four explicit roots.

Active, version-controlled project governance uses one canonical `.guard/` entry point in TargetRoot.
Portable Profile, Module, policy, integration, authorization and low-churn governance-record sources may
live in schema-owned children. Machine-specific context, install/cleanup receipts, leases, caches, logs
and full Evidence remain external. Adoption material such as `docs/guard-adoption/` is historical and
does not remain active authority merely because it exists.

Init never writes governance into TargetRoot. A separate preview/review/apply adoption operation may
prepare and apply an exact Target change under the applicable Plan and trust authorization, including a
provenance-preserving migration from an existing adoption tree. The first implementation requires
active governance in the Target repository. A later external-governance-repository version must pin
repository identity, exact revision/content, availability and independent review policy; an arbitrary
sibling directory is not authority.

## V4-AD-038 — Version lifecycle and bounded runtime storage

The first post-v1 lifecycle implementation accepts operator-supplied packages and automates verification,
immutable sibling staging, explicit selection and rollback. It does not add background discovery,
download or activation. The previous verified sibling remains available until replacement certification
completes. Downgrade is allowed only when retained state/context schemas are compatible or a reviewed,
reversible migration exists; destructive down-migration is refused and reset remains separate.

Runtime storage is classified by ownership and durability. Accepted/published verdicts, authorization or
release records, explicit pins/archives, pending transactions and active-run leases create retention
references. Finalized successful-run work is disposable. Failed diagnostics, advisory Evidence and
caches use bounded age/count/capacity policies; protected data is never evicted merely to meet a quota.
Cleanup requires preview, active-lease and reference checks, canonical-path/link confinement,
restart-safe application and an exact receipt. Certification fixtures and long-running test clones are
not installed runtime data.

Initial implementation candidates are: retain the newest five failed runs or 14 days, retain the newest
20 advisory Evidence runs or 30 days, apply a 5 GiB per-project unpinned Evidence ceiling and a 5 GiB
global reclaimable-cache ceiling, and keep installed Guard plus ordinary State comfortably below 1 GiB.
The age/count rules use whichever retains fewer items. These numerical defaults must be confirmed by
storage measurements before their contract is stabilized. Immutable content-addressed deduplication and
verified negative-case overlays may optimize physical storage only when evidence identity and tamper
detection remain equivalent.

## V4-AD-039 — Profile discovery, draft and promotion authority

Profile discovery is deterministic, read-only observation. It may inspect inert repository metadata,
solution/project manifests, language and framework declarations, package and lock files, source/test
roots, the installed Module catalog and declared prerequisites. It does not build, restore, download,
execute target code, mutate TargetRoot or infer architecture policy, severities, baselines, exceptions or
acceptance. Every fact binds its source, detector/version and target snapshot; unknown and ambiguous
inputs remain visible unresolved questions.

Generated Profile drafts live below the initialized project's StateRoot and bind project context, target
snapshot, generator and discovery identities. A generator may fill deterministic facts and conservative
schema defaults and may present labelled recommendations, but gate selection, severity, exceptions,
baselines, unsupported coverage and ambiguous Module choices require explicit human decisions. Empty or
no-op coverage is reported as unprotected. Drafts are not executable and cannot be selected by Stage
execution or composition.

Promotion requires schema and capability validation, exact Module/configuration hashes, positive and
negative fixtures, a coverage/readiness summary, resolved human policy choices and a portable review
record. Applying portable active sources to `.guard/` is a separately authorized Target change governed
by V4-AD-037 and the target trust policy. Promotion creates a new immutable sibling composition and
external receipt; it never edits an installed base or existing composition. CI activation remains a
separate integration and remote-authority transaction.

## V4-AD-040 — Expanded local UI and application-service boundary

Post-P9 setup, authoring and lifecycle UI expands the existing separately packaged, package-verified
Web Companion rather than introducing a second desktop/backend product. The Companion remains a
loopback-only presentation and orchestration client. The Host and schema-versioned typed application
services remain the execution, path-safety, authority and verdict boundary; browser code never computes
an authoritative trust decision.

Every operation is classified as query, local-mutable preview, local-mutable apply, Target trust-change
candidate or remote-change candidate. Browser requests select vetted identities and schema-constrained
values, never arbitrary roots, executables, shell text, environment mutation, working directories or raw
Host arguments. Expanded routes require a loopback-bound session, unpredictable token, strict
origin/host validation, CSRF protection, request/body limits, stale-preview hash rejection,
cancellation/recovery behavior and exact receipts. Remote apply is not part of the first expansion.

A project is reported as protected only when it has an initialized context, an accepted non-empty
Profile, a verified immutable composition, satisfied prerequisites, non-vacuous required Stage coverage,
CI pinned to the same authority and repository policy requiring the unchanged aggregate verdict. Local
runnable, CI configured and CI enforced are separate states; a green default/no-op Profile is not
protection.

Local tooling may generate and validate an exact CI workflow/configuration candidate. Applying a Target
change, creating or updating a pull request, target trust authorization, remote workflow/ruleset
activation and positive/negative enforcement certification remain separate Plans and operations. Setup
does not push or modify remote repository policy by default.

Multi-project expansion is phased. After project identity and Evidence isolation are stable, the first
increment may add read-only aggregate status. Parallel execution remains deferred until per-project
queues, cancellation, log isolation and fair CPU/memory/disk ceilings are defined and certified. Neither
phase introduces non-loopback access or a remote control plane.

## V4-AD-041 — Versioned Stage roles, Module kinds and dependencies

The Bootstrap, Analysis, Pre and Post wire names and V4-AD-007 direct-execution behavior remain stable.
A new explicit semantic contract version gives them enforceable roles for new Profiles and Modules:

| Stage | Role | Result kind |
| --- | --- | --- |
| Bootstrap | Guard/project readiness; never installation or initialization | ready/not-ready |
| Analysis | deterministic read-only Evidence production | complete/incomplete |
| Pre | pre-build policy gate over declarations, source and approved Evidence | pass/fail |
| Post | post-build policy gate over evaluated, test and compiled Evidence | pass/fail |

Module result kinds are `readiness-provider`, `analysis-provider`, `pre-gate` and `post-gate`. Built-in
versus extension is an ownership dimension, not a result kind. Readiness and Analysis are read-only,
have no network capability and do not write TargetRoot. Process execution remains limited to a
registered adapter with declared prerequisites and capabilities. Providers cannot satisfy a policy gate
by themselves; gates emit pass/fail with findings and non-vacuous coverage.

Existing v1 manifests remain readable for a bounded compatibility period and are reported as
legacy/untyped rather than silently reinterpreted. New compositions use the versioned semantic contract
and valid placement. Direct execution never silently runs another Stage. `Pre/Post
--with-dependencies` may visibly run missing or stale readiness/analysis producers in dependency order;
direct Pre/Post validates eligible reusable Evidence and fails closed when required dependencies are
absent or stale.

## V4-AD-042 — Timing baseline, optimization proof and Windows cadence

Timing instrumentation precedes coverage-selection changes. It records workflow, job, approved-test,
Stage and Module wall time; critical path and total runner minutes; queue, restore, build and test time;
platform/change class; and cache/Evidence reuse decisions. The baseline includes at least 20 comparable
ordinary PR samples plus representative documentation-only, malformed-Plan, Windows-sensitive,
milestone and release runs.

The initial planning target is at least a 30% reduction in median ordinary-PR critical path, no
statistically meaningful p95 regression and identical required coverage. Measurements may refine that
target before it becomes a stable acceptance threshold. An optimization is invalid if a relevant change
can escape a required gate.

Until that baseline justifies a change, V4-AD-012 remains in force: Linux-complete for ordinary work,
base-classified Windows smoke for platform-sensitive changes, and Windows-full for milestones, releases,
runtime/trust changes and explicit certification. Scheduled Windows-full is added only if measurements
show it catches otherwise undetected drift. The required aggregate context remains present when an
optional platform job is skipped.

## V4-AD-043 — Evidence trust, reuse and local feedback

Initial authoritative reuse supports only Evidence from the same trusted CI run or a prior exact
trusted-CI run. Reuse eligibility binds repository/commit/workspace state, dirty/untracked policy,
Package/Host/Profile/Module/config/dependency identities, OS/architecture/runtime, Stage/command and
capabilities, isolation/network policy, output hashes, coverage, producer, freshness, replay controls
and revocation state. Base-owned policy makes the reuse decision and publishes the required aggregate.

Local Modules may emit the same versioned Evidence format and receive content/freshness/reuse diagnostics,
but developer-machine Evidence is advisory even when content hashes match. Content identity and producer
trust remain separate. Managed local attestation is deferred until device identity, key protection,
rotation/revocation, runner policy and replay resistance have an accepted threat model.

## V4-AD-044 — Target-project trust-change authorization

Guard will provide a consumer-neutral, schema-bound capability through which a target can protect its
pinned Guard repository/tag/archive hash, active Profile/bundle/review identities, integration workflow
and trust policy, plus explicitly declared verdict components. Consumer-specific protected sets are
defined by trusted base policy and cannot weaken themselves.

The design adapts Guard's base-held, single-use two-step authorization: an authorization Plan adds a
record that binds the consuming Plan and exact base/head hashes or add/delete operations; a separate
trust-change Plan consumes it. The record cannot be candidate-only, reused or added and consumed by one
root Plan/plan-set. The previously trusted Host/policy validates the candidate, and judge identity is
included in Evidence. Active governance, adoption history and operational receipts remain distinct.

Applying a Target governance change, pull-request delivery and workflow/ruleset activation remain
separate transactions. An external governance repository, if supported later, is a separately pinned
trust domain rather than an arbitrary directory.

## V4-AD-045 — Plan-set limits and concurrent authorship

Plan-set composition enforces versioned contract constants: at most 16 members, 1 MiB per Plan document,
8 MiB aggregate Plan input, dependency depth 8, 4,096 unique planned paths, 256 validation commands, 256
combined risk/decision entries and a 30-second validation/composition ceiling under the certification
fixture. Cycles, duplicate identities, unknown fields, missing dependencies and aggregate omissions
continue to fail closed. Measurements may revise these constants only through a versioned decision and
compatibility review; they are not environment-dependent heuristics.

Humans, Agents and mixed teams may author independent members concurrently, but the finalized plan-set
has one exact owner for every changed path. Shared path ownership is rejected even when dependency order
is declared. Every member is rebased and reconciled against the exact base/head before finalization.
Authorization and consuming trust change, trust weakening and activation, or engine change and remote
activation remain forbidden to co-bundle.

## V4-AD-046 — Plan-pair authoring and analysis authority

One schema-versioned structured authoring model renders the executable JSON Plan and its matching human
review Markdown. JSON remains the execution contract. Markdown explains the same goal, scope, paths,
decisions, risks, validation and acceptance; presentation cannot override JSON.

The lifecycle distinguishes a proposal with explicit unresolved questions from a finalized Plan bound to
an exact reviewed diff. Only finalized output may authorize implementation. Finalization never silently
adds changed paths to obtain a pass and requires operator confirmation plus source, generator and policy
identity. Imported prose, embedded instructions and Agent/model output are untrusted suggestions.
Deterministic Guard code owns schema, path, boundary, root-mutability and policy diagnostics.

## V4-AD-047 — Local Module lifecycle and deferred ecosystem

Guard provides immutable local Module lifecycle operations for list/inspect/graph, scaffold, validate,
test, diff, deterministic pack, review preparation, compose and verify. Validation covers schemas,
hashes, dependency locks, Stage/result placement, capabilities, prerequisites, timeouts and target
immutability. Updating an extension creates a new complete bundle/composition; updating a built-in
Module is a Guard product and release change.

The Module UI begins with read-only inventory, provenance, hashes, compatibility, capabilities,
prerequisites, Profile usage and dependency graphs. A later schema-driven wizard may edit metadata and
configuration, show diffs, run fixtures and prepare a bundle candidate. Adapter source remains an
IDE/repository responsibility, and the UI cannot create production acceptance.

Marketplace discovery/download, signature trust roots, rotation/revocation and remote installation stay
deferred until local lifecycle, compatibility and rollback are stable. Extension authenticity remains
distinct from Evidence producer attestation. CODEOWNERS/ruleset review stays conditional until a second
maintainer can satisfy approval; an unsatisfiable ownership rule is not enabled for appearance alone.
