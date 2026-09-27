# V4 P3A — direct independent Stage execution

Status: local implementation checkpoint authorized on `codex/v4-development-base`

Parent roadmap: `docs/guards/v4/plans/01-v4-self-contained-guard-plugin.md`, V4-P3.1,
V4-P3.2, V4-P3.4 and V4-P3.5.

Predecessor: `20260922-v4-p2b-safe-reset`

## Goal

Implement one uniform direct runtime for Bootstrap, Analysis, Pre and Post that resolves its own
declared inputs, emits the frozen structured result, and confines generated evidence to the bound
project instance.

## Scope

- Add direct stable `stage run` dispatch for all four frozen Stage identities.
- Validate package authority before loading the selected profile and registered modules.
- Bind the canonical target to a project instance and write per-run results and module evidence only
  below that project's EvidenceRoot claim.
- Report missing Stage inputs explicitly without invoking any earlier Stage.
- Extend the synthetic profile and probe adapter to exercise every Stage while preserving the P0
  analysis spike.
- Keep the default profile empty and deterministic; defer opt-in dependency orchestration to P3B.

## Validation

1. Formal Pre accepts this pair and its exact paths.
2. Each Stage passes direct execution from an otherwise clean synthetic target.
3. A blocking synthetic finding and a missing declared input return distinct structured failures.
4. Every result validates against `stage-result.schema.json` and all generated paths stay beneath the
   bound project evidence root.
5. PackageRoot and TargetRoot remain byte-identical, and P0/P1/P2 plus current V3 validation remain
   green.
6. No workflow, ruleset or remote state changes.

## Recovery

The recovery seed is P2B commit `d2553867eb227243327699aec289ab08683662d2`. P3A outputs are
test-only and live below ignored fixture roots; source recovery is a separately authorized revert or
branch restore.
