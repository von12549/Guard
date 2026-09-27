# V4 P9.5 — Immutable offline Web Companion distribution and certification

Status: implementation authorized on `codex/v4-development-base`; P9.5 implementation and local
certification only. V4-P9.GATE, publication, tagging, push, pull request, workflow/ruleset activation
and every remote operation remain separately planned and require separate authorization.

Parent roadmap: `docs/guards/v4/plans/01-v4-self-contained-guard-plugin.md`, V4-P9.5.

Predecessor: `20260922-v4-p9d-evidence-plan-center`

## Goal

Ship the P9.4 Web Companion as a deterministic, installable, offline part of the V4 distribution with
immutable embedded UI assets, then bind the complete P9 suite into Linux-complete and Windows-full
certification without changing Host authority or the remote activation state.

## Scope

- Embed the three first-party HTML, JavaScript and CSS assets into the Companion assembly and serve
  only those fixed resources on loopback; the runtime output must not depend on a loose `wwwroot`.
- Extend the deterministic V4 archive with an exact Companion payload and provenance hash, while the
  existing distribution manifest and external install receipt continue to bind every installed byte.
- Add an installed Companion launcher that fixes the shipped PackageRoot and Host DLL, validates the
  declared .NET prerequisite, accepts only a JSON string array of Companion-owned root/port options,
  and refuses attempts to override the packaged authorities.
- Exercise archive creation, install, installed Companion launch, exact embedded-asset responses,
  command-injection/path-escape/Markdown-XSS refusals, asset drift refusal, uninstall and identical
  reinstall under hostile parent configuration.
- Include all P9 tests in the CI contract's exact hash-approved suite for Linux complete and Windows
  full; keep Windows sensitivity explicit for Web Companion and P9 test paths.
- Extend offline supply-chain inspection to the Web integration and retain the no-external-source,
  no-undeclared-package and no-V3/IFX-runtime boundary.

## Validation

1. The Companion builds without external packages; its output contains no loose `wwwroot`, and HTTP
   responses for `/`, `/app.js` and `/styles.css` are byte-identical to the reviewed source assets.
2. Two builds and two distributions from identical inputs are byte-identical, with Companion DLL
   provenance and every `companion/*` payload file represented exactly once in the archive manifest.
3. Installation rejects Companion payload drift, the installed launcher refuses authority overrides
   and shell-shaped input, and a hostile parent cannot affect build, install, launch or output.
4. Installed UI/API operation preserves PackageRoot and TargetRoot, confines writes to StateRoot and
   EvidenceRoot, and retains the P9.1–P9.4 injection, traversal and Markdown-XSS refusals.
5. Verified uninstall detects asset/assembly drift, removes only receipted files and permits an
   identical reinstall.
6. The exact P0–P9 test set is hash-bound; native Windows full and pinned network-disabled Linux
   complete certification pass against the same clean commit.
7. Package, distribution, lifecycle, supply-chain, stable CLI, V3 Validate, isolated IFX package and
   Formal Pre checks remain passing.
8. No P9.GATE conclusion, UI authority expansion, remote access, release/tag, activation, push or PR
   action is introduced.

## Recovery

Revert the P9.5 commit. The P9.1–P9.4 source Companion and Host contracts remain intact; local archives,
installs and certification reports are disposable ignored artifacts, and there is no remote state to
unwind.
