# V4 P9.4 — Evidence viewer and read-only Plan Center

Status: implementation authorized on `codex/v4-development-base`; P9.4 implementation only. V4-P9.5,
push, pull request, workflow/ruleset activation and every remote operation remain separately planned
and require separate authorization.

Parent roadmap: `docs/guards/v4/plans/01-v4-self-contained-guard-plugin.md`, V4-P9.4.

Predecessor: `20260922-v4-p9c-workspace-stage-runner`

## Goal

Add structured run/result/evidence inspection and a read-only Plan Center to the local Web Companion,
using only P9.2 Host projections and Host-vetted Plan identities while preserving the Host as the sole
integrity, validation and verdict authority.

## Scope

- Expose active-Target run catalogs and evidence details by Host-derived project and run IDs; browser
  requests never supply a root, relative path or raw Host argument.
- Present the unchanged Stage result as structured summary, findings, coverage, module evidence,
  authority hashes and a raw JSON view without reinterpreting Host status.
- Expose the active Target's Host-classified Plan catalog from a launcher-fixed relative Plan root.
- Select Plan details by validated Plan ID only, re-check the Host-projected paths, links, byte limits
  and SHA-256 values, and return the Markdown text plus parsed JSON as a read-only presentation pair.
- Render Markdown through explicit DOM nodes and `textContent`; do not execute embedded HTML, links,
  scripts, images or event attributes.
- Label `v4-native` / `native-contract` separately from `v3-historical` /
  `historical-read-only`; presentation must not grant historical pairs V4-native validity.
- Keep P9.3 one-active-Target selection and serialized Stage execution unchanged.

## Validation

1. Run and evidence endpoints return the P9.2 Host projections unchanged and satisfy their registered
   schemas.
2. Evidence selection accepts only an active-Target Host run ID and rejects traversal, unknown runs
   and requests without a loopback session.
3. Plan catalog output preserves Host kind, presentation mode, validation and content hashes.
4. Plan detail selection accepts only a Plan ID; the browser cannot provide a path or Plan root.
5. Returned Plan bytes match the Host-projected hashes and remain JSON-object / strict UTF-8 content.
6. Safe Markdown rendering creates text-only headings, paragraphs, lists, quotes and code blocks and
   never executes source HTML or Markdown links.
7. Windows and pinned, network-disabled Linux tests prove read-only root behavior and unchanged P9.3
   Stage execution.
8. No Plan edit, authority edit, Target mutation, reset, Git/PR action, terminal, remote access,
   remote activation or P9.5 packaging/certification work is introduced.

## Observed result

- Native Windows (`Microsoft Windows 10.0.26200`) passed the P9.4 suite with zero-warning,
  zero-error Host and Companion builds; the P9.1 Web Companion regression also passed.
- The P9.4 suite passed in the pinned, network-disabled Linux container
  (`Ubuntu 22.04.5 LTS`).
- Browser QA displayed the Host run catalog, a newly completed run, findings, coverage, module results,
  evidence files, authority hashes and raw JSON. A UI Stage run automatically selected its new evidence.
- Browser QA displayed both `v4-native` and `v3-historical` Plan modes with their exact Host validation
  labels and hashes. Fixture `<img onerror>` and `javascript:` Markdown remained inert visible text,
  while headings, lists and fenced code rendered through explicit DOM nodes.
- V4 package validation passed with package hash
  `0160c51855e4ef9c81a626a4b97330079f4587e8f530d7a65a23c31716e6651a`.
- P0 regression passed with 31 schemas, 11 unchanged stable CLI entries, six experimental read queries
  and 33 bound contracts. Stable CLI 1.0.0 behavior passed unchanged.
- V3 Validate, the declared isolated `ifx-package-test` and Formal Pre passed.
- The 14 actual changed paths equal the 14 declared `plannedPaths`.

## Recovery

Revert the P9.4 commit. P9.2 read/query contracts and the P9.3 workspace/Stage Runner remain available;
the new viewer stores no durable state and performs no writes.
