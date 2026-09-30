# M3.4 — Secured Companion Workbench

Status: `IMPLEMENTATION PLAN — IMPLEMENTED 2026-10-01`

Formal Plan ID: `20261001-m3-companion-workbench`.

Predecessor: `20261001-m3-authority-lifecycle-handoffs`.

## Goal and acceptance

Extend the existing embedded, separately packaged Web Companion with a Setup/status/lifecycle Workbench.
Routes transport exact Host documents and accept only registered project IDs, vetted operation IDs and
preview hashes. Every new route requires the unpredictable loopback session, strict Host/Origin checks,
an independent CSRF token for mutation-shaped requests, the global body limit, stale-preview refusal,
cancellation and a schema-valid local receipt that names the unperformed apply boundary.

## Risks, boundaries and dependencies

Depends on M3.1–M3.3 and the existing P9 packaging/session boundary. Browser presentation must not
recompute protection, infer authority or construct raw Host arguments. The Workbench remains loopback
only, serializes active work, embeds all assets, writes no Target/package path and offers no apply,
terminal, Git, pull-request, workflow/ruleset, marketplace or remote control.

## Stop, resume and recovery

Stop on any missing session/origin/CSRF/size/stale/cancellation negative, Host-result transformation or
new filesystem write primitive. Resume after the focused test proves the refusal occurs before Host
execution. Recovery reverts routes/assets/contracts; no Target, selected installation or remote state
requires rollback.

Implementation evidence: the two new POST routes require the session cookie, exact loopback Origin and
independent 256-bit CSRF token. Confirmation reruns the Host, rejects a changed preview hash and returns
a schema-valid local receipt with `applied: false` and all four unperformed authority boundaries. The
focused suite covers missing/wrong security inputs, body limits, cancellation recovery, stale refusal,
exact Host-result hashing and root immutability.

