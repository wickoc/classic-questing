# Blizzard's own UI source, for this exact build

**`git clone --depth 1 --branch classic --filter=blob:none https://github.com/Gethe/wow-ui-source.git`**

On 2026-09-12 that branch's `version.txt` read:

```
5.5.4.69585
```

That is the build this AddOn is developed against, to the revision. The repository is a git mirror
of the interface code Blizzard ships inside the game: 1,897 Lua files and 774 XML files, about
35 MB checked out, seconds to fetch. `dev/knowledge/fetch_client_source.sh` does the clone and
rebuilds the index.

## Why this matters more than it sounds

Until now the only way to learn what this client does was to put a probe in front of the player and
read the log back. That is slow — one round trip per question — and it is why this project has the
rule about never guessing API names from training data.

Blizzard's source does not replace a probe. It answers a different question:

| Question | Answered by |
| --- | --- |
| Does this function exist, and what does it return? | the source, exactly |
| Which file does this flavour actually load? | the source, exactly |
| What does Blizzard's own code do when this CVar changes? | the source, exactly |
| Does the write succeed in play, and does it look right? | only the game |
| Is this call protected, or does it taint? | only the game |

So: read the source first, and probe what the source cannot say. What must not happen is a third
thing — asserting behaviour from memory when the source is one clone away.

### The calibration that keeps this honest

A CVar the Lua never reads does not appear in the Lua. Counted across the whole drop:

| CVar | mentions in Lua | exists on the client? |
| --- | --- | --- |
| `questHelper` | 11 | yes |
| `autoQuestWatch` | 10 | yes |
| `instantQuestText` | 6 | yes |
| `Outline` | 3 | yes |
| `showBosses` | 2 | yes |
| `particleDensity` | **0** | **yes — this project has set it in game** |
| `ffxGlow` | **0** | **yes — this project has tested it in game** |

`particleDensity` and `ffxGlow` are consumed by the engine, not by the interface, so they are
invisible here. **Absence from the Lua source is not evidence of absence from the client.**
Presence is proof; absence is a reason to probe.

For the complete list of what the client actually has, the client can be asked directly:
`ConsoleGetAllCommands` / `C_Console.GetAllCommands` (see `REFERENCE-ADDONS.md`).

## Which file does 5.5.x really load

Blizzard ships one `.toc` per Blizzard AddOn with per-flavour directories beside it, and gates the
files with `AllowLoadGameType`:

```
Interface/AddOns/Blizzard_UIPanels_Game/Blizzard_UIPanels_Game_Classic.toc:56
    Wrath\WatchFrame.lua    [AllowLoadGameType wrath, cata, mists]
Interface/AddOns/Blizzard_UIPanels_Game/Blizzard_UIPanels_Game_Classic.toc:89
    Wrath\QuestMapFrame.lua [AllowLoadGameType wrath, cata, mists]
```

There are `Vanilla/`, `TBC/`, `Wrath/`, `Cata/`, `Mists/`, `Classic/` and `Shared/` directories in
that AddOn, and **a `Mists/` directory is not the same thing as the file Mists loads.** The tracker
and the quest map on 5.5.x come out of `Wrath/`; `Mists/` holds seven unrelated files. Reading the
wrong one is the easiest possible mistake here, so check the `.toc` before citing a path:

```sh
grep -rn 'AllowLoadGameType' <dest>/Interface/AddOns/<addon>/*.toc
```

`AllowLoadGameType` is also the answer to a question this project has open on its own account —
see the notes in issue #5 and issue #21 about shipping one `.toc` for several clients.

## What reading it settled, on the first pass

### The tracker knows which lines are quests — SPEC limitation #1 is wrong

`Wrath/WatchFrame.lua` gives every pooled link button a `type`:

```
887:   linkButton.type = "ACHIEVEMENT";
1090:  linkButton.type = "QUEST"
```

and Blizzard's own code branches on it at lines 92, 137, 155, 161, 175 and 191, releasing it at 81:

```lua
-- WatchFrame_ReleaseUnusedLinkButtons
watchButton.type = nil
watchButton.index = nil;
```

SPEC said the tracker "draws quest and achievement titles from one pool of buttons and does not
mark which is which". It marks which is which. The limitation stands as written for v1.0.0 — the
shipped code really does disable both — but it is a defect, not a law. Raised as an issue.

Two things to get right when fixing it: the buttons come from `WatchFrame.buttonPool`, so `type` is
only meaningful *after* the redraw that set it, and a button keyed in a remembered table can come
back next redraw as the other kind.

### `questHelper` is a second CVar, and nothing in the interface owns it

Every gate in Blizzard's code is `questPOI` **and** `questHelper`:

```
Blizzard_SharedMapDataProviders/QuestDataProvider.lua:72
    if not GetCVarBool("questPOI") or not GetCVarBool("questHelper") then
Blizzard_SharedMapDataProviders/QuestBlobDataProvider.lua:131
    if not self.mapAllowsBlobs or not GetCVarBool("questPOI") or not GetCVarBool("questHelper") then
Blizzard_WorldMap/Wrath/QuestLogOwnerMixin.lua:167
    return GetCVarBool("questPOI") and GetCVarBool("questHelper");
Blizzard_UIPanels_Game/Wrath/QuestLogFrame.lua:175
    ... and GetCVarBool("questPOI") and GetCVarBool("questHelper")
```

