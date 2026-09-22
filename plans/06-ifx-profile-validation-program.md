# V4 P10 — IFX Profile validation program

Status: `PLANNED — implementation and remote activation not authorized`

Formal planning checkpoint: `20260923-v4-ifx-profile-validation-program`

Initial V4 baseline: `v4-guards-v1.1.0`

Scope authority: V4-TODO-001, V4-TODO-002 and V4-TODO-003. V4-TODO-004 legacy retirement remains
separate and cannot be pulled forward by this program.

## 1. Program invariant

The published 1.1.0 archive is the immutable initial baseline. The canonical source remains
`D:\IFX\docs\guards\v4`; no file below an extracted release is edited. A defect found while testing is
reproduced against the installed release, fixed in canonical source, certified on Windows and Linux,
published as the next `1.1.x` release and installed into a new sibling directory.

The active V3/V3_ifx guard remains the trusted IFX reference until a later, separately authorized
cutover. Candidate V4 code and `ifx_profile` cannot establish their own parity verdict.

## 2. 1.1.0 extension gap and entry gate

The 1.1.0 Host resolves Profiles exclusively from `PackageRoot/profiles/catalog`; module loading is
exclusive to the package registry. Package Check hashes the Profile and module catalogs, and the
distribution receipt binds the package hash. There is no implemented package-external Profile or
extension installation/composition command.

Consequences:

- `ifx_profile` cannot be copied into the released PackageRoot without invalidating release identity;
- a hand-modified package still reporting product version 1.1.0 is not a valid test baseline;
- P10.0 first records the pristine behavior and evaluates the published composition surface;
- if no existing compliant composition path exists, P10.1 starts with a separate compatibility Plan
  for a deterministic, receipted local extension install/composition boundary and publishes it as the
  next 1.1.x patch before IFX policy testing proceeds.

Automatic discovery, download, marketplace access and remote installation remain excluded. Any local
installer must accept an explicit reviewed bundle, validate schema/hash/capabilities, compose an
immutable PackageRoot deterministically and produce an external receipt.

## 3. Filesystem topology

```text
D:\IFX\                              TargetRoot and canonical repository
├─ docs\guards\v4\                   canonical V4 source authority
└─ guard\                             ignored test installation container
   └─ releases\
      ├─ v4-guards-1.1.0\            exact immutable published installation
      └─ v4-guards-1.1.x\            later exact immutable patch installations

D:\IFX.guard-runtime\                never below TargetRoot or PackageRoot
├─ state\                             mutable StateRoot
└─ evidence\                          mutable EvidenceRoot
```

The four-root contract allows PackageRoot to be below read-only TargetRoot but forbids StateRoot or
EvidenceRoot from overlapping either authority root or one another. `ifx_profile` must constrain
project discovery to reviewed IFX roots and prove `guard/**` cannot enter the project model, build copy,
findings, policy hashes or evidence. If current module configuration cannot express that exclusion,
the program stops for a separately reviewed 1.1.x compatibility change.

`guard/` is created only by the P10.0 implementation checkpoint. That checkpoint also adds the exact
repository ignore rule and proves the directory contains no tracked source authority.

## 4. P10.0 — released baseline and topology

Required evidence:

1. verify the remote tag peels to candidate
   `a81a12e0d1f476c563497f961fe41fccc53edfb6`;
2. verify archive SHA-256
   `d7d3b1ef7f70bab3153c4d1253b8a1e6db2bdea13645fe6597d36c29432c9fbd` before extraction;
3. install into `guard/releases/v4-guards-1.1.0` through the released lifecycle command and retain the
   external install receipt;
4. prove `version` is 1.1.0, API is 1.0, Package Check returns package hash
   `cfea69e151f4edcccb51c16f91ce3c1d2651bcdf89323ea133fdff8f37615802`, and prerequisites pass;
5. hash PackageRoot and TargetRoot before/after query and synthetic dry runs; only external StateRoot
   and EvidenceRoot may change;
6. prove `query profiles` exposes only the two released Profiles and record package-external Profile
   installation as unsupported unless a reviewed existing contract proves otherwise; and
7. prove all target discovery and evidence omit `guard/**`.

