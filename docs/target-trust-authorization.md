# Target-project trust-change authorization

This experimental M5 capability is available in the 1.2.0 source candidate; it is not part of the 1.1.6 asset
and does not report remote enforcement.

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
   validate` reads the Plan set and every member Plan from the exact head Git object. It verifies the
   complete schema projection, member identity/hash/dependencies, canonical order, derived union,
   composition hash and an exact match between the union's planned paths and the base/head diff. It
   then requires the consuming Plan in that verified set, exact protected-path coverage, exact hashes
   and a `trust-change` boundary without `authorization`.

Candidate-only, missing, partial, undeleted/reused, hash-mismatched, unprotected and self-authorizing
records fail closed. The result includes the Host assembly, base policy and M5 governance-catalog hashes
as judge identity.

Working-tree files and candidate-declared hashes are never substituted for the reviewed base/head Git
objects. The Plan set must own its own path and all member Plan paths through its exact derived union;
omitted diff paths, forged member hashes, missing members, duplicate identities and stale composition
hashes are blocking findings.

Validation reports `applied: false`. It does not apply Target files, deliver a pull request, change a
workflow/ruleset, inspect remote enforcement or activate anything. Active governance, repository
history and operational receipts remain different records. An external governance repository is not
accepted as an arbitrary policy directory.
