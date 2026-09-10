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

## Work list

Tiers have stopped being useful. Work has landed across all three, so "Tier 3" no longer means
"later" and the label was hiding what is actually left. What follows is by **state**.

### Shipped

| Feature | Option | Since |
| --- | --- | --- |
| World map quest pins, shaded areas, Track Quest box, in-map quest list | `worldMapMarkers` | v0.1.0 |
| Minimap quest markers | `minimapMarkers` | v0.1.0 |
| Automatic tracking of newly accepted quests | `autoQuestTracking` | v0.2.0 |
| World map boss/creature portraits | `mapCreaturePortraits` | v0.2.0 |
| Tracker quest titles made plain text (no click-to-track, no context menu) | `trackerClickToTrack` | v0.12.0 |
| Tracker quest item use buttons | `trackerItemButtons` | v0.12.0 |
| Instant Quest Text, so quest text types out | `questTextTypesOut` | v0.13.0 |
| The framed questgiver portrait beside quest text | `questGiverPortrait` | v0.16.0 |
| Quest progress appended to tooltips | `questProgressTooltips` | v0.16.0 |
| Yellow quest-item highlight in bags | `bagQuestHighlight` | v0.13.0 |

Plus the options panel itself: Blizzard's own vertical layout, real checkboxes, the real
dropdown, the real Apply and Defaults buttons.

### Shipped but unproven

| Feature | Option | What is unproven |
| --- | --- | --- |
| Turn-in pop-up bubbles | `trackerTurnInPopups` | No pop-up has been seen in play, so the removal has never run. Ships **experimental and off**. The one unverified assumption is stated in `Tracker.lua`: the first return of `GetAutoQuestPopUp` is taken to be the questID `RemoveAutoQuestPopUp` wants. |
| Quest object outline | `questObjectOutline` | The CVar writes fine and changes nothing, because the client cannot render the outline. Kept as an experiment in case a future build fixes it. |

### In flight

Nothing. The next probe section goes with the next question.

### Backlog

- **Questgiver `!` blips on the minimap.** Classic never showed them. Parked, not abandoned: the
  mark lives in a shared texture atlas, so removing it means replacing artwork. Waiting on an
  edited `ObjectIconsAtlas.blp`. Workflow written up in `dev/BLIP-TEXTURE-WORKFLOW.md`.
- **Turn-in markers: `?` versus the gold bullet.** The minimap shows both for nearby turn-ins.
  Close enough to Classic to leave alone by default; offer a purist toggle for gold-bullet-only.
- **A wiki of what this client actually exposes.** Twenty-two probe sections have established a
  large amount about a client nobody has documented: which globals exist, which CVars are real,
  what `Settings.RegisterAddOnSetting` wants, where Blizzard's own settings can be read from.
  It lives as raw logs plus this file. Turning it into a reference — for this project, so nothing
  has to be re-probed, and for anyone else writing for MoP Classic — is worth doing. Not yet;
  the logs stay as they are until then.

### Dropped

- **~~Hide the tracker entirely.~~** Classic *has* a tracker — you shift-click a quest in the log
  and it appears. Hiding it removes a Classic feature rather than a MoP one, which is backwards
  for this AddOn. Also redundant: with `autoQuestTracking` on and nothing tracked by hand, the
  frame is already empty and invisible.
- **~~Auto-sort by distance to objective.~~** Nothing to remove. The only sort constants this
  client defines are `WATCHFRAME_SORT_MANUAL` (0), `_DIFFICULTY_HIGH` (1) and `_DIFFICULTY_LOW`
  (2) — there is no proximity sort — and `WATCHFRAME_SORT_TYPE` already reads 0.
- **~~Map hover-highlight~~, ~~click-to-pan~~, ~~pin numbers in the quest list column.~~** All
  three were descriptions of the pin system's behaviour, and `questPOI 0` removes the pins, the
  shaded areas and the in-map quest list outright. With nothing to hover, click or number, there
  is nothing left to disable. Closed.
- **~~Disable supertracking.~~** Supertracking is the client's idea of one "active" quest that
  the UI points you toward — the quest whose objectives sit at the top of the tracker, whose
  area is shaded on the map, and which the minimap arrow follows. `SetSuperTrackedQuestID` and
  `GetSuperTrackedQuestID` both exist on this client. It is closed for the same reason as the
  three above: with `worldMapMarkers` and `minimapMarkers` on there is no marker, no shaded area
  and no arrow left for it to drive, so the concept has no visible expression. Reopen only if
  something is spotted in play that still behaves as though one quest were special.

### Open bugs

**GitHub Issues.** `BUGS.md` was tried and removed — a bug has a state and a conversation, and a
markdown file gives it neither.

### Known limitations

Documented in `README.md` and to be repeated on the CurseForge page. These are things this
client will not let an AddOn do cleanly, not things left undone.

1. **Achievement tracker lines also stop being clickable** when `trackerClickToTrack` is on. The
   tracker draws quest and achievement titles from one pool of buttons (`WATCHFRAME_LINKBUTTONS`)
   and does not mark which is which. Accepted as a cost; stated in the option's own tooltip so
   the player reads it where they decide. Worth another probe pass some day — if a button
   carries a type field, they could be told apart — but not a priority.
2. **Quest object sparkles cannot be removed.** A client rendering fault: the outline the client
   should draw does not render, so it falls back to sparkles. `particleDensity` and `ffxGlow`
   were both tried and rejected. The same sparkle marks lootable corpses, which *is* Classic.
3. **Questgiver `!` blips.** See Backlog.
4. **~~Instant Quest Text cannot be enforced.~~** Solved in v0.13.0 — see G19.

## Architecture

```
ClassicQuestingMoP/
  ClassicQuestingMoP.toc
  Core.lua        -- addon table, event dispatch, saved variables, defaults, slash command
  CVars.lua       -- set + re-assert console variables
  Minimap.lua     -- minimap quest markers
  Tracker.lua     -- objective tracker
  Options.lua     -- settings panel (loaded last: it reads every module)

  (No WorldMap.lua, and no QuestLog.lua. Both were planned and neither is
   needed. questPOI 0 covers every world map target on its own -- see G5 --
   and it takes the in-map quest list with it, which is what QuestLog.lua was
   for. Nothing has been found since that needs either file.)
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

**Addon-list tooltip: version renders outside the box.** Unresolved. Shortening `## Notes`
did not fix it, so the cause is not Notes length. The remaining differences from the recon
addon, which renders correctly, are the title length ("Classic Questing (MoP)" at 22 characters
versus "Unmarked Recon" at 14) and the version format ("0.2.1", two dots, versus "0.7", one).
v0.3 tests the version format by changing only that. If it still overflows, shorten the Title
next. Do not keep guessing past that without a screenshot.

**One name per feature — no second name anywhere.** v1 gave each feature a display key
(`mapCreaturePortraits`) *and* a saved-setting name mirroring the CVar (`showBosses`). That
duplication was not good practice and it caused two separate bugs: `/cq on|off` rejected every
name `/cq` itself printed, and `"showBosses turned on"` read as though the portraits were being
*shown* when they were being hidden. As of v2 the module key, the saved-settings key and the
typed handle are the same string, and it names what the addon does rather than what Blizzard
calls the switch underneath. The CVar name is an implementation detail inside the rule table.
A `dbVersion` migration carries v1 saved settings across, and the old names still resolve as
handles.

