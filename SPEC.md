# Classic Questing (MoP) — build spec

**Target:** World of Warcraft — Mists of Pandaria Classic, 5.5.4 (build 69585), interface `50504`.
Install path: `World of Warcraft\_classic_\Interface\AddOns\ClassicQuestingMoP\`
(Folder without parentheses; the parenthesised form is the `## Title` shown in the addon list.)

**Goal:** restore the Classic questing experience by hiding the quest-helper layer MoP added
on top of it. Everything the addon does is *subtractive* — hiding or unregistering Blizzard UI.
It never adds quest data of its own.

> Named *Unmarked* while in recon, then *Classic Questing*, now **Classic Questing (MoP)**.
> The old name survives only in `dev/UnmarkedRecon/`, the throwaway probe addon, which stays a
> separate dev-only addon and is never shipped or folded into this one.

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

- **Minimap quest area blobs.** The blue shaded objective area on the minimap.
  > ✅ **Real, and already handled by the bullet below.** The `Minimap:SetQuestBlob*` widget
  > methods named in the original spec do not exist on this client, but the blob does — and
  > the *Track Quest POIs* tracking entry toggles it along with the pins. One lever covers
  > both. No separate work. See G1.
- **Minimap quest POI pins.** The numbered objective pins. Blizzard exposes a *Quest POIs*
  entry in the minimap tracking dropdown; the addon should set it off and re-assert it, rather
  than fight the frames. Re-assert on `PLAYER_ENTERING_WORLD` and `MINIMAP_UPDATE_TRACKING`.
  > ✅ **Confirmed, and it is the single minimap lever.** Use `C_Minimap.SetTracking`; the
  > bare globals do not exist. Toggling *Track Quest POIs* controls both the numbered pins
  > **and** the blue area blob. It was already off on the test character, so the module
  > enforces rather than changes. The index must be resolved **by name**, never hardcoded.
  > See G2.
- **World map quest pins** — the numbered markers.
- **World map quest area highlights** — the shaded "objective is somewhere in here" regions.
  > ✅ **Both covered by `questPOI 0`, observed in game.** No world map code is needed. The
  > CVar also removes the *Track Quest* checkbox and the quest log panel inside the fullscreen
  > map — bundled, not separable, and both are Classic-correct. See G5.
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
- **Disable auto-tracking of newly accepted quests (`autoQuestWatch`).** ✅ Shipped in
  v0.2.0 as an **opt-in** setting, default off: this is genuine quality of life rather than
  clutter, so the player chooses it instead of having it chosen for them.
- **Instant Quest Text.** The Blizzard option. Classic-correct is *off*, so quest text types
  out rather than appearing at once. **Blocked:** the CVar behind it is unknown, and
  `C_Console.GetAllCommands` does not exist on this client, so the console cannot be
  enumerated. Probe v0.6 walks the Settings registry instead — see G8.
- Suppress the "click to turn in" pop-up bubbles

### Tier 3 — full Classic feel

Default **off**. Individually toggleable, all on one options page.

- Kill the map's hover-highlight (mousing a quest in the list stops lighting up the map)
- Kill click-to-pan (clicking a quest stops flying the map to its objective)
- Remove pin numbers from the quest list column
- **Hide questgiver `!` blips on the minimap.** Promoted in importance by live testing:
  Classic never showed `!` for nearby questgivers, MoP does, and there is no obvious switch
  for it. Mechanism unknown — the only plausible lever seen in recon is `Minimap:SetBlipTexture`
  (present in the 205-method dump), which is untested and may affect more than quest blips.
  Needs its own probe pass before it is designed.
- **World map creature portraits.** ✅ Shipped in v0.2.0 as an **opt-in** setting
  (`showBosses`), default off. Recon v0.4 named the lever — provider 7 is
  `EncounterJournalDataProviderMixin` carrying `cvar=showBosses` — and setting it to 0 was
  confirmed working in game. Note it appears to have **no checkbox in the Blizzard options
  window**; it is a console variable only, which is why it could not be found there.
  (`DigSiteDataProviderMixin` / `digSites` is the same shape if archaeology clutter is ever
  worth an option; not shipped, not requested.)
