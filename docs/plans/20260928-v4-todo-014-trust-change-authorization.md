# V4-TODO-014 — Trusted-base authorization for approved-test and trusted-component changes

Status: `COMPLETE 2026-09-28 — B1 (PR #7) and B2 (PRs #8–#12, #13, #14 and the records PR) done; see §10`

Formal Plan ID: `20260928-v4-todo-014-trust-change-authorization`.

Backlog: `docs/plans/product/TODO.md` V4-TODO-014. This Plan is a prerequisite of V4-TODO-011 phase 2.
Checklist items: O16 (the interim operator-acceptance rule) and O17 (the improvement point from PR #5).

## 1. Scope: Guard's own development gate

This Plan concerns **the Guard repository gating its own evolution**: V4's trusted-base CI judges changes
to V4 itself. Target projects such as IFX are not directly affected. They consume an immutable, receipted
V4 release installed outside their repository, so their pull requests cannot change the judge. Their
analogous risks belong to the consumer's own trust domain, and section 7 routes them.

## 2. Problem

The base-owned runner judges every pull request with the **base** versions of the verdict components. A
candidate's own copies have no effect on its own verdict. Two gaps remain.

- **G1: no authorization channel.** The runner checks candidate approved tests against the base CI
  contract hashes. That protection is correct and stays. But a legitimate test change always fails with
  "Approved test hash drift" and today merges only under O16. Once a V4-TODO-011 ruleset requires
  `v4-required`, such a change cannot merge at all. P7, P8 and P10 also hard-code the product version, so
  every release bump edits protected tests.
- **G2: trusted components can be weakened silently after merge.** A candidate can change the verdict
  components and still pass, because the base judges it. Once merged, the changed components judge every
  later PR. Current coverage, verified:

  | Silent change | Caught today? |
  | --- | --- |
  | Runner check covered by an existing negative control | yes: approved P6 runs the candidate runner against known negatives |
  | Runner logic without a negative control | no: human review only |
  | CI contract `allowedChangedPatterns` widened | no: no test reads the field |
  | CI contract `windowsSensitivePatterns` reduced | partly: the classifier test only checks the patterns that remain |
  | Certification scripts or package checker weakened in an edge case | partly |
  | Workflow specimen changed (and with it the active-workflow equality baseline) | indirectly |

  Nothing records which runner produced a verdict, although 03 §2 names the runner hash as transition
  evidence.

**G3 (out of scope; platform side).** For `pull_request` events, GitHub runs the workflow definition of the
PR merge result. A PR that edits `.github/workflows/v4-guards.yml` can therefore run a modified workflow.
The runner cannot close this. V4-TODO-011 phase 2 must require review for `.github/**` (section 7).

## 3. Design

### 3.1 Tiered protected set (base-owned)

A new base-owned policy `integrations/github/trust-policy.json` declares explicit paths. It uses no broad
globs, and the runner reads it only from the **base** tree.

| Tier | Paths | Protection |
| --- | --- | --- |
| Verdict components (mandatory) | every `approvedTests` path of the base CI contract; `integrations/github/Invoke-V4TrustedBase.ps1`, `Get-V4WindowsSelection.ps1`, `Test-V4Required.ps1`, `ci-contract.json`, `trust-policy.json`, `proposed-v4-guards.yml`; `integrations/git/Invoke-V4PlanDiff.ps1`; `core/contracts/ci-contract.schema.json`, `ci-artifact-manifest.schema.json`, `trust-change-authorization.schema.json`, `plan.schema.json`, `plan-set.schema.json` | authorization required |
| Certification components | `core/certification/**`, which decides release certification; `core/runtime/Test-V4Package.ps1`, the package authority checker | authorization required |
| Product code | Host, modules, profiles, distribution and installer scripts, documentation | not protected; judged by tests as today |

Implementation note: the runner also executes the Plan-set diff validator and the Plan and Plan-set
schemas from the base, so these three files are verdict components too.

### 3.2 Single-use authorization records (two-step, as V3 P11)

1. **Authorization PR.** Its root Plan has boundary `authorization`, and the runner enforces its shape:
   the diff may **only** add one or more records under `docs/plans/authorizations/<id>.json`, plus the
   PR's own Plan pair. A record validates against the new additive schema
   `core/contracts/trust-change-authorization.schema.json` and binds:
   - the consuming Plan ID;
   - for every protected path, exact `baseSha256` and `headSha256` values, or an explicit add or delete;
   - `acceptedBy`: `human-review` with a non-empty authority id and `candidateHostVerdictAllowed: false`.

   The PR is documentation only, passes V4 checks and merges on operator review.
2. **Trust-change PR.** Its root Plan has boundary `trust-change` and the consuming Plan ID. Against the
   base, which now holds the record, the runner requires all of the following:
   - every changed protected path is covered by exactly one entry of a base-held record for this Plan;
   - the base content equals `baseSha256` and the head content equals `headSha256`;
   - the same diff deletes the consumed record (single use), and the deletion is declared;
   - approved-test drift is accepted only at the authorized `headSha256`, and the candidate CI contract
     binds that hash.

   Missing, partial, mismatched, unconsumed, reused and candidate-only authorizations fail closed with
   stable messages. The existing ban on `authorization` + `trust-change` in one root Plan keeps
   self-authorization impossible.

### 3.3 Judge identity in evidence

The runner writes a `verdictComponents` array (path and SHA-256 of every base verdict component) into its
contract, Linux, Package and Windows results. It also adds the array to the CI artifact manifest through an
additive, optional property of `ci-artifact-manifest.schema.json`. Every verdict can then be traced to the
exact judge that produced it.

### 3.4 Version pins

P7, P8 and P10 read the expected product and assembly version from `plugin.json`. They still assert that
the Host, Web Companion, distribution and composition versions agree with it. A version bump no longer
touches approved tests.

## 4. Bootstrap change (B1)

| Area | Change |
| --- | --- |
| `integrations/github/Invoke-V4TrustedBase.ps1` | protected-set evaluation; base-held authorization lookup; consumption and hash checks; authorization-PR shape rule; `verdictComponents` in results |
| `integrations/github/trust-policy.json` | new tiered policy |
| `core/contracts/trust-change-authorization.schema.json`, `ci-artifact-manifest.schema.json` (optional `verdictComponents`), `contracts-manifest.json` | additive contract changes |
| `tests/p6/Test-V4TrustedBase.ps1` | new controls (section 6) |
| `tests/p0/Test-V4Contracts.ps1` | the new schema appears in the schema list and fixtures |
| `tests/p7`, `tests/p8`, `tests/p10` | versions read from `plugin.json` |
| `integrations/github/ci-contract.json` | test hashes rebound |
| `docs/plans/product/03-genesis-bootstrap-and-autonomy.md` §8.1, `README.md`, `docs/plans/README.md` | document the trust-change flow, the authorization directory and judge identity |

The public CLI, runtime schemas, modules, profiles and four-root runtime are unchanged. The package hash
changes (declared). No release is created.

**Bootstrap acceptance.** The old base has no mechanism, so this is the **last** change accepted under O16:

- the drift must be limited exactly to the declared paths;
- `v4-contract` must pass;
- exact-head dispatch certification must pass Linux-complete and Windows-full with one `packageHash`;
- the operator confirms on the PR.

## 5. Live acceptance after merge (B2)

1. **Live negative.** An approved-test comment edit without authorization must fail `v4-required`. Close
   it unmerged.
2. **Live authorization.** An authorization PR adds exactly one record for that edit. It passes and merges.
3. **Live trust change.** The same edit consumes the record under a `trust-change` Plan. `v4-required`
   must pass, and the results must show `verdictComponents`. Merge it.
4. **Records PR.** Update the backlog and records:
   - V4-TODO-014 is complete;
   - the V4-TODO-011 phase 2 scope gains the required review of `.github/**` and
     `docs/plans/authorizations/**` (closing G3), and its prerequisite is satisfied;
   - a new backlog item records the consumer-side follow-up from section 7;
   - checklist O16 is retired and O17 closed;
   - 03 §8 is updated.

## 6. P6 controls

| Case | Expected |
| --- | --- |
| unauthorized approved-test drift | reject (existing) |
| authorized drift, exact hashes, record consumed | pass |
| record `headSha256` mismatch | reject |
| record not consumed in the same diff | reject |
| record only in the candidate, not in the base | reject |
| record covers only part of the changed protected paths | reject |
| runner change without a record | reject |
| `allowedChangedPatterns` widened without a record | reject |
| `windowsSensitivePatterns` reduced without a record | reject |
| certification script change without a record | reject |
| authorization PR that also changes any other path | reject |
| `authorization` and `trust-change` in one root Plan | reject (existing) |
| product-code change (for example a module adapter comment) without a record | pass (not protected) |
| results carry `verdictComponents` equal to the base component hashes | pass |

## 7. Consumer-side counterpart (routed, not in this Plan)

A target project's analogous exposure lies in its integration layer:

- the pinned Guard release (repository, tag and asset SHA-256);
- its own Profile, bundle and review records;
- its own workflow.

For IFX, these belong to **T7**, which must pin `von12549/Guard` explicitly with an asset hash, keep the
Profile, bundle and review inputs in the IFX trust domain, and protect the IFX workflow through IFX's own
review and ruleset.

Offering the two-step authorization as a **product capability** for targets, so they can protect their
own Profile and bundle changes, is a separate feature. The B2 records PR adds it to the backlog as an item
to evaluate.

## 8. Authorizations requested

- **B1:** implement, run the full local sweep, open the bootstrap PR, dispatch certification, and merge
  under O16 with your PR confirmation.
- **B2:** the live negative (closed), authorization and trust-change PRs (merged), and the records PR.

No ruleset, tag or release is created.

## 9. Stop conditions and rollback

**Stop** if:

- any required control or certification fails;
- any negative control passes;
- the protected set or authorization lookup would read candidate-controlled data;
- the change would alter public CLI, runtime schemas or runtime behavior;
- any need for a ruleset or release arises.

**Rollback:**

- Before merge: close the PR.
- After merge: revert through a PR. The revert touches protected paths, so it needs an authorization
  record. If the mechanism itself is broken, the revert is accepted once under O16 and the use is recorded.

## 10. Outcome (2026-09-28)

| Step | PR | Result |
| --- | --- | --- |
| B1 bootstrap | #7 | Accepted under O16 (expected drift of 5 declared tests). Certification run 36342238399: Linux 33/33, Windows 34/34, package `79d12a1b`. Merged as `0b29783` |
| B2.1 live negative | #8 | `v4-contract` rejected "Approved test hash drift without trust-change authorization: tests/p0/Test-V4Contracts.ps1". Closed unmerged |
| B2.2 authorization | #9 | All checks green (`authorization-added`). Merged |
| B2.3 trust change | #10 | First run failed only in `v4-windows`, on a pre-existing runner defect: the isolated child environment lacked `PATHEXT` (O18). After the fix, all checks were green including Windows smoke, with `authorized` and `verdictComponents` (run 36359282105). Merged |
| Fix: authorization | #11 | All checks green. Merged |
| Fix: trust change | #12 | `v4-contract` `authorized`; `v4-linux` and `v4-package` green; `v4-windows` failed on the unfixed base runner. Accepted once under O16 by the §9 broken-mechanism clause. Certification run 36358564876: Linux 33/33, Windows 34/34, package `19c9c7f0` |
| P6 probe: authorization | #13 | All checks green. Merged |
| P6 probe: trust change | #14 | All checks green (run 36360790400). Merged. P6 now fails if the runner's isolated children cannot resolve `git` |
| B2.4 records | this PR | V4-TODO-014 complete; V4-TODO-011 phase 2 scope extended; V4-TODO-015 added; O16 retired; O17 and O18 closed |

Deviations from this Plan:

- Implementation added three runner-executed files to the verdict tier (§3.1).
- An extra O16 use for PR #12 under §9. It was confirmed by the operator on the PR.
- A P6 regression control. The operator approved fix steps 1–4.