**Report the effect, not the switch.** `/cq on X` prints what actually changed
("world map creature portraits hidden"), never the raw CVar transition.

**Versioning: stay below 1.0 until the AddOn is releasable.** Use `0.MINOR.PATCH`. Version
`1.0.0` is reserved for the first genuinely releasable build — not for an iterative step that
happens to follow `0.9`. (`0.9` is followed by `0.10`, not `1.0`.) What "releasable" means is
tracked in the work list; as of v0.15.1 it is the CurseForge description, the name decision in
`NAMING.md`, and removing the fallback panel's live status readout.

**Version numbers have one source of truth: the `.toc`.** Never hardcode a version string in
Lua. Read it at runtime with `C_AddOns.GetAddOnMetadata(addonName, "Version")` (fall back to
`GetAddOnMetadata` if the namespaced form is missing, per safety rule 5) so the chat banner,
the options panel, and the addon list cannot disagree. This rule exists because the recon
probe broke it: v0.4 announced itself as v0.4 in chat while its `.toc` still said 0.3, because
the version lived in two places and only one got bumped.

---

## Options panel — built

`Options.lua`. Two implementations, one preferred and one held in reserve.

### The native panel — what ships

Blizzard's own controls, through its own Settings API. Registered as a **vertical layout
category**, so Blizzard draws the list: a real `Settings.CreateCheckbox` per option, the real
dropdown for the preset, and Blizzard's own **Apply** and **Defaults** buttons.

The signature that makes it possible was settled by readback rather than guesswork — see G13c:

```lua
Settings.RegisterAddOnSetting(category, variable, variableKey,
                              variableTbl, variableType, name, default)
```

Details that matter:

- **Ordering** comes from `ns:SortedModules()`, the same source `/cq status` uses, with the
  experiments moved to the end so a heading can sit in front of them.
- **The Experimental heading** is a real section header —
  `CreateSettingsListSectionHeaderInitializer`, a plain global, added to the **second** return
  value of `RegisterVerticalLayoutCategory`. Coloured with an escape in the header text.
- **The version** is a grey section heading at the foot. At the top it would read as a heading
  *for* the options below it.
- **Reload-needing options** carry `CommitFlag.Apply` and `Revertable`, so ticking one parks the
  value and Blizzard's Apply commits it. The changed callback fires inside the commit, and that
  is where the reload happens. Apply never asks: pressing it *is* the answer.
- **Defaults** needs nothing from this AddOn. Blizzard's button reloads the UI itself when a
  setting it reset requires one. Two workarounds for this were written and both removed; see the
  v0.14.3 notes.
- **Tooltips** are built as strings with colour escapes: yellow body, orange for an experimental
  note or a known limitation, grey for the slash handle at the foot.

### The canvas panel — the fallback

The original hand-built panel is kept and used automatically if any step of `registerNative()`
fails, so the worst case is the panel that shipped before rather than no panel. It has its own
`Defaults` button, dialogs and arrow-stepper preset control, and it is the only consumer of each
module's `group` field — the native layout uses one heading and no grouping.

If even `RegisterCanvasLayoutCategory` fails, the same frame is shown as a standalone movable
window and `/cq` still opens it. One warning line, once.

### Presets

- *Full Classic experience* — every normal option on, experimental ones **left exactly as the
  player set them**.
- *Disabled* — every option off, experimental included.
- *Custom* — **derived, never stored.** Shown whenever the settings match neither preset. Listed
  in the dropdown because a dropdown cannot display a value that is not among its entries, but
  never a choice.

Experimental options do not enter into whether the settings read as Full Classic. See
"Presets and experimental options".

**Shipped defaults are the Full Classic experience** — every non-experimental option on. That is
what people install the AddOn for; neither "all off" nor a subset picked to the author's taste is
a defensible out-of-the-box state.

**The player-facing name is "Classic Questing"** everywhere in game, including the AddOn list.
The `(MoP)` suffix survives only in the folder name, the repository and the future CurseForge
listing, where it identifies which build to download for which client. See `NAMING.md` — the name
itself is under review.

**TODO(v1.0):** remove the live status readout from each row of the canvas fallback. It is useful
while developing and meaningless to a player. The native panel never had one.

### The dropdown — resolved

This section tracked a long hunt for Blizzard's real dropdown. It is finished, and the detail
lives in the G13/G13b/G13c results below. The short version, kept because the *method* is worth
repeating:

- v0.12 and v0.13 named the templates and dumped them. `WowStyle1DropdownTemplate` is the visual
  match but has no `SetupMenu` on this client, so driving it by hand was never the route.
  `SettingsDropDownControlTemplate` is built to be driven by a registered **Setting object**.
- v0.14 `[G13b]` asked "which signature is accepted?" and got the useless answer "all five" —
  `RegisterAddOnSetting` validates nothing.
- v0.15 `[G13c]` asked the right question, "where did each argument land?", with sentinel values
  read back through `GetName`/`GetVariable`/`GetVariableType`/`GetDefaultValue`. One shape scored
  4/4 and the panel was rebuilt on it.

**The rule that came out of it:** when a call takes arguments and validates none of them,
acceptance is not evidence. Pass values you can recognise and read them back.

Two font sizes are Blizzard's, not the AddOn's: tooltip **body** text uses `GameTooltipText`, and
changing it would alter every tooltip in the game, so it is left alone. Option labels already use
`GameFontNormal`, which is exactly what Blizzard's own option rows use.

### Applying changes while a frame is open

`questPOI` only takes effect when the world map redraws, so toggling it while the map was open
appeared to do nothing. **`WorldMapFrame:RefreshAllDataProviders()` is rejected and must not be called.** It re-runs the
exploration data provider, which **wipes the fog-of-war state** — the map opens fully revealed
until you leave the zone and return. That is far worse than the problem it was meant to solve.
Hooking the map's `OnShow` to call it was tried and reverted; the addon now never touches it.

**An Apply button was also tried and rejected.** Nothing forces the player to press it: Blizzard's
own Close button and the X ignore an addon's Apply entirely, so a change could sit unapplied
with no sign of it. Hooking Blizzard's Apply properly means registering settings through
`Settings.RegisterAddOnSetting` with commit semantics whose signature is unverified — the exact
class of guess that has cost this project repeatedly. Probe v0.13 dumps that machinery so it can
be attempted from evidence rather than hope.

**What ships instead: ask at the moment of the change.** Rules set `needsApply`; toggling one —
or picking a preset, or restoring defaults, when that moves one — immediately asks *"The UI needs
to reload for this setting to take effect"* with **Reload** and **Cancel**, and Cancel puts the
setting (and its CVar) back. This cannot be ignored and needs no state carried across the panel
closing. Blizzard's screen dim is reproduced behind it, since that is what makes a confirmation
read as modal.

### Consistency rules

**The slash path says nothing about reloading; the panel asks.** These are not inconsistent —
they are two different situations, and I had the reasoning backwards until it was corrected:

- **`/cq on|off|reset`** — the player is at the keyboard with the map reachable, and the map is
  correct the next time it opens. No reload is involved, so saying otherwise is advice for a
  problem they do not have. A regression guard in the suite asserts the slash path never says
  "reload".
