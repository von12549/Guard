# V4 runtime architecture

Status: accepted planning view; implementation not authorized

Decision authority: `00-architecture-decision-set.md`

This document is the maintained architecture view for V4 v1. It shows ownership and data flow; it
does not grant authority to create the development branch, runtime, workflow or remote configuration.

## System and root boundaries

```mermaid
flowchart TB
    Caller[CLI / local developer / CI / future Web UI] --> Host[V4 .NET Host]

    subgraph PackageRoot[PackageRoot - immutable]
        Host
        Contracts[JSON Schemas and contracts]
        Profiles[Profile catalog]
        Registry[Module registry and hashes]
        Modules[Built-in modules and adapters]
    end

    subgraph TargetRoot[TargetRoot - read-only by default]
        Target[Target repository source and project files]
    end

    subgraph StateRoot[StateRoot - V4-owned mutable data]
        Bindings[Project bindings and transactions]
        BuildEvidence[Isolated build evidence]
        Cache[Locks and caches]
    end

    subgraph EvidenceRoot[EvidenceRoot - V4-owned run output]
        Results[Stage and module results]
        Reports[Reports, logs and manifests]
    end

    Host --> Contracts
    Host --> Profiles
    Host --> Registry
    Host --> Modules
    Host --> Bindings
    Modules -->|declared read capabilities| Target
    Modules -->|declared mutable capabilities| StateRoot
    Host --> Results
    Results --> Reports
```

`PackageRoot`, `TargetRoot`, `StateRoot` and `EvidenceRoot` are explicit inputs. The process working
directory and package location never select the target. Local ignored data may use `V4/.work`; CI
places mutable roots under an isolated runner-temporary V4 namespace.

## Architecture Conformance composition

```mermaid
flowchart LR
    Profile[Validated profile and rule authorities] --> Planner[Rule execution planner]
    Planner --> Project[Project Model detector]
    Planner --> Source[Roslyn source detectors]
    Planner --> Assembly[ArchUnitNET adapter]

    Target[TargetRoot] -->|declared project and package facts| Project
    Target -->|syntax and source facts| Source
    Target --> Builder[Build Evidence Provider]
    Builder -->|hash-bound assemblies and manifest| Assembly

    Project --> Findings[Layered findings]
    Source --> Findings
    Assembly --> Findings
    Findings --> Aggregator[V4 baseline, severity and verdict aggregator]
    Aggregator --> Result[Architecture Conformance result]
```

The stable module is `architecture-conformance`; detector brands are internal implementation choices.
The module does not run the LayerGuard-derived engine in production. During development only, a frozen
V3 reference may run beside V4 to compare architecture claims and coverage.

## Evidence and Stage allocation

| Evidence kind | Owner | Earliest Stage | Target execution | Examples |
| --- | --- | --- | --- | --- |
| Raw declared project model | Project Model detector | Pre | none | project/package references, names, ownership |
| Source syntax | Roslyn syntax detector | Pre | none | imports, disabled branches, declaration text |
| Evaluated/semantic source | Roslyn semantic detector | Post | isolated build context | bound symbols, member and payload types |
| Compiled assembly semantics | ArchUnitNET adapter | Post | isolated Build Evidence Provider | type dependency, implementation and namespace placement |
| Policy, baseline and verdict | V4 Host | Pre/Post | none | rule plan, severity, non-vacuity and aggregate status |

Pre never invokes target-owned MSBuild targets, analyzers, generators or executables. Post may use a
declared process capability to build an isolated target copy or output tree under `StateRoot`. A report
must distinguish raw declarations, evaluated state and compiled semantics.

## Local and pull-request trust topology

```mermaid
flowchart TB
    subgraph Local[Local feedback]
        LocalHost[Explicitly selected installed V4] --> LocalTarget[Local TargetRoot]
    end

    subgraph PR[Pull-request verdict]
        BaseHost[Previously trusted base V4] --> HeadTarget[Head checkout as TargetRoot]
        HeadCandidate[Changed head V4] --> CandidateTests[Candidate and parity tests only]
        CandidateTests -. no required verdict .-> HeadTarget
    end
```

Local and CI use the same CLI and result schemas. CI additionally pins the trusted base revision,
target revision, mutable roots and evidence bindings. A candidate host or detector never judges its
own change.

## Genesis bootstrap and autonomy transition

```mermaid
flowchart LR
    V3[V3 trusted repository controls] -->|formal Plan, exact additive diff, non-interference, recovery| Seed[Reviewed V4 seed]
    Candidate[Candidate V4 host and tests] -. supplemental evidence only .-> Seed
    Seed -->|separate authorization| Base[codex/v4-development-base]
    Base -->|base-owned V4 runner| Head[V4 feature head as TargetRoot]
    Head --> Required[v4-required]
    V3 -. no runtime or ongoing feature-gate dependency .-> Base
```

The V3 bootstrap is a finite genesis ceremony, not a V4 execution layer. It ends when the accepted,
hash-bound seed becomes the immutable V4 development base and that base can evaluate candidate heads.
Subsequent V4-only changes use V4 Plans or plan-sets and V4 checks; V3/V3_ifx continues separately as
the active IFX guard until the deferred production cutover.

## Architecture Conformance migration boundary

```text
V4 v1
  capability matrix
      -> Project Model + Roslyn + ArchUnitNET detectors
      -> synthetic claim parity
      -> no V3/LayerGuard runtime dependency

Post-v1 IFX practice
  ifx_profile
      -> V3/V3_ifx and V4 parallel evidence
      -> real IFX negative controls
      -> trusted-base cutover and rollback
      -> final LayerGuard freeze or authorized retirement
```

Plan 06 section 20 closes only after the post-v1 IFX cutover and retirement boundary completes.
