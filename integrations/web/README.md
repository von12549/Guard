# V4 Web Companion

The Web Companion is a local presentation and manual-control integration over the released V4 Host.
It is not a guard engine, policy authority or verdict producer.

P9.3 supports one active Target at a time:

```text
trusted launcher adds one or more TargetRoot values
  -> Host query.project assigns project identities
  -> browser selects one projectId (never a path)
  -> Host query.profiles/query.doctor provide readiness
  -> manual Stage request enters a single run gate
  -> v4-guards stage run uses the active trusted TargetRoot
  -> Host-owned structured result is returned unchanged
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

`PackageRoot` and every `TargetRoot` are read-only. Host writes remain below the explicit shared
`StateRoot` and `EvidenceRoot`. The Companion provides no browser path input, terminal, raw arguments,
authority or Plan editing, Target mutation, Reset Apply, Git/PR action, remote access or activation.
P9.4 result/evidence viewing and Plan Center work remains separately authorized.