- **The options panel** — the map is *not* open, cannot be opened while the panel is (this
  client will not show both), and does not open itself afterwards. Without the dialog the
  player closes the panel, sees no change, and concludes the AddOn is broken. **The dialog is
  not caution, it is the fix for a stale frame.** It stays.

**When the dialog can go:** once every control in the panel is a real Blizzard control driving
a real setting object, Blizzard's own Apply button handles the rebuild and the dialog becomes
redundant. That needs the checkboxes *and* the dropdown to be Blizzard's — one alone is not
enough, since Apply only knows about settings registered through it. As of v0.10.0 both are;
what is still missing is the commit-flag value that asks Apply to appear. Probe v0.16 [G16].

**One ordering.** `ns:SortedModules()` is the single source; the options panel and `/cq status`
both use it, so they cannot drift apart as options are added.

**"AddOn", not "addon".** Blizzard's own capitalisation, in every user-visible string and in
the comments.

## Release notes — CurseForge listing

**TODO before first release:** write the CurseForge description, and give it a **Known
limitations** section. It must include, at minimum:

- **Quest object and gathering-node sparkles cannot be removed.** They appear because the
  client falls back to sparkles when it cannot render object outlines, and on affected clients
  the outline does not render at any setting — including through Blizzard's own options window.
  This is a client rendering fault and no addon can reach it. The `questObjectOutline` option is
  offered as an **experimental** semi-fix: if your client *can* render outlines, turning it on
  replaces the sparkles with an outline. It does nothing on clients that cannot.
- Anything else discovered to be unreachable gets listed here rather than quietly omitted.

---

## Recon results — v0.14 probe

Run 2026-09-09 16:49, client 5.5.4 build 69585, interface 50504.

### G13b — asked the wrong question

All five `Settings.RegisterAddOnSetting` shapes came back **OK**, and a setting object with 39
keys was returned. That is not the good news it looks like. A function that accepts five
mutually contradictory argument orders is not validating its arguments — it built a setting
every time, just a scrambled one where the name may have landed in the variable slot.

**My probe was at fault, twice.** It asked *"was the call accepted?"* when the question is
*"where did each argument land?"*, and two of its five shapes were the same call written out
with different descriptions (shape 1 passed seven arguments under a six-argument label).

What it did settle, usefully:

- The setting object exposes `GetName`, `GetVariable`, `GetVariableType`, `GetDefaultValue`,
  `GetValue`, `SetValue`, `SetValueChangedCallback`, `Commit`, `Revert`, `IsModified`,
  `SetPendingValue`, `ClearPendingValue` — **the full commit/revert vocabulary an Apply button
  needs.** If the signature can be pinned down, Blizzard's own Apply comes with it.
- `Settings.CreateDropdown`, `Settings.CreateDropdownInitializer` and
  `Settings.CreateControlTextContainer` all exist.
- `MenuUtil`, `Menu` and `MenuResponse` exist. `CreateContextMenu` does not, and a frame built
  from `WowStyle1DropdownTemplate` has **no `SetupMenu` method** — its `menuMixin` carries only
  `Generate`, `GetChildExtentPadding`, `GetInset`. So driving that template by hand is not the
  route; going through `Settings.CreateDropdown` is.

**v0.15 [G13c] replaces it** with a readback test: each shape gets distinct sentinel strings and
a `true` default against an empty backing table, then the object is interrogated. Four correct
slots out of four identifies the real signature; anything less shows exactly which argument
went astray.

### G14 — the tracker, resolved enough to plan against

- **`WatchFrame:IsProtected()` → `false`, explicitly false.** Safety rule 1 is satisfied: it can
  be touched, in combat included.
- Three children: `WatchFrameHeader` (Button), `WatchFrameCollapseExpandButton` (Button),
  `WatchFrameLines` (Frame). **Zero regions** — all art lives in the children.
- Driving globals present: `WatchFrame_Update`, `WatchFrame_Collapse`, `WatchFrame_Expand`,
  `WatchFrame_ClearDisplay`, `WATCHFRAME_QUESTLINES`.
- Absent, so not routes: `ObjectiveTrackerFrame`, `ObjectiveTracker_Update`, `QuestWatchFrame`,
  `AutoQuestPopUpTracker`, `WatchFrame_GetRemainingSpace`, `AUTOQUEST_POPUP_ENABLED`,
  `AutoQuestPopUp_Show`. This client is the 5.x `WatchFrame`, not the later
  `ObjectiveTrackerFrame` — the modern names must not be reached for.
- **The turn-in pop-up mechanism is fully named:** `AddAutoQuestPopUp`, `GetAutoQuestPopUp`,
  `GetNumAutoQuestPopUps`, `RemoveAutoQuestPopUp`, and the display side
  `WatchFrameAutoQuest_DisplayAutoQuestPopUps`, `_SlideIn`, `_GetOrCreateFrame`, `_ClearPopUp`,
  `_ClearPopUpByLogIndex`, `_OnUpdate`.
- Sorting constants exist — `WATCHFRAME_SORT_TYPE`, `WATCHFRAME_SORT_MANUAL`,
  `WATCHFRAME_SORT_DIFFICULTY_HIGH/LOW` — alongside the confirmed CVar `trackQuestSorting`
  (currently `"top"`). That pair is where "no auto-sort by distance" will be settled.
- Also present and relevant to stripping: `WATCHFRAME_LINKBUTTONS`, `WATCHFRAME_NUM_ITEMS`,
  `WATCHFRAME_ITEM_WIDTH`, `WATCHFRAME_MAXQUESTS`, `WATCHFRAME_FILTER_TYPE`.

**What it does not answer:** the run was made with an empty tracker, so `WATCHFRAME_QUESTLINES`
was never described, no quest item button was seen, and no pop-up was live. The global list was
also cut at 60 of 150 names. v0.15 [G15] covers all of it — **and must be run with a quest
tracked**, or it will honestly report nothing.

### Probe output size

The report had reached 85KB, nearly all of it settled ground already written into this file.
v0.15 adds an `ACTIVE` switchboard: every section survives in full, but only the open questions
print. Flip a flag to bring one back when a new client build makes a settled answer worth
re-checking.

## Recon results — v0.15 probe

Run 2026-09-09 17:32, same client.

### G13c — the signature, settled

```lua
Settings.RegisterAddOnSetting(category, variable, variableKey,
                              variableTbl, variableType, name, default)
```

Scored **4/4** on readback: `GetName` → the name, `GetVariable` → the variable,
`GetVariableType` → `"boolean"`, `GetDefaultValue` → `true`. Every other shape scrambled at
least one slot — the six-argument form returned the *category*, and three shapes came back with
`VARd` regardless of what they were passed, which is a registry handing back an existing
setting rather than making a new one. **This is why "the call was accepted" was worthless as
evidence: nothing here rejects anything.**

Confirmed to accept a real setting object afterwards:

- `Settings.CreateCheckbox(category, setting, tooltip)`
- `Settings.CreateControlTextContainer()` → `container:Add(value, label)` → `container:GetData()`
- `Settings.CreateDropdown(category, setting, getOptions, tooltip)`

Also present, unprobed: `RegisterProxySetting`, `SetOnValueChangedCallback`,
`CreateSettingInitializer`, `CreateElementInitializer`, `RegisterInitializer`,
`RegisterCVarSetting`.

