# V4 Guards 1.2.x onboarding, Profile authoring and UI-first repair

Status: `P1 BLOCKERS FIXED — 11/12 PLAN GATES PASS; CLEAN-COMMIT DISTRIBUTION PENDING 2026-10-05`

Formal Plan ID: `20261004-v4-guards-1-2-x-onboarding-repair`.

Source acceptance plan: `D:\IFX-10-Root\docs\plans\20261004-guard-ifx-p02-onboarding-repair.md`.
That external path is evidence and acceptance context only; it is not package input and this Plan does
not authorize writes to IFX.

Target release line: `1.2.x`. Before producing a candidate archive, `x` must be resolved to an unused
`1.2.<patch>` value and applied consistently to product, host, archive, manifest, receipt and evidence
metadata. This repair must not become `1.3.0` or `2.0.0`, overwrite a 1.2.0 release asset, or publish a
release without a separate release authorization.

## Goal

Repair the installed launcher and Profile-first onboarding path, add supported candidate and incomplete
review-template authoring, correctly handle simple inherited .NET target frameworks, and make Web
Companion the primary human onboarding path while preserving Host authority, fail-closed behavior and
zero persistent environment mutation.

## Observed defects

The first human IFX onboarding test established these product defects:

1. The launcher binds an optional wrapper `Profile` parameter ahead of Host arguments, so `version` can
   be consumed as that parameter. Requiring an explicit wrapper profile is undocumented operator lore.
2. `profile draft --profile <new-id>` makes prerequisite resolution look for the not-yet-installed
   Profile that the command is meant to create.
3. Two byte-identical `guard.ps1` files ship, but the nested copy derives an invalid duplicated
   `core/distribution/core/distribution` runner path.
4. Drafting is deterministic and non-mutating, but yields an intentionally empty, unprotected Profile
   without a supported command to configure a candidate or produce a safe incomplete review template.
5. Project discovery sees many manifests but does not turn a single root solution covering every
   project into actionable project-root guidance.
6. Architecture pre-analysis treats projects inheriting `TargetFramework` from a simple root
   `Directory.Build.props` as missing a framework.
7. Installation and onboarding require too many PowerShell variables, raw JSON edits and manual hash
   checks. The existing Web Companion does not carry the operator through this flow.
8. Script-host errors are not consistently capturable through PowerShell redirection.

## Accepted design

### Launcher and prerequisites

- `package/guard.ps1` is the only public launcher declared by the distribution and documentation.
- The public launcher has only launcher-specific named parameters and captures all remaining Host
  arguments without positional ambiguity, reordering or string conversion.
- Prerequisites are selected by Host operation. `version`, `profile discover` and `profile draft` do
  not require an installed Profile. Stage/Application operations retain Profile Module prerequisite
  checks.
- A nested implementation script, if retained, must either work from its own supported layout or fail
  with a stable explicit `non-public-entrypoint` error. It must never derive a duplicated path.
- Errors must have stable categories and exit codes and be capturable by both `& script 2>` and
  `pwsh -File ... 2>`.

### Candidate authoring and human authority

- `profile draft` remains conservative, `unprotected` and StateRoot-owned.
- `profile configure` accepts an original Draft plus a separate human-authored candidate Profile. The
  Host validates Profile, Module config, stage compatibility, rules/claims, capabilities, target
  snapshot and path bindings, then atomically stores a new configured Draft below StateRoot.
- The original Draft and discovery bytes remain unchanged. The Host computes and binds all hashes.
- `profile review-template` creates a deterministic `incomplete` document containing bindings,
  unresolved policy questions and positive/negative fixture slots. It must not satisfy the accepted
  review schema until a human supplies and accepts the required decisions and evidence.
- Empty Modules, stages and rules remain `unprotected`. The Host never fills `acceptedBy`, accepts
  policy, fabricates fixtures, writes TargetRoot or activates CI/remotes.

### Discovery and inherited framework support

- A single root solution that includes every on-disk project becomes an explicit, reviewable `.`
  project-root candidate, never an automatic policy decision.
- Each unresolved policy category has a human explanation, safe default, candidate values and a next
  action.