- **Turn-in markers: `?` versus the gold bullet.** The minimap shows a `?` plus a gold bullet
  for nearby turn-ins. That is close enough to Classic to leave alone by default, but offer a
  toggle for the purist option: gold bullet only, no `?`.
- Disable supertracking (the concept of one "active" quest the UI points you toward)

**Note on the minimap tracking toggle.** Blizzard's tracking dropdown stays fully functional
and is deliberately not touched: disabling one entry means reaching into Blizzard's menu code,
which risks taint (safety rule 2) and fights the player's own UI (rule 4). Instead the addon
**re-asserts** — flipping *Track Quest POIs* back on from the dropdown fires
`MINIMAP_UPDATE_TRACKING` and the addon turns it off again, so the entry is effectively inert
while the module is on, with no Blizzard code touched. The options panel is the real switch,
and `Minimap:Status()` already reports the live tracking state (visible today via `/cq`) so the
panel can show it and explain the interaction rather than leaving the player confused about a
dropdown entry that will not stick.

**Note on the "only show `?` when close" idea:** minimap range already *is* proximity, so
there's no meaningful radius rule to add here. The real choice is keep-as-is versus remove.
Ship it as a plain on/off toggle.

---

## Architecture

```
ClassicQuestingMoP/
  ClassicQuestingMoP.toc
  Core.lua        -- addon table, event dispatch, saved variables, defaults, slash command
  CVars.lua       -- set + re-assert console variables
  Minimap.lua     -- Tier 1 minimap
  Tracker.lua     -- Tier 2
  QuestLog.lua    -- Tier 3
  Options.lua     -- options panel, built last

  (No WorldMap.lua. Recon showed the world map needs no code of its own -- the
   questPOI CVar covers every Tier 1 world map target. See conclusion G5.)
```

Every module exposes `Enable()` / `Disable()` and is driven from `Core.lua` off the saved
settings table. Toggling any option in the panel takes effect immediately — no `/reload`
required. If some specific thing genuinely can't be undone live, the panel says so on that
row rather than forcing a global reload prompt.

**Options panel requirement.** Every setting the addon creates must be individually
toggleable in the panel. Turning everything on gives the ultimate Classic experience; leaving
some off lets a player tune their own. Nothing the addon does may be all-or-nothing at the
panel level, even where the underlying lever is (see the `questPOI` bundling note in G5).

**SavedVariables:** account-wide, not per character. Someone who wants this wants it everywhere.

**Slash command:** `/cq` opens the panel, with `/classicquesting` as a long-form alias.
`/cq reset` restores defaults. (Renamed from `/unmarked` along with the project.)

**Keep `## Notes` short.** A long Notes line widens the addon-list tooltip until the version
is pushed outside the box. One short sentence.

**The name `/cq` prints is the name `/cq` accepts.** Modules carry both a display key
(`mapCreaturePortraits`) and a saved-setting name (`showBosses`); the status list shows the
key, so the key must be a valid handle for `/cq on|off`. Accepting only the setting name made
every name on screen report "Unknown setting".

**Version numbers have one source of truth: the `.toc`.** Never hardcode a version string in
Lua. Read it at runtime with `C_AddOns.GetAddOnMetadata(addonName, "Version")` (fall back to
`GetAddOnMetadata` if the namespaced form is missing, per safety rule 5) so the chat banner,
the options panel, and the addon list cannot disagree. This rule exists because the recon
probe broke it: v0.4 announced itself as v0.4 in chat while its `.toc` still said 0.3, because
the version lived in two places and only one got bumped.

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

## Recon results — v0.4 probe

Run 2026-09-05 13:39, same client, plus live in-game CVar and tracking tests.
Full output at `dev/recon-log-v4-2026-09-05.txt`.

**[G3] All 15 providers identified exactly.** The own-keys fix also revealed
`WorldMapFrame`'s real surface: 352 methods, not the 192 v0.3 could see.

