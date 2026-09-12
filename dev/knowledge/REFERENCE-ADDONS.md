# Reference AddOns

Five AddOns worth reading, and what each one is actually good for. Read as evidence of *how other
people solved the problem on a real client*, which is the one thing a wiki cannot give you.

Nothing here is a dependency and nothing here is copied. This project stays a single AddOn with no
libraries.

Three of the five are on GitHub and can be cloned:

```sh
git clone --depth 1 https://github.com/bloerwald/MapCleaner
git clone --depth 1 https://github.com/Stanzilla/AdvancedInterfaceOptions
git clone --depth 1 https://github.com/ItsJustMeChris/idTip-Community-Fork
```

The two scrolling-quest-text AddOns are CurseForge-only, and CurseForge is not reachable from the
development environment. Their sources have **not** been read; what is written below about them
comes from their listings and is marked as such.

---

## Advanced Interface Options — the most useful of the five

`Stanzilla/AdvancedInterfaceOptions`. Puts back the interface options Blizzard removed, by exposing
the CVars behind them. Its whole reason to exist is the class of problem this AddOn is in.

**It ships for our client.** One `.toc`, ten flavours:

```
## Interface: 120105, 120100, 120001, 50504, 40402, 30405, 20506, 11509
# WOW_INTERFACE_TARGETS: mainline-beta, mainline-test, mainline, mists-test, mists, cata, wrath, tbc-test, tbc, vanilla
```

`50504` is this AddOn's target exactly. So **a multi-value `## Interface:` line is real and is
shipping** — which is the mechanism issue #5 and issue #21 are about, in production, in a CurseForge
package, with the packager directive (`WOW_INTERFACE_TARGETS`) that goes with it.

### What to take from it

**`ConsoleGetAllCommands` — enumerate every CVar the client has.**

```lua
addon.GetAllCommands = ConsoleGetAllCommands or C_Console and C_Console.GetAllCommands
```

This is the answer to "what else is in here". Every probe so far has asked about a CVar we already
suspected; this asks the client for the list. Two names, because it was renamed in 10.2.0 — which
one 5.5.4 has is a probe, and it is one line.

**A list of CVars that cannot be written in combat.** `cvars.lua` opens with
`addon.combatProtected`, about forty entries, all of them nameplate and colourblind variables.
Nothing quest-, map- or tracker-related is on it. That does not clear our own combat problem —
what fails for us is the map panel, not the CVar write — but it does say the write itself was never
the protected part.

AIO's own position is blunter than ours: `addon:SetCVar` returns without writing if
`InCombatLockdown()`, for everything, protected or not.

**An honest reading of the tooltip CVars, which are not there.** AIO's catalogue lists
`showQuestTrackingTooltips` ("Displays quest tracking information in unit and object tooltips") and
`minimapShowQuestBlobs`, both of which would be shortcuts for modules this AddOn hand-writes.
Neither appears anywhere in the 5.5.4 interface source. AIO's catalogue is retail-shaped and
entries in it are *candidates*, not facts about our client — the AddOn checks each at runtime before
offering it. So should we.

**Its `Outline` entry is commented out** with `-- don't know what this does aside from make you
flash when it's set`. On this one thing this project knows more than AIO does.

### One thing not to copy

```lua
function addon:CVarExists(cvar)
  return not not select(2, pcall(function() return addon.GetCVarInfo(cvar) end))
end
```

This is only correct if `GetCVarInfo` *returns nil* for an unknown name. If it *raises*, `pcall`
hands back `false, "error text"`, `select(2, ...)` picks the error string, and the function answers
`true` for every CVar that does not exist. Which way 5.5.4 behaves is unprobed. The construct hides
the difference either way; `GetCVarInfo` has a documented return list, so read it.

---

## MapCleaner — the retail map, and how to take things off it

`bloerwald/MapCleaner`. Retail only (`## Interface: 110002, 120000`). One 900-line Lua file. Lets a
player filter individual POIs, vignettes and quests off the world map by ID.

This is the closest thing to a map of the retail port, because retail's map is not 5.x's map. There
is no `questPOI` to switch off: the map is assembled from **data providers**, each owning a pin
template, and removing something means taking its pins away as they appear.

### The mechanism

```lua
hooksecurefunc(WorldMapFrame, "AcquirePin", function(worldMapFrame, pinTemplate, ...)
    if pinTemplatesToIgnore[pinTemplate] then return end
    self.shallDoTemplateUpdate[pinTemplate] = (self.shallDoTemplateUpdate[pinTemplate] or 0) + 1
    self:DoTemplateUpdatesInNextFrameOrWhenOutOfCombat()
end)
```

then, a frame later, `WorldMapFrame:EnumeratePinsByTemplate(t)` and `WorldMapFrame:RemovePin(pin)`.

The pin templates it knows about are the retail inventory of quest clutter:
`QuestPinTemplate`, `QuestOfferPinTemplate`, `QuestHubPinTemplate`, `BonusObjectivePinTemplate`,
`ThreatObjectivePinTemplate`, `AreaPOIPinTemplate`, `AreaPOIEventPinTemplate`,
`VignettePinTemplate`, `MapLinkPinTemplate`.

The matching data providers, all present in `Blizzard_SharedMapDataProviders` on **our** client too:
`QuestDataProvider`, `QuestBlobDataProvider`, `StorylineQuestDataProvider`, `WorldQuestDataProvider`,
`BonusObjectiveDataProvider`, `AreaPOIDataProvider`, `VignetteDataProvider`,
`DungeonEntranceDataProvider`, `MapLinkDataProvider`.

