# Classic Questing — build spec

**Target:** World of Warcraft — Mists of Pandaria Classic, 5.5.4 (build 69585), interface `50504`.
Install path: `World of Warcraft\_classic_\Interface\AddOns\ClassicQuesting\`

**Goal:** restore the Classic questing experience by hiding the quest-helper layer MoP added
on top of it. Everything the addon does is *subtractive* — hiding or unregistering Blizzard UI.
It never adds quest data of its own.

> Previously working-named *Unmarked*. The name survives only in `dev/UnmarkedRecon/`, the
> throwaway probe addon, which stays a separate dev-only addon and is never shipped or folded
> into Classic Questing.

---

## Before writing any implementation code

Run the `UnmarkedRecon` addon in game and paste its output into this file under
"Recon results". Three things it settles, each of which changes the implementation entirely:

| Question | Branch A | Branch B | **Resolved** |
|---|---|---|---|
| World map | old `WorldMapBlobFrame` / `WorldMapPOIFrame` → hide frames | modern canvas → `WorldMapFrame:RemoveDataProvider()` | **B** |
| Objective tracker | `WatchFrame` (MoP-era) | `ObjectiveTrackerFrame` (backported) | **A** |
| Options panel | `InterfaceOptions_AddCategory` | `Settings.RegisterCanvasLayoutCategory` | **B** |

Do not write speculative code that handles both branches. Pick the one that's real and delete
the other. A compatibility shim for a client that only ships in one configuration is dead weight.

See "Conclusions" below for the evidence behind each verdict.

---

## Feature tiers

### Tier 1 — MVP: map and minimap markers

Default **on**.

- **Minimap quest area blobs.** `Minimap:SetQuestBlobRingAlpha(0)`,
  `SetQuestBlobInsideAlpha(0)`, `SetQuestBlobRingScalar(0)`. Undocumented widget methods,
  present since Cataclysm. Verify against recon output.
  > ⚠ **Resolved against this bullet — DROP IT.** v0.3 read the full 205-method `Minimap`
  > chain: no blob methods of any kind exist, there are no quest pin child frames, and
  > `questPOI 0` changed nothing on the minimap. There is no layer here to hide. See G1.
- **Minimap quest POI pins.** The numbered objective pins. Blizzard exposes a *Quest POIs*
  entry in the minimap tracking dropdown; the addon should set it off and re-assert it, rather
  than fight the frames. Re-assert on `PLAYER_ENTERING_WORLD` and `MINIMAP_UPDATE_TRACKING`.
  > ✅ **Confirmed available, with a caveat.** Use `C_Minimap.SetTracking`; the bare globals
  > do not exist. `Track Quest POIs` is already off, so the module enforces rather than
  > changes — and the index must be resolved **by name**, not hardcoded. See G2.
- **World map quest pins** — the numbered markers.
- **World map quest area highlights** — the shaded "objective is somewhere in here" regions.
- **CVar enforcement.** `questPOI` and friends set once at login and re-asserted on
  `CVAR_UPDATE`, so the settings don't drift back after a patch or a UI reset.
  > Narrowed to **`questPOI` alone**. `questHelper` exists but cannot be written — the write
  > is silently refused. `autoQuestWatch` and `trackQuestSorting` are Tier 2 concerns. See G5.

### Tier 2 — objective tracker

Default **off**. The on-screen tracker that lists your active quests.

Options, each independently toggleable:

- Hide the tracker entirely
- Strip it to Classic form: quest name and objective counts only — no click-to-track,
  no quest item use buttons, no auto-sort by distance to objective
- Disable auto-tracking of newly accepted quests (`autoQuestWatch`)
- Suppress the "click to turn in" pop-up bubbles

### Tier 3 — full Classic feel

Default **off**. Individually toggleable, all on one options page.

- Kill the map's hover-highlight (mousing a quest in the list stops lighting up the map)
- Kill click-to-pan (clicking a quest stops flying the map to its objective)
- Remove pin numbers from the quest list column
- Hide questgiver `!` / `?` blips on the minimap entirely
- Disable supertracking (the concept of one "active" quest the UI points you toward)

**Note on the "only show `?` when close" idea:** minimap range already *is* proximity, so
there's no meaningful radius rule to add here. The real choice is keep-as-is versus remove.
Ship it as a plain on/off toggle.

---

## Architecture

```
ClassicQuesting/
  ClassicQuesting.toc
  Core.lua        -- addon table, event dispatch, saved variables, defaults, slash command
  CVars.lua       -- set + re-assert console variables
  Minimap.lua     -- Tier 1 minimap
  WorldMap.lua    -- Tier 1 world map
  Tracker.lua     -- Tier 2
  QuestLog.lua    -- Tier 3
  Options.lua     -- options panel, built last