**Built in v0.10.0.** The panel is now a vertical layout of Blizzard's own controls, with the
hand-built canvas kept as an automatic fallback — if any step of `registerNative()` fails the
old panel takes over unchanged, so the worst case is what shipped before.

Two things did not survive the move and are tracked, not forgotten:

- The orange **"Experimental"** section header. A vertical layout has no header mechanism I have
  evidence for yet, so the warning moved into the tooltip. [G16] looks for one.
- The panel's own **Defaults** button. `/cq reset` still does the job. [G16] looks for the
  category-level defaults callback.

### G15 — the tracker from the inside

Run with 2 quests tracked.

- `WatchFrameLines` holds **10 children**: unnamed line frames, unnamed Buttons,
  `WatchFrameScenarioFrame`, `WatchFrameScenarioBonusHeader`, and `WatchFrameItem1`.
- `WATCHFRAME_QUESTLINES` → **4 entries** for 2 quests: a title line and an objective line each.
- `WATCHFRAME_LINKBUTTONS` → **2 entries, both with an `OnClick`** — one per quest title. These
  are click-to-track, and the handlers are named: `WatchFrameLinkButtonTemplate_OnClick`,
  `_OnLeftClick`, `_ShowContextMenu`, `_Highlight`. **This is the lever for "no click-to-track".**
- `WatchFrameItem1` is shown, parented to `WatchFrameLines`, with `WATCHFRAME_NUM_ITEMS = 1`.
  Its whole family exists: `WatchFrameItem_OnClick/_OnEnter/_OnShow/_OnUpdate`. **The lever for
  "no quest item buttons".**
- **"No auto-sort by distance" is a non-issue on this client.** `WATCHFRAME_SORT_TYPE = 0`,
  and the only constants that exist are `SORT_MANUAL = 0`, `SORT_DIFFICULTY_HIGH = 1`,
  `SORT_DIFFICULTY_LOW = 2`. There is no proximity sort to remove, and the current value is
  already manual. `trackQuestSorting = "top"` governs where a newly tracked quest is inserted,
  not distance. Nothing to build.
- Turn-in pop-ups: `GetNumAutoQuestPopUps()` → 0, so the data shape is still unknown.
  **Not probeable on demand** — it needs a pop-up actually on screen. Parked until one appears.

Also newly visible in the full 150-name global list: `WatchFrame_DisplayTrackedQuests`,
`WatchFrame_SetLine`, `WatchFrame_SetSorting`, `WatchFrame_SetFilter`, `WatchFrame_AbandonQuest`,
`WatchFrame_ShareQuest`, `WatchFrame_StopTrackingQuest`, `WatchFrame_OpenMapToQuest`,
`WatchFrameQuestPOI_OnClick`, `WatchFrame_AddObjectiveHandler` / `_RemoveObjectiveHandler`.

## Recon results — v0.16 probe

Run 2026-09-09 21:34. Every question [G16] asked came back answered, and the native panel is
finished on the strength of it.

### Apply

```
Settings.CommitFlag = { None=0, ClientRestart=1, GxRestart=2, UpdateWindow=4,
                        SaveBindings=8, Revertable=16, Apply=32,
                        IgnoreApply=64, KioskProtected=128 }
```

`SettingsPanel` carries `SetApplyButtonEnabled`, `HasUnappliedSettings`, `CommitSettings`,
`Commit` and a real `ApplyButton` (hidden and disabled at rest, which is why none was visible).
`Settings.IsCommitInProgress` exists, which is what lets the AddOn tell an Apply commit from an
ordinary click without inspecting Blizzard's internals.

**Built in v0.11.0.** Options that need a rebuild are registered with `Apply` and `Revertable`
via `AddCommitFlag` — one flag per call, so nothing has to guess whether `SetCommitFlags` wants
a list or a bitmask. Ticking one parks the value; Blizzard's Apply commits it; the changed
callback fires inside the commit and reloads there.

### Section headers

`CreateSettingsListSectionHeaderInitializer` is a **plain global**, not a `Settings` member —
which is why every earlier search for it under `Settings.` came up empty. It pairs with the
**second return value** of `RegisterVerticalLayoutCategory`, a layout object carrying
`AddInitializer`. v0.10.0 discarded that second value.

`Settings.SetCategoryDefaultsCallback` does **not** exist; the category object has no defaults
method either. Blizzard's own Defaults button drives the settings directly, which is exactly why
it misbehaved in v0.10.0 — see below.

### What this fixed

- **Defaults resetting one setting at a time** raised the reload dialog once per setting. With
  the dialog gone the button behaves.
- **No Apply button.** The dialog was intercepting the change before the commit machinery ever
  saw it. The flags put it back where it belongs.
- **The preset never reading "Disabled".** My bug, and a plain one: `displayPreset()` returned
  the stored `ns.db.preset` whenever it was set, and turning options off one at a time sets it
  to `"custom"` — so all-off could never read as Disabled again. The stored value is no longer
  consulted for display at all; the settings are the only thing that cannot go stale.
- **The dropdown reading "Full Classic experience" with every box unticked.** Registration
  leaves controls showing their registration-time value and nothing refreshed them.
  `registerNative()` now refreshes at the end, and hooks `SettingsPanel`'s `OnShow` so a change
  made from chat is on screen when the panel comes back.

### Tooltips

Colour escapes work in Blizzard's tooltips as in any font string, so the three-colour shape
survived the move to native controls: body in white, the experimental warning in orange, the
quiet aside in grey.

## v0.12.0 — native panel corrections

### The tooltip regression was mine, and avoidable

Moving to native controls I repainted tooltip bodies white. The canvas panel drew them with
`AddLine(text, 1, 0.82, 0)` — Blizzard's yellow — and used white only for the headings inside
the preset tooltip. **Nothing about native controls required that to change**; I changed a
setting nobody asked me to change while migrating something else, which is how a working thing
becomes a broken thing. Restored, along with the grey slash handle at the foot of each tooltip
that had gone missing in the same move. The suite now asserts option bodies are yellow *and*
that they are not white.

Tooltip shape, fixed:

- Heading — the setting's name, which Blizzard paints white itself.
- Body — yellow.
- Preset tooltip — a leading break, then `WHITE Heading:|r YELLOW body` on one row each, in the
  dropdown's own order (Full Classic experience, Custom, Disabled), and the slash commands in
  grey at the foot.

### Apply, corrected twice

- **A preset that moved a reload-needing option never lit Apply.** `applyPreset` wrote
  `ns.db.settings` directly, so Blizzard never learned anything had changed. It now writes
  *through* the control (`ns.SetNativeValue`), and a guard stops the per-setting callback
  marking the preset "custom" halfway through applying it.
- **Apply reloaded without asking.** It now raises one confirmation — once per Apply, not once
  per setting, since Blizzard commits them one at a time.

### The preset could not see a parked change

Ticking a box that needs Apply parks the value and fires **no** value-changed callback, so the
dropdown had nothing to tell it the settings had moved. Two halves to the fix:

- `ns.EffectiveSetting(key)` reads what a setting *will* be once applied. A setting waiting on
  Apply reports `IsModified()`, and these are all booleans that Blizzard only parks on a real
  change — so a modified boolean is by definition the opposite of the committed one. No guess
  about what `GetValue` returns for a pending setting is needed.
