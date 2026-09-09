# In-game text

Every string a player can see, labelled for editing. Send this back with your rewrites and I will
put each one where it belongs.

**How to read a row.** `Text` is what appears on screen. Anything in `<angle brackets>` is a
variable filled in at runtime — leave the brackets in place and I will wire them up.

**Colours** use WoW's escape format: `|cffRRGGBB` opens a colour, `|r` closes it. `|n` is a line
break inside a tooltip; `\n` is one in chat and in dialogs. The palette is at the bottom — change
a colour there to change it everywhere it is used, or override it on a single row.

---

## 1. Identity

| ID | Where | Text | Notes |
| --- | --- | --- | --- |
| `ID.NAME` | Everywhere in game: chat prefix, options category, tooltips | `Classic Questing` | One variable, `ns.title`. Changing it here changes every use. |
| `ID.NOTES` | The AddOn list, under the name | `Hides MoP's quest markers. Read the text, explore.` | From the `.toc`. Kept short: long values were suspected in the tooltip layout bug. |
| `ID.AUTHOR` | The AddOn list | `Wictor` | From the `.toc`. |

---

## 2. Chat

Every line is prefixed automatically. Do not repeat the name inside a message.

| ID | Trigger | Text |
| --- | --- | --- |
| `CHAT.PREFIX` | Every chat line | `[Classic Questing] ` in `COLOR.BRAND`, trailing space |
| `CHAT.ON_ALL` | `/cq on` | `The Full Classic Experience has been enabled. Experimental features must be activated manually.` |
| `CHAT.OFF_ALL` | `/cq off` | `AddOn disabled.` |
| `CHAT.OPTION_CHANGED` | `/cq on <name>` / `/cq off <name>` | `<optionKey>` in `COLOR.HIGHLIGHT`, then ` on` or ` off`, then ` -- <effect>.` — `<effect>` is the option's own `ON_*` / `OFF_*` text from section 5 |
| `CHAT.RESET` | `/cq reset` | `Settings restored to defaults.` |
| `CHAT.UNKNOWN_OPTION` | `/cq on wrongname` | `Unknown setting '<name>'. Try /cq for the list.` |
| `CHAT.UNKNOWN_COMMAND` | `/cq wrongword` | `Unknown command '<word>'. Try ` + `/cq help` in `COLOR.HIGHLIGHT` + ` for the list.` |
| `CHAT.NO_PANEL` | `/cq` when the options panel could not be built | `Options panel unavailable; use ` + `/cq on|off <name>` in `COLOR.HIGHLIGHT` + `.` |
| `CHAT.HELP_HINT` | End of `/cq status` | `/cq help` in `COLOR.HIGHLIGHT` + ` lists every command.` |

### Chat: the two list headers

| ID | Trigger | Text |
| --- | --- | --- |
| `CHAT.STATUS_TITLE` | `/cq status` | `<AddOn name> v<version> - Status` |
| `CHAT.STATUS_ROW` | one per option | two spaces, then `on ` in `COLOR.ON` or `off` in `COLOR.OFF`, two spaces, `<optionKey>` in `COLOR.HIGHLIGHT`, then ` (experimental)` in `COLOR.EXPERIMENTAL` where it applies |
| `CHAT.HELP_TITLE` | `/cq help` | `<AddOn name> v<version> - Commands` |
| `CHAT.HELP_ROW` | one per command | two spaces, `<command>` in `COLOR.HIGHLIGHT`, then `  -  `, then the description below |

### Chat: the command list

Order as shown. The separator between command and description is a fixed `  -  ` — the game font
is not monospaced, so padding to a column comes out ragged.

| ID | Command | Description |
| --- | --- | --- |
| `HELP.OPEN` | `/cq` | `Open the options panel` |
| `HELP.ON` | `/cq on` | `Turn on the full Classic experience` |
| `HELP.OFF` | `/cq off` | `Disable the AddOn` |
| `HELP.STATUS` | `/cq status` | `List every option and its state` |
| `HELP.ON_ONE` | `/cq on <name>` | `Turn one option on` |
| `HELP.OFF_ONE` | `/cq off <name>` | `Turn one option off` |
| `HELP.RESET` | `/cq reset` | `Restore default settings` |

