# Target-project trust-change authorization

M5 implements V4-AD-044 as an experimental consumer-neutral Host capability. A Target's trusted base
policy declares its protected paths and authorization directory. The consuming change is validated by
the previously trusted Host against policy and authorization bytes read from the exact base Git object.

## Two-step lifecycle

1. `target-trust authorize` prepares a non-authoritative authorization candidate below EvidenceRoot.
   Each entry binds the consuming Plan and exact base/head file hashes, including add or delete as a
   null endpoint. A human-review authority is recorded and candidate Host verdicts are forbidden.
2. A separate authorization change deliberately adopts that record into the policy's authorization
   directory.
3. A later `trust-change` Plan changes the protected files and deletes the record. `target-trust
   validate` requires the consuming Plan in the candidate Plan set, exact protected-path coverage,
   exact hashes and a `trust-change` boundary without `authorization`.

Candidate-only, missing, partial, undeleted/reused, hash-mismatched, unprotected and self-authorizing
records fail closed. The result includes the Host assembly, base policy and M5 governance-catalog hashes
as judge identity.

Validation reports `applied: false`. It does not apply Target files, deliver a pull request, change a
workflow/ruleset, inspect remote enforcement or activate anything. Active governance, repository
history and operational receipts remain different records. An external governance repository is not
accepted as an arbitrary policy directory.
