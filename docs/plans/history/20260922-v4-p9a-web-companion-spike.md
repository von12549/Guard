# V4 P9.1 — Local Web Companion architecture and contract spike

Status: implemented and locally certified on `codex/v4-development-base`; local P9.1 implementation only.
V4-P9.2 through V4-P9.5, push, pull request, workflow/ruleset activation and every remote operation
remain separately planned and authorized.

Parent roadmap: `docs/guards/v4/plans/01-v4-self-contained-guard-plugin.md`, V4-P9.1.

Predecessor: `20260922-v4-p9-lightweight-web-ui-planning`

## Goal

Prove that a separately packaged, loopback-only Web Companion can provide one synthetic
Target-to-result flow through the released V4 Host without becoming a guard engine, accepting raw
commands or weakening the four-root execution contract.

## Scope

- Add a separate .NET Web Companion process which binds only to IPv4 loopback.
- Bind `PackageRoot`, `TargetRoot`, `StateRoot`, `EvidenceRoot` and the V4 Host DLL at trusted process
  startup; none of these values are browser-controlled.
- Issue an HTTP-only, same-site loopback session cookie and require an exact same-origin request for
  the only mutation route.
- Expose one strictly parsed Stage request which allowlists the four public Stage names and the
  installed `synthetic_profile`; reject unknown, duplicate and malformed fields.
- Invoke only the stable public `stage run` command by `ProcessStartInfo.ArgumentList`, with shell
  execution disabled and a minimal allowlisted environment.
- Preserve the Host JSON and exit code without deriving or replacing the Host verdict.
- Serve package-owned, offline UI assets that identify the Host as the verdict authority and provide
  no terminal, raw argument, authority editing, target mutation, reset, Git or remote controls.
- Prove root immutability, request injection refusal, loopback/session enforcement and one real
  synthetic Host result on Windows and Linux.

## Validation

1. The formal Plan pair declares the exact P9.1 changed path set.
2. The Companion refuses non-loopback Host headers, missing/wrong origin, missing session, unknown or
   duplicate JSON fields, non-allowlisted stages and non-synthetic profiles before Host invocation.
3. A valid request reaches the existing V4 Host `stage run` route and returns its structured result
   and exit code without reinterpretation.
4. PackageRoot and TargetRoot hashes do not change; all Host writes remain confined to the supplied
   StateRoot and EvidenceRoot.
5. An overlapping mutable root is rejected before the HTTP listener starts.
6. The same spike suite passes natively on Windows and in the pinned Linux toolchain image.
7. No Host policy, profile, module, rule, baseline, verdict, reset behavior, workflow, ruleset or
   remote state changes.

## Observed result

- Native Windows (`Microsoft Windows 10.0.26200`): P9.1 spike suite passed; Host and Companion built
  with zero warnings and zero errors.
- Pinned, network-disabled Linux container (`Ubuntu 22.04.5 LTS`): the same P9.1 spike suite passed.
- V4 package validation passed with package hash
  `dae826370fe0c639491c9b353faa84d86cd6022813aacaa1a244096a0baa100d`.
- V4 P0 contract regression passed with 24 schemas, 11 commands and 25 bound contracts; V4 stable CLI
  regression preserved version `1.0.0` and all released command behavior.
- Formal Pre accepted the exact Plan pair, and the 16 actual changed paths equal the 16 declared
  `plannedPaths`.

## Recovery

Revert the P9.1 commit. V4 Guards 1.0.0 and every released CLI/runtime contract remain unchanged; the
new Companion has no remote state and writes no data outside explicitly supplied V4 mutable roots.