### Chat: when a Blizzard control is changed instead

Fires when the player moves one of Blizzard's own checkboxes that this AddOn also drives.

| ID | Trigger | Text |
| --- | --- | --- |
| `CHAT.BLIZZ_YIELD` | Blizzard's control moved away from Classic | `<Blizzard option name>` in `COLOR.HIGHLIGHT` + ` was changed in Blizzard's options, so ` + `<optionKey>` in `COLOR.HIGHLIGHT` + ` is now off.` |
| `CHAT.BLIZZ_ADOPT` | Blizzard's control moved to what this AddOn wants | `<Blizzard option name>` in `COLOR.HIGHLIGHT` + ` matches Classic, so ` + `<optionKey>` in `COLOR.HIGHLIGHT` + ` is now on.` |

### Chat: minimap tracking

| ID | Trigger | Text |
| --- | --- | --- |
| `CHAT.TRACKING_REASSERTED` | The player switches *Track Quest POIs* on and the AddOn switches it back. Throttled to once every 10 seconds. | `Track Quest POIs` in `COLOR.HIGHLIGHT` + ` was switched back off automatically. To allow it, use ` + `/cq off minimapMarkers` in `COLOR.HIGHLIGHT` + `.` |

---

## 3. Warnings

Shown in `COLOR.WARNING`, once per problem per session, with the standard prefix. These appear
only when this client lacks something the AddOn expected, so most players never see one.

| ID | Condition | Text |
| --- | --- | --- |
| `WARN.CVAR_SET` | A console variable would not accept a write | `could not set <cvar>; skipping <label>.` |
| `WARN.CVAR_REFUSED` | The write was accepted and silently ignored | `<cvar> would not change (asked for <value>, still <value>). Skipping <label>.` |
| `WARN.CVAR_MISSING` | `GetCVar`/`SetCVar` absent | `GetCVar/SetCVar missing; skipping <label>.` |
| `WARN.CVAR_ABSENT` | The variable does not exist here | `<cvar> does not exist on this client; skipping <label>.` |
| `WARN.MM_API` | `C_Minimap` absent | `C_Minimap tracking API missing; skipping minimap markers.` |
| `WARN.MM_NAME` | The tracking-name constant is absent | `MINIMAP_TRACKING_QUEST_POIS missing; skipping minimap markers.` |
| `WARN.MM_COUNT` | The tracking list could not be read | `could not read the tracking list; skipping minimap markers.` |
| `WARN.MM_NOTFOUND` | No entry by that name | `no '<name>' entry in the tracking list; skipping minimap markers.` |
| `WARN.MM_SET` | The tracking entry would not change | `could not change quest POI tracking; skipping minimap markers.` |
| `WARN.MM_REFUSED` | It changed back by itself | `quest POI tracking would not turn off; skipping minimap markers.` |
| `WARN.MM_TOOLTIP` | The tracking button was not found | `tracking button not found; using chat notices instead of a tooltip.` |
| `WARN.BAGS_MISSING` | `ContainerFrame_Update` absent | `ContainerFrame_Update is not present on this client; skipping the bag quest highlight.` |
| `WARN.OPTIONS_REGISTER` | The panel could not be added to Blizzard's settings | `could not add the panel to Blizzard's settings; /cq opens it as its own window instead.` |
| `WARN.OPTIONS_REFRESH` | The panel failed to refresh | `could not refresh the panel: <error>` |
| `WARN.EVENT` | A handler errored | `error handling <event>: <error>` |
| `WARN.APPLY` | An option failed to apply | `could not <enable/disable> <optionKey>: <error>` |

---

## 4. The options panel

| ID | Where | Text | Notes |
| --- | --- | --- | --- |
| `PANEL.CATEGORY` | Blizzard's AddOn list | `<AddOn name>` | Same variable as `ID.NAME`. |
| `PANEL.VERSION` | Grey heading at the foot of the list | `v<version>` in `COLOR.MUTED` | Read from the `.toc`, never typed. |
| `PANEL.SECTION_EXPERIMENTAL` | Heading above the experimental options | `Experimental` in `COLOR.EXPERIMENTAL` | |
| `PANEL.PRESET_LABEL` | The dropdown's own label | `Preset` | |

