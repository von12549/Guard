# V4 P10.1 entry — local extension composition compatibility

Status: `WINDOWS + OFFLINE LINUX SYNTHETIC PROTOTYPE PASS — candidate patch and IFX detector-family gates pending`

Formal Plan pair: `20260923-v4-p10-extension-composition-compatibility`.
Predecessor evidence: `07-p10-0-baseline-acceptance.md`.
Parent program: `06-ifx-profile-validation-program.md`, section 2 and P10.1.

## Problem and decision

V4 Guards 1.1.0 loads Profiles only from `PackageRoot/profiles/catalog` and modules only from
`PackageRoot/modules/registry.json`. Package Check hashes both catalogs, while the public release
manifest and external installation receipt identify the unmodified installation. There is no public
operation that turns an explicitly reviewed local Profile/extension bundle into a receipted,
Host-consumable installation. A sibling `ifx_profile` is invisible; copying it into the 1.1.0
PackageRoot destroys that installation's released identity.

### Prototype checkpoint (2026-09-23)

The exact-path Formal Pre returned `advisory` with zero unmapped paths before implementation and
again before the cross-platform receipt correction.
Canonical source now contains four registered composition schemas, a local composer, a read-only
base/composed receipt verifier, a receipted Web Companion launcher and a synthetic test. The test
used the unchanged released 1.1.0 installation as read-only input, created two separate
`synthetic-test-only` compositions under repository `artifacts/`, and never represented them as a
published patch or a human-approved bundle. Their Package hash was
`dd6cea9679ed25966b563dea7544b62c6f74aab8f609496ec3447cce5cfbf336`; both full-file
inventories matched in ordinal order (134 files). Standard Host Profile/doctor/Stage/runs/evidence operations and
the receipted Companion's loopback session/readiness projections passed. The released base and
TargetRoot remained unchanged. Default refusal of the test-only receipt, receipt tampering,
wrong base archive identity and capability-review mismatch also passed. Evidence:
`artifacts/guards/p10-composition/20260923T073359Z-52950e3d7d894ec6888eacc311a68991/summary.json`.

The same test passed in a cached Linux PowerShell/.NET image with `--network none`;
evidence: `artifacts/guards/p10-composition/linux-final/20260923T073443Z-0999f84e85a8465eadc2d1b1a5ec48df/summary.json`.
Windows and Linux composition receipts contained the same Package hash and identical ordinally sorted
`(path, size, SHA-256)` rows for all 134 output files. A final early-rejection guard for a
composition receipt path under TargetRoot passed on both platforms without creating the output
or receipt. The expanded matrix passed 24 Windows rejection cases and 25 offline Linux cases;
Windows could not create the symbolic-link fixture, while Linux verified its rejection.
Both platforms killed a child composer after owned staging appeared, confirmed that no output or
receipt was promoted, then retried with identical input. The retry verified successfully and left
the exact orphan staging unchanged for explicit inspection. A simulated output-without-receipt
state was rejected by both the verifier and composer retry. A project-model zero-match control
against the composed installation was rejected with `matched=0`, `minimum=1` and
`prerequisite-missing`. This is not coverage of every later IFX detector family, nor closure of
the full negative matrix, human bundle acceptance, version promotion or P10.1. The launcher used by
this proof lives in canonical source outside the 1.1.0 installation; a future unique patch must
package it and run installed-path acceptance tests. No browser-interactive composed-UI session
was claimed here; the Companion's Host-backed HTTP projections were smoke-tested.

Before Linux reproduction, a cross-platform identity defect was found in the prototype design:
the copied original installation receipt contains an absolute `installRoot`. That path differs
between Windows and Linux, so retaining the receipt inside the composed output makes the full
file inventory platform-dependent. The corrected design keeps the original base receipt external:
the composition receipt records its SHA-256, and verification/launch requires that exact external
base receipt as a separate input. The internal composition manifest binds only platform-neutral
base archive/manifest/package identity. The prototype paths were unchanged, Formal Pre was
refreshed, and both Windows and offline Linux proofs were rerun successfully.

