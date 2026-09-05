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
  > ⚠ **Contradicted by recon — all six blob methods are absent on this client.** This bullet
  > cannot be implemented as written. See "What the log contradicts", finding C1.
- **Minimap quest POI pins.** The numbered objective pins. Blizzard exposes a *Quest POIs*
  entry in the minimap tracking dropdown; the addon should set it off and re-assert it, rather
  than fight the frames. Re-assert on `PLAYER_ENTERING_WORLD` and `MINIMAP_UPDATE_TRACKING`.
  > ⚠ **Unverified — the recon never probed the tracking API or the tracking frame.** See
  > gap G2.
- **World map quest pins** — the numbered markers.
- **World map quest area highlights** — the shaded "objective is somewhere in here" regions.
- **CVar enforcement.** `questPOI` and friends set once at login and re-asserted on
  `CVAR_UPDATE`, so the settings don't drift back after a patch or a UI reset.
  > Recon narrows "and friends" to the CVars that actually exist here: `questPOI`,
  > `questHelper`, `autoQuestWatch`, `trackQuestSorting`. The last two are Tier 2 concerns.

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

## Recon results

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

## Conclusions

Everything below is drawn from the log above and nothing else. Where a claim is an inference
from a *name* in the log rather than something the log measured, it is labelled as such.

### The three open questions

**1. World map — Branch B: modern canvas, `WorldMapFrame:RemoveDataProvider()`.**

The probe prints `MODERN CANVAS` only inside `if WorldMapFrame and WorldMapFrame.RemoveDataProvider`,
so that method is confirmed non-nil, not merely assumed. Corroborating: every Branch-A global is
absent — `WorldMapBlobFrame`, `WorldMapPOIFrame`, and the MoP-era
`WorldMapQuestShowObjectives` / `WorldMapShowDropDown` checkbox globals are all `--`. There is
nothing of the old map left to hide. Fifteen data providers are registered and six pin pools have
spawned.

*Branch A is dead. Do not write it. No shim.*

**2. Objective tracker — Branch A: `WatchFrame`.**

`WatchFrame [Frame]`, `WatchFrame_Update`, and `WatchFrame_Collapse` all exist. Every
Branch-B global is absent: `ObjectiveTrackerFrame`, `ObjectiveTracker_Update`,
`ObjectiveTrackerBlocksFrame`. `QuestWatchFrame` (vanilla) and `AutoQuestPopUpTracker` are
also absent. This is the MoP-era tracker, unmodified — the retail tracker was *not* backported.

*Tier 2 only. Not built in the MVP.*

**3. Options panel — Branch B: `Settings.RegisterCanvasLayoutCategory`.**

`Settings` exists as a table, and the probe's closing line is emitted only inside
`if Settings and Settings.RegisterCanvasLayoutCategory`, so that function is confirmed present.
Both legacy anchors are gone: `InterfaceOptions_AddCategory` and
`InterfaceOptionsFramePanelContainer` are `--`. There is no legacy panel to fall back to.

*Branch A is dead. Caveat in gap G4 about the slash command.*

### The shape this client actually has

Worth stating plainly, because it drives everything else: this is **MoP-era quest logic running
on a modern engine**, and the two halves disagree about which era they're from. The map is a
retail-style canvas with data providers and pin pools, while the tracker is `WatchFrame` and
supertracking is still the old `SetSuperTrackedQuestID` / `GetSuperTrackedQuestID` globals with
no `C_SuperTrack` namespace. The quest-POI helpers are split down the middle:
`QuestPOIGetIconInfo`, `QuestPOI_GetButton`, and `QuestPOIUpdateIcons` are present, while
`QuestPOI_DisplayButton` and `GetQuestPOILeaderboardInfo` are gone.

Practical consequence: **no era assumption transfers.** Every global this addon touches gets
probed before it is used, and the fail-soft rule (safety rule 5) is load-bearing rather than
defensive boilerplate.

### What the log contradicts in this spec — the log wins

**C1 — the minimap blob API does not exist here.** Tier 1's first bullet asserts
`Minimap:SetQuestBlobRingAlpha` / `SetQuestBlobInsideAlpha` / `SetQuestBlobRingScalar` are
"present since Cataclysm". All three are absent, and so are `SetQuestBlobInsideTexture`,
`SetArchBlobRingAlpha`, and `SetArchBlobInsideAlpha` — the whole family, not one renamed
member. That bullet has no implementation on this client as written, and it is the single
biggest hole in the Tier 1 plan. Blocked on gap G1.