### Preset choices

| ID | Text |
| --- | --- |
| `PRESET.CLASSIC` | `Full Classic experience` |
| `PRESET.CUSTOM` | `Custom` |
| `PRESET.DISABLED` | `Disabled` |

Listed in that order. `Custom` is shown but never chosen — it is what the control reports when
the settings match neither of the others.

### Preset tooltip

Opens with a blank line. Each row is the preset name and a colon in `COLOR.TITLE`, then the body
in `COLOR.BODY` on the same line. Rows separated by a blank line.

| ID | Text |
| --- | --- |
| `PRESET.TIP_CLASSIC` | `Every normal option on. Experimental ones are left exactly as you set them.` |
| `PRESET.TIP_CUSTOM` | `Your own mix. It cannot be selected; it is chosen automatically as soon as you change any option below.` |
| `PRESET.TIP_DISABLED` | `Every option off, experimental ones included: the game as Blizzard ships it.` |
| `PRESET.TIP_COMMANDS` | `/cq on, /cq off` in `COLOR.MUTED`, at the foot |

### Option tooltips: the shape

Blizzard paints the first line — the option's name — white by itself. Everything below is ours:

1. `DESC_*` from section 5, in `COLOR.BODY`.
2. A blank line, then `LIMIT_*` if the option has one, in `COLOR.EXPERIMENTAL`.
3. A blank line, then `EXPERIMENTAL_NOTE` if it is experimental, in `COLOR.EXPERIMENTAL`.
4. A blank line, then `/<optionKey>` in `COLOR.MUTED`.

| ID | Text |
| --- | --- |
| `TIP.EXPERIMENTAL_NOTE` | `Experimental: not part of the Full Classic experience, which leaves it exactly as you set it. Switch it on by hand.` |

### On Blizzard's own controls

Appended to the tooltips of *Instant Quest Text*, *Automatic Quest Tracking* and *Outline Mode*,
after a blank line, so a checkbox that moves on its own is not a mystery.

| ID | Text |
| --- | --- |
| `TIP.MANAGED_BY` | `Managed by <AddOn name>.` in `COLOR.BRAND` |

### Minimap tracking-button tooltip

Appended to Blizzard's tracking-button tooltip while the minimap option is on.

| ID | Text | Colour |
| --- | --- | --- |
| `TIP.TRACK_HEADER` | `<AddOn name>` | `COLOR.BRAND` |
| `TIP.TRACK_LINE1` | `Track Quest POIs` in `COLOR.HIGHLIGHT` + ` is kept off automatically.` | white body |
| `TIP.TRACK_LINE2` | `Switching it on here will not stick.` | light grey |
| `TIP.TRACK_LINE3` | `To allow it: ` + `/cq off minimapMarkers` in `COLOR.HIGHLIGHT` | grey |

### Dialogs

Only shown by the fallback panel, which appears on clients that refuse Blizzard's Settings API.
On a normal client Blizzard's own dialogs do this work.

| ID | Where | Text |
| --- | --- | --- |
| `DLG.RELOAD_ONE` | After changing one option that needs a rebuild | `The UI needs to reload for this setting to take effect.` |
| `DLG.RELOAD_MANY` | After a preset moves several | `The UI needs to reload for some of these settings to take effect.` |
| `DLG.RELOAD_YES` | button 1 | `Reload` |
| `DLG.RELOAD_NO` | button 2 | `Cancel` — uses the game's own translation where available |
| `DLG.DEFAULTS` | Confirming a reset | `Do you want to reset <AddOn name> settings to their defaults?` |
| `DLG.DEFAULTS_NOTE` | Added when the reset needs a rebuild, after a blank line | `Note: The UI will reload.` |
| `DLG.DEFAULTS_YES` | button 1 | `Yes` — game translation where available |
| `DLG.DEFAULTS_NO` | button 2 | `No` — game translation where available |
| `BTN.DEFAULTS` | The fallback panel's own button | `Defaults` |
| `BTN.DEFAULTS_TIP` | Its tooltip body | `Returns every option to the state a fresh install has: the full Classic experience, with experimental options off.` |

