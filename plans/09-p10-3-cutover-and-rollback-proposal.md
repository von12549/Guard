# V4 P10.3 — IFX cutover and rollback proposal

Status: `DESIGN AND LOCAL REHEARSAL ACCEPTED — REMOTE ACTIVATION NOT AUTHORIZED`

Formal Plan: `20260927-v4-p10-3-cutover-and-rollback-design`.

## Bound baseline

This proposal binds the accepted V4 Guards 1.1.4 + `ifx_profile` 0.4.2
installation and target commit
`40b4c0f85e5d8a63ac5af5c1da80d4d46ba32b82`. P10.1 C6e-R1 is bound by
decision SHA-256
`94a7c01bd991a7b4371f6d3406b43f58830bdb29740c477db7abdaf2bb0ece22`;
P10.2 is bound by decision SHA-256
`7c5ff243ec452958ffbb08ced46ae6e1a8320f586b9fb71ef0d98f2931934516`;
the exact Windows-full report is bound by SHA-256
`858b69949c0febc386557f8bb70287d2abe3a7c2af56e6f5aa20b2fbc7de9ff8`.

The local rehearsal accepted this design with decision
`p10-3-design-and-local-rehearsal-accepted`, recorded at
`artifacts/guards/p10-ifx-114/p10-3-design-042/rehearsal/p10-3-decision.json`,
SHA-256 `529e19b567c05619ec054117e2514c579a908a4e614355411fc28b6d52964964`.
It proved 13 context-owner rows, nine detector-owner rows, five rejection
controls and unchanged protected roots without a remote mutation.

## Read-only remote finding

The live ruleset `IFX V3 Required Checks` (`23459908`) is active, strict and
requires the same 13 V3 contexts as the checked-in contract. The remote default
branch is still `main` at
`ecb03726a6c67208d25e7988695c53f6326d77c0` and contains no workflow files.
GitHub retains eight active workflow registrations, but their paths are not in
that default-branch tree. The V3 workflow exists on the remote development
branch at commit `c3e055235c51ac8e0394e76135ef7abf3045fb63`, blob
`51986b5aae2ccdacb52020f21c20b7c12f630726`.

This is classified, not repaired: a separately reviewed promotion must first
place the accepted V3 workflow and P10 evidence on the default branch. P10.3
does not push, merge or change the default branch.

## Proposed verdict topology

The inactive specimen defines three V4 jobs:

- `v4-ifx-contract` verifies the exact 1.1.4 release, accepted bundle/review
  bytes and trusted-base separation;
- `v4-ifx-windows` composes those trusted inputs outside the Target checkout
  and runs the `ifx_profile` Pre and Post stages against the PR head;
- `v4-ifx-required` uses `if: always()` and is the only future V4 required
  context.

All jobs have `contents: read`, use no repository secret, write only runner
temporary State/Evidence roots and reject candidate-supplied authority bytes.
The IFX bundle is not yet a tracked, remotely consumable immutable input. A
separate publication Plan must place the exact reviewed 0.4.2 tree under the
trusted base before the specimen can be activated.

## Coexistence and ownership

During coexistence all 13 V3 contexts remain required and
`v4-ifx-required` is additive. The minimum window is seven calendar days,
three distinct PR heads and one deliberate negative-control PR. Every current
V3 context has an explicit V4 owner in `ifx-cutover-proposal.json`.

Because the accepted 1.1.4/0.4.2 certification is Windows-product
certification and Linux complete remains advisory-failed,
`v3-cross-platform-ubuntu-latest` remains a required compatibility bridge even
after V4 becomes primary. Removing that final bridge requires a later exact
Plan, same-bundle Linux-complete proof and separate authorization.

## Rollback

Rollback triggers include a missing/skipped/false-pass V4 aggregate,
candidate self-judgment, authority drift, unexplained V3/V4 divergence,
release/bundle integrity failure, required-context drift or protected-root
mutation.

The reversal order is fixed:

1. freeze the merge queue;
2. restore the V3 workflow from commit
   `c3e055235c51ac8e0394e76135ef7abf3045fb63` and blob
   `51986b5aae2ccdacb52020f21c20b7c12f630726`;
3. restore all 13 V3 contexts in ruleset `23459908`;
4. prove all 13 on the rollback head;
5. only then remove `v4-ifx-required`;
6. disable the V4 workflow only after the V3 proof is preserved.

V3/V3_ifx source remains present. Retirement is V4-TODO-004 and is not part of
P10.3.

## Activation blockers retained

- default-branch promotion is not authorized;
- exact IFX 0.4.2 bundle publication is not authorized;
- installing the specimen under `.github/workflows` is not authorized;
- adding/removing any required context is not authorized;
- no remote negative-control PR or coexistence window has run.

Therefore P10.3 can establish an adoption design and local rehearsal, but it
cannot claim P10.GATE, activation or cutover.