**C2 — the minimap tracking-dropdown plan is unverified, and the one adjacent CVar is gone.**
Tier 1 proposes setting a *Quest POIs* entry off via the tracking dropdown and re-asserting it.
The log neither confirms nor denies that: it never probed the tracking API or the tracking frame.
What it does show is that `minimapTrackingShowAll` does not exist, and that the only *named*
children of `Minimap` are `MiniMapMailFrame`, `MiniMapBattlefieldFrame`, and `MinimapBackdrop` —
no tracking frame among them. That is suggestive but not conclusive, since a tracking button is
commonly parented to `MinimapCluster` rather than `Minimap`, which the probe never enumerated.
Blocked on gap G2.

**C3 — "`questPOI` and friends" is a shorter list than assumed.** Of the nine CVars probed,
four exist: `questPOI = 1`, `autoQuestWatch = 1`, `trackQuestSorting = top`, `questHelper = 1`.
Five do not: `autoQuestProgress`, `mapQuestDifficulty`, `showQuestTrackingTooltips`,
`minimapTrackingShowAll`, `worldMapFilterAccountCompletedQuests`. Tier 1's CVar module therefore
has exactly two candidates — `questPOI` and `questHelper` — and the CVar enforcement loop must
skip absent names rather than set them blindly.

**C4 — project rename knock-ons.** Folder, `.toc`, and slash command all move off *Unmarked*.
Recorded above; flagging it here so it isn't mistaken for drift.

### What the log does not settle

These are genuine gaps, not things I can reason around. Each needs probe v0.3.

**G1 — how to suppress minimap quest blobs and pins at all (blocks half of Tier 1).**
With the blob methods gone, the log offers no route. Unprobed and needed: whether a `C_Minimap`
namespace exists; what `MinimapCluster:GetChildren()` holds; how many *unnamed* children
`Minimap` has (the probe only printed named ones, so anything anonymous is invisible in this
log); and whether the minimap quest layer is itself data-provider-driven on this hybrid client.

**G2 — the minimap tracking API.** Unprobed: `C_Minimap.SetTracking` / `GetNumTrackingTypes` /
`GetTrackingInfo`, the bare `SetTracking` global, `MiniMapTracking*` and `MinimapCluster.Tracking`
globals, and whether any tracking entry is actually named for quest POIs. Until this is answered
the "use Blizzard's own switch" approach (safety rule 4) can't be confirmed as available.

**G3 — which of the 15 data providers to remove.** This is the one gap inside the branch we
*did* resolve. `RemoveDataProvider` takes a provider *object*, and the log gives us pin-pool
*template names* instead — a different thing. Only 6 pools appear because a pool is created
lazily when a provider first spawns a pin, so 9 providers are entirely unrepresented. Nothing
in the log lets me map a template name back to the provider that owns it. Unprobed and needed:
whether providers expose an identifying method such as `GetPinTemplate`, and whether the
provider mixins exist as globals (`QuestDataProviderMixin` and friends) so a provider can be
identified by its metatable. Without one of those, the removal call has no argument.

Separately, my reading of the six template names — `QuestPinTemplate` as the numbered quest
markers and `QuestBlobPinTemplate` as the shaded objective areas, i.e. exactly the two Tier 1
world-map targets, with `MapHighlightPinTemplate` being the zone hover-highlight belonging to
Tier 3 — is **inference from the names**, which is all the log contains. It gets confirmed in
game against the Tier 1 checklist, not assumed.

**G4 — how the options panel is opened by slash command.** `RegisterCanvasLayoutCategory` is
confirmed; `Settings.OpenToCategory` was never probed, and `/cq` needs it. Low urgency — the
panel is built last — but it should ride along on the next probe run.

**G5 — what `questPOI` and `questHelper` actually do here.** The log proves the CVars exist and
reports their values. It says nothing about their effect. Worth testing first in game: if
`questPOI 0` alone suppresses the pins, most of the Tier 1 frame work is unnecessary and safety
rule 4 says take the CVar.
