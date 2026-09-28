# V4-TODO-018 — build-location-independent Host and Companion builds (O14)

Status: `COMPLETE 2026-09-28 — merged in #25 (243cdc8), released in V4 Guards 1.1.6 (https://github.com/von12549/Guard/releases/tag/v4-guards-v1.1.6)`

Formal Plan ID: `20260928-v4-todo-018-deterministic-builds`.

Product phase G2 of the post-V4-TODO-008 sequence: Guard product defects first (V4-TODO-017 done in G1,
V4-TODO-018 here), then release 1.1.6 as the stable base for IFX.

## Defect

Two independent Release builds of the same commit from different directories produce different
distribution archives. Reproduced 2026-09-28 at `b757b79`: two clones at different locations, each built
with its own `--artifacts-path`, give archives `782fa7e0…` and `17ca81e5…` (142 entries, same
`packageHash`). Exactly three entries differ:

| Entry | Cause |
| --- | --- |
| `host/v4-guards.dll` | The CodeView debug directory entry holds the absolute PDB path under the build's `obj` directory. The PDB itself is not shipped. |
| `companion/v4-web-companion.staticwebassets.runtime.json` | The static web assets manifest holds the absolute source `wwwroot` path (`ContentRoots`). |
| `distribution-manifest.json` | It records the two hashes above. |

The Companion `PathMap` also still pointed six levels up, which matched the IFX layout
(`docs/guards/v4/integrations/web/…`). In the standalone layout it maps a directory above the repository.
It had no byte effect because the Companion is built without debug information and uses no caller paths,
but it is corrected so it maps the repository root.

## Fix

- `core/host/V4.Guards.Host/V4.Guards.Host.csproj`: `DebugType` `none`, `DebugSymbols` `false`, and
  `PathMap` of the repository root to `/_/`. This is the setting the Companion already uses. Release
  archives never contained the Host PDB, so an installed Host loses no debug information.
- `integrations/web/V4.Guards.WebCompanion/V4.Guards.WebCompanion.csproj`: `PathMap` uses the repository
  root (`NormalizeDirectory` three levels up), and `StaticWebAssetsEnabled` is `false`. The Companion
  serves its UI only from embedded resources (P9) and uses no static-file middleware, so the two
  `staticwebassets.*.json` files (runtime and endpoints) are no longer built or shipped.

No source code, CLI, schema, module or profile changes.

## Behavior equivalence

Builds of `b757b79` (before) and of the fix, both with the source revision left out of the informational
version so the commit does not enter the bytes:

- `v4-web-companion.dll` is byte-identical;
- `v4-guards.dll` has the same IL (1,935 method bodies, one SHA-256) and the same metadata once the MVID
  is normalized. Its debug directory changes from `CodeView, PdbChecksum, Reproducible` to
  `Reproducible`.

The archive has 140 entries instead of 142: the two static web assets manifests are gone.

## Regression control

`tests/p7/Test-V4Distribution.ps1` clones the tested commit to a second location, builds Host and Companion
there with a separate artifacts path, makes a distribution and requires the archive SHA-256 to equal the
first build's. On a mismatch it lists the differing entries. It also fails if the second location is not
distinct or the `packageHash` differs.

- Red first: the new P7 on the unfixed `b757b79` fails only on this check, and lists exactly the three O14
  entries.
- Green: the full P7 passes with the fix, and the local Windows full sweep passes.
- A two-location reproduction of the fix gives one archive (`caed1a8b…`, 140 entries, no difference).

## Trust change

P7 is an approved test, so this change uses the V4-TODO-014 two-PR flow. The base-held record
`docs/plans/authorizations/20260928-v4-todo-018-deterministic-builds-record.json` binds exactly:

| Path | Base SHA-256 | Head SHA-256 |
| --- | --- | --- |
| `tests/p7/Test-V4Distribution.ps1` | `861ce79a…` | `3d5fb570…` |
| `integrations/github/ci-contract.json` (P7 hash only) | `12991185…` | `d8676c14…` |

The two project files are not protected paths. This PR consumes the record by deleting it. It changes
release bytes, so the fix ships in V4 Guards 1.1.6 (G3), whose release notes describe it.

## Acceptance

- `v4-required` passes through the consumed authorization;
- exact-head dispatch certification passes Linux-complete and Windows-full with one `packageHash`;
- merged normally under `v4-main-autonomy`, without bypass.