---

## 5. The options themselves

Each option has five strings. `TITLE_*` is the checkbox label, `DESC_*` the tooltip body,
`ON_*` and `OFF_*` the phrases chat uses to say what actually changed, and `LABEL_*` the phrase
warnings use.

**`ON_*` and `OFF_*` describe the effect, not the switch** — "world map creature portraits
hidden", never "showBosses set to 0". They are dropped into `CHAT.OPTION_CHANGED` after a dash,
so they should read as a continuation and start lowercase.

`LABEL_*` appears only inside warnings, in the middle of a sentence, so it too starts lowercase.

The **key** column is what the player types after `/cq on` and what appears in tooltips.

### worldMapMarkers

| ID | Text |
| --- | --- |
| `TITLE_worldMapMarkers` | `Hide world map quest markers` |
| `DESC_worldMapMarkers` | `Removes the numbered quest pins, the shaded objective areas, the Track Quest checkbox and the quest list inside the full-screen map.` |
| `ON_worldMapMarkers` | `world map quest markers, blue areas and map quest log hidden` |
| `OFF_worldMapMarkers` | `world map quest markers shown again` |
| `LABEL_worldMapMarkers` | `world map quest markers` |

### minimapMarkers

| ID | Text |
| --- | --- |
| `TITLE_minimapMarkers` | `Hide minimap quest markers` |
| `DESC_minimapMarkers` | `Keeps the Track Quest POIs tracking entry switched off, which removes both the numbered pins and the blue objective area from the minimap.` |
| `ON_minimapMarkers` | `minimap quest pins and the blue quest area hidden` |
| `OFF_minimapMarkers` | `minimap quest pins and the blue quest area shown again` |

### questTextTypesOut

| ID | Text |
| --- | --- |
| `TITLE_questTextTypesOut` | `Type quest text out` |
| `DESC_questTextTypesOut` | `Quest text types out a line at a time instead of appearing at once, as it did in Classic. This is Blizzard's Instant Quest Text option, turned off.` |
| `ON_questTextTypesOut` | `quest text types out a line at a time` |
| `OFF_questTextTypesOut` | `quest text appears all at once again` |
| `LABEL_questTextTypesOut` | `instant quest text` |

### autoQuestTracking

| ID | Text |
| --- | --- |
| `TITLE_autoQuestTracking` | `Disable automatic quest tracking` |
| `DESC_autoQuestTracking` | `Accepting a quest no longer adds it to the tracker by itself. Quality of life rather than clutter, so it is yours to choose.` |
| `ON_autoQuestTracking` | `newly accepted quests are no longer tracked automatically` |
| `OFF_autoQuestTracking` | `newly accepted quests are tracked automatically again` |
| `LABEL_autoQuestTracking` | `automatic tracking of new quests` |

### mapCreaturePortraits

| ID | Text |
| --- | --- |
| `TITLE_mapCreaturePortraits` | `Hide world map creature portraits` |
| `DESC_mapCreaturePortraits` | `Hides the boss and creature portrait pins MoP puts on zone maps. Classic never had them.` |
| `ON_mapCreaturePortraits` | `world map creature portraits hidden` |
| `OFF_mapCreaturePortraits` | `world map creature portraits shown again` |
| `LABEL_mapCreaturePortraits` | `world map creature portraits` |

### trackerClickToTrack

| ID | Text |
| --- | --- |
| `TITLE_trackerClickToTrack` | `Make tracker quests plain text` |
| `DESC_trackerClickToTrack` | `Quest titles in the tracker stop being clickable, so there is no click-to-open-map and no right-click menu. Classic's tracker was text you read.` |
| `ON_trackerClickToTrack` | `tracker quest titles are plain text` |
| `OFF_trackerClickToTrack` | `tracker quest titles are clickable again` |
| `LIMIT_trackerClickToTrack` | `Known limitation: achievement lines in the tracker stop being clickable too. The tracker draws both from one pool of buttons and does not mark which is which.` |

### trackerItemButtons