### Its recorded failures, which are the valuable part

- A whole block of `RefreshAllData` hooking is commented out, with
  `--- does not refresh on unhide`. Hooking the provider refresh was tried and abandoned in favour
  of hooking pin acquisition.
- `-- filtervignette + refresh does not re-add vignettes` — removal is not symmetrical. Taking a
  pin away is easy; putting it back needs `WorldMapFrame:RefreshAll()`.
- `-- DungeonEntranceDataProviderMixin DOES NOT seem to control dungeon entrances` — worth knowing
  before starting issue #9 on retail.
- `-- removes during iteration. bad?` — its own author is unsure. Ours would want to collect first.

### Two idioms to keep

```lua
if InCombatLockdown() then
    EventUtil.RegisterOnceFrameEventAndCallback("PLAYER_REGEN_ENABLED", function() self:DoTemplateUpdates() end)
else
    C_Timer.After(0, function() self:DoTemplateUpdates() end)
end
```

`EventUtil` **exists on 5.5.4** (`Blizzard_SharedXML/EventUtil.lua`) with
`RegisterOnceFrameEventAndCallback`, `ContinueOnAddOnLoaded`, `ContinueOnVariablesLoaded`,
`ContinueOnPlayerLogin`, `ContinueAfterAllEvents`. One-shot registration that unregisters itself is
a thing the client already provides.

And what **not** to copy: MapCleaner replaces the global `MapUtil_ShouldShowTask` outright rather
than hooking it. That is last-writer-wins against every other AddOn, and it is a taint risk.

---

## idTip (Community Fork) — tooltips, and multi-client layout

`ItsJustMeChris/idTip-Community-Fork`. Adds IDs to every tooltip in the game. Interesting here for
two unrelated reasons.

### Tooltip line handling

It reads lines back out of the tooltip by global name:

```lua
for i = 1, 15 do
    frame = _G[tooltip:GetName() .. "TextLeft" .. i]
    if frame then text = frame:GetText() end
    if text and string.find(text, line) then return end   -- already added
end
```

Two lessons, opposite in sign:

- **Idempotence from the frame, not from a flag.** It never keeps "did I touch this tooltip"; it
  looks at the rendered text. `Tooltip.lua` keeps `__vqPinned`, and issue #19 is precisely that the
  flag is never cleared. State re-derived from the frame cannot go stale.
- **The hard-coded `1, 15` is a bug to avoid.** `GameTooltip:NumLines()` exists; a fixed ceiling
  silently misses line 16.

It also documents a hazard we have not hit yet:

```lua
-- Try to avoid C stack overflow from hookscript, only do it once
if not hooked[tooltip] then
    hooked[tooltip] = true
    tooltip:HookScript("OnHide", function() ALL_IDS = {} end)
end
```

Repeated `HookScript` on the same frame stacks up. Guard per-frame.

Note what it does *not* have to solve: it **adds** lines and calls `tooltip:Show()`, and growing a
tooltip works that way. Shrinking one does not — which is the whole story of this project's
six-attempt tooltip stutter, and why the fix had to live in `OnSizeChanged`. Do not read idTip's
`Show()` as evidence that `Show()` is enough.

### Multi-client layout, the other way round

Where AIO ships one `.toc` for ten flavours, idTip ships **one `.toc` per flavour**
(`idTip_CommunityFork.toc`, `_Vanilla`, `_TBC`, `_Wrath`, `_Beta`) with a shared core and a
`clients/` directory split by expansion, selected at runtime:

```lua
function Helpers.GetGameVersion()
    local _, _, _, version = GetBuildInfo()   -- the interface number, e.g. 50504
    return version
end
function Helpers.IsClassic()  return Helpers.GetGameVersion() < 90000 end
```

Two models for issue #5, then: AIO's one-package-many-interfaces and idTip's one-package-per-client.
AIO's is the one that matches "one AddOn, one listing".

`GetBuildInfo()`'s fourth return as a flavour test is worth noting but it is crude —
`IsPTR()` there is `== 100000`. The documented modern test is `WOW_PROJECT_ID` against the
`WOW_PROJECT_*` constants; **which of those constants 5.5.4 defines has not been checked** and
should not be assumed.

---

## Classic Quest Text, and Vanilla Scrolling Quest Text — not read

- **Classic Quest Text** — <https://www.curseforge.com/wow/addons/scrolling-quest-text>
  "Restores the old scrolling quest text known from patches 1.x–3.x."
- **Vanilla Scrolling Quest Text (For Midnight)** — <https://www.curseforge.com/wow/addons/vanilla-scrolling-quest-text>
  Brings the character-by-character quest text back to **retail**. Configurable speed; option for
  whether Accept is greyed out while text is still running. Author `jeppe982117151`.

CurseForge is blocked from the development environment, so neither source has been read. Both are
listed here because of what their existence proves, which does not need their source:

**On retail, `noInstantQuestText` cannot be a CVar write.** This AddOn's version of this feature is
one line — turn `instantQuestText` off and the client types the text out, because the typewriter is
still in the 5.x client. Retail has no typewriter left to switch on; these AddOns re-implement it in
Lua, with a timer and a substring. That makes the retail port of this one option a rewrite, not a
port, and it is the only one of the twelve where that is true so far.

Also worth noting from the listings, as a design detail we would face: both deal with the **Accept
button during the scroll**, and a third AddOn (Nonintrusive Quest Text) exists only to let you
double-click through it. Whatever the typewriter does, it has to not make accepting a quest worse.

If these become relevant, ask for the zips — they are small, and reading them beats guessing.