- Selecting `architecture-conformance` requires non-empty `enabledClaims`; every claim must be selected
  by the Profile rules.
- Pre-analysis may walk from a project directory to TargetRoot and parse only simple, unconditional,
  literal `TargetFramework` or `TargetFrameworks` values in `Directory.Build.props`. Project-local
  values win and evidence records the source file. Conditions, imports, expressions and ambiguity are
  unsupported coverage rather than `<missing>` violations. No MSBuild target or consumer code runs.

### UI-first onboarding

- Web Companion gains a first-onboarding stepper covering installation integrity, PATH/Profile safety,
  roots/write boundaries, Target snapshot, discovery, conservative Draft, candidate configuration and
  the incomplete review-template stop point.
- Steps expose `not started`, `running`, `pass`, `needs decision` or `blocked`, completed-step counts,
  the current Host operation, human conclusions, machine error categories, exit codes, safe recovery
  hints and exportable evidence paths. Do not invent progress percentages or ETAs.
- Forms replace raw JSON/hash work for the default path. The UI and CLI call the same Host contracts;
  the browser performs no independent validation or protection inference.
- Browser requests never contain raw filesystem paths, Host argument arrays, shell text, executables or
  environment values. The trusted launcher pins roots, and the browser uses derived identifiers.
- Typed, preview-bound, stale-refusing operations may write Draft/Candidate/Review-template data only
  below StateRoot. Target, CI, composition activation, remote state and human acceptance remain outside
  this Plan.
- From verified installation to configured candidate plus incomplete review template, the default path
  requires at most one shell command to start Web Companion.

## PATH and host-environment safety

Persisted User/Machine environment data, registry environment keys, PowerShell profiles and shell
startup files are host-owned and immutable for this work.

- Never use `setx`, persistent `SetEnvironmentVariable`, registry environment writes or profile edits.
- Never copy process PATH into persisted User or Machine PATH.
- Every child process with isolated `DOTNET_CLI_HOME` also receives
  `DOTNET_ADD_GLOBAL_TOOLS_TO_PATH=0`, scoped to that child only.
- Regression tests statically reject persistent mutation APIs and dynamically compare User, Machine
  and process PATH plus PowerShell profile existence/hash before and after install, launcher, dotnet
  child-process and cleanup operations. Evidence records hashes/equality only, never PATH contents.
- Any drift is `BLOCKED — HOST SAFETY INCIDENT`: stop, preserve evidence, do not continue and do not
  attempt automatic repair.

## Implementation sequence

1. Preserve current local `main` at `da81855cfe0278e35a58904c992fbcf269304548` and its two local
   commits. Create a dedicated repair branch from that exact local state; do not reset or rewrite it.
2. Capture non-secret environment/profile hashes and run focused tests to establish the pre-change
   baseline.
3. Repair launcher argument forwarding, operation-aware prerequisites, public-entrypoint packaging and
   error transport with regressions first.
4. Add `profile configure`, `profile review-template`, their contracts and fail-closed authority tests.
5. Add actionable discovery output and simple inherited target-framework support with an IFX-like
   central-props fixture.
6. Add typed application operations and the UI-first Web Companion onboarding stepper without moving
   authority into the browser.
7. Strengthen repository instructions, documentation and PATH/environment static and dynamic tests.
8. Resolve the exact unused `1.2.<patch>` candidate version, update all version-bearing product files
   consistently, build a local candidate ZIP and validate only through its installed public launcher.
9. Run focused, package, CLI, Web Companion and environment-safety suites. Prepare code review evidence.
   Do not push, open a PR, tag, publish or start IFX P03 from this Plan.

If implementation needs a path absent from the paired `.plan.json`, amend both Plan files before
changing that path and explain why it is necessary. Do not use that mechanism to expand authority.

Plan-path amendment (implementation): `modules/registry.json` is included because the already planned
architecture-conformance adapter, capability matrix and Module manifest changes necessarily change the
manifest hash bound by the package Module registry. This is only the required integrity-chain update;
it does not add a Module, capability or implementation scope.

