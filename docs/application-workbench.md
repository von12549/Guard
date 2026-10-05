# Local application Workbench

The M3 Workbench expands the existing separately packaged Web Companion. It remains a loopback-only
presentation and orchestration surface over the V4 Host; it is not a second setup engine, policy judge
or remote control plane.

Version 1.2.2 repairs the typed First onboarding stepper. Preview or confirmation evidence does not mean
Target adoption, CI activation, remote enablement or human acceptance.

## Host operation

The experimental command is:

```text
v4-guards application preview \
  --operation <setup|protection|authorities|lifecycle> \
  --package-root <path> --target-root <path> \
  --state-root <path> --evidence-root <path> --plan-root <relative-path>
```

Onboarding also uses `application setup-progress` and `application setup-action`. Progress has exactly
eight Host-derived steps: installation integrity, PATH/profile safety, roots, Target snapshot,
discovery, Draft, configure and review-template. Status is count-based (`not-started`, `running`,
`pass`, `needs-decision` or `blocked`) and never invents a percentage.

The first five steps are not a fixed baseline. Installation passes only after current package/contract
validation; the remaining four stay blocked until StateRoot contains a fresh hash-only safety proof
bound to the current package, project and Target snapshot. The proof compares unexpanded persistent
User/Machine environment state, Process PATH and all four PowerShell profile locations. Any mismatch
is a host-safety incident and no later step is counted as complete.

Every setup action is typed and preview-first. Apply must present the exact preview identity binding the
operation, project, form choices, Target snapshot, package authority and current safety-proof bytes.
An expired proof returns exit 17 `proof-expired`; a changed binding returns `proof-binding-mismatch`;
actual environment or Profile drift returns a host safety incident. Explicit renewal archives the old
proof and requires a new Preview. The only permitted writes are non-authoritative artifacts below
StateRoot. Host progress exposes capture and expiry time and the current recovery step.

The launcher fixes every root before the browser connects. Browser requests contain only one
startup-registered project ID and one of the four operation IDs. There is no raw Host argument,
executable, environment, working-directory, shell-text or browser path input.

Each Host result binds:

- the project identity;
- a deterministic Package authority hash;
- the inert M2 Target snapshot;
- the V4-AD-040 operation class;
- the strict operation payload; and
- a SHA-256 preview identity over all of those values.

Candidate configuration is claim-specific: `ARCH.PROJECT_REFERENCE` requires an explicit non-empty
forbidden-reference list, `ARCH.TARGET_FRAMEWORK` requires an explicit non-empty framework list, and
`ARCH.GRAPH_COMPLETENESS` sets `requireResolvedProjectReferences=true`. Adapter coverage is emitted
only after the corresponding semantic check is configured and executed.

The experimental schema catalog at `core/application/contracts/application-service-contract.json`
hash-binds all ten application/onboarding schemas. New CLI entries remain experimental; the stable
API version and stable command semantics are unchanged.

## Protection semantics

The Host reports `protected: true` only when all seven components pass:

1. initialized project context;
2. accepted non-default, non-empty installed Profile;
3. verified installed immutable distribution or composition;
4. satisfied declared prerequisites;
5. non-empty required Pre and Post Stage coverage;
6. CI pinned to the same Package authority; and
7. repository policy requiring the unchanged aggregate verdict.

Local runnable, CI configured and CI enforced are separate fields. M3 does not query remote policy, so
CI pin and enforcement stay `unverified` unless a later typed certification contract provides exact
evidence. A local pass, workflow file or default/no-op Profile cannot produce a protected claim.

## Companion request boundary

`POST /api/v1/application/preview` and `POST /api/v1/application/confirm` require the unpredictable
HTTP-only same-site session cookie, exact loopback Host and Origin, the session's independent
`X-V4-CSRF` token and the 4 KiB server body limit. Both share the existing serial run gate and propagate
client cancellation to the Host process.

`GET /api/v1/onboarding/progress/{projectId}` and `POST /api/v1/onboarding/action` use the same session,
Origin, CSRF, body-size and single-run controls. The action endpoint accepts only the exact typed
project/operation/mode/preview/profile/project-root/claim/framework/project-reference-policy fields. Unknown properties,
including raw paths, executable names, Host arguments, shell text or environment values, are rejected.

Confirmation reruns the same Host preview. A changed package, Target snapshot, project or payload
returns `409 stale-preview`. A matching preview produces a process-local receipt that binds the exact
Host-result bytes and always records:

```json
{
  "applied": false,
  "unperformed": [
    "target-write",
    "composition-selection",
    "ci-activation",
    "remote-change"
  ]
}
```

The receipt confirms review of unchanged data; it is not acceptance authority and is not persisted.

## Handoffs and lifecycle

Profile, Plan and Module entries use Host-derived IDs and installed hashes. The lifecycle preview names
verify, compose, select, rollback, retention preview/apply and remote activation, but only current
read-only verification is available. M4/M5 Plan authoring, Module lifecycle, Target trust authorization,
Target apply, composition selection, workflow/ruleset activation, enforcement certification,
publication and merge remain separate Plans and operations.

## Validation and recovery

Run:

```powershell
pwsh -NoProfile -File core/application/validation/Test-V4ApplicationBoundary.ps1
```

The focused suite builds the Host and Companion offline, validates all contracts, compares direct Host
and Companion identities, exercises positive and negative security cases, forces Target drift between
preview and confirmation, cancels a live request and verifies recovery, and proves the application
surface does not modify PackageRoot or TargetRoot. Recovery is a source/contract/UI revert; M3 applies
no protected or remote state.