| ID | Text |
| --- | --- |
| `TITLE_trackerItemButtons` | `Hide tracker quest item buttons` |
| `DESC_trackerItemButtons` | `Removes the use buttons MoP puts beside tracked quests. Quest items are used from your bags, as they were in Classic.` |
| `ON_trackerItemButtons` | `tracker quest item buttons hidden` |
| `OFF_trackerItemButtons` | `tracker quest item buttons shown again` |

### bagQuestHighlight

| ID | Text |
| --- | --- |
| `TITLE_bagQuestHighlight` | `Hide quest item highlight in bags` |
| `DESC_bagQuestHighlight` | `Quest items in your bags stop being outlined in yellow, and items that start a quest lose their exclamation mark. Both are drawn by the same texture, and neither was in Classic: a quest item looked like any other item.` |
| `ON_bagQuestHighlight` | `bag quest item highlight hidden` |
| `OFF_bagQuestHighlight` | `bag quest item highlight shown again` |

### trackerTurnInPopups  *(experimental)*

| ID | Text |
| --- | --- |
| `TITLE_trackerTurnInPopups` | `Suppress turn-in pop-ups` |
| `DESC_trackerTurnInPopups` | `Stops the bubble that slides out of the tracker to tell you a quest can be handed in.` |
| `ON_trackerTurnInPopups` | `turn-in pop-ups suppressed` |
| `OFF_trackerTurnInPopups` | `turn-in pop-ups shown again` |
| `LIMIT_trackerTurnInPopups` | `Untested: no turn-in pop-up has been seen in play yet, so the removal has never actually run.` |

### questObjectOutline  *(experimental)*

| ID | Text |
| --- | --- |
| `TITLE_questObjectOutline` | `Request quest object outline` |
| `DESC_questObjectOutline` | `Quest objects show either an outline or sparkles, never both, so asking for the outline suppresses the glimmer. Many clients cannot render outlines at all, in which case this does nothing.` |
| `ON_questObjectOutline` | `outline requested instead of sparkles (experimental; many clients cannot render it)` |
| `OFF_questObjectOutline` | `outline setting returned to what it was` |
| `LABEL_questObjectOutline` | `quest object outline` |

### Group names

Used only by the fallback panel, as headings. The native panel uses one `Experimental` heading
and no others.

`Map and minimap` · `Quest text` · `Quest tracking` · `World map clutter` · `Bags` ·
`Experimental`

---

## 6. Colours

Change a value here to change it everywhere that colour is used.

| ID | Value | Used for |
| --- | --- | --- |
| `COLOR.BRAND` | `|cff66ccff` — light blue | The chat prefix, tooltip headers that are ours, `Managed by`. Chosen to stand clear of Blizzard's white body text and yellow highlights. |
| `COLOR.HIGHLIGHT` | `|cffffd100` — Blizzard gold | Option keys, commands and Blizzard option names inside a sentence. This is the game's own highlight colour. |
| `COLOR.BODY` | `|cffffd100` — Blizzard gold | Tooltip body text. Same value as `COLOR.HIGHLIGHT`; it is what Blizzard's own tooltips use for a body line. |
| `COLOR.TITLE` | `|cffffffff` — white | Headings inside a tooltip, such as each preset name. |
| `COLOR.MUTED` | `|cff808080` — grey | The slash handle at the foot of a tooltip, and the version footer. |
| `COLOR.EXPERIMENTAL` | `|cffff8019` — orange | The `Experimental` heading, the experimental note, and known-limitation lines. |
| `COLOR.WARNING` | `|cffff9955` — pale orange | Warning messages in chat. |
| `COLOR.ON` | `|cff55ff55` — green | The word `on` in `/cq status`. |
| `COLOR.OFF` | `|cffff5555` — red | The word `off` in `/cq status`. |

Two colours are currently near-duplicates and worth a decision:

- `COLOR.EXPERIMENTAL` (`ff8019`) and one older orange still used by `/cq status` for the
  `(experimental)` tag (`ff8800`). **These should be one colour.** Say which and I will unify.
- `COLOR.HIGHLIGHT` and `COLOR.BODY` are the same value used for two purposes. Fine as it stands,
  but if you want tooltip bodies to differ from inline highlights, they need splitting first.