P10.0 stops on archive/receipt drift, root overlap, self-discovery, undeclared prerequisites or any
need to edit the installation.

## 5. P10.1 — V4-TODO-001 `ifx_profile` practice

The checkpoint inventories and maps, without importing V3 runtime paths:

| IFX authority | V4 destination | Required proof |
| --- | --- | --- |
| Project map and repository identity | Profile project identity/config | exact reviewed roots; `guard/**` absent |
| Toolchain and prerequisites | Profile/module prerequisite declarations | versions and missing-runtime failure |
| Architecture policy and claim matrix | Architecture Conformance config/authorities | every claim has detector/evidence ownership |
| Finding baselines | Profile-owned baseline references | explicit entries; no blanket suppression |
| Specialized IFX gates | Declared extension modules | schema, result, capability and dependency locks |
| Stage ownership | Bootstrap/Analysis/Pre/Post configuration | direct execution and visible dependencies |

Acceptance requires schema-valid Profile and extension bundles, deterministic package composition and
receipts, capability ceilings, clean/direct Stage runs, deliberate IFX violations, missing prerequisites,
zero-match refusal, reset confinement and PackageRoot/TargetRoot immutability. A public-contract gap is
a V4 defect/compatibility decision and consumes a new 1.1.x patch; it is not hidden in the Profile.

## 6. P10.2 — V4-TODO-002 parallel parity

Before execution, record one fixed repository commit, toolchain identity, V3/V3_ifx package hash, V4
release/package hash, Profile version, extension hashes and corpus manifest. Neither engine reads output
from the other.

The corpus contains:

- the clean fixed IFX commit;
- one deliberate violation per blocking claim and specialized gate;
- missing project/toolchain/build/policy evidence controls; and
- zero-match controls for each detector family.

The parity matrix compares blocking/advisory verdict, exit category, rule/finding identity, subject,
evidence kind, detector, coverage/non-vacuity, policy/authority hashes, prerequisites and report
provenance. Formatting and detector implementation may differ; missing claims, weakened severity,
accepted missing evidence, zero-match success, stale build evidence or unexplained verdict differences
block the gate.

Parity evidence is judged by the previously trusted V3/V3_ifx reference plus an independent comparison
script. Candidate V4 output is evidence, not its own acceptance authority.

## 7. P10.3 — V4-TODO-003 cutover and rollback design

Entry requires completed P10.2 parity, no open blocking gap and a Windows-full certification of the
exact proposed 1.1.x baseline. The proposal must specify:

- trusted base/source selection and prevention of candidate self-judgment;
- stable required contexts and their always-present aggregate verdict;
- inactive workflow specimen, permissions, secrets and artifact flow;
- Architecture Conformance detector-family ownership transition;
- one-time compatibility bridges with deletion/expiry conditions;
- coexistence window with the active V3/V3_ifx guard;
- rollback triggers, exact restore commit/tag, remote reversal order and local rehearsal evidence; and
- the boundary keeping V4-TODO-004 retirement as the final, separate migration action.

P10.3 authorizes documentation and local rehearsal only. Creating or modifying GitHub workflows,
required checks, rulesets, default branches or protected settings, and performing IFX cutover, require
a later exact Plan and separate explicit authorization.

## 8. Version ledger and gates

Every test run records `(V4 product version, source commit, package hash, archive hash, Profile version,
extension hashes, IFX target commit, corpus hash)`. Evidence from different tuples is never merged under
one result.

- 1.1.0 is retained permanently as the initial immutable baseline.
- Each correction to the distributed V4 test baseline publishes the next unique 1.1.x version after
  Windows-full, Linux-complete, lifecycle, supply-chain and compatibility certification.
- Installations are side by side; promotion selects a new path only after receipt verification.
- Rollback selects the prior immutable installation and external state snapshot; it never rewrites an
  installation in place.

P10.GATE passes only when P10.0–P10.3 evidence is complete, the latest installation is reproduced from
a public 1.1.x release, all parity gaps are closed, rollback is rehearsed and no V3 runtime dependency
exists in V4. Passing P10.GATE means adoption-ready only; it does not activate anything remotely.