Choose **explicit offline composition into a new sibling installation** as the compatibility
direction. The input is a verified, immutable next-`1.1.x` base installation and one explicitly
specified, reviewed local extension bundle. The output is a new immutable installation containing
the standard `package/`, `host/` and `companion/` layout plus an external composition receipt. The
published base release and its receipt remain intact. The composed output is never described as
byte-for-byte equal to the public release; its tuple contains the base release identity, bundle
identity and resulting package hash.

This is a proposed implementation boundary, not permission to edit 1.1.0 or publish a patch. The
exact implementation path set and receipt-enforcement mechanism must pass the design gate below
before runtime code changes begin. A package-external runtime loader is not the default: it would require
new Profile/module resolution and query/prerequisite semantics across the Host and Web Companion.

## Public lifecycle contract to add in the next patch

The patch must provide a documented, packaged local composition command with explicit parameters
for the base installation, its verified release receipt, the extension bundle, its independently
accepted review record (or signature evidence if H2-B is selected), an absent sibling output
installation path and an external receipt path. It must not discover, download or execute a
bundle automatically. Browser input cannot select any of these paths or invoke composition.

The bundle has a versioned manifest and a complete sorted file inventory with sizes and SHA-256
hashes. It may add Profiles and declared modules, including a Profile that uses only existing
modules; it may not replace base files or IDs. A module contribution must include its manifest,
adapter, dependency lock, config/result schemas, authority files, requested capabilities and
prerequisites. The Profile's selected modules, per-Stage configuration, baselines and project
identity must validate under the existing V4 schemas and Package Check.

The expanded negative matrix passed 24 Windows cases and 25 offline Linux cases (the Windows
environment could not create a symbolic-link fixture). Running the Linux suite on a local
container filesystem exposed culture-dependent `Sort-Object` ordering. The composer now orders
generated registry entries and receipt inventory paths with `StringComparer.Ordinal`, and the
Windows/Linux reruns produced identical ordered 134-row inventories. The verifier also rejects
non-ordinal receipt inventories. Staging interruption, retry and unreceipted-output refusal now
pass on both platforms; zero-match proof here covers only the existing project-model family.

Composition must:

1. Verify the base public archive/manifest/package identity and installation receipt, plus the
   entire bundle inventory, before creating output. Reject drift, undeclared files, duplicate or
   case-colliding paths/IDs, unsafe relative paths, reparse points/symlinks, and overlaps among
   input, output, TargetRoot and mutable roots.
2. Enforce a declared maximum capability set; never grant TargetRoot writes, arbitrary process,
   network or extra read roots because a bundle asks for them. Reject unsupported API/product
   ranges, missing dependencies, invalid module schemas and ambiguous registry references.
3. Copy and compose in a private staging directory, generate catalog/registry bytes in stable
   order and encoding, run Package Check and prerequisite validation, then atomically promote to
   a previously absent output path. Failure leaves no promoted installation or success receipt.
4. Emit a schema-validated external composition receipt that binds the base release tag/commit,
   archive and original receipt hashes, accepted review/signature evidence, bundle manifest and
   file hashes, output full-file
   inventory, resulting package hash, Profile/module IDs and versions, and composition format
   version. The receipt must make base-versus-composed identity unambiguous.
5. Provide a read-only verifier for that receipt. P10 operator commands and the installed Web
   Companion launcher must verify it before running a composed installation. Receipt drift or a
   missing receipt fails closed; direct Host calls remain subject to the existing Package Check
   and must not be misrepresented as receipted P10 evidence.

The composed installation must remain consumable by the standard Host `stage run`, `query
profiles`, `query doctor`, `query runs` and `query evidence` surfaces. The UI remains a
non-authoritative projection. The composition command does not add a browser editor, package
hot-reload, marketplace, remote installer, or IFX-specific policy to the V4 core.

### Proposed receipt and launch mechanics

The composer copies `package/`, `host/` and `companion/` into a new output. It moves the base
`distribution-manifest.json` to a clearly named `provenance/base-distribution-manifest.json`
there, rather than leaving a top-level manifest that appears to describe the composed output.
An output `provenance/composition-manifest.json` records platform-neutral base and bundle
identities but not its own final hash. The original base receipt stays outside the output; its
exact SHA-256 belongs in the **external** composition receipt. That receipt hashes the complete
output inventory and records the composed package hash, avoiding both a self-hash cycle and
platform-specific `installRoot` bytes in the composed tree. Verification requires both external
receipts.

