# M2 Profile authority decisions — discovery, draft and promotion

Status: `DECISION RECORD — ACCEPTED 2026-10-01; implementation not authorized by this Plan`

Formal Plan ID: `20261001-m2-profile-authority-decision`.

Predecessor decision record: `20261001-m1-foundation-decisions`.

## Goal

Resolve D11–D14 so later implementation Plans have an exact authority boundary between inert project
discovery, non-authoritative Profile drafting, reviewed Target governance and immutable installed
composition.

## Accepted decisions

### 1. Discovery allowlist

Discovery may read inert repository metadata, solution/project manifests, declared languages and
frameworks, package/lock files, source/test roots, installed Module inventory and declared prerequisites.
Each fact binds source path, normalized value, detector/version and target snapshot. Discovery does not
build, restore, download, execute target code, mutate TargetRoot or decide architecture policy,
severity, exceptions, baselines or acceptance. Unsupported and ambiguous forms remain explicit.

### 2. Draft and authority locations

Generated drafts are schema-versioned and stored below the initialized project's StateRoot, bound to
project context, target snapshot, generator and discovery identities. After review, portable active
Profile/Module/policy sources may be applied to Target-owned `.guard/` only through a separate reviewed
Target change. Promotion then creates and verifies a new immutable sibling composition. Drafts are
never executable authority.

### 3. Generated recommendations

The generator may populate deterministic observations and conservative schema defaults and may present
recommendations with rationale/confidence. Gate selection, severity, exceptions, baselines, unsupported
coverage and ambiguous Module choices remain explicit human policy decisions. Empty or no-op output is
labelled unprotected.

### 4. Promotion acceptance

Promotion requires schema/capability validation, exact Module and configuration hashes, positive and
negative fixtures, coverage/readiness summary, resolved policy choices, a portable review record and
target trust authorization where protected `.guard/` sources change. Composition is immutable and
sibling-based; CI workflow/ruleset activation remains separate.

## Scope and non-authorization

This Plan records architecture and backlog state only. It does not add discovery code, schemas, commands,
UI, Target files, Modules, Profiles, compositions, CI workflows, rulesets, network behavior or remote
state. It does not accept a generated Profile or authorize any consumer migration.

## Acceptance

1. V4-AD-039 records the observation allowlist and prohibits build/restore/download/execution.
2. Drafts remain external non-authoritative data and accepted sources/compositions have distinct homes.
3. Generated recommendations cannot become human policy decisions implicitly.
4. Promotion prerequisites and Target/CI authorization boundaries are explicit.
5. V4-TODO-020 tracks implementation without claiming that the accepted decision is implemented.
6. The native Plan pair validates and declares the exact maintained documentation paths.

## Next formal Plans

After M1 project context and the M5 target trust decision are available, promote separate implementation
Plans for the discovery fact contract, Profile scaffold service/CLI, review/promotion pipeline and UI.
Keep Target adoption, immutable composition and CI activation in their required authorization boundaries.

## Recovery

Revert this documentation-only decision record and remove V4-AD-039/V4-TODO-020. No runtime, Target,
composition or consumer data requires rollback.
