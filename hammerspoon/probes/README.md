# probes

Throwaway code for answering a question about the running macOS, written by a
session and run by Hammerspoon. **`active.lua` is gitignored and temporary.**
What a probe found goes in `docs/verification/`, not here.

## Contract

`init.lua` runs `probes/active.lua` on every load if the file exists, after
the other modules and before the load-time status is written. Writing the file
therefore triggers the run, because it is in the watched directory.

The file returns a table, all fields optional:

```lua
local diag = require("modules.diag")
local log  = diag.logger("probe")

local P = {}

-- state lives here, and survives until the next reload
P.handles = {}

-- `open -g hammerspoon://probe` calls this, with NO reload. Use it for steps
-- that need state captured earlier (e.g. window handles from another space).
function P.run() log.i("step") end

diag.provide("probe", function() return { handles = #P.handles } end)

log.i("loaded")
return P
```

- Log through `diag.logger("probe")`. Results are read from `.live/log.txt`
  and `.live/status.json`.
- A probe that errors is caught and logged. It does not take the config down.
- Keep watchers and timers on `P`, or they are garbage-collected.
- Delete `active.lua` when done. The removal triggers a reload, which drops
  the probe's watchers and state.
