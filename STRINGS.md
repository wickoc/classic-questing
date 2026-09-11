# In-game text

Every string a player can see, labelled. **This is a record of what ships, not a queue of things
waiting to be written** — it is kept in step with the AddOn, and a row here matches the string in
the code. When the two disagree, the code is the bug or this file is stale; either way one of
them gets corrected in the same pass.

It is still the place to edit wording. Mark up a row, send it back, and the change is made in the
code and reflected here.

**How to read a row.** `Text` is what appears on screen. Anything in `<angle brackets>` is a
variable filled in at runtime — leave the brackets in place.

**Colours** use WoW's escape format: `|cffRRGGBB` opens a colour, `|r` closes it. `|n` is a line
break inside a tooltip; `\n` is one in chat and in dialogs. The palette is at the bottom — change
a colour there to change it everywhere it is used, or override it on a single row.

---

## 1. Identity

| ID | Where | Text | Notes |
| --- | --- | --- | --- |
| `ID.NAME` | Everywhere in game: chat prefix, options category, tooltips | `Vanilla Questing` | One variable, `ns.title`. Changing it here changes every use. |
| `ID.NOTES` | The AddOn list, under the name | `Turn off the quest helper and experience questing as in the original game.` | From the `.toc`. |
| `ID.AUTHOR` | The AddOn list | `wickoc` | From the `.toc`. |

---

## 2. Chat

Every line is prefixed automatically. Do not repeat the name inside a message.

| ID | Trigger | Text |
| --- | --- | --- |
| `CHAT.PREFIX` | Every chat line | `[Vanilla Questing] ` in `COLOR.BRAND`, trailing space |
| `CHAT.ON_ALL` | `/vq on` | `Enabled all vanilla options.` |
| `CHAT.OFF_ALL` | `/vq off` | `Disabled all options.` |
| `CHAT.OPTION_CHANGED` | `/vq on <option>` / `/vq off <option>` | `<optionKey>` in `COLOR.HIGHLIGHT`, then ` on` in `COLOR.ON` or ` off` in `COLOR.OFF`, then `. <effect>.` — `<effect>` is the option's own `ON_*` / `OFF_*` text from section 5 |
| `CHAT.RESET` | `/vq reset` | `Restored default options.` |
| `CHAT.UNKNOWN_OPTION` | `/vq on wrongname` | `Unknown option '<option>'.` in `COLOR.WARNING` + ` Try ` + `/vq help` in `COLOR.HIGHLIGHT` + ` for list of commands.` |
| `CHAT.UNKNOWN_COMMAND` | `/vq wrongword` | `Unknown command '<word>'.` in `COLOR.WARNING` + ` Try ` + `/vq help` in `COLOR.HIGHLIGHT` + ` for list of commands.` |
| `CHAT.NO_PANEL` | `/vq` when the options panel could not be built | `Options panel unavailable.` in `COLOR.WARNING` + ` Use ` + `/vq on|off <option>` in `COLOR.HIGHLIGHT` + `.` |

### Chat: the two list headers

| ID | Trigger | Text |
| --- | --- | --- |
| `CHAT.STATUS_TITLE` | `/vq status` | `<AddOn name> v<version> - Status and list of options` |
| `CHAT.STATUS_ROW` | one per option | two spaces, then `on ` in `COLOR.ON` or `off ` in `COLOR.OFF`, two spaces, `<optionKey>` in `COLOR.HIGHLIGHT` — or in `COLOR.EXPERIMENTAL` where the option is experimental — then ` (experimental)` in `COLOR.EXPERIMENTAL` where it applies |
| `CHAT.HELP_TITLE` | `/vq help` | `<AddOn name> v<version> - List of commands` |
| `CHAT.HELP_ROW` | one per command | two spaces, `<command>` in `COLOR.HIGHLIGHT`, then `  -  `, then the description below |

### Chat: the command list

Order as shown. The separator between command and description is a fixed `  -  ` — the game font
is not monospaced, so padding to a column comes out ragged.

| ID | Command | Description |
| --- | --- | --- |
| `HELP.OPEN` | `/vq` | `Open the options panel` |
| `HELP.ON` | `/vq on` | `Enable all vanilla options` |
| `HELP.OFF` | `/vq off` | `Disable all options` |
| `HELP.STATUS` | `/vq status` | `List every option and its current state` |
| `HELP.ON_ONE` | `/vq on <option>` | `Turn one option on` |
| `HELP.OFF_ONE` | `/vq off <option>` | `Turn one option off` |
| `HELP.RESET` | `/vq reset` | `Restore default options` |

