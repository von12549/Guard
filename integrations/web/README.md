# V4 Web Companion

The Web Companion is a local presentation and manual-control integration over the released V4 Host.
It is not a guard engine, policy authority or verdict producer.

Published V4 1.1.0 packages the completed P9 one-active-Target workspace, evidence desk and Plan Center
as an offline, installable Companion. Version 1.1.1 preserves that surface:

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

The reviewed `index.html`, `app.js` and `styles.css` sources are embedded resources in
`v4-web-companion.dll`. A runtime build or installed distribution contains no loose `wwwroot`; the
loopback endpoints serve the embedded bytes with the same CSP and `no-store` policy. The deterministic
distribution includes the Companion DLL, dependency/runtime metadata and integration schemas under
`companion/`. Its distribution manifest binds every file and records the Companion entry-assembly
SHA-256 alongside the Host and package provenance.

`core/distribution/Invoke-V4InstalledWebCompanion.ps1` launches only the shipped Companion and Host
from an installed distribution. It resolves the declared .NET prerequisite, fixes PackageRoot and the
Host DLL itself, accepts a JSON string array containing only TargetRoot, StateRoot, EvidenceRoot,
PlanRoot and port options, and never invokes a command shell. Attempts to override Host or PackageRoot
are refused.

Version 1.1.1 also packages `core/distribution/Invoke-V4ReceiptedWebCompanion.ps1` for
explicitly reviewed local compositions. It requires the external composition receipt and original
base-installation receipt, verifies both against the composed installation, and then delegates to
the same installed Host and Companion. A synthetic test receipt is denied unless its explicit
fixture-only switch is present. This is not browser-initiated bundle installation or an IFX verdict.

The Companion is part of the exact hash-approved Linux-complete and Windows-full test set. Its installed
lifecycle proves deterministic independent builds and archives, byte-identical embedded asset
responses, hostile-parent isolation, command/path/XSS refusal, receipt drift detection, verified
uninstall and identical reinstall.

`PackageRoot` and every `TargetRoot` are read-only. Host writes remain below the explicit shared
`StateRoot` and `EvidenceRoot`. The Companion provides no browser path input, terminal, raw arguments,
authority or Plan editing, Target mutation, Reset Apply, Git/PR action, remote access or activation.
P9.GATE passed before the 1.1.0 release candidate. Later capability expansion and every activation
action remain separately authorized.
