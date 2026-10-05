# V4 Guards P04 onboarding and safety repair

Status: `IN PROGRESS — implementation and release gates pending`.

Formal Plan ID: `20261006-v4-guards-p04-onboarding-safety-repair`.

The source acceptance plan is `D:\IFX-10-Root\docs\plans\20261005-guard-ifx-p04-onboarding-ux-and-safety-repair-plan.md`. P03 remains a technical and usability FAIL. Its A1 and B3 evidence gaps cannot be reconstructed, and IFX is not protected. This Plan changes Guard only; a future IFX retest is human operated under the IFX repository rules.

## Baseline and release identity

Implementation starts from clean Guard `main` commit `48c1470c4486316967b34c4b260bf3882b4481bb`, after the immutable 1.2.1 release at `6e8d3ec02a8bb2eab4a83131de7d59b59fa4c2f7`. The branch is `codex/v4-guards-1-2-2-p04-repair`. Reserve new patch version `1.2.2`; verify its tag, Release and asset names are unused before publication. Never replace 1.2.1. Final release source, package and archive hashes, Windows and required CI must be frozen on one commit in a separate release record.

Changing the protected compatibility baseline requires the prior authorization record in PR #57. The repair branch consumes that exact record by deletion after PR #57 reaches `main`; it does not authorise itself. The deletion and baseline change are governed under this Plan's `trust-change` boundary.

## Repair contract

1. Distinguish missing, expired, binding mismatch, malformed proof and actual environment or Profile drift. Host progress and responses expose the current reason, proof capture and expiry times, and a specific recovery action. Apply checks the proof again before every write. Recapture is explicit, archives the old proof under StateRoot, and invalidates old previews.
2. Every Companion request has one current result. A failure clears prior success and exit code, refreshes Host progress, updates recovery and raw diagnostics, and cannot be overwritten by an older response. The browser never infers protection or accepted authority.
3. First onboarding is a step focused path. Show purpose, prerequisites, relevant required inputs, defaults, next action and absolute Package, Target, State and Evidence roots with read/write boundaries. Preview shows planned StateRoot outputs; Apply shows actual outputs. Keep Stage Runner, installed Profiles and diagnostics in separate secondary sections. Graph only configuration has no orphan framework or reference policy.
4. Provide a verified preflight/bootstrap entry before the first dotnet or install call. It captures an independent hash-only User/Machine environment, Process PATH and four Profile baseline; validates identity and root topology independently of cwd; records complete step/time/result/boolean/evidence/hash data even on failure. Fail closed on missing evidence and never change persisted host settings. External baseline does not reset when a Guard proof is renewed.
5. Replace process-name IDE blocking with warnings scoped to a Target workspace or an ancestor. Keep Target ordinary and ignored drift checks and preserve evidence. Never kill IDE processes, alter global extensions or delete generated Target files.
6. Public `guard-web.ps1` accepts omitted port as dynamic port zero. Documentation and installed launcher agree. The ready report shows the actual loopback address and roots. Test `-File`, call operator, alternate cwd and paths with spaces.

## Verification and stop rules

Exercise proof missing, exact expiry boundary, expiry after Preview, explicit renewal, old Preview rejection, binding changes, tampering and drift with an injected clock. Check the complete UI result after failed Apply, response ordering and field relevance. Verify graph only Configure and incomplete Review template. Test preflight across cwd, spaces, links, root overlap, incomplete reports, fault injection and PATH/Profile equality. Keep static rejection of persistent environment mutations and dynamic isolation of dotnet child processes with `DOTNET_ADD_GLOBAL_TOOLS_TO_PATH=0`.

No P03 result is rewritten. Any unexpected persisted environment or Profile drift stops Guard operations and preserves evidence for human review. No Guard candidate, local UI step or release establishes IFX adoption or CI protection. Publication follows a separate reviewed 1.2.2 release Plan after the P04 repair, Windows validation, required CI and a 1.2.1 lessons review shown to the operator.