- `SettingsPanel:SetApplyButtonEnabled` is hooked. The Apply button changing state is the only
  signal a parked change gives, and hooking it is the only place that information exists.

### The version number

Native layouts have no header to put it in. It ships as a grey section heading at the **foot**
of the list. At the top it would sit above the preset dropdown, and a section header at the top
of a Blizzard list reads as a heading *for* what follows — so "v0.12.0" would look like the name
of the options beneath it. At the foot it reads as a footer, which is what it is.

### Still open

The Experimental heading renders orange but shows a tooltip on hover, which a heading has no use
for. Only the name is passed in, so it is being defaulted from that somewhere inside the
initializer. v0.12.0 clears the two fields it could plausibly be; probe v0.18 `[G17]` dumps the
initializer to say which is real, or name a third.

## v0.12.1 — the freeze

**v0.12.0 locked the client solid** the moment any options panel opened — Blizzard's own, not
just this AddOn's. Mine, and a plain bug.

`suppress` was a boolean. The Apply-button hook added in v0.12.0 re-enters `RefreshNative`, and
when the inner call finished it set `suppress = false` while the **outer** loop was still
writing values. Every remaining `SetValue` then fired its changed-callback, which refreshed
again, without bound.

Three fixes, because one guard clearly was not enough:

1. `suppress` is a **depth counter**. A count cannot be cleared by someone else's exit.
2. `RefreshNative` refuses to run inside itself, whatever route the re-entry takes, and restores
   both guards through a `pcall` so an error cannot leave the panel permanently deaf.
3. The Apply-button hook stands down while the AddOn is the one writing, and while a preset is
   being applied — mid-preset it would read the half-applied state as "Custom" and write that
   back over the preset the player had just chosen.

### A second bug the same investigation turned up

The preset callback read its value with `GetValue()`. Blizzard signals the Apply button as soon
as a value lands, which is **before** the changed-callback runs — so the hook refreshed and
overwrote the value first, and choosing "Disabled" re-applied "Full Classic experience". The
callback now takes the value from its own arguments, scanning the slots for a preset it knows
rather than betting on which position carries it.

### Why the suite did not catch it

**It could not.** The harness had no `SettingsPanel` at all, so the hook it recursed through was
never called — 345 checks passed on a build that froze the game. The harness now models
`SettingsPanel`, and calls `SetApplyButtonEnabled` on **every** `SetValue`, including no-op
writes, which is what the client does. Run against the v0.12.0 code, the new checks fail 7 times,
including two that catch the Apply-button storm (90 and 110 calls where a healthy build makes
fewer than 50).

Honest limit: the harness does not literally hang, it detects the runaway signalling underneath
the hang. The definitive test is still the client.

### G17 — the section header's tooltip

Answered, and my fix was aimed at the wrong thing. `CreateSettingsListSectionHeaderInitializer`
puts the name in `data.name` and leaves `data.tooltip` **nil** when only one argument is passed —
so there was nothing for v0.12.0's clearing to clear. The hover text comes from
`SettingsListSectionHeaderMixin`'s own `OnEnter`, which has `SetTooltipFunc`,
`InitDefaultTooltipScriptHandlers` and `SetCustomTooltipAnchoring` on it. Reachable in principle;
parked behind the freeze and the two new probes.

## Recon results — v0.19 probe

### G19 — Instant Quest Text, solved

The variable is **`instantQuestText`**, a boolean.

Worth recording *why* this took so long: every earlier attempt searched the **console**, and this
client cannot enumerate it (`C_Console.GetAllCommands` is absent). The option was reachable the
whole time from the other direction — the player can set it in Blizzard's own options, which
means Blizzard registered a setting for it, and a registered setting can be read. `[G19]` walked
`SettingsPanel.categoryLayouts`, pulled `GetSetting()` off each initializer, and printed name
against variable:

```
Instant Quest Text                variable=instantQuestText   [boolean]
Automatic Quest Tracking          variable=autoQuestWatch     [boolean]
```

The second line is a free confirmation that `autoQuestWatch`, in use since v0.2.0, is the same
variable Blizzard's own control drives.

**Lesson worth keeping:** when the player can already do a thing in Blizzard's options, the
answer is in the settings registry, not the console. Ask the UI what it is driving.

Shipped as `questTextTypesOut`, driving `instantQuestText` to 0 — Classic-correct is *off*, so
quest text types out a line at a time.

### G18 — the bag quest highlight

**No console variable exists.** All six plausible names came back absent. But every bag slot
carries `ContainerFrame<N>Item<M>IconQuestTexture` — 468 of them on this client — and hiding it
takes the highlight with it. Shipped as `bagQuestHighlight` in `Bags.lua`, off a
`ContainerFrame_Update` post-hook since bags redraw constantly.

One coupling, stated in the option's tooltip: that single texture draws both the yellow border on
a quest item and the `!` on an item that *starts* a quest. Blizzard swaps the texture on one
object rather than using two, so they cannot be separated. Both go, which is the Classic result.

`IconBorder` is a different thing — the item-quality border — and is left alone.

## v0.13.0 — Apply, corrected again

**Apply never asks.** v0.12.1 raised a confirmation on commit. That was wrong twice over:
pressing Apply *is* the confirmation, and Blizzard already asks its own question on **Cancel** —
so one decision was drawing two dialogs. The confirmation is gone; committing rebuilds directly.

**Defaults now leaves something to press.** Blizzard's Defaults writes values straight through
without parking them, so the Apply button never lit and a reload-needing option could be reset
with the panel looking finished. Three pieces, all built from methods `[G16]` confirmed:

1. A `needsApply` change arriving outside a commit sets `rebuildPending` and lights Apply via
   `SettingsPanel:SetApplyButtonEnabled`.
2. The button is re-armed whenever Blizzard darks it while a rebuild is held — Defaults writes
   several settings in a row and each write re-evaluates the button, so arming once is not
   enough.
3. `SettingsPanel:CommitSettings` is hooked, because pressing Apply after a Defaults reset
   commits nothing of ours — the values were already written — so the changed-callback never runs
   and the rebuild would otherwise be lost.

This is a workaround, and is written up as one. `[G20]` asks whether it is necessary.

## Driving Blizzard's options: registry or CVar?

Asked directly, and worth writing down because the question contains a false premise I created.

**Instant Quest Text was never switched to the Settings API.** It is a `CVars.lua` rule like every
other, driving `instantQuestText` through `SetCVar`. What `[G19]` supplied was the **name**.

So the two are not alternatives:

- **The settings registry is a discovery tool.** It answers "what variable is Blizzard's own
  control driving?" — which is exactly the question that had `showQuestTrackingTooltips` and four
  other invented CVar names wasted on it. When the player can already do a thing in Blizzard's
  options, the answer is in the registry, not the console.
- **The CVar is the driving layer.** It is what persists across sessions, what `CVAR_UPDATE` lets
  the AddOn notice a change on, and what works whether or not the options panel has ever been
  built. Writing through a Blizzard setting object instead would add a dependency on Blizzard's
  panel being loaded, for no gain.

**Keep both, for what each is good at.** Discovery through the registry; driving through the CVar.

### Who wins a conflict

