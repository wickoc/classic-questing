# Vanilla Questing

*Turn off the quest helper and experience questing as in the original game. Read the quest, explore, and immerse yourself in the World of Warcraft. You have full control, disable as much or as little as you like: no map/minimap markers, no progress in tooltips, instant quest text, vanilla quest tracker, and much more.*

A World of Warcraft AddOn that turns off the quest helper, so questing feels like the original
game again: you read the quest text and go and look, instead of following a marker.

Built and tested against **Mists of Pandaria Classic** (5.5.4). Support for other client versions
is planned.

**Everything it does is subtractive.** It hides or switches off parts of Blizzard's UI. It never
adds quest data of its own, never tells you where anything is, and leaves no trace when turned
off — every value it changes is remembered first and put back.

## Commands

| Command | What it does |
| --- | --- |
| `/vq` | Open the options panel |
| `/vq on` | Enable all vanilla options |
| `/vq off` | Disable all options |
| `/vq on <option>` | Turn one option on |
| `/vq off <option>` | Turn one option off |
| `/vq status` | List every option and its current state |
| `/vq reset` | Restore default options |
| `/vq help` | List the commands |

`/vanillaquesting` works anywhere `/vq` does, if something else has claimed the short form.

`<option>` is one of the names below — `/vq status` lists them in game:

`hideMapQuestHelper` · `hideMinimapQuestHelper` · `hideBossPortraits` · `noInstantQuestText` ·
`hideCharacterFrame` · `hideTooltipsQuestProgress` · `noAutoQuestTracking` · `trackerPlainText` ·
`hideTrackerItemButtons` · `noBagItemHighlight` · `outlineMode` · `noCompleteQuestPopup`

Every option is individually switchable, and each has a description in the options panel.

## What it removes

**Map and minimap**

- Numbered quest pins, shaded objective areas, the Track Quest checkbox and the quest list
  inside the full-screen map
- Quest markers on the minimap
- Boss and creature portrait pins on zone maps, which Classic never had

**Quest text and bags**

- The framed questgiver portrait beside quest text, in the offer window and the quest log
- Quest progress appended to tooltips — mousing a creature no longer tells you which quest it
  belongs to or how many you still need
- Instant Quest Text, so quest text types out a line at a time as it did in Classic
- The yellow highlight MoP puts on quest items in your bags, and the `!` on items that start a
  quest — one option, since Blizzard draws both with the same texture

**Quest tracker**

The tracker itself stays. Classic had one: you shift-click a quest in the log and it appears.
What goes is everything MoP bolted onto it.

- Clickable quest titles — no click-to-open-map, no right-click menu. Classic's tracker was text
  you read
- Quest item use buttons beside tracked quests. Quest items are used from your bags
- Automatic tracking of newly accepted quests

**Experimental**

These are never switched on by the **Vanilla (Default)** preset. Turn them on yourself.

- Turn-in pop-up bubbles
- Loot sparkles on quest objects, replaced with an outline — see Known limitations

Every option is individually switchable. The **Vanilla (Default)** preset turns on every normal
option and leaves the experimental ones exactly as you set them; **Disabled** turns everything
off.

## Known limitations

These are things this client will not let an AddOn do cleanly. They are listed here rather than
quietly worked around.

### Achievement tracker lines also stop being clickable

Turning on **Make tracker quests plain text** also stops achievement lines in the tracker
responding to clicks. The tracker draws quest titles and achievement titles from a single pool of
buttons and does not mark which is which, so there is no way to disable one without the other.

If you track achievements and want them clickable, leave that one option off. Everything else
still works.

### Quest objects show either an outline or loot sparkles — never neither

The two are alternatives in the engine, so the loot sparkles on quest objects cannot simply be
taken away. What an AddOn can do is ask for the outline instead, which is what **Outline Mode**
does. Where a client fails to render the outline, loot sparkles are shown automatically.

It is experimental and off by default for that reason: whether you see any difference depends on
your client.

Two other ways round it were tried and rejected. `particleDensity` removes the sparkle — and the
particles on lootable corpses with it, which *is* Classic behaviour. `ffxGlow` does not touch it
at all.

## Where it overlaps Blizzard's own options

Three of these settings have a Blizzard checkbox of their own: **Instant Quest Text**,
**Automatic Quest Tracking** and **Outline Mode**. Their tooltips are annotated to say Vanilla
Questing is driving them.

Change one of those in Blizzard's options and **Vanilla Questing follows** — the matching
option turns off, and turns back on if you put the option back. Whichever window you use, the two
agree, and the AddOn says in chat which way it went. Your interface wins.

## Compatibility

Built and tested against interface **50504**, client 5.5.4 build 69585.

## Create a release

Releases → "Draft a new release" → Create new tag: "vX.X.X" → Publish
The /.github/workflows/ script will create the zip and fill out details from the changelog.