```
   WorldMapFrame: 352 methods visible.
      WorldMapFrame:AddDataProvider          WorldMapFrame:RemoveDataProvider
      WorldMapFrame:RemoveAllPinsByTemplate  WorldMapFrame:RemovePin
      WorldMapFrame:EnumeratePinsByTemplate  WorldMapFrame:GetNumActivePinsByTemplate
      WorldMapFrame:RefreshAllDataProviders  WorldMapFrame:AddStandardDataProviders

   provider  2  EXACT: AreaPOIDataProviderMixin(20)     GetPinTemplate=AreaPOIPinTemplate
   provider  6  EXACT: DigSiteDataProviderMixin(22)     fields: cvar=digSites
   provider  7  EXACT: EncounterJournalDataProviderMixin(21)  fields: cvar=showBosses
   provider 12  EXACT: QuestBlobDataProviderMixin(26)   fields: none
   provider 13  EXACT: QuestDataProviderMixin(25)       GetPinTemplate=QuestPinTemplate
   (1 AreaLabel, 3 BattlefieldFlag, 4 BonusObjective, 5 DeathMap, 8 Gossip,
    9 GroupMembers, 10 MapExploration, 11 MapHighlight, 14 Scenario, 15 Vehicle)
```

**Live test — `questPOI 0`.** Removes: world map quest pins, the blue quest area highlights,
the *Track Quest* checkbox, and the quest log panel inside the fullscreen world map. Survives
zone changes, accepting new quests, a fresh map open, and `/reload`. Minimap: no change.

**Live test — minimap tracking.** Toggling *Track Quest POIs* toggles the blue quest area on
the minimap, along with the pins.

**Live test — `questHelper 0`.** Refused; value unchanged at 1.

**Observed, not yet actionable.** The minimap shows `?` plus a gold bullet for nearby turn-ins
(acceptable, close to Classic), and `!` for nearby questgivers (not Classic, no obvious switch).

---

## Conclusions

Updated after the v0.3 run. The three headline verdicts are unchanged; what changed is
the Tier 1 implementation plan, which is now considerably smaller.

### The three open questions — unchanged

Branch **B** (modern canvas), branch **A** (`WatchFrame`), branch **B**
(`Settings.RegisterCanvasLayoutCategory`). The v0.3 run reconfirms all three and adds
nothing that disturbs them. Evidence as recorded against the v0.2 run above.

### G1 — resolved, and it corrects an earlier conclusion of mine

After v0.3 I concluded there was "no minimap quest-blob layer to hide." **That was wrong, and
the live test overrides it.** Toggling *Track Quest POIs* visibly toggles a blue quest area on
the minimap, so the blob is real.

What was true, and remains true, is narrower: there is no *widget-method* lever for it. The
`Minimap` method chain is fully readable at 205 methods and contains no `SetQuestBlob*` or
`SetArchBlob*` of any kind, the minimap has no quest pin child frames, and it is not
data-provider driven. I over-read the absence of an API as the absence of the feature. The
feature is engine-drawn and switched through the tracking system instead.

Consequence for Tier 1: unchanged in practice, since the tracking toggle covers it — but the
reasoning behind the bullet is now right rather than accidentally right.

### G2 — resolved: `C_Minimap`, one lever, index resolved by name

The bare `SetTracking` / `GetNumTrackingTypes` / `GetTrackingInfo` globals are absent; the
working functions are namespaced under `C_Minimap`. `GetTrackingInfo` returns a **table**
(`.name`, `.active`), not a tuple.

Entry 17 is `Track Quest POIs` and was already `active=false` on the test character, which is
why `questPOI 0` changed nothing on the minimap. Live testing confirms this one entry governs
**both** the numbered pins and the blue area.

**The trap, restated because it is the single most likely way to ship a silent bug:** the
indices are not stable. Entry 1 on this run is `Find Herbs`, which exists only because the
test character is a herbalist. On another character the list shifts and index 17 is something
else. Resolve by name against the `MINIMAP_TRACKING_QUEST_POIS` global, which is present.

### G3 — resolved, and the earlier failure was mine