The reported desync — Blizzard's checkbox saying one thing, this panel another — was a missing
rule, not a wrong mechanism. There are now two, chosen by whether Blizzard shows a control:

| | Blizzard control | Behaviour on an outside change |
| --- | --- | --- |
| `questPOI`, `showBosses` | none | **Re-assert.** Nothing in the interface claims to own these, so something moved it behind the player's back and putting it back is the job. |
| `instantQuestText`, `autoQuestWatch`, `Outline` | yes | **Mirror, both ways.** The player used their own interface. The option follows the variable — off when it moves away, back on when it returns — and says so in chat. |

Safety rule 4 — do not fight the player's UI — decides it. Re-asserting against a control the
player can see produces exactly the standoff that was reported: two checkboxes disagreeing, and
neither giving.

## v0.14.0 — the Close → Exit bug

Two faults, one flag. `rebuildPending` was set whenever a `needsApply` option's callback ran, and
was never cleared when the panel closed.

- **Defaults lit Apply even when nothing reload-worthy moved**, because every setting Defaults
  touched looked like news whether or not its value changed.
- **Closing with Exit left the flag set.** Apply was still lit on the next open, and the next
  Close rebuilt the UI with no warning — acting on a decision the player had already walked away
  from.

Fixed with a **baseline**: the reload-needing options are recorded as the panel opens, and a
rebuild is pending only while something differs from that. Toggling one away and back leaves
nothing lit. `OnHide` clears the flag and the baseline, so a visit the player abandoned cannot
reach into the next one.

### G20 — why the workaround is needed

Confirmed: `SetValueToDefault` **writes straight through**. The test setting carried
`CommitFlag.Apply`, a normal `SetValue` parked correctly (`IsModified` true), and
`SetValueToDefault` moved the backing value with `IsModified` still **false**. Defaults ignores
the Apply flag. `SettingsPanel:Cancel` and `:Revert` do not exist; `Commit` and `CommitSettings`
do.

So lighting the button by hand and catching `CommitSettings` is not a guess to be tidied away
later — it is the only route this client offers.

## v0.14.1 — one direction is not a sync

Three separate symptoms, one cause. v0.14.0's rule only fired when *our option was on and the
variable had moved away*, so:

- **Outline Mode never responded at all.** That option ships **off**, so the branch was
  unreachable from the start.
- **Automatic Quest Tracking yielded once, then went dead.** After yielding, the option was off —
  and the branch was unreachable again.
- **Putting a Blizzard control back to the Classic value never turned the option back on**, for
  the same reason.

Now the option simply **mirrors** the variable in both directions, and says which way it went.
Guarded by tests that run three full round trips, plus one on an option that ships off, since a
single yield is exactly what used to deafen it.

### G21 — annotations confirmed

All three tooltips are **strings**, all three carry the note. The function case that v0.14.0
carefully avoided does not arise on this client — the caution cost nothing and the answer is now
on record. `data.options` is a function for Outline Mode and a table for the other two, which is
the control's own list, not its tooltip.

The slash handle is gone from these; on someone else's tooltip it read as clutter. Name only.

### Defaults — two workarounds for a problem that was never there

Blizzard's Defaults button **reloads the UI by itself** when a setting it reset needs one. Tested
in game, and it settles the whole thread.

I built two workarounds on top of a guess about what that button does, without ever asking for it
to be tested:

1. **v0.13.0** lit the Apply button by hand and hooked `CommitSettings`, so a Defaults reset would
   leave something to press.
2. **v0.14.2** raised an AddOn dialog on close, because Blizzard's own Close confirmation could
   never fire on a button the AddOn had lit.

Both are gone. A `needsApply` change arriving outside a commit is Defaults writing straight
through — `[G20]` confirmed `SetValueToDefault` ignores the Apply flag — and the player has
already decided, in Blizzard's own dialog. So it rebuilds immediately. Roughly sixty lines
removed, `rebuildPending` and `armApplyButton` with them.

**The lesson, and it is the same one as `instantQuestText`:** the answer was in the client, not in
reasoning about the client. One in-game test of a button neither of us had pressed would have
saved two releases. Where a Blizzard control's behaviour matters, test it before designing around
it.

**What remains:** `rebuildBaseline`, so a reset that moves nothing does not reload for nothing,
cleared on rebuild so one visit cannot ask twice.

### Presets and experimental options

Checking the experimental wording turned up a real inconsistency: the panel's **Full Classic
experience** preset set experimental options to `false`, while `/cq on` left them where they were.
Same preset, two behaviours depending on whether it was clicked or typed.

v0.14.3 aligned them by making `/cq on` turn the experiments off. **That was the wrong side to
align to**, and v0.15.0 reverses it. A preset that undoes a deliberate choice is worse than one
that ignores it: switch an experiment on, pick Full Classic, and it went off again with no
explanation.

The rule now:

| | Normal options | Experimental options |
| --- | --- | --- |
| **Full Classic experience** | all on | **left exactly as the player set them** |
| **Disabled** | all off | all off — Disabled means nothing is on |
| **Derived display** | all normal on ⇒ Full Classic | ignored entirely |

So switching an experiment on no longer drops the preset to Custom. The experiments are not part
of the Classic experience, so having one on does not stop the rest of the settings being it. Both
the panel and `/cq on|off` follow this.

### A rule can have more than one "on" value

`Outline` is not a boolean. It has four settings on this client, and **1, 2 and 3 all mean
outlines are on** — they differ in what they apply to. Only 0 is off.

Rules may now declare `onValues`, and two things follow from it: the option reads as ticked for
any of them, and `Enable()` no longer writes `wanted` over a value that already counts as on. A
player who chose Outline 3 keeps Outline 3; the AddOn only asks for 1 when starting from 0.

## v0.15.1 — audit

A full sweep of the repository. What changed, and why.

### Dead code removed

- **`ns.db.preset` and `ns.MarkCustomPreset`.** The preset was stored *and* derived. The stored
  copy went unread from v0.11.0, when `displayPreset()` became purely derived — five writes, zero
  reads, across three files. Removed, with a `dbVersion` 3 migration that clears the orphaned key
  from existing saved variables.
- **`nonExperimental()`** in `Options.lua` — defined, never called.
- **`M.rule = rule`** in `CVars.lua` — assigned, never read.

### Drift fixed

- The **canvas fallback's experimental tooltip** still carried the v0.12 wording after the native
  panel moved on. One string, two places, and only one was being updated — the kind of thing an
  audit exists to catch.
- **"Options panel — built"** in this file still described the canvas panel as what ships. It has
  been the fallback since v0.10.0. Rewritten.
- **"Still to verify"** tracked the dropdown hunt that finished in v0.11.0. Collapsed to the
  method that came out of it, which is still worth having.
- The **versioning rule** defined 1.0 as "after the Tier 3 options GUI ships", and tiers were
  dropped in v0.12.1. Reworded against the work list.
- **`README.md`** did not list the tracker or experimental options and still described the old
  preset behaviour.

### The finding that mattered

**The test suite was not in the repository.** 412 checks lived only in an ephemeral scratchpad
directory — one container restart from gone, and invisible to anyone reading the project. Moved
to `dev/tests/` with a `run.sh`, and the harness's hardcoded absolute path made repo-relative.

### Added

