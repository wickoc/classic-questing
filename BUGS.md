# Known bugs

Open faults, with enough detail to pick each one up cold. Fixed bugs move out of here and into
the version notes in `SPEC.md`.

---

## B1 — Slash commands do not reach the panel while it is open

**Reported:** v0.15.0, in play. **Severity:** minor. **Status:** open, deferred by the player.

### What happens

With the options window open, typing `/cq on` or `/cq off` in chat leaves the AddOn in a
half-applied state:

- The world map cannot be opened while the options window is up, so the settings that only show
  themselves on the map appear to do nothing.
- The Apply button sometimes lights and sometimes does not.
- Closing the window leaves the AddOn inert until the map is opened by hand, or the UI reloaded.

### Why, most likely

Not diagnosed. The shape of it points at the slash path and the panel path writing the same
settings by different routes:

- `ns:Set()` writes `ns.db.settings` and calls `ns:ApplyAll()` directly.
- The panel writes through Blizzard's setting objects, and a `needsApply` option is **parked**
  rather than written until Apply commits it.

So a slash change made while the panel is open can leave Blizzard's controls holding a pending
value that disagrees with what the AddOn has already applied — which would explain the
intermittent Apply button, and the settings that need the map to redraw before they show.

### Where to start

- `ns.RefreshNative()` in `Options.lua` skips any setting reporting `IsModified()`, to avoid
  discarding a parked click. A slash change to a parked setting therefore never reaches the
  control.
- `ns:Set()` in `Core.lua` does not go through `ns.SetNativeValue()`, so Blizzard never learns
  the value moved.
- A fix probably routes slash changes through the control when the native panel exists, the way
  `applyPreset` already does.

### Workaround

Close the options window before using slash commands, or `/reload` afterwards.
