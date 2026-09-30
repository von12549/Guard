# M1.3 — project initialization, context and derived mutable roots

Status: `IMPLEMENTATION PLAN — READY; not yet executed`

Formal Plan ID: `20261001-m1-project-initialization`.

Predecessor checkpoint: `20261001-m1-installed-launcher`.

## Goal

Add `guard init` preview/apply for an explicit TargetRoot. It creates an external stable project context
and derives sibling `state/` and `evidence/` roots under LocalApplicationData on Windows or
`XDG_STATE_HOME`/`~/.local/state` on Linux. Init never writes TargetRoot.

## Exact implementation

Add strict context/receipt contracts and CLI entry, deterministic project identity, canonical path,
ownership, overlap, permission and link/reparse checks, `--data-root` relocation and advanced independent
root overrides. Preview binds an exact hash; apply rejects stale previews and writes only the external
context/receipt plus empty owned roots. Low-level execution continues to receive four explicit roots.

## Acceptance and tests

`tests/m1/Test-V4ProjectInitialization.ps1` covers Windows defaults plus isolated Linux/XDG behavior,
stable identity, relocated/independent overrides, overlap/link/permission refusal, stale apply and no
Target writes. Re-run P0 contracts, P2 state/reset, P4 project model, P8 stable CLI and documentation
generation checks.

## Stop and resume

Stop if Init would create `.guard/`, infer a Target from cwd, accept an arbitrary external governance
directory, weaken four-root checks or require protected CLI/test changes without authorization. Resume
from the last receipt-free preview or after exact Plan/authorization revision.

## Recovery

Remove only the receipted empty context container through a later receipted local operation; source
recovery is a revert. TargetRoot needs no rollback.
