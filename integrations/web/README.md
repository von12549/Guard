# V4 Web Companion

The Web Companion is a local presentation integration over the released V4 Host. It is not a guard
engine, policy authority or verdict producer.

P9.1 intentionally exposes one narrow flow:

```text
local browser
  -> loopback session + strict Stage request
  -> Web Companion
  -> v4-guards stage run (fixed ArgumentList, no shell)
  -> Host-owned structured result
```

The trusted launcher fixes the Host DLL and all four roots before the listener starts. Browser requests
cannot replace those values, select an executable, supply a working directory, append arguments or
invoke another V4 command. The Companion accepts only `bootstrap`, `analysis`, `pre` or `post` with
`synthetic_profile` during this spike.

`PackageRoot` and `TargetRoot` are read-only. The Companion itself does not write them; the V4 Host
continues to own all writes beneath `StateRoot` and `EvidenceRoot`. The Companion returns the exact Host
JSON and process exit code and does not infer a second verdict.

P9.2 will define durable read/query projections. P9.3 will define the full workspace and Stage Runner.
The P9.1 endpoints and schemas are spike contracts and must not be treated as those later authorities.