All 15 providers now identify exactly. The v0.3 blanks were a probe fault, not a client
property: these objects are built with `CreateFromMixins`, which copies methods onto the
object rather than linking a metatable, so walking the metatable chain looked in the wrong
place. The same bug hid 160 of `WorldMapFrame`'s 352 methods, including `RemoveDataProvider`
itself, which the probe had already confirmed by direct access — an internal contradiction in
the v0.3 output that was the tell.

The two providers that matter:

- **`QuestDataProviderMixin`** (provider 13, `GetPinTemplate=QuestPinTemplate`) — numbered pins.
- **`QuestBlobDataProviderMixin`** (provider 12) — the shaded objective areas.

Worth noting: neither carries a `cvar` field, while `DigSiteDataProviderMixin` (`digSites`) and
`EncounterJournalDataProviderMixin` (`showBosses`) do. So `questPOI` is not gating these two
through the generic CVar-provider mechanism; it is consulted inside their own logic. That
matters only if we ever need finer control than the CVar gives.

**We do not need any of this for Tier 1.** It is recorded because it is hard-won and because
Tier 3 will want it.

### G4 — resolved

Everything the options panel needs is present, including `Settings.OpenToCategory` for the
slash command. `InterfaceOptionsFrame` does not exist in any form, so there is no legacy path
and none will be written.

### G5 — resolved: one CVar does the entire world map job

`questPOI 0` removes the world map quest pins, the blue quest area highlights, the *Track
Quest* checkbox, and the quest log panel inside the fullscreen map. It survives zone changes,
newly accepted quests, a fresh map open, and `/reload`.

Two consequences:

1. **`WorldMap.lua` is not needed.** Every Tier 1 world map target falls to a CVar that
   Blizzard maintains — safety rule 4's best case. No `RemoveDataProvider` call ships in Tier 1.
2. **The CVar is all-or-nothing.** The quest log panel removal is bundled and cannot be
   separated from the pin removal. Both are Classic-correct so this is fine here, but if a
   future option needs pins gone while keeping that panel, it would have to drop the CVar and
   use `RemoveDataProvider` on provider 13 instead. Recorded for the Tier 3 options page.

`questHelper` **cannot be written** — the write is silently refused, value unchanged. Dropped.
Shipping `SetCVar("questHelper", 0)` would have thrown no error and done nothing, forever.

### Final Tier 1 plan — BUILT

| Spec bullet | Implementation |
|---|---|
| Minimap quest area blobs | Covered by the tracking toggle below — no separate work |
| Minimap quest POI pins | `C_Minimap.SetTracking(<index by name>, false)`, re-asserted |
| World map quest pins | `questPOI 0` |
| World map quest area highlights | `questPOI 0` |
| CVar enforcement | `questPOI` only; re-assert on `CVAR_UPDATE` |

Three files: `Core.lua`, `CVars.lua`, `Minimap.lua`. No `WorldMap.lua`. Shipped as v0.1.0.

Verified off-client against a stubbed WoW environment across six scenarios (normal, refused
CVar write, refused tracking write, missing `C_Minimap`, missing tracking entry, missing
CVar): 49 checks, all passing. The stub models `SetCVar` firing `CVAR_UPDATE` and
`SetTracking` firing `MINIMAP_UPDATE_TRACKING`, because a feedback loop between enforcement
and its own event is the main structural risk in this design. Measured event depth stays at 2.

Both levers are Blizzard's own switches, so **Tier 1 needs no frame surgery, no `Hide()`, and
no `hooksecurefunc`.** Safety rules 1 and 2 are not reached by any Tier 1 code path; they stay
in force for Tiers 2 and 3, which will reach them. Rule 5 still applies throughout — every
global is probed before use.

## Recon results — v0.5 probe

Run 2026-09-05 14:41. Full output at `dev/recon-log-v5-2026-09-05.txt`. Three results,
two of them negative and therefore decisive.

**The console cannot be enumerated.**

```
== [G6] CVar discovery - full console command list ==
   C_Console.GetAllCommands missing - cannot enumerate the CVar space.
```

**Tracking entries, every field — and no questgiver entry among them.**

