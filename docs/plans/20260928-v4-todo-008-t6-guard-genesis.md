# V4-TODO-008 T6 — Guard genesis seed, CI certification and trusted-base activation

Status: `APPROVED 2026-09-28 — T6.1–T6.4 authorized; T6.5 (seed merge), T6.6 (activation) and T6.7 (release) not yet authorized`

Formal Plan ID: `20260928-v4-todo-008-t6-guard-genesis`.

Parent program: `20260927-v4-todo-008-standalone-repository-extraction`, tranche T6. This Plan is the
"minimal trusted-base workflow through its own reviewed Plan" required by T6 step 3, and it records
Amendment A3.

## 1. Problem: no previously trusted V4 base exists in Guard

Guard `main` is `e75d0386` and contains only the original README. The V4 trusted-base model judges a
candidate with the runner (`integrations/github/Invoke-V4TrustedBase.ps1`) taken from the **base**
commit. For the migration PR, the base holds no runner. The IFX-hosted runner (1.1.4 / IFX `80f7b6b6`)
cannot judge the Guard layout, because it resolves the package below `docs/guards/v4`. A workflow
added by the migration PR would be a candidate-authored judge, which the Plan forbids.

This is the same bootstrap V4 faced inside IFX. There it was solved by the finite genesis ceremony
V4-AD-035 (`docs/plans/product/03-genesis-bootstrap-and-autonomy.md`): an operator-accepted seed becomes
the trusted base, and only later changes are judged by that base.

## 2. Decision (Amendment A3)

The Guard migration PR is a **genesis seed** (G0 → G1). It is accepted by the operator on the recorded
evidence, not by a V4 CI verdict. The master Plan's canonical-source-switch condition 3 ("Guard CI
passes from a previously trusted V4 base") therefore applies from the first change after the seed. For
the seed itself, it is replaced by:

- operator review of the PR;
- T5 local evidence (Windows-full 34/34, supporting Linux-complete 33/33, structured and binary
  equivalence to the IFX-certified 1.1.4 source);
- a GitHub-hosted **platform certification** at the exact PR head, in which Linux-complete and
  Windows-full run on GitHub runners.

That certification is platform evidence, not a trusted verdict.

Facts that make this safe:

- `.github/**` is not package authority, so workflows never change the package identity
  (`491e7eb4bd3fbdaec5619601c334414f2820998aedaec529c21be004a027d3ee`).
- The runner does not read `ci-contract.json` `targetBranch`. The branch coupling lives only in the
  workflow trigger, so the product package needs no change to target `main`. The schema constant
  `codex/v4-development-base` stays as declared naming debt for a later product Plan.

## 3. Steps (each needs its own explicit authorization)

| Step | Action | Authorization |
| --- | --- | --- |
| T6.1 | Commit this Plan on `codex/v4-todo-008-standalone`, then push that branch to `von12549/Guard`. Never push `main`. | A-PUSH |
| T6.2 | Open a PR `codex/v4-todo-008-standalone` → `main` with the migration receipt, the T5 matrix, declared differences and this Plan. The PR adds no workflow. | A-PR |
| T6.3 | Genesis CI: commit only `.github/workflows/v4-certification.yml` directly to Guard `main` as a separate operator-authorized commit. This is outside any candidate. The workflow is `workflow_dispatch` only, with input `sourceCommit`. It checks out that exact commit into a clean directory, runs `core/certification/Invoke-V4PlatformCertification.ps1` (`linux` on `ubuntu-24.04`, `windows` full on `windows-2025`), and uploads both reports. It has no secrets and `contents: read`. | A-CI-1 |
| T6.4 | Dispatch the certification at the exact PR head. Both reports must pass and bind the same `packageHash`. That supplies the T6 Linux-complete and Windows-full evidence for one commit and package identity, and makes overall T5 `pass`. | A-CI-1 (dispatch) |
| T6.5 | Seed acceptance: the operator reviews the PR and merges it into `main` with a merge commit (main now also holds the T6.3 commit). The result is G1, the first trusted Guard base. | A-MERGE |
| T6.6 | Trusted-base activation: an operator-authorized commit on `main` installs `.github/workflows/v4-guards.yml` from `integrations/github/proposed-v4-guards.yml`. The only changes are `branches: [main]` and adding `.gitattributes` to the path filter. From then on, every PR's verdict comes from the base-owned runner at the PR base SHA. Rulesets or required contexts are not part of this Plan. | A-CI-2 |
| T6.7 | Release: a separate publication Plan chooses the next unused version, bumps product metadata through a normal PR judged by the trusted base, certifies, and publishes. Never recreate `v4-guards-v1.*`. | A-RELEASE (separate Plan) |

## 4. Stop conditions

Stop on any of these:

- a certification failure or a `packageHash` mismatch between platforms;
- any PR change beyond the recorded migration commits and this Plan;
- a workflow that references secrets, writes contents, or runs candidate-supplied judging code for a PR
  verdict;
- any attempt to push `main` outside T6.3, T6.5 or T6.6, or without its authorization;
- any tag or release creation outside T6.7.

## 5. Rollback

- Before T6.5: close the PR, remove the T6.3 workflow through a reviewed revert commit, and leave the
  branch intact.
- After T6.5: revert through a reviewed commit on `main`. IFX remains the canonical source until the
  T7 handoff decision. There is no force push and no history rewrite.
