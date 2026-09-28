# Correct the V4 Guards 1.1.6 release notes before publication (G3 A1)

Formal Plan ID: `20260928-v4-guards-1-1-6-release-notes-correction`.

Documentation only. It implements Amendment A1 of `20260928-v4-guards-1-1-6-release` (§8 there).

- `docs/1.1.6-release-notes.md` now includes V4-TODO-014, which was merged after 1.1.5 (trusted-base
  authorization, `trust-policy.json`, the trust-change authorization schema, `verdictComponents` and the
  runner `PATHEXT` fix). It states the archive change against 1.1.5 correctly: 140 to 141 entries, two
  removed and three added.
- `README.md`: the 1.1.6 summary and paragraph name V4-TODO-014.
- The release Plan: §1 scope, status and Amendment A1.

No product code, contract, test, workflow or trust-policy file changes. This changes package authority
(the README and the release notes), so the merge commit becomes the 1.1.6 release commit, and R2 and R3
are repeated there.