`questHelper` appears in eight interface files and **in none of the settings definitions** — there
is no Blizzard control for it, which puts it in the same class as `questPOI` and `showBosses`: a
variable this AddOn may own outright rather than mirror.

It is also strictly wider than `questPOI`. With `questHelper` off, Blizzard's own code hides
`WorldMapQuestShowObjectives` — the Track Quest checkbox this AddOn currently hides itself — and
sets `WatchFrame.showObjectives = false`.

Not a recommendation to switch to it: it is a lever nobody has pulled in play, and a wider lever
can break more. It is a lever that was not known to exist.

### Blizzard already refreshes the quest UI when `questPOI` changes

`Wrath/QuestMapFrame.lua:253`:

```lua
elseif ( event == "CVAR_UPDATE" ) then
    if ( arg1 == "questPOI" ) then
        WatchFrame_Update();
        QuestLog_UpdateMapButton();
        QuestMapFrame:GetParent():HandleUserActionToggleQuestLog();
        QuestMapFrame_CloseQuestDetails();
        QuestMapFrame_UpdateAll();
```

This bears directly on two open issues and it is evidence, not a verdict:

- The AddOn's own `cycleWorldMap()` — hide, show, hide — may be re-implementing
  `HandleUserActionToggleQuestLog()`, which Blizzard calls here for free.
- `HandleUserActionToggleQuestLog` is a UI-panel-manager call, and it is reached **from Blizzard's
  handler, on our CVar write**. If that is the taint path, it is reached whether or not the AddOn
  cycles the map itself, which would change what issue #17 is about.
- `QuestMapFrame` lives in a load-on-demand AddOn. Before the map has ever been opened this handler
  does not exist to run, which is the shape of the symptom in issue #11.

All three want a probe. None of them should be written into SPEC until one happens.

### `ShowQuestUnitCircles` exists here

The yellow ring under a quest mob — reported to us as a retail-only lever — is on this client:

```
Blizzard_SettingsDefinitions_Frame/Nameplates.lua:373  SetCVar("ShowQuestUnitCircles", "0");
Blizzard_SettingsDefinitions_Frame/Nameplates.lua:379  SetCVar("ShowQuestUnitCircles", "1");
```

Blizzard drives it from the **nameplate** settings, which means an option here would be mirroring a
Blizzard control, not owning a variable — safety rule 4 territory.

### There is no `showQuestTrackingTooltips` in the interface code

Zero mentions. Retail had this CVar and removed it in Shadowlands; if it survives in the 5.5.4
engine it is invisible from Lua, exactly like `particleDensity`. Worth one line in a probe, because
if it does exist it replaces the whole tooltip-scrubbing module with a CVar write. Until that probe,
the hand-written scrub is the only route we know works.

## The generated API documentation

`Interface/AddOns/Blizzard_APIDocumentationGenerated/` — 533 Lua files, generated from the build.
Each declares a system's namespace, functions, argument and return types, events and structures.
This is the authoritative reference for what this client exposes, and it ships inside the client.

Two files in this directory are committed here so the questions stay answerable with no network:

- **[`api-index.txt`](api-index.txt)** — every system, every function and event name. 533 systems,
  4,590 functions, 1,483 events.
- **[`api-signatures.txt`](api-signatures.txt)** — full argument and return signatures plus
  structures, for the systems this AddOn touches. Everything else is noise this project will never
  read; the allowlist is `SYSTEMS` at the top of `build_api_index.lua`.

Both are generated by `build_api_index.lua`, which **loads** the documentation files under Lua 5.1
with a stand-in for `APIDocumentation` and reads the tables the client would have read. It does not
pattern-match Lua, because a regex over Lua is a guess.

### What that already answered

```
C_CVar.SetCVar(name:cstring, value:cstring?, scriptCVar:cstring?) -> success:bool
C_CVar.GetCVarInfo(name:cstring) -> value, defaultValue, isStoredServerAccount,
                                    isStoredServerCharacter, isLockedFromUser,
                                    isSecure, isReadOnly
C_CVar.GetCVarDefault(name:cstring) -> defaultValue:string?
```

- **`SetCVar` returns a success boolean.** `CVars.lua` wraps it in `pcall` and infers refusal from
  not-taking-effect. There is a documented return value to read instead.
- **`isLockedFromUser`, `isSecure`, `isReadOnly`** mean a refusal is knowable *before* the write —
  which is what issue #18 needs, since latching `refused` forever is what blocks the restore.
- **`GetCVarDefault`** gives Blizzard's default without hard-coding it, which issue #27 argues about.

```
C_Minimap.GetTrackingInfo(spellIndex:luaIndex) -> trackingInfo:MinimapScriptTrackingInfo?
structure MinimapScriptTrackingInfo { name:cstring, texture:fileID, active:bool,
                                      type:cstring, subType:number, spellID:number? }
event MINIMAP_UPDATE_TRACKING()
```

- The entry carries a **`type`** as well as a `name`. `Minimap.lua` resolves by matching the
  localised `MINIMAP_TRACKING_QUEST_POIS` string; if `type` is a stable token it is a better key.
  What `type` contains is not in the documentation — that is a probe.
- **`MINIMAP_UPDATE_TRACKING`** fires when tracking changes. The minimap module currently re-asserts
  on its own schedule.

None of the above is a decision. All of it is a lever that was previously unknown.
