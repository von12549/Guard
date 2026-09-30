# M3.3 — Profile, Plan, Module and lifecycle handoffs

Status: `IMPLEMENTATION PLAN — AUTHORIZED 2026-10-01; IMPLEMENTATION IN PROGRESS`

Formal Plan ID: `20261001-m3-authority-lifecycle-handoffs`.

Predecessor: `20261001-m3-setup-protection-preview`.

## Goal and acceptance

Expose deterministic read-only inventories and handoff descriptors for installed Profiles and Modules,
active Target Plans, and immutable installation lifecycle actions. Each item uses a Host-projected ID,
declares the next typed operation, availability and authorization boundary, and carries no browser path
or command. Lifecycle output previews verify/current/compose/select/rollback/retention classes without
running scripts or changing the installed sibling selection.

## Risks, boundaries and dependencies

Depends on M3.2 and current M1/M2/P9 query contracts. A handoff label must not imply authorization or
turn a script name into an executable gateway. M4/M5 authoring, Target trust authorization, plan
governance and Module lifecycle operations stay unavailable until their own contracts exist. No apply,
installation, selection, rollback, cleanup, Target mutation, Git or remote action occurs.

## Stop, resume and recovery

Stop if inventory identity cannot be derived from validated package/Host authority or if preview needs
an operator-supplied filesystem path. Resume after adding the missing typed contract under separate
authorization. Recovery reverts the projections; no installation or authority changed.