A new installed, receipted launcher should require an explicit receipt path for either a base
or composed installation, verify the complete installation before starting the Web Companion,
and pass only the standard PackageRoot/Host arguments afterward. A marker is descriptive, not
an authorization shortcut: deleting it cannot make a composed tree match the base release
receipt's exact file inventory. The existing direct Host interface remains available, but a
direct unreceipted run is not admissible as P10 composition evidence.

Staging uses a unique, private sibling directory and atomic promotion to an absent destination.
The composer may clean only a staging directory it created and can identify exactly; unknown
leftovers after interruption require explicit inspection, never wildcard cleanup. Equal inputs
must produce equal package and full-file inventory hashes on Windows and Linux; timestamps and
output path are excluded from composed authority bytes.

### Confirmed design choices and human approval boundary

On 2026-09-23 the user selected `H1=A, H2=A, H3=A, H4=A` for the compatibility design and named
Xiaolong Feng as the bundle approver. The existing
`docs/guards/V3_ifx/stages/post/policy/g03/catalog.json` owner catalog identifies that person
as `xiaolong-feng`; use `authorityType: human-review` and
`authorityId: xiaolong-feng` in the future bundle-review record. This selects the design and
the eligible human authority only. It does **not** approve an as-yet-unbuilt bundle, grant
actual IFX module capabilities, or authorize a release.

| ID | Selected design (A) | Rejected alternative (B) |
| --- | --- | --- |
| H1 — receipt gate | A new receipted launcher requires and verifies the external receipt before Web UI start; P10 operator evidence requires the same verifier. Direct Host invocations remain diagnostic unless separately receipted. Preserve the existing stable Stage CLI. | Require the Host itself to accept and verify a receipt on every Stage and query call; stronger enforcement, larger CLI/Host compatibility change. |
| H2 — bundle trust | Xiaolong Feng (`xiaolong-feng`) must accept an exact bundle-manifest SHA-256, file inventory and capability ceiling in a separate review record; composition checks that record and never treats candidate V4 output as self-approval. | Require an externally signed bundle plus independent signature verification and key governance before composition. |
| H3 — capability ceiling | Default-deny, per-bundle and per-module allowlists bounded by V4's existing root/capability model. The first synthetic prototype permits only `TargetRoot` read, no writes, `pwsh`, no network and at most 30 seconds. Actual IFX grants need later exact review. | A centrally fixed global extension ceiling; simpler administration but either over-broad or unable to serve differing IFX gates. |
| H4 — composed-installation retirement | No automatic removal in the compatibility prototype; rollback selects the prior receipted sibling. Any later removal is an exact, receipt-verified operation with separate authorization. | Add receipt-verified uninstall to the first patch's public lifecycle contract. |

The future bundle-review record must have its own stable record ID and bind the concrete bundle
manifest SHA-256, complete file inventory, per-module capability ceilings, reviewer authority
type/ID and the decision's scope. It must be created only after those bytes are fixed and
reviewed. Its record ID is not the same as the person's governance ID. The exact patch release
candidate and remote publication also require their own recorded human decisions at later gates.
H1–H4 may change only through an explicit Plan revision, not through a bundle manifest.

### Prototype path set and later candidate-version inventory

The H1=A design uses the following canonical paths. The contract, lifecycle, test and
documentation paths for the **synthetic prototype** are now frozen in the formal Plan
`plannedPaths` and require refreshed Formal Pre before source edits. The version and
release-candidate paths remain a later, separately planned checkpoint.

- Contracts: `core/contracts/extension-bundle.schema.json`,
  `core/contracts/extension-review.schema.json`,
  `core/contracts/composition-manifest.schema.json`,
  `core/contracts/composition-receipt.schema.json`,
  `core/contracts/contracts-manifest.json`, and `tests/p0/Test-V4Contracts.ps1`.
- Local lifecycle: `core/distribution/Compose-V4Extension.ps1`,
  `core/distribution/Test-V4ComposedInstallation.ps1`,
  `core/distribution/Invoke-V4ReceiptedWebCompanion.ps1`, and
  `tests/p10/Test-V4ExtensionComposition.ps1`.
