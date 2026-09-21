# V4 genesis bootstrap and autonomy handoff

Status: accepted P0 proposal; inactive until a separately authorized activation

Decision authority: `00-architecture-decision-set.md`, especially V4-AD-014, V4-AD-015,
V4-AD-026 and V4-AD-035.

This proposal makes the transition boundary exact. It does not create a remote branch, activate a
workflow, change the current V3 workflow or ruleset, or make V4 authoritative for IFX.

## 1. Branch and recovery lineage

The user authorized the local branch `codex/v4-development-base`. It was created without a worktree
from planning commit `20c93d521728746e1c227654b32219d94fcdf6bb` and currently carries these P0
checkpoints:

| Checkpoint | Commit | Role |
| --- | --- | --- |
| Planning seed | `20c93d521728746e1c227654b32219d94fcdf6bb` | Accepted V4 architecture and roadmap |
| P0A | `eba8178211e5bfc995adac53d05d0d1d7dc5c4dd` | Four-root host/adapter spike |
| P0B | `b44c85fcd62d944e245c2782e21ec7f81af22e61` | Frozen contracts and CLI identities |

P0C extends this lineage only with an inactive proposal. No commit in this lineage has been pushed by
the P0 implementation. Before remote activation, the final reviewed P0 seed SHA and the package,
contract-manifest, deterministic-test and recovery hashes must be written to a schema-valid genesis
record and accepted by `human-review` or `external-governance`. Candidate V4 output cannot accept it.

## 2. Transition states

| State | Required entry evidence | Verdict authority | Allowed work | Exit condition |
| --- | --- | --- | --- | --- |
| `G0_V3_GENESIS` | Formal V3 Plan pair, exact additive diff, V3 non-interference and recovery seed | Previously trusted V3 base | P0 host spike, contracts and inactive governance proposal | Accepted genesis record binds the reviewed P0 seed |
| `G1_V4_DORMANT_BASE` | Local `codex/v4-development-base` at the accepted seed; no active V4 workflow/ruleset | V3 remains active for IFX; V4 results are local/supplemental | Build P1–P6 candidate authority, runner and negative corpus under formal Plans | A previously reviewed V4 base can judge a separate head checkout and the activation transaction is authorized |
| `G2_V4_AUTONOMOUS` | Active base-owned runner, active V4 workflow, branch rules requiring `v4-required`, negative-control proof | Previously trusted V4 base for V4-only PRs | P1–P8 V4 development using V4 Plans/plan-sets | Separate release or IFX-cutover authorization; neither is implied here |

State transitions fail closed. Missing or mismatched seed, package/contract hash, base SHA, plan root,
runner hash, required check, negative control or ruleset evidence leaves the system in its prior state.
There is no fallback in which the candidate head judges itself.

## 3. End of the V3 bootstrap

V3's genesis role is complete only for a seed that has all of the following evidence:

1. Formal Pre accepts the exact P0 Plan pair.
2. Base-owned V3 Diff matches every committed P0 path.
3. Current V3 Validate and isolated IFX package tests pass.
4. P0A proves path safety, declared capabilities and equivalent in-place/separated execution.
5. P0B binds the frozen contracts and rejects candidate self-acceptance.
6. P0C records this transition and proves it has not activated a workflow.
7. An external acceptance records the final seed and recovery hashes.

That evidence does not make the P0 spike a production V4 judge. Until the base-owned V4 runner and
activation transaction exist, the branch is in `G1_V4_DORMANT_BASE`.

## 4. Base-owned V4 verdict contract

For a pull request whose base branch is `codex/v4-development-base`:

- GitHub checks out the head only as `TargetRoot`.
- It materializes `github.event.pull_request.base.sha` outside the target as immutable `V4_BASE`.
- Every required verdict starts through
  `V4_BASE/docs/guards/v4/integrations/github/Invoke-V4TrustedBase.ps1`.
- The base runner verifies the head Plan/plan-set, exact diff, candidate authority hashes, fixed
  negative corpus, package isolation and platform selection before accepting the candidate.
- Candidate tests may add evidence but cannot set a required verdict.
- StateRoot and EvidenceRoot are runner-temporary and never overlap the base or head checkout.
- Missing base runner, ambiguous Plan root, unsupported schema, hash drift, skipped required work or
  an unavailable selected platform is blocking.

The stable required contexts are `v4-contract`, `v4-linux`, `v4-package` and the aggregate
`v4-required`. Conditional Windows work is selected by the base classifier; `v4-required` always
appears and rejects a required Windows job that did not succeed.

A manual dispatch pins both base and head to `github.sha` and is certification evidence only. It
cannot promote a different candidate or replace the pull-request trusted-base verdict.

## 5. Inactive workflow specimen

`../integrations/github/proposed-v4-guards.yml` is the exact P0 workflow proposal. It intentionally
lives outside `.github/workflows/`, so GitHub cannot execute it. The P1–P6 implementation may refine
internal command arguments, but changing check identities, target branch, trust direction, failure
semantics or Windows selection requires a new decision and Plan.

The proposed future active path is exactly `.github/workflows/v4-guards.yml`. Materializing that file
is an activation change, not a documentation copy operation.

## 6. Separately authorized activation transaction

Activation must be a reviewed transaction after the V4 trusted runner exists. Its exact mutation
surface is:

1. freeze and externally accept the final genesis record;
2. verify the accepted base runner against a clean head, deliberate violation, missing input, hash
   drift and head-self-judgment negative controls;
3. add `.github/workflows/v4-guards.yml` from the reviewed specimen;
4. change `.github/workflows/v3-ifx-guardrails.yml` so pull requests targeting
   `codex/v4-development-base` do not run IFX/V3 candidate suites;
5. push the reviewed base branch only when explicitly authorized;
6. install a branch ruleset that requires the exact `v4-required` context, strict up-to-date
   checking and reviewed workflow/authority changes;
7. run a positive control and a negative-control pull request, recording check and mergeability
   evidence; and
8. declare `G2_V4_AUTONOMOUS` only after every item passes.

Workflow activation, the V3 trigger change, push, ruleset mutation, pull requests and merges are
distinct external effects. This P0C checkpoint authorizes none of them. Engine/trust changes and
remote activation must not be co-bundled merely to make the ceremony shorter.

## 7. Recovery

Before `G2`, recovery is restoration of the local branch to the accepted seed or an authorized revert;
there is no remote state to unwind. After `G2`, recovery disables the V4 ruleset/workflow through the
recorded activation rollback, restores the last accepted V4 base and re-runs both controls. Recovery
does not weaken or retire V3/V3_ifx, which remains the active IFX guard until a deferred cutover.