### Chat: when a Blizzard control is changed instead

Fires when the player moves one of Blizzard's own checkboxes that this AddOn also drives.

| ID | Trigger | Text |
| --- | --- | --- |
| `CHAT.BLIZZ_YIELD` | Blizzard's control moved away from this AddOn | `<Blizzard option name>` in `COLOR.HIGHLIGHT` + ` was changed in Blizzard's options, so ` + `<optionKey>` in `COLOR.HIGHLIGHT` + ` is now `+ `off ` in `COLOR.OFF` + `.` |
| `CHAT.BLIZZ_ADOPT` | Blizzard's control moved to what this AddOn wants | `<Blizzard option name>` in `COLOR.HIGHLIGHT` + ` was changed in Blizzard's options, so ` + `<optionKey>` in `COLOR.HIGHLIGHT` + ` is now `+ `on ` in `COLOR.ON` + `.` |

### Chat: minimap tracking

| ID | Trigger | Text |
| --- | --- | --- |
| `CHAT.TRACKING_REASSERTED` | The player switches *Track Quest POIs* on and the AddOn switches it back. Throttled to once every 10 seconds. | `Track Quest POIs` in `COLOR.HIGHLIGHT` + ` was disabled automatically. To allow it, use ` + `/vq off hideMinimapQuestHelper` in `COLOR.HIGHLIGHT` + `.` |

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
| `WARN.MM_API` | `C_Minimap` absent | `C_Minimap tracking API missing; minimap markers are untouched.` |
| `WARN.MM_NAME` | The tracking-name constant is absent | `MINIMAP_TRACKING_QUEST_POIS missing; minimap markers are untouched.` |
| `WARN.MM_COUNT` | The tracking list could not be read | `could not read the tracking list; minimap markers are untouched.` |
| `WARN.MM_NOTFOUND` | No entry by that name | `no '<option>' entry in the tracking list; minimap markers are untouched.` |
| `WARN.MM_SET` | The tracking entry would not change | `could not change quest POI tracking; minimap markers are untouched.` |
| `WARN.MM_REFUSED` | It changed back by itself | `quest POI tracking would not turn off; minimap markers are untouched.` |
| `WARN.MM_TOOLTIP` | The tracking button was not found | `tracking button not found; using chat notices instead of a tooltip.` |
| `WARN.QUESTFRAME_MISSING` | The portrait frame was not found | `could not find the questgiver portrait on this client; skipping that option.` |
| `WARN.TOOLTIP_MISSING` | `GameTooltip` is not hookable | `GameTooltip is not hookable here; skipping quest progress tooltips.` |
| `WARN.BAGS_MISSING` | `ContainerFrame_Update` absent | `ContainerFrame_Update is not present on this client; bag quest highlight is untouched.` |
| `WARN.OPTIONS_REGISTER` | The panel could not be added to Blizzard's settings | `could not add the panel to Blizzard's settings; /vq opens as its own window instead.` |
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
| `PANEL.OPTION_NAME` | Each checkbox label | `TITLE_*` from section 5. Orange (`COLOR.EXPERIMENTAL`) for an experimental option in the **canvas** panel only | The native panel draws the label and the tooltip title from one string and offers no way to separate them (`[G23b]`), so it is left uncoloured there — Blizzard's yellow label, white title. An orange tooltip title would be worse than a plain label. |
| `PANEL.PRESET_LABEL` | The dropdown's own label | `Preset` | |

### Preset choices

| ID | Text |
| --- | --- |
| `PRESET.VANILLA` | `Vanilla (Default)` |
| `PRESET.CUSTOM` | `Custom` |
| `PRESET.DISABLED` | `Disabled` |

Listed in that order. `Custom` is shown but never chosen — it is what the control reports when
the settings match neither of the others.

### Preset tooltip

Opens with a blank line. Each row is the preset name and a colon in `COLOR.TITLE`, then the body
in `COLOR.BODY` on the same line. Rows separated by a blank line.

| ID | Text |
| --- | --- |
| `PRESET.TIP_VANILLA` | `Enable all vanilla options.` |
| `PRESET.TIP_CUSTOM` | `Automatically selected when you change any option below.` |
| `PRESET.TIP_DISABLED` | `Disable all options.` |

### Option tooltips: the shape

Blizzard paints the first line — the option's name — white by itself. Everything below is ours:

1. `DESC_*` from section 5, in `COLOR.BODY`. The tooltip's first line is the option's name,
   painted white by Blizzard — it is **not** orange for an experimental option, even though the
   checkbox label is.
2. A blank line, then `LIMIT_*` if the option has one, in `COLOR.EXPERIMENTAL`.
3. A blank line, then `EXPERIMENTAL_NOTE` if it is experimental, in `COLOR.EXPERIMENTAL`.
4. A blank line, then `/<optionKey>` in `COLOR.MUTED`.

| ID | Text |
| --- | --- |
| `TIP.EXPERIMENTAL_NOTE` | `Experimental: untested and potentially unstable. Use at your own discretion.` |

### The Experimental heading's description

The only place the AddOn says that the Vanilla preset leaves experimental options alone.

Shown differently in the two panels, because of what each can draw:

- **Canvas panel** — a line of text between the heading and the first checkbox, in
  `COLOR.EXPERIMENTAL`, always visible. This is the intended form.
- **Native panel** — on the `Experimental` heading's **tooltip**. There is no description element
  on this client: `[G23]` enumerated all nine and none of them draws a paragraph, and drawing it
  with the heading element read as a second heading.

| ID | Text |
| --- | --- |
| `PANEL.EXPERIMENTAL_DESC` | `These are not turned on by the Vanilla preset.` |

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
| `TIP.TRACK_HEADER` | `Track Quest POIs` in `COLOR.HIGHLIGHT` + `is managed by <AddOn name>.` | `COLOR.BRAND` |

### Dialogs

Only shown by the fallback panel, which appears on clients that refuse Blizzard's Settings API.
On a normal client Blizzard's own dialogs do this work.

| ID | Where | Text |
| --- | --- | --- |
| `DLG.RELOAD_ONE` | After changing one option that needs a rebuild | `The UI needs to reload for this option to take effect.` |
| `DLG.RELOAD_MANY` | After a preset moves several | `The UI needs to reload for some of these options to take effect.` |
| `DLG.RELOAD_YES` | button 1 | `Reload` |
| `DLG.RELOAD_NO` | button 2 | `Cancel` — uses the game's own translation where available |
| `DLG.DEFAULTS` | Confirming a reset | `Do you want to reset <AddOn name> options to their defaults?` |
| `DLG.DEFAULTS_NOTE` | Added when the reset needs a rebuild, after a blank line | `Note: The UI will reload.` |
| `DLG.DEFAULTS_YES` | button 1 | `Yes` — game translation where available |
| `DLG.DEFAULTS_NO` | button 2 | `No` — game translation where available |
| `BTN.DEFAULTS` | The fallback panel's own button | `Defaults` |
| `BTN.DEFAULTS_TIP` | Its tooltip body | `Restore default options.` |

---

## 5. The options themselves

Each option has five strings. `TITLE_*` is the checkbox label, `DESC_*` the tooltip body,
`ON_*` and `OFF_*` the phrases chat uses to say what actually changed, and `LABEL_*` the phrase
warnings use.

**`ON_*` and `OFF_*` describe the effect, not the switch** — "world map boss portraits
hidden", never "showBosses set to 0". They are dropped into `CHAT.OPTION_CHANGED` after a period,
so they should start uppercase.

`LABEL_*` appears only inside warnings, in the middle of a sentence, so it too starts lowercase.

The **key** column is what the player types after `/vq on` and what appears in tooltips.

### hideMapQuestHelper

| ID | Text |
| --- | --- |
| `TITLE_hideMapQuestHelper` | `Hide World Map Quest Helper` |
| `DESC_hideMapQuestHelper` | `Removes the quest markers, the blue objective areas, the Track Quest checkbox and the quest list in the world map pane.` |
| `ON_hideMapQuestHelper` | `World map quest markers, blue areas and quest list removed.` |
| `OFF_hideMapQuestHelper` | `World map quest helper restored.` |
| `LABEL_hideMapQuestHelper` | `world map quest helper` |

### hideMinimapQuestHelper

| ID | Text |
| --- | --- |
| `TITLE_hideMinimapQuestHelper` | `Hide Minimap Quest Helper` |
| `DESC_hideMinimapQuestHelper` | `Keeps the ` + `Track Quest POIs` in `COLOR.TITLE` + ` tracking switched off, removing both the markers and the blue objective areas from the minimap.` |
| `ON_hideMinimapQuestHelper` | `Minimap quest markers and the blue quest areas removed.` |
| `OFF_hideMinimapQuestHelper` | `Minimap quest helper restored.` |
| `LABEL_hideMinimapQuestHelper` | `minimap quest helper` |

### noInstantQuestText

| ID | Text |
| --- | --- |
| `TITLE_noInstantQuestText` | `No Instant Quest Text` |
| `DESC_noInstantQuestText` | `Quest text appear slowly, accompanied by the sound of a quill writing.` |
| `ON_noInstantQuestText` | `quest text appear slowly` |
| `OFF_noInstantQuestText` | `quest text appear instantly` |
| `LABEL_noInstantQuestText` | `instant quest text` |

### noAutoQuestTracking

| ID | Text |
| --- | --- |
| `TITLE_noAutoQuestTracking` | `No Automatic Quest Tracking` |
| `DESC_noAutoQuestTracking` | `Stops quests from instantly appearing in the quest tracker when accepted.` |
| `ON_noAutoQuestTracking` | `Newly accepted quests are no longer tracked automatically.` |
| `OFF_noAutoQuestTracking` | `Newly accepted quests are tracked automatically.` |
| `LABEL_noAutoQuestTracking` | `automatic tracking of new quests` |

### hideCharacterFrame

| ID | Text |
| --- | --- |
| `TITLE_hideCharacterFrame` | `Hide Character Frame` |
| `DESC_hideCharacterFrame` | `Removes the character frame next to quests, both when a quest is offered and in the quest log.` |
| `ON_hideCharacterFrame` | `Character frame removed.` |
| `OFF_hideCharacterFrame` | `Character frame restored.` |
| `LABEL_hideCharacterFrame` | `character frame` |

### hideTooltipsQuestProgress

| ID | Text |
| --- | --- |
| `TITLE_hideTooltipsQuestProgress` | `Hide Quest Progress In Tooltips` |
| `DESC_hideTooltipsQuestProgress` | `Hovering a creature or object no longer tells you which quest it belongs to and your progress.` |
| `ON_hideTooltipsQuestProgress` | `Quest progress removed from tooltips.` |
| `OFF_hideTooltipsQuestProgress` | `Quest progress in tooltips restored.` |
| `LABEL_hideTooltipsQuestProgress` | `quest progress in tooltips` |

### hideBossPortraits

| ID | Text |
| --- | --- |
| `TITLE_hideBossPortraits` | `Hide Boss Portraits` |
| `DESC_hideBossPortraits` | `Hides the boss portraits on the world map.` |
| `ON_hideBossPortraits` | `Boss portraits removed from the world map.` |
| `OFF_hideBossPortraits` | `Boss portraits restored.` |
| `LABEL_hideBossPortraits` | `boss portraits` |

### trackerPlainText

| ID | Text |
| --- | --- |
| `TITLE_trackerPlainText` | `Plain Text Quest Tracker` |
| `DESC_trackerPlainText` | `Quest titles in the tracker stop being clickable.` |
| `ON_trackerPlainText` | `Tracker quest titles are now plain text.` |
| `OFF_trackerPlainText` | `Tracker quest titles are clickable.` |
| `LABEL_trackerPlainText` | `plain text quest tracker` |
| `LIMIT_trackerPlainText` | `Known limitation: tracked achievements stop being clickable too.` |

### hideTrackerItemButtons

| ID | Text |
| --- | --- |
| `TITLE_hideTrackerItemButtons` | `Hide Quest Item Buttons` |
| `DESC_hideTrackerItemButtons` | `Removes the quest item buttons next to tracked quests.` |
| `ON_hideTrackerItemButtons` | `Tracker quest item buttons removed.` |
| `OFF_hideTrackerItemButtons` | `Tracker quest item buttons restored.` |
| `LABEL_hideTrackerItemButtons` | `quest item buttons` |

### noBagItemHighlight

| ID | Text |
| --- | --- |
| `TITLE_noBagItemHighlight` | `No Quest Item Highlight In Bags` |
| `DESC_noBagItemHighlight` | `Quest items in your bags stop being outlined in yellow, and items that start a quest lose their exclamation mark.` |
| `ON_noBagItemHighlight` | `Bag quest item highlight removed.` |
| `OFF_noBagItemHighlight` | `Bag quest item highlight restored.` |
| `LABEL_noBagItemHighlight` | `quest item highlight` |

### noCompleteQuestPopup  *(experimental)*

| ID | Text |
| --- | --- |
| `TITLE_noCompleteQuestPopup` | `No Complete Quest Popup` |
| `DESC_noCompleteQuestPopup` | `Removes the popup that tells you a quest can be completed.` |
| `ON_noCompleteQuestPopup` | `Complete quest popup removed.` |
| `OFF_noCompleteQuestPopup` | `Complete quest popup restored.` |
| `LABEL_noCompleteQuestPopup` | `complete quest popup` |

### outlineMode  *(experimental)*

| ID | Text |
| --- | --- |
| `TITLE_outlineMode` | `Outline Mode` |
| `DESC_outlineMode` | `Removes the loot sparkles on quest objects, showing an outline instead.` |
| `LIMIT_outlineMode` | `Known limitation: either an outline or loot sparkles must be shown. If the outline fails to render, loot sparkles are shown automatically.` |
| `ON_outlineMode` | `Rendering outlines on quest objects.` |
| `OFF_outlineMode` | `Rendering sparkles on quest objects.` |
| `LABEL_outlineMode` | `outline mode` |

### Group names

Used only by the fallback panel, as headings. The native panel uses one `Experimental` heading
and no others.

`Map and minimap` · `Quest text` · `Quest tracking` · `World map clutter` · `Bags` ·
`Experimental`

---

## 6. Colours

There is now **one palette**, defined once in `Core.lua` as `ns.color`. Nothing else in the AddOn
writes a colour code. Change a value there and it changes everywhere.

**The yellows and whites are the game's own**, not values typed in by hand. The AddOn reads
`NORMAL_FONT_COLOR_CODE`, `HIGHLIGHT_FONT_COLOR_CODE` and `GRAY_FONT_COLOR_CODE` from the client,
so it uses exactly what Blizzard's own tooltips and option labels use and cannot drift away from
them. The hex values below are the fallbacks, for a client that does not define those globals —
and they are the same values those globals hold. `|cffffd100` was the right yellow; it is now
sourced rather than assumed.

| ID | Source | Value | Used for |
| --- | --- | --- | --- |
| `COLOR.BODY` | `NORMAL_FONT_COLOR_CODE` | `|cffffd100` | Tooltip body text. Blizzard's standard yellow. |
| `COLOR.HIGHLIGHT` | `NORMAL_FONT_COLOR_CODE` | `|cffffd100` | Option keys, commands and Blizzard option names inside a sentence. |
| `COLOR.TITLE` | `HIGHLIGHT_FONT_COLOR_CODE` | `|cffffffff` | Headings inside a tooltip, such as each preset name. |
| `COLOR.MUTED` | `GRAY_FONT_COLOR_CODE` | `|cff808080` | The slash handle at the foot of a tooltip, and the version footer. |
| `COLOR.CLOSE` | `FONT_COLOR_CODE_CLOSE` | `|r` | Ends a coloured run. |

These four are the AddOn's own, and have no Blizzard equivalent to inherit:

| ID | Value | Used for |
| --- | --- | --- |
| `COLOR.BRAND` | `|cff66ccff` — light blue | The chat prefix, tooltip headers that are ours, `Managed by`. Chosen to stand clear of Blizzard's white body text and yellow highlights. |
| `COLOR.EXPERIMENTAL` | `|cffff8019` — orange | The `Experimental` heading and its tooltip, the experimental note, and known-limitation lines. The AddOn's only orange. |
| `COLOR.WARNING` | `|cffff9955` — pale orange | Warning messages in chat. |
| `COLOR.ON` / `COLOR.OFF` | `|cff55ff55` / `|cffff5555` | The words `on` and `off` in `/vq status`. |

`COLOR.HIGHLIGHT` and `COLOR.BODY` are deliberately the same value doing two jobs — that is what
Blizzard does. They are separate entries so that if you ever want tooltip bodies to differ from
inline highlights, the split is one line rather than a search-and-replace.