Plan-path amendment (implementation): `core/certification/compatibility-baseline.json` is included
because this Plan already requires new experimental CLI contract entries and a consistent candidate
product version. Package validation hash-binds both `core/contracts/cli-contract.json` and
`plugin.json` through that baseline, so their planned changes cannot be exercised or packaged without
rebinding those two exact hashes. The baseline API version and every other frozen entry remain
unchanged; this is not publication or a stable-API expansion.

Plan-path amendment (implementation):
`integrations/web/V4.Guards.WebCompanion/V4.Guards.WebCompanion.csproj` is included because the Plan
requires one consistent candidate version across the product, Host, Companion, archive manifest and
receipt. Updating only the already listed product and Host metadata would create a split-version
candidate. No Companion dependency or runtime scope is changed.

Plan-path amendment (implementation audit):
`core/application/contracts/application-service-contract.schema.json` is included because the already
planned service-contract instance now declares six operations and ten schemas, and its validator must
permit and require that exact shape. This corrects a paired contract/schema omission only; it adds no
browser or Host capability beyond the planned typed onboarding operations.

Plan-path amendment (implementation validation):
`modules/architecture-conformance/rule-execution-plan.json` is included because its `matrixSha256`
field must bind the already planned capability-matrix bytes after documenting central-props support.
Rules, stages, detectors, severity and minimum coverage remain unchanged; this is only the required
matrix integrity-chain update.

Plan-path amendment (P1 acceptance repair):
`core/application/contracts/host-safety-proof.schema.json` is included because onboarding progress may
mark PATH/Profile safety complete only from a current StateRoot proof bound to package, project and
Target identities. The proof permits hashes, existence flags and equality results only; it cannot
contain environment values, PATH text, profile paths, Target writes or human acceptance.

## Acceptance gates

1. `version` and Profile onboarding work through the single public installed launcher without a wrapper
   Profile trick; unknown new Profile IDs do not block drafting.
2. Public launcher arguments are byte/ordinal-preserving strings and launcher failures are capturable
   with stable exit codes and categories in both supported PowerShell invocation styles.
3. Candidate configuration and incomplete review-template generation are deterministic, idempotent,
   StateRoot-confined and reject stale/tampered/unsupported inputs.
4. Operators never edit internal Draft state, calculate hashes or mistake an incomplete template for
   accepted authority.
5. IFX-like projects inheriting a literal `net10.0` from root `Directory.Build.props` are recognized;
   unsafe MSBuild forms remain explicit unsupported coverage.
6. Web Companion completes the primary flow with at most one start command and displays progress,
   decisions, validation, errors, boundaries and evidence without accepting raw paths or commands.
7. The package contains one documented public launcher and remains relocation-safe and hostile-CWD-safe.
8. Static and dynamic tests prove no persistent User/Machine environment or PowerShell profile mutation;
   isolated dotnet processes cannot add tools to User PATH.
9. All focused and package suites pass and the candidate reports one consistent unused `1.2.<patch>`
   version. No release or consumer protection claim is made.

## P1 acceptance repair record

- Direct same-process call-operator and `pwsh -File` launcher failures both produce one parseable stderr
  JSON document with stable exit/category and empty stdout.
- Setup progress begins with one verified installation step and unlocks the next four steps only after a
  fresh hash-only proof bound to the current package, project and Target; tamper/drift blocks later steps.
- Project-reference and target-framework claims require explicit non-empty policies, graph completeness
  requires resolved project references, and adapter coverage follows actual configured execution.
- The focused regressions and 11 source-checkout validation commands pass. The distribution command is
  intentionally pending until these implementation bytes exist in a clean commit.

## Recovery and stop conditions

- Restore only files changed on the dedicated repair branch; do not reset or rewrite the preserved
  local main commits.
- Candidate packages, StateRoot and EvidenceRoot remain disposable local outputs outside consumers.
- Stop on dirty/unattributed source state, baseline commit mismatch, inability to capture safety
  baselines, any host environment/profile drift, unexpected Target writes, or a request requiring
  remote/release authority.
- IFX retesting requires a separately reviewed human-operated P03 plan.