```

Every module exposes `Enable()` / `Disable()` and is driven from `Core.lua` off the saved
settings table. Toggling any option in the panel takes effect immediately — no `/reload`
required. If some specific thing genuinely can't be undone live, the panel says so on that
row rather than forcing a global reload prompt.

**SavedVariables:** account-wide, not per character. Someone who wants this wants it everywhere.

**Slash command:** `/cq` opens the panel, with `/classicquesting` as a long-form alias.
`/cq reset` restores defaults. (Renamed from `/unmarked` along with the project.)

---

## Safety rules — non-negotiable

Getting these wrong produces bugs that only appear in combat, hours later, and are miserable
to trace back to their cause.

1. **Never call `Hide()` on a secure or protected frame during combat.** Queue the change and
   apply it on `PLAYER_REGEN_ENABLED`.
2. **Hook, don't replace.** Use `hooksecurefunc` to run code *after* a Blizzard function.
   Overwriting a Blizzard global with your own version is what causes *taint* — the game
   marking its own execution path as addon-influenced and then refusing protected actions
   later, usually mid-fight, with an unhelpful error.
3. **Never touch the protected quest APIs** — accepting, abandoning, or turning in quests.
   The addon has no business calling those.
4. **Prefer Blizzard's own switches to frame surgery.** A CVar or a tracking-menu option that
   Blizzard maintains will survive patches; a hidden frame will not.
5. **Fail soft.** If a frame or method the addon expects is missing (a patch renamed it), log
   one line to chat and skip that feature. Never let a `nil` global break the whole addon and
   take the user's UI with it.

---

## Recon results — v0.2 probe

Source: `UnmarkedRecon` v0.2, run on the live client, world map opened first (the pin-pool
section is populated, so the `"No pin pools yet"` branch did not fire). Raw SavedVariables
file preserved at `dev/recon-log-2026-09-05.txt`; the `report` string is reproduced verbatim
below with its escaped newlines expanded.

```
Unmarked Recon - 2026-09-05 11:22
Client 5.5.4 build 69585, interface number 50504

== Objective tracker (on-screen) ==
OK   WatchFrame  [Frame]
OK   WatchFrame_Update  [function]
OK   WatchFrame_Collapse  [function]
--   ObjectiveTrackerFrame
--   ObjectiveTracker_Update
--   QuestWatchFrame
--   AutoQuestPopUpTracker
--   ObjectiveTrackerBlocksFrame

== World map ==
OK   WorldMapFrame  [Frame]
--   WorldMapBlobFrame
--   WorldMapPOIFrame
--   WorldMapQuestShowObjectives
--   WorldMapShowDropDown
OK   QuestMapFrame  [Frame]
OK   QuestScrollFrame  [ScrollFrame]
OK   QuestMapFrame_UpdateAll  [function]
OK   QuestMapFrame_ShowQuestDetails  [function]
OK   WorldMapTooltip  [GameTooltip]

== Map style: old frame or modern canvas? ==
MODERN CANVAS - WorldMapFrame:RemoveDataProvider exists.
Registered data providers: 15
Pin pool templates (these name the pins to remove):
   QuestBlobPinTemplate
   QuestPinTemplate
   MapExplorationPinTemplate
   MapHighlightPinTemplate
   GroupMembersPinTemplate
   ScenarioBlobPinTemplate

