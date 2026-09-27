# V4 read/query contracts

Status: shipped in V4 1.1.0 as an experimental read-only API. The stable CLI/API version remains 1.0.

The V4 Host owns every projection. A caller supplies explicit roots, the Host validates PackageRoot
and the registered query contract, validates any state or Stage-result authority it reads, constructs
a projection, and validates that projection against its registered result schema before returning it.
The caller must not read package, state or evidence internals and recreate these rules independently.

## Commands

| Command | Required input | Result schema | Meaning |
| --- | --- | --- | --- |
| `query project` | PackageRoot, TargetRoot, StateRoot, EvidenceRoot | `project-query` | Deterministic Target identity and current binding status |
| `query profiles` | PackageRoot | `profile-catalog-query` | Installed package-owned Profile choices and Stage/module readiness |
| `query doctor` | PackageRoot, Profile ID | `prerequisite-query` | The validated package prerequisite report, including missing or incompatible runtimes |
| `query runs` | PackageRoot, StateRoot, EvidenceRoot, project ID | `run-catalog-query` | Validated Stage-result summaries, IDs and hashes |
| `query evidence` | PackageRoot, StateRoot, EvidenceRoot, project ID, run ID | `evidence-query` | One validated Stage result and deterministic evidence file catalog |
| `query plans` | PackageRoot, TargetRoot, relative Plan root | `plan-catalog-query` | V4-native and labelled V3 historical Plan pairs |

The exact syntax, required roots, mutability and result-schema mapping are registered in
`core/contracts/query-contract.json`. All six entries are `experimental` and `read-only`; they are
intentionally separate from `core/contracts/cli-contract.json`, whose released stable command set
does not change in P9.2.

## Authority and presentation rules

- `query project` derives its ID from the canonical TargetRoot and reports state as `missing` or
  `valid`; it never creates a binding.
- `query doctor` is an observation operation. A successfully produced report is returned even when
  its embedded prerequisite status is `error`; that report does not become a guard verdict.
- Run and evidence lists use IDs, content hashes, counts and relative paths. File timestamps are not
  part of the contracts.
- A `v4-native` Plan has passed the V4 Plan runtime. A `v3-historical` entry is only a
  `historical-read-only` / `v3-compatibility-view`; cataloguing it never grants V4-native validity.
- Unknown arguments, malformed identifiers, root overlap, traversal, links, unregistered schema
  drift, malformed stored results and package hash drift fail closed through the existing exit
  categories.

Queries may use operating-system temporary files for schema validation, but never write beneath
PackageRoot, TargetRoot, StateRoot or EvidenceRoot. P9.2 adds no workspace selection, Stage Runner,
authority editor, target mutation, reset, Git operation, remote access or remote activation.