- Candidate-version and certification bindings, only when a unique patch candidate is prepared:
  `plugin.json`, `core/host/V4.Guards.Host/V4.Guards.Host.csproj`,
  `integrations/web/V4.Guards.WebCompanion/V4.Guards.WebCompanion.csproj`,
  `core/certification/compatibility-baseline.json`,
  `integrations/github/ci-contract.json`, `tests/p7/Test-V4Distribution.ps1`,
  and `tests/p8/Test-V4StableCli.ps1`.

All paths above are relative to `docs/guards/v4/`. The existing `tests/p9/Dockerfile.linux`
may be reused for a network-disabled Linux run without modifying it. H1=A assumes no Host
or Web Companion source change; if the prototype disproves this, stop, amend the exact Plan
and rerun Formal Pre before touching additional paths. The prototype is not a 1.1.x
distribution, and no modified source that still reports 1.1.0 is admissible as release evidence.

## Design gate before implementation

Before editing runtime source, record and review an exact formal `plannedPaths` set, specify
how a small synthetic prototype will answer these verification questions, and pass Formal Pre:

- Where is the composition marker stored, and how does the installed launcher distinguish a
  published base installation from a composed one without trusting a removable marker alone?
- How does the verifier bind the output full-file inventory to its external receipt without
  creating a package-hash cycle? How is an interrupted staging directory recovered safely?
- Does the copied base `distribution-manifest.json` remain explicitly base provenance, or is it
  retained outside the composed installation? No stale manifest may claim the composed tree is
  the public archive.
- Can a composition of the same base and bundle reproduce the same package hash and complete
  file inventory on native Windows and pinned, network-disabled Linux?
- Can the installed launcher and Host queries all consume the composed PackageRoot without a
  second loader or a second verdict authority?

The prototype is the first source implementation step after that gate. If it cannot meet these,
stop and amend this Plan with the minimal Host,
query and/or lifecycle contract changes. Do not silently broaden the implementation diff.

## Ordered implementation and evidence gates

1. **Contract and synthetic prototype.** Specify bundle and receipt schemas, canonical paths,
   composition identity and read-only verifier. Freeze the exact source/contract/test paths in
   a formal Plan revision and pass Formal Pre. Then prove one added synthetic Profile and one
   declared synthetic module from an explicit local bundle.
2. **Fail-closed implementation.** Implement composition, full receipt validation and launcher
   integration in canonical `docs/guards/v4` source only. Preserve the stable Stage CLI, four-root
   confinement and existing uncomposed 1.1.0 behavior. Exercise direct Stage and dependency runs,
   query projections and prerequisite checks on the composed synthetic installation.
3. **Negative and determinism matrix.** Test corrupt hashes, missing/extra files, stale or wrong
   base receipt, duplicate IDs, case collisions, traversal/absolute paths, symlinks/reparse
   points, over-capability, incompatible version, missing runtime, schema-invalid Profile/module,
   interrupted compose, existing output, receipt drift, zero-match and attempted writes to
   PackageRoot/TargetRoot. Repeat identical-input composition and compare package/full-file hashes.
4. **Certification and patch gate.** Pass V4 contract, package, lifecycle, supply-chain,
   compatibility, Windows-full and pinned Linux-complete suites. Record source commit, product/API
   versions, new package/archive hashes, base and composed receipts, and recovery. Only a separate
   exact release-publication Plan and authorization may publish the next unique `1.1.x` patch.
5. **P10.1 handoff.** Install that published patch in a new sibling directory, verify its release
   receipt, then compose a reviewed `ifx_profile` bundle into another new sibling installation.
   Freeze the resulting version ledger before IFX Stage/UI practice. This compatibility Plan does
   not itself claim IFX policy coverage or P10.1 completion.

## Stop and recovery conditions

Stop on any need to write an existing release or TargetRoot, unverifiable base/bundle/receipt,
unbounded capability, non-deterministic output, Host/UI disagreement, missing evidence, cross-root
overlap, or unplanned source path. No failure may be turned into an accepted baseline or solved by
hand-editing an installation. Recovery discards only an exact, verified temporary staging path or
switches back to the prior receipted sibling installation; it never rewrites 1.1.0 in place.

Remote workflows, rulesets, required checks, default branches, IFX cutover, V3 retirement and
marketplace/network installation remain out of scope.