== Quest POI system ==
OK   QuestPOIGetIconInfo  [function]
--   QuestPOI_DisplayButton
OK   QuestPOI_GetButton  [function]
OK   QuestPOIUpdateIcons  [function]
--   GetQuestPOILeaderboardInfo
OK   SetSuperTrackedQuestID  [function]
OK   GetSuperTrackedQuestID  [function]
--   C_SuperTrack

== Minimap blob methods ==
--   Minimap:SetQuestBlobRingAlpha
--   Minimap:SetQuestBlobInsideAlpha
--   Minimap:SetQuestBlobRingScalar
--   Minimap:SetQuestBlobInsideTexture
--   Minimap:SetArchBlobRingAlpha
--   Minimap:SetArchBlobInsideAlpha

== Named Minimap children ==
   MiniMapMailFrame
   MiniMapBattlefieldFrame
   MinimapBackdrop

== Relevant CVars ==
OK   cvar questPOI = 1
OK   cvar autoQuestWatch = 1
--   cvar autoQuestProgress
--   cvar mapQuestDifficulty
--   cvar showQuestTrackingTooltips
OK   cvar trackQuestSorting = top
--   cvar minimapTrackingShowAll
OK   cvar questHelper = 1
--   cvar worldMapFilterAccountCompletedQuests

== Options panel API ==
OK   Settings  [table]
--   InterfaceOptions_AddCategory
--   InterfaceOptionsFramePanelContainer
Modern Settings API available - use Settings.RegisterCanvasLayoutCategory.
```

---

## Recon results — v0.3 probe

Run 2026-09-05 12:05, same client. Full output at `dev/recon-log-v3-2026-09-05.txt`;
the `Minimap` method dump at `dev/recon-log-v3-minimap-methoddump-2026-09-05.txt`.
Decisive excerpts only, below.

**[G1] The minimap has no quest-blob surface, and no quest pin frames.**

```
   Minimap: 205 methods visible.
      Minimap:SetBlipTexture          Minimap:SetCorpsePOIArrowTexture
      Minimap:SetPOIArrowTexture      Minimap:SetStaticPOIArrowTexture
      Minimap:UpdateBlips
   Minimap: 3 child frame(s)
       1  MiniMapMailFrame     2  MiniMapBattlefieldFrame     3  MinimapBackdrop
   Minimap: 0 region(s)
Is the minimap data-provider driven, like the world map?
--   Minimap.dataProviders          --   Minimap:RemoveDataProvider
--   MinimapCluster.dataProviders   --   Minimap:AddDataProvider
```

**[G2] Tracking is available through `C_Minimap`, and quest POIs are already off.**

```
--   SetTracking      --   GetNumTrackingTypes      --   GetTrackingInfo
   C_Minimap members: 5
      C_Minimap.ClearAllTracking      C_Minimap.GetNumTrackingTypes
      C_Minimap.GetPOITextureCoords   C_Minimap.GetTrackingInfo
      C_Minimap.SetTracking
Tracking types on this client:
   18 tracking type(s)
       1  table: name=Find Herbs active=false
      13  table: name=Low Level Quests active=false
      14  table: name=Points of Interest active=false
      17  table: name=Track Quest POIs active=false
```

**[G3] Provider identification failed — a fault in the probe, not the client.**

```
   WorldMapFrame: 192 methods visible.
      (no method name matches dataprovider / pin)
   Providers reachable: 15
   provider 10  mixin=nil  GetPinTemplate=QuestPinTemplate
      own keys (33): AddQuest, AssignMissingNumbersToPins, ClearFocusedQuestID, ...
   provider 13  mixin=nil  GetPinTemplate=AreaPOIPinTemplate
   provider  6  mixin=nil  own keys (24): GetMap, Init, IsCVarSet, ...
   provider 12  mixin=nil  own keys (26): GetMap, Init, IsCVarSet, IsZoneMapType, ...
   (providers 1-5, 7, 9, 11, 14, 15: mixin=nil, GetPinTemplate=nil)