- **~~`BUGS.md`~~** — open faults, with enough detail to pick one up cold. **Removed in v0.16.1**:
  bugs belong in GitHub Issues, where they have a state and a conversation. Its one entry is now
  [issue #1](https://github.com/wickoc/classic-questing/issues/1).
- **`STRINGS.md`** — every player-visible string, labelled, with the colour palette.
- **`NAMING.md`** — the name decision, with everything a rename touches.
- **`dev/README.md`** — what the probe is, why the old logs are kept, how to run the tests.

### Kept deliberately

- **The eleven old recon logs** (616 KB). Every conclusion in this file is evidence from one of
  them, and later probe runs switch settled sections off — so an earlier log is often the only
  remaining record of an answer. Indexed in `dev/README.md` rather than pruned.
- **The canvas fallback panel**, and each module's `group` field, which only it consumes. It is
  the reason a client that refuses the Settings API still gets a working panel.
- **`local ADDON_NAME, ns = ...`** in files that never use the first value. It is the standard
  idiom and the name documents what the slot holds.

## v0.16.0 — two features, and a trap sprung for the third time

### The questgiver portrait

MoP frames a character box beside quest text, in the offer window and again in the quest log.
Shipped as `questGiverPortrait`.

**This is the first feature in this project built on names that have not been probed on this
client**, which is a departure worth flagging rather than hiding. Three candidate frame names and
two candidate show-functions are tried, the first that exists is used, and `Status()` reports what
was actually found — so a wrong guess disables the option loudly instead of erroring. `[G22]`
settles it in the same build.

### Quest progress in tooltips — built at last

Not lost: **never built.** The matching rule was settled in G12 and then sat in the backlog while
the options panel took over. It is built now, and the rule is exactly the one the six captured
tooltips produced:

1. Never touch line 1; it is always the name.
2. From line 2 on, a gold `1.00, 0.82, 0.00` line **whose text matches an active quest in the
   log** is the quest header.
3. Lines under it matching `^%s*%-%s.+:%s*%d+/%d+%s*$` are its objectives.

The quest-log match is what stops a gathering node called *Silverleaf* — gold, on line 1 — being
eaten, and the tests carry all three captured samples plus a zone header, which is gold and in
the quest log but is not a quest.

`[G22]` also asks whether Blizzard registers a **setting** for this, the way it turned out to for
`instantQuestText`. Blanking tooltip lines works but is surgery; a switch would be better.

### One palette

Every colour now comes from `ns.color` in `Core.lua`, and nothing else in the AddOn writes a
colour code. Two changes of substance:

- **One orange.** There were two near-identical ones; `ff8019` survives and `ff8800` is gone.
- **The yellows and whites are the game's own.** `NORMAL_FONT_COLOR_CODE`,
  `HIGHLIGHT_FONT_COLOR_CODE` and `GRAY_FONT_COLOR_CODE` are read from the client rather than
  typed in. `|cffffd100` was the right yellow all along — it is now sourced rather than assumed,
  so it cannot drift from what Blizzard's own tooltips use.

### The forward-reference trap, third time

Declaring the palette next to the code that uses it most put it **halfway down** `Options.lua` —
after the canvas panel that also needs it. Lua 5.1 resolves a local declared later in the file as
a nil global, silently, so the canvas panel's tooltips concatenated nil and failed inside a
`pcall`. Invisible in game; caught by the suite.

**Standing rule, since this keeps happening: file-level locals go at the top of the file, not
beside their heaviest user.** Previous victims were `notice()` in `Minimap.lua` and
`refreshMapNow`/`hookWorldMap` in `Options.lua`.

### And a harness fault worth recording

The test harness guarded against the v0.12.0 freeze with a **running total** of
`SetApplyButtonEnabled` calls. Once there were enough modules, ordinary use crossed the limit and
the harness reported a recursion that was not happening. It counts **depth** now, which is what
the real fault looked like. A guard that measures the wrong quantity eventually lies.

## v0.16.1 — the tooltip hook was at the wrong moment

`questProgressTooltips` shipped in v0.16.0 and **removed nothing at all in play**, while passing
its tests. Both halves of that are worth recording.

**The fault.** It hooked `GameTooltip`'s `OnShow`. That fires when the tooltip becomes *visible*,
which is **before its lines have been filled in** — so `NumLines()` was zero or still showing the
previous tooltip, the scrub found nothing, and left. Worse, moving the mouse from one creature
straight to the next never fires `OnShow` again at all, because the tooltip never hides.

It now hooks the content-set scripts, where the lines exist by definition:
`OnTooltipSetUnit`, `OnTooltipSetItem`, `OnTooltipSetDefaultAnchor`, and `Show` via
`hooksecurefunc` as a catch-all for any route those miss. A script name this client lacks makes
`HookScript` throw, which the `pcall` absorbs, so listing one that turns out not to exist costs
nothing.

**Why the suite missed it.** The harness fired `OnShow` *with the lines already in place*. That
is not what the client does, and a harness that models a convenient order rather than the real
one will confirm anything. `__showTooltip` now empties the tooltip, fires `OnShow`, then puts the
lines in and fires the content-set script — and there is a `__retargetTooltip` for the
creature-to-creature case that fires no `OnShow` at all. Against v0.16.0 the new checks fail five
times.

**The pattern, since this is the second one:** the freeze got through because the harness had no
`SettingsPanel`; this got through because the harness had the wrong *order*. Both are the same
mistake — modelling what is easy to model rather than what the client does.

### G22 — the portrait frame, and a switch that does not exist

- **The frame is `QuestModelScene`**, a ModelScene parented to `QuestLogDetailFrame`.
  `QuestNPCModel` does **not** exist here as a frame — only as a prefix on its own regions
  (`QuestNPCModelBg`, `QuestNPCModelNameText`, and 25 more), which is exactly the near-miss that
  makes guessing a name unreliable. `QuestFrame_ShowQuestPortrait` and `_HideQuestPortrait` are
  both present. The candidate list is reordered with the confirmed name first.
- **There is no registered setting for quest progress in tooltips.** The whole registry offers
  only `showNewbieTips` and `PROXY_TARGET_TOOLTIP` on the tooltip side. So blanking the lines is
  not a stopgap for a switch that exists — it is the only route, and the question is closed.
- **Every colour code the palette prefers exists**: `NORMAL_FONT_COLOR_CODE` is `|cffffd100`,
  confirming the yellow that had been assumed. The literals in `Core.lua` are dead fallbacks and
  can stay dead.

### "No objective arrows" — a claim I should not have made

It was in the draft CurseForge summary. **There is no objective arrow in this client**, and
Blizzard's quest helper has never drawn one; on-screen arrows are Carbonite and TomTom, which are
third-party. It sounded like part of a quest helper, which is why it went in unchallenged.
Removed. Nothing in a public listing should describe something the AddOn does not do.

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

**Questgiver `!` blips — research changed the answer. It may be shippable after all.**

Two things were wrong in the previous assessment, both because the restore path was unknown:

1. **There is a documented default sheet: `Interface\MINIMAP\ObjectIconsAtlas`.** A
   Mists-targeted addon (KeyboardsMinimapIcons) restores exactly that path on `PLAYER_LOGOUT`,
   with no reload. If that works here, "cannot be undone in session" is simply false, and the
   feature becomes a normal live toggle. `/unrecon blipreset` now restores it.
2. **Selective suppression is possible.** The sheet can be replaced with a copy that blanks
   only the questgiver cells, leaving herbs, vendors and trainers intact — which removes the
   collateral that made this a bad trade. Several established addons ship blip sheets this way
   (Chinchilla, KeyboardsMinimapIcons, DragonUI, including a DragonUI fork targeting MoP).

Two caveats stand:

- **The documented 8x2 / 256x64 `ObjectIcons` layout is the OLD sheet, not this one.**
  `GetPOITextureCoords` on this client steps 0.0703125 across and 0.03515625 down, so the atlas
  is far larger. Replacement art must match the real grid. the v0.9 cell grid stretched each cell into a
  square and made the icons unreadable. v1.0 instead draws the **whole sheet** and labels every
  index in place on top of it. **This whole line of enquiry is now closed as misdirected** —
  see `dev/BLIP-TEXTURE-WORKFLOW.md`. Knowing an index was never going to answer the real
  question, because nothing exposes which index the engine picks for a questgiver blip; and the
  person editing the sheet can see the cells anyway. What remains useful from the probe is the
  arithmetic: UV coords convert to exact pixel rectangles once the file's dimensions are known.
  For the record on the viewer itself: at 256x256 and 512x512 the sheet
  renders correctly, but the boxes do **not** line up with the art, so `GetPOITextureCoords` and
  `ObjectIconsAtlas` disagree about the grid. `/unrecon cell <index>` now renders a single index
  large at three aspects, which settles what one index actually points at without needing the
  whole-sheet mapping to be right.
- **A modified sheet means shipping altered Blizzard art.** That is what the existing addons do,
  but it is a judgement call for the author, and it is the first thing this addon would ship
  that is not purely subtractive.

**On breaking the safety rules.** Still not the blocker, and still buys nothing. These blips are
not drawn by Lua: `Minimap` has zero regions and zero unnamed children, zero globals contain
"blip", and nothing in the 205-method dump renders one. There is no call site to hook or
overwrite. The one thing research turned up that *does* overwrite `Minimap.SetBlipTexture` (the
DragonUI fork) does so only to stop other addons fighting over the sheet, not to gain access.

**`Minimap:SetToDefaults()` must never be called.** It removed the entire minimap frame in game.

### Tier 3 candidates — live results

**Quest object glimmer — resolved as a client fault, not an addon problem.**

The `Outline` CVar exists here and **writes correctly**: 0, 1, 2 and 3 all take. Nothing renders
at any value — and crucially, **Blizzard's own options window changes nothing either**. So this
is a client-side rendering fault, not a dead CVar and not something an addon can reach.
`graphicsOutlineMode` is absent, as expected: it was added in Patch 7.0.3, long after 5.4.

Because outline and sparkle are alternatives, an outline that never renders means the sparkle is
always shown. That accounts for the whole observation: glimmer always present, outline never
seen, on this client.

Tested and rejected as fixes:

| Lever | Result |
|---|---|
| `particleDensity 0` | Removes the glimmer — and the particles on lootable bodies too. Classic had those. Not a fix. |
| `ffxGlow 0` | Visible change elsewhere; does not touch the particle glow at all. Not a fix. |
| `Outline` re-set every ~100ms | Restarts the animation rather than stopping it; on larger objectives it freezes mid-glimmer. Rejected by the author. |

**Target behaviour, for the record:** sparkles off for quest objectives and herb/mining nodes,
**kept** on lootable bodies. Nothing found so far separates those three, and the one CVar that
would cannot render here.

**Shipped anyway as `questObjectOutline`, experimental, default off.** Turning `Outline` *on* is
a semi-fix for anyone whose client can render outlines (1 is enough; 2 and 3 also work). It is
the one rule in `CVars.lua` that turns something **on** rather than off. It is never enabled by
default and is deliberately skipped by a bare `/cq on`, which enables the Classic set but leaves
experiments alone — those must be named explicitly. `/cq` marks it `(experimental)`.

**Quest progress tooltip: reachable, and the matching rule is now settled.** Six captured
tooltips, with per-line colours:

```
 1  [0.90,0.70,0.00]  Stonetusk Boar          <- unit name, colour varies by reaction
 2  [1.00,1.00,1.00]  Level 6 Beast
 3  [1.00,0.82,0.00]  Pie for Billy           <- quest title
 4  [1.00,1.00,1.00]   - Tender Boar Meat: 0/4  <- objective

 1  [1.00,0.82,0.00]  Silverleaf              <- OBJECT name, same gold as a quest title
 2  [1.00,1.00,0.00]  Herbalism

 1  [0.90,0.70,0.00]  Stonetusk Boar
 2  [1.00,1.00,1.00]  Level 5 Corpse
 3  [1.00,1.00,0.00]  Skinnable
 4  [1.00,0.82,0.00]  Pie for Billy           <- same quest, now line 4, not 3
 5  [1.00,1.00,1.00]   - Tender Boar Meat: 0/4
```

Neither colour nor line number is sufficient on its own — gold `1.00,0.82,0.00` is also a
gathering node's *name*, and the quest title moved from line 3 to line 4 between two tooltips
on the same mob. The rule that survives all six samples:

1. Never touch line 1; it is always the name.
2. From line 2 on, a line coloured `1.00, 0.82, 0.00` **whose text equals an active quest title**
   (read from the quest log) is the quest header.
3. Lines immediately after it matching `^%s*%-%s.+:%s*%d+/%d+%s*$` are its objectives.

Blank those in place. Requiring the quest-log match is what stops "Silverleaf" being eaten. Observed live: the quest name is
its own line, followed by one line per objective (`" - Riverpaw Gnoll Clue: 0/1"`). The line
number **varies**, so a matcher must key off text and colour, never a fixed index. `/unrecon
tipwatch` + `tipdump` now capture a real tooltip with per-line colours so the matcher can be
written against real data instead of assumptions.

### Earlier research notes

**Quest object outline and sparkles.** Research names a CVar `Outline` behind the option in
Blizzard's menu (the No Questgiver Sparkles addon sets it to 0 and re-asserts it), and
`graphicsOutlineMode` (0 disabled / 1 good / 2 high) for outline density. A recurring report is
that disabling the outline *replaces* it with sparkles, so both may need handling together.
Neither name has ever been probed here — v0.9 does, and `/unrecon trycvar Outline 0` tests the
effect. Note the reference addon re-asserts on every frame via `OnUpdate`; if that proves
necessary, this addon would re-assert on events instead, never per frame.

**Quest progress tooltip on mouseover.** The documented CVar `showQuestTrackingTooltips` is
**absent on this client** — already probed, negative. So the CVar route does not exist here and
the fallback is to strip the quest lines from `GameTooltip`, which unlike the blips *is*
Lua-reachable: the tooltip's line font strings are individually named (`GameTooltipTextLeft<N>`)
and can be blanked in place from a script hook. v0.9 confirms which of those exist.

### Addon-list version alignment — parked

`0.3` sits on the border rather than outside, so the version format did affect it. But the
recon addon's `0.8` has always been slightly misaligned too, which points at the AddonList's own
layout rather than anything this addon controls. No addon-side fix turned up in research. Parked
as cosmetic unless a screenshot shows something actionable.

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
