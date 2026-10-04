# V4 command reference

Generated from `core/contracts/cli-contract.json`. Do not edit by hand.

API version: `1.0`

| Command | Stability | Mutability | Required roots | Syntax |
| --- | --- | --- | --- | --- |
| `version` | stable | read-only | none | `v4-guards version` |
| `contract.validate` | stable | read-only | PackageRoot | `v4-guards contract validate --package-root <path> --schema <id> --document <path>` |
| `stage.run` | stable | state-write | PackageRoot, TargetRoot, StateRoot, EvidenceRoot | `v4-guards stage run --stage <bootstrap|analysis|pre|post> --package-root <path> --target-root <path> --state-root <path> --evidence-root <path> --profile <id> [--with-dependencies]` |
| `reset.project` | stable | accepted-apply | PackageRoot, StateRoot, EvidenceRoot | `v4-guards reset project --mode <preview|apply> --package-root <path> --state-root <path> --evidence-root <path> --project <id> [--accept-manifest-hash <sha256>]` |
| `reset.factory` | stable | accepted-apply | PackageRoot, StateRoot, EvidenceRoot | `v4-guards reset factory --mode <preview|apply> --package-root <path> --state-root <path> --evidence-root <path> [--accept-manifest-hash <sha256>]` |
| `plan.validate` | stable | read-only | PackageRoot, TargetRoot | `v4-guards plan validate --package-root <path> --target-root <path> --plan <path>` |
| `plan.compose` | stable | state-write | PackageRoot, TargetRoot, EvidenceRoot | `v4-guards plan compose --package-root <path> --target-root <path> --evidence-root <path> --id <id> --plan <path>... --output <path>` |
| `state.bind` | experimental | state-write | PackageRoot, TargetRoot, StateRoot, EvidenceRoot | `v4-guards state bind --package-root <path> --target-root <path> --state-root <path> --evidence-root <path> --profile <id>` |
| `state.put` | experimental | state-write | PackageRoot, StateRoot, EvidenceRoot | `v4-guards state put --package-root <path> --state-root <path> --evidence-root <path> --project <id> --relative-path <path> --content <text>` |
| `state.recover` | experimental | state-write | PackageRoot, StateRoot, EvidenceRoot | `v4-guards state recover --package-root <path> --state-root <path> --evidence-root <path>` |
| `spike.run` | experimental | state-write | PackageRoot, TargetRoot, StateRoot, EvidenceRoot | `v4-guards spike run --package-root <path> --target-root <path> --state-root <path> --evidence-root <path> --module synthetic-probe` |
| `profile.discover` | experimental | read-only | PackageRoot, TargetRoot | `v4-guards profile discover --package-root <path> --target-root <path>` |
| `profile.draft` | experimental | state-write | PackageRoot, TargetRoot, StateRoot | `v4-guards profile draft --package-root <path> --target-root <path> --state-root <path> --profile <new-id>` |
| `profile.configure` | experimental | state-write | PackageRoot, TargetRoot, StateRoot | `v4-guards profile configure --package-root <path> --target-root <path> --state-root <path> --draft <path> --candidate <path>` |
| `profile.review-template` | experimental | state-write | PackageRoot, TargetRoot, StateRoot | `v4-guards profile review-template --package-root <path> --target-root <path> --state-root <path> --draft <configured-draft-path>` |
| `application.preview` | experimental | preview | PackageRoot, TargetRoot, StateRoot, EvidenceRoot | `v4-guards application preview --operation <setup|protection|authorities|lifecycle> --package-root <path> --target-root <path> --state-root <path> --evidence-root <path> --plan-root <relative-path>` |
| `application.setup-progress` | experimental | read-only | PackageRoot, TargetRoot, StateRoot, EvidenceRoot | `v4-guards application setup-progress --project-id <id> --package-root <path> --target-root <path> --state-root <path> --evidence-root <path> --plan-root <relative-path>` |
| `application.setup-action` | experimental | state-write | PackageRoot, TargetRoot, StateRoot, EvidenceRoot | `v4-guards application setup-action --operation <step> --mode <preview|apply> --project-id <id> [typed choices] --package-root <path> --target-root <path> --state-root <path> --evidence-root <path> --plan-root <relative-path>` |

## Exit categories

| Category | Code |
| --- | ---: |
| `success` | 0 |
| `invalid-input` | 10 |
| `unsafe-path` | 11 |
| `integrity-failure` | 12 |
| `capability-denied` | 13 |
| `adapter-failure` | 14 |
| `prerequisite-missing` | 15 |
| `findings-blocking` | 16 |
| `state-conflict` | 17 |
| `reset-refused` | 18 |
| `internal-error` | 19 |