```

**[G4] Settings surface, fully answered.**

```
OK   Settings:RegisterCanvasLayoutCategory   OK   Settings:RegisterAddOnCategory
OK   Settings:RegisterVerticalLayoutCategory OK   Settings:OpenToCategory
OK   Settings:RegisterAddOnSetting           OK   Settings:CreateCheckbox
OK   Settings:CreateControlTextContainer     OK   Settings:SetValue
OK   SettingsPanel  [Frame]                  --   InterfaceOptionsFrame
```

**[G5] Live CVar effect test, observed in game.**

- `questPOI 0` — world map quest markers removed, and the *Track Quest* checkbox in the
  world map's bottom-left corner removed with them. Minimap: no change.
- `questHelper 0` — refused. The probe reported `questHelper: 1 -> 1`; the write did not take.

---

## Conclusions

Updated after the v0.3 run. The three headline verdicts are unchanged; what changed is
the Tier 1 implementation plan, which is now considerably smaller.

### The three open questions — unchanged

Branch **B** (modern canvas), branch **A** (`WatchFrame`), branch **B**
(`Settings.RegisterCanvasLayoutCategory`). The v0.3 run reconfirms all three and adds
nothing that disturbs them. Evidence as recorded against the v0.2 run above.

### G1 — resolved: there is no minimap quest-blob layer to hide

The v0.2 result was inconclusive by construction — six probed names came back absent, but
absent-or-misnamed could not be distinguished. v0.3 settles it: the `Minimap` method chain
**is** readable, 205 methods deep, and the full dump contains no `SetQuestBlob*`,
`SetArchBlob*`, or any blob-related method whatsoever. What it does contain is the blip
family: `SetBlipTexture`, `UpdateBlips`, `SetPOIArrowTexture`, `SetCorpsePOIArrowTexture`,
`SetStaticPOIArrowTexture`.

Corroborating, and all pointing the same way: `Minimap` has three named children and **zero**
unnamed ones (v0.2 could not see unnamed children at all), zero regions, and no
data-provider machinery. There are no quest POI pin frames parented to the minimap. And
`questPOI 0` changed nothing on the minimap in the live test.

The reading: **this client's minimap draws quest markers as engine blips and has no quest
area blob rendering at all.** SPEC's first Tier 1 bullet is therefore not merely
unimplementable as written — it has nothing to act on. Subject to confirmation Q1 below.

### G2 — resolved: use `C_Minimap`, and resolve the index by name

The tracking route the spec wanted does exist, but only namespaced. The bare
`SetTracking` / `GetNumTrackingTypes` / `GetTrackingInfo` globals are absent; the working
functions are `C_Minimap.SetTracking`, `.GetNumTrackingTypes`, `.GetTrackingInfo`,
`.ClearAllTracking`. `GetTrackingInfo` returns a **table** (`.name`, `.active`), not a
tuple — worth stating because the two shapes are not interchangeable and the probe had to
handle both to find out.

Entry 17 is `Track Quest POIs`, and it is **already `active=false`**, which explains the
minimap's Classic-looking behaviour and the null result from `questPOI 0` there.

**The trap:** these indices are not stable. Entry 1 on this run is `Find Herbs`, which only
exists for a herbalist — so the list shifts by class and profession, and index 17 means
something different on another character. The addon must resolve the entry **by name at
runtime**, comparing against the `MINIMAP_TRACKING_QUEST_POIS` global (present, confirmed in
the globals listing). Hardcoding 17 would appear to work on this character and silently
toggle the wrong tracking type on the next one.

Since the entry is already off, the module's job is to **enforce** rather than to change.

### G3 — partially resolved, and the gap was my probe's fault

All 15 providers reported `mixin=nil`, and `WorldMapFrame` reported "no method name matches
dataprovider / pin" despite `RemoveDataProvider` being confirmed present. Both are the same
false negative: these objects are built with `CreateFromMixins`, which **copies** each
method onto the object rather than linking a metatable. v0.3 walked the metatable chain
only, so it was looking in the wrong place. The 12-key display cap compounded it — providers
1-5, 7, 9 and 11 are identical across their first twelve alphabetical keys, so their
distinguishing members were cut off.

Both are fixed in probe v0.4, which identifies providers by **function-reference
fingerprint** against every global `*DataProviderMixin` table, lists the keys that are *not*
common to all providers, and prints scalar fields — the last of these being how a CVar-gated
provider reveals which CVar gates it.

What v0.3 did establish, and which stands:

- **Provider 10 is the quest pin provider** — `GetPinTemplate=QuestPinTemplate`, with
  `AddQuest`, `AssignMissingNumbersToPins`, `ClearFocusedQuestID` among its keys.
- Provider 13 is an area-POI provider (`GetPinTemplate=AreaPOIPinTemplate`).
- **Providers 6 and 12 are CVar-gated** — both carry `Init` and `IsCVarSet`, the signature of
  `CVarMapCanvasDataProviderMixin`. One of them is the likely owner of
  `QuestBlobPinTemplate`, and `questPOI` is the likely gate. That is consistent with the
  live test, where `questPOI 0` removed the world map markers.

### G4 — resolved

Everything the options panel needs is present, including `Settings.OpenToCategory` for the
slash command. `InterfaceOptionsFrame` does not exist in any form, so there is no legacy
path to fall back to and none will be written.

### G5 — resolved, and it removes a CVar from the plan

`questPOI` works and is the right lever for the world map. `questHelper` **cannot be set** —
the write was silently refused, value unchanged at 1. It is locked or read-only on this
client.

This is the clearest vindication of testing over assuming in the whole exercise. Shipping
`SetCVar("questHelper", 0)` would have thrown no error, logged nothing, and done nothing,
forever. It is dropped from the plan. Probe v0.4 now reports the lock/secure/read-only flags
from `GetCVarInfo` so this class of thing is visible without a live test next time.

### Consequence: Tier 1 is much smaller than the spec assumed

Both of the levers that survive are Blizzard's own switches, which is exactly what safety
rule 4 asks for. Tier 1 as now understood needs **no frame surgery, no `Hide()` calls, and
no `hooksecurefunc`** — the combat-safety and taint rules stay in force for later tiers, but
Tier 1 does not currently reach for anything they constrain.

| Spec bullet | Status after recon |
|---|---|
| Minimap quest area blobs | **Drop.** No such layer on this client (G1). |
| Minimap quest POI pins | Enforce `Track Quest POIs` off via `C_Minimap.SetTracking`, index resolved by name (G2). |
| World map quest pins | `questPOI 0` removes them (G5, observed). |
| World map quest area highlights | **Open** — see Q2. Needs `RemoveDataProvider` only if the CVar doesn't cover it. |
| CVar enforcement | `questPOI` only. `questHelper` is unsettable (G5). |

So: `Core.lua` + `CVars.lua` + `Minimap.lua`, and `WorldMap.lua` only if Q2 says it is
needed. Tiers 2 and 3 unchanged and out of scope.

### Open questions before Tier 1 is written

**Q1 — Does a blue shaded quest area ever appear on the *minimap* on this client?**
If never, the minimap blob bullet is closed as a no-op. If it does appear somewhere, G1 says
there is no documented lever for it and we would need another probe pass.

**Q2 — With `questPOI 0`, does the shaded quest objective *area* also disappear from the
world map, or only the numbered markers?** This decides whether `WorldMap.lua` exists at
all. If the CVar covers both, Tier 1 is two modules and no data-provider code.

**Q3 — With `questPOI 0`, do quest markers reappear on a fresh map open or a zone change?**
Determines whether the CVar needs re-asserting on map events or only on `CVAR_UPDATE`.
