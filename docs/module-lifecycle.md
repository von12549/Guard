# Immutable local Module lifecycle

M5 adds `core/modules/Invoke-V4ModuleLifecycle.ps1`, an Agent-independent local lifecycle over installed
immutable Modules and extension candidates.

## Operations

- `inventory`, `inspect` and `graph` expose installed provenance, hashes, API/platform support, Stages,
  capabilities, prerequisites, Profile usage and locked dependencies.
- `scaffold` creates Module/Profile metadata and a fixture manifest below StateRoot. It deliberately
  does not generate adapter source; `ADAPTER_REQUIRED.md` records the repository/IDE handoff.
- `validate` checks public schemas, identity, adapter and lock hashes, allowed Stage-result placement,
  capabilities, prerequisites, timeouts and the companion Profile. A built-in Module ID is refused.
- `test` executes declared local fixtures with a fixed JSON input contract and proves the fixture Target
  and candidate Package trees are byte-unchanged.
- `diff` reports the complete candidate as an additive extension and refuses built-in replacement.
- `pack` creates an extension-bundle directory and byte-deterministic ZIP below EvidenceRoot.
- `review` prepares an unresolved, non-authoritative production-review candidate. It cannot create
  acceptance; an operator must review and deliberately produce a valid `extension-review` record.
- `compose` and `verify` delegate to the existing reviewed `Compose-V4Extension.ps1` and
  `Test-V4ComposedInstallation.ps1` authorities. Composition creates a new immutable sibling and does
  not select it.

All result documents explicitly report no Target mutation, no built-in mutation and no remote change.
The lifecycle does not discover/download marketplace content, establish signature roots, publish,
select an installation or remotely install anything. Authentic bundle bytes remain distinct from
trusted Evidence producer identity. The local Web Companion read-only inventory remains a separately
planned projection.
