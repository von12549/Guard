# Profile discovery and reviewed promotion

The experimental M2 Profile authority surface is defined by
`core/profile/contracts/profile-authority-contract.json`. It deliberately sits outside the stable `1.0` CLI
compatibility baseline while its contracts are exercised and reviewed.

The latest formal release is 1.2.0. The unpublished 1.2.1 local candidate adds supported configure and
review-template steps; it is not publication, Target adoption, CI activation or consumer authorization.

## Operations

| Operation | Purpose | Writes |
| --- | --- | --- |
| `profile discover` | Report deterministic inert Target facts, installed Modules and unresolved questions | none |
| `profile draft` | Store a conservative snapshot-bound Profile scaffold | StateRoot only |
| `profile configure` | Validate a separate typed candidate against the Draft, current Target snapshot, Module configuration, capabilities, stages and selected rules; store a new configured Draft | StateRoot only |
| `profile review-template` | Create a deterministic incomplete review document with explicit fixture and policy questions | StateRoot only |
| `profile validate` | Recheck snapshot, schema, hashes, capabilities, fixtures and human policy review | none |
| `profile promote` | Emit an extension bundle and review handoff for the immutable sibling composer | operator-selected candidate root only |

Use the exact syntax and result-schema mapping in the contract. Drafts are not Profile authority and are
never searched by Stage execution. A successful validation or promotion is not proof that a project is
protected: the result reports whether coverage is non-vacuous and keeps Target adoption, immutable
composition creation/selection and CI activation as explicit required follow-up transactions.

The supported authoring sequence is `discover` → `draft` → `configure` → `review-template`. Configure
never edits the original Draft, discovery evidence or supplied candidate. Review-template deliberately
omits human identity/acceptance and positive/negative fixture receipts, so it cannot satisfy the
accepted review schema or be promoted until an authorized human completes a separate review.

Discovery reports actionable human explanations, safe defaults, candidate values and next actions.
Project-local `TargetFramework`/`TargetFrameworks` wins; otherwise the nearest ancestor
`Directory.Build.props` within TargetRoot may provide exactly one unconditional literal declaration.
Conditional, imported, expression-based or ambiguous MSBuild values are unsupported coverage, never a
fabricated missing-framework violation. A root solution that exactly covers discovered projects is
offered explicitly as the `.` candidate.

## Review record

The `profile-review` contract binds the draft, discovery, candidate Profile and Target snapshot hashes.
It requires a human reviewer, an explicit decision and rationale for gates, severity, exceptions,
baselines, unsupported coverage and ambiguous Modules, exact installed Module/configuration/capability
bindings, and matching positive and negative fixture receipts. Candidate Host output cannot accept its
own recommendation.

## Promotion handoff

`profile promote` writes a new candidate directory containing `bundle/`, `extension-review.json`, the
portable Profile review and `promotion-receipt.json`. The bundle is compatible with the existing
`Compose-V4Extension.ps1` verifier/composer when a separately authorized base installation, archive,
output sibling and receipt are supplied. Promotion does not invoke that composer.

The promotion bundle carries the candidate Profile file only: its manifest intentionally has
`modules: []`. Module selections in that Profile refer to hash-bound Modules already present in the
separately verified base installation; promotion does not copy, download or authorize Module binaries.
Validation/review binds those installed Module identities and capability ceilings. A candidate that
needs new Module bytes must use the separate Module lifecycle and extension review path.

Applying portable sources to Target-owned `.guard/` requires the target trust authorization flow.
Creating or selecting an immutable composition, rollback selection, workflow/ruleset activation,
publication and merge remain separate operations and are not authorized by any M2 command.
