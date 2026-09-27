# V4 P9.3 — One-active-Target workspace and Stage Runner

Status: implementation authorized on `codex/v4-development-base`; P9.3 implementation only. V4-P9.4,
V4-P9.5, push, pull request, workflow/ruleset activation and every remote operation remain separately
planned and require separate authorization.

Parent roadmap: `docs/guards/v4/plans/01-v4-self-contained-guard-plugin.md`, V4-P9.3.

Predecessor: `20260922-v4-p9b-read-query-contracts`

## Goal

Turn the P9.1 Companion spike into a one-active-Target workspace and manual Stage Runner that consumes
P9.2 Host projections for Target identity, installed Profiles and prerequisite readiness while keeping
the V4 Host as the only execution and verdict authority.

## Scope

- Accept one or more Target roots only from trusted Companion startup arguments and expose Host-derived
  project IDs to the browser; browser requests select a project ID, never a path or raw Host argument.
- Maintain exactly one active Target in Companion memory and serialize Target switching against
  UI-originated Stage execution.
- Project installed Profile, selected-module and per-Stage readiness from `query profiles` and runtime
  readiness from `query doctor`.
- Allow manual Bootstrap, Analysis, Pre or Post execution only when the selected installed Profile
  enables that Stage; show the explicit dependency chain before execution.
- Continue to construct the fixed `stage run` ArgumentList with shell execution disabled, shared
  StateRoot/EvidenceRoot and the active trusted TargetRoot.
- Reject simultaneous UI-originated runs, unknown projects, uninstalled Profiles, disabled Stages,
  raw arguments, path input, missing session and wrong origin before Stage invocation.
- Reshape the offline UI around Target selection, readiness, visible Stage order and the unchanged
  Host result without adding evidence interpretation or Plan presentation.

## Validation

1. Workspace, selection and Stage request/response payloads satisfy strict schemas.
2. Two trusted startup Targets receive distinct Host-derived project IDs and only one is active.
3. A valid project-ID selection changes the active Target without accepting a browser path.
4. Installed Profile, module and Stage readiness is sourced from P9.2 query results; doctor output is
   returned unchanged and is not converted into a guard verdict.
5. The selected Stage and optional dependency chain are visible before a manual run.
6. Concurrent UI run requests cannot execute in parallel; switching is refused while a run is active.
7. A successful synthetic run uses the active Target and returns the Host JSON and exit code unchanged.
8. PackageRoot and every TargetRoot remain byte-identical; Host writes remain confined to StateRoot
   and EvidenceRoot on Windows and pinned, network-disabled Linux.
9. No result/evidence browser, Plan Center, authority edit, target mutation, reset, Git/PR action,
   terminal, remote access or remote activation is introduced.

## Observed result

- Native Windows (`Microsoft Windows 10.0.26200`) passed the P9.3 suite with zero-warning,
  zero-error Host and Companion builds; the P9.1 Web Companion regression also passed.
- The P9.3 suite passed in the pinned, network-disabled Linux container
  (`Ubuntu 22.04.5 LTS`).
- Browser QA proved immediate cached Target switching, the visible `Bootstrap -> Analysis` dependency
  chain, an unchanged Host `pass` result and a 720 px layout without horizontal overflow or console
  errors. A deliberate Pre run also displayed the Host-owned prerequisite failure unchanged.
- V4 package validation passed with package hash
  `c550eed25aa73189bd0b223a0e41657a132a451b128b6faed314f11caf8ac739`.
- P0 regression passed with 31 schemas, 11 unchanged stable CLI entries, six experimental read queries
  and 33 bound contracts. Stable CLI 1.0.0 behavior passed unchanged.
- V3 Validate, the declared isolated `ifx-package-test` and Formal Pre passed.
- The 18 actual changed paths equal the 18 declared `plannedPaths`.

## Recovery

Revert the P9.3 commit. P9.2 query contracts, P9.1 spike behavior and V4 Guards 1.0.0 remain available;
the active workspace exists only in Companion process memory and has no remote state.