```
    1  active=false, name=Find Herbs, spellID=2383, subType=-1, texture=133939, type=spell
   13  active=false, name=Low Level Quests, subType=-1, texture=237607, type=other
   14  active=false, name=Points of Interest, subType=-1, texture=457292, type=other
   17  active=false, name=Track Quest POIs, subType=-1, texture=535616, type=other
   18  active=false, name=Track Digsites, subType=-1, texture=535615, type=other
   (2-12 are the NPC trackers: Repair, Innkeeper, Flight Master, ... all type=other subType=2)

   Globals containing 'blip': 0 global name(s)
```

`C_Minimap.GetPOITextureCoords` works, returning four coordinates per index in a 13-per-row
grid — an atlas lookup into the POI icon sheet.

**Live tests.** `/unrecon set showBosses 0` works. `/cq` works: it removes what the probe
removed, and holds the minimap POI toggle off.

---

## Conclusions (continued)

### Still open

**Questgiver `!` blips — Tier 1, and the honest position.**

The v0.6 live test settles the mechanism: `/unrecon blip 136458` turned **every** minimap POI
icon into a grey square, questgiver `!` and `?` among them. So `Minimap:SetBlipTexture` does
reach them. Three costs come with it, all confirmed rather than predicted:

1. **It swaps the whole sheet, not one icon.** Every POI blip changed, each sampling a
   different region of the replacement texture. Suppressing the `!` this way also blanks
   tracked herbs, vendors, trainers and flight masters. The recon character has *Find Herbs*
   active, so this is a real loss, not a hypothetical one.
2. **`/reload` did not undo it.** Only a full client restart restored the real icons. The
   blip texture survives a UI reload, and there is no getter to read the original path back.
   That breaks the architecture rule that toggling takes effect immediately.
3. **It needs an asset.** The addon would have to ship its own transparent sheet. Still
   subtractive in effect, but no longer subtractive in the sense of touching nothing but
   Blizzard's own switches.

Probe v0.7 adds `/unrecon blipreset`, which tries `Minimap:SetToDefaults()` (present in the
205-method dump) and then `SetBlipTexture(nil)` / `("")`. If any restores the icons without a
restart, cost 2 disappears and the feature becomes a normal opt-in toggle. If none do, it can
only be applied at login and undone by restarting the client, and should ship — if at all — as
a loudly-labelled opt-in rather than part of the default Classic experience.

**On breaking the safety rules to get this done.** They are not what is blocking it, so
breaking them buys nothing. Rules 1 and 2 guard against taint and protected-frame errors,
which are about Lua reaching into Blizzard's *code*. These blips are not drawn by Lua at all:
`Minimap` reports zero regions and zero unnamed children, there are zero globals containing
"blip", and no function in the 205-method dump renders one. There is no Lua call site to hook,
overwrite, or subvert — the drawing happens below the API surface entirely. Overwriting
Blizzard globals here would add taint risk while changing nothing on screen. The constraint is
architectural, not a permission we are declining to take.

So the realistic choice is the transparent-sheet trade above, or documenting this as a client
limitation. Not a rule we can spend to buy our way out.

**Instant Quest Text — Tier 2, one probe away.** v0.6 reached the registry:
`SettingsPanel:GetCategoryList()` returns 42 entries, `GetAllCategories()` 16, and
`SettingsPanel.settings` exists as a table. The walk printed `category: nil` for all 42 only
because v0.6 *guessed* at the field names (`name`, `settings`, `layout`). v0.7 stops guessing:
it dumps the actual key set of sample entries and reads `SettingsPanel.settings` directly,
which is where a variable name like Instant Quest Text should surface.

### G8 — the Settings registry is the remaining discovery route

With `C_Console.GetAllCommands` gone, guessing CVar names is the only alternative to walking
Blizzard's own options registry, and guessing is what this client punishes. v0.6 dumps the
full `Settings` table, `SettingsPanel`'s methods and keys, and `Settings.CategorySet`, then
tries five ways to reach a category list and reports which one works — an unreachable list
being a real answer that tells the next probe to find another angle. Where a list is reached
it walks it and prints every setting variable with its current value.

This should answer, in one run: the Instant Quest Text CVar, whether `showBosses` is exposed
in the options UI at all, and whatever else Blizzard registers that this addon might want.
