# V4 Web Companion

The Web Companion is a local presentation and manual-control integration over the released V4 Host.
It is not a guard engine, policy authority or verdict producer.

P9.4 supports one active Target at a time with read-only evidence and Plan inspection:

```text
trusted launcher adds one or more TargetRoot values
  -> Host query.project assigns project identities
  -> browser selects one projectId (never a path)
  -> Host query.profiles/query.doctor provide readiness
  -> manual Stage request enters a single run gate
  -> v4-guards stage run uses the active trusted TargetRoot
  -> Host-owned structured result is returned unchanged
  -> query.runs/query.evidence supply the evidence desk
  -> query.plans classifies read-only Plan pairs
```

The launcher may repeat `--target-root <path>`. Those roots are canonicalized, link-checked, required
to be distinct and non-overlapping, and fixed before the loopback listener starts. The browser can
switch only among their Host-derived 32-character project IDs. Workspace selection is in Companion
memory; it writes no preference or authority file.

Installed Profiles, selected modules, enabled Stages and prerequisite status come from the P9.2
`query profiles`, `query project` and `query doctor` contracts. A browser Stage request contains only
`stage`, an installed Profile ID and `withDependencies`. The Companion refuses disabled Stages and
uninstalled Profiles, then constructs the fixed public `stage run` ArgumentList with shell execution
disabled. The Stage Host still owns binding, prerequisite handling, execution, aggregation and verdict.

The immutable Profile and registered-Target projections are loaded through the Host once and cached
only for the Companion process lifetime, so browser Target switching does not repeat package validation.
After every Stage attempt, the Companion asks the Host for that Target's project projection again and
replaces only the cached presentation snapshot. The cache is never accepted as execution authority.

Target switching and UI-originated Stage runs share a non-blocking single-run gate. A second run or a
switch during an active run receives `409 run-active`; no parallel UI Stage process is started.

The evidence desk requests `/api/v1/runs` and `/api/v1/evidence/{runId}`. The Companion supplies only
the active Host-derived project ID and a validated 32-character run ID to the P9.2 query contracts,
then returns those Host projections unchanged. Findings, coverage, module results, authority hashes,
evidence-file metadata and raw JSON are presentation views; the Companion does not calculate another
verdict.

The optional trusted launcher argument `--plan-root <relative-path>` defaults to `plans` and is fixed
before listening. `/api/v1/plans` returns the active Target's Host catalog. Plan detail requests contain
only a validated Plan ID. The Companion resolves the Host-projected paths below the active Target,
rejects links and files above 1 MiB, reads strict UTF-8 bytes once, and requires their SHA-256 values to
match the Host catalog before returning Markdown text and parsed JSON. The browser builds Markdown
headings, paragraphs, lists, quotes and code blocks with DOM `textContent`; source HTML, images, links,
scripts and event attributes are never interpreted.

V4-native Plans remain `native-contract` / `v4-plan-valid`. Current V3-formal pairs remain labelled
`historical-read-only` / `v3-compatibility-view`; presenting them does not grant V4 authority.

`PackageRoot` and every `TargetRoot` are read-only. Host writes remain below the explicit shared
`StateRoot` and `EvidenceRoot`. The Companion provides no browser path input, terminal, raw arguments,
authority or Plan editing, Target mutation, Reset Apply, Git/PR action, remote access or activation.
P9.5 packaging and certification work remains separately authorized.
