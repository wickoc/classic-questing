![Vanilla Questing banner image](.github/vanilla-questing-banner.png)

# Vanilla Questing

*Turn off the quest helper and experience questing as in the original game. Read the quest, explore, and immerse yourself in the World of Warcraft. You have full control, disable as much or as little as you like: no map/minimap markers, no progress in tooltips, instant quest text, vanilla quest tracker, and much more.*

A World of Warcraft AddOn that turns off the quest helper, so questing feels like the original
game again: you read the quest text and go exploring, instead of following a marker.

Built and tested against **Mists of Pandaria Classic** (5.5.4). Support for other client versions
is in the pipeline.

## Install

**[Download the latest release](https://github.com/wickoc/vanilla-questing/releases/latest)**, or
get it from CurseForge.

Extract the zip into:

```
World of Warcraft\_classic_\Interface\AddOns\
```

You should end up with `Interface\AddOns\VanillaQuesting\VanillaQuesting.toc`. Restart the game
or `/reload`, then type `/vq` to open the options.

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

## Known limitations

### Achievement tracker lines also stop being clickable

Turning the quest tracker to plain text also stops achievement lines in the tracker
responding to clicks. The tracker draws quest titles and achievement titles from a single pool of
buttons and does not mark which is which, so there is no way to disable one without the other.

If you track achievements and want them clickable, leave that one option off. Everything else
still works.

### Quest objects show either an outline or loot sparkles — never neither

The two are alternatives in the engine, so the loot sparkles on quest objects cannot simply be
taken away. What an AddOn can do is ask for the outline instead, which is what **Outline Mode**
does. Where a client fails to render the outline, loot sparkles are shown automatically.

Two other ways round it were tried and rejected. `particleDensity` removes the sparkle — and the
particles on lootable corpses with it, which *is* Vanilla behaviour. `ffxGlow` does not touch it
at all.

## Compatibility

Built and tested against interface **50504**, client 5.5.4 build 69585.

## Bugs and requests

**[Open an issue](https://github.com/wickoc/vanilla-questing/issues)** — bug reports are genuinely
welcome, and most of the fixes in v1.0.0 came from someone saying "that still looks wrong".

### Check these first

Cheapest answers first. Most reports are answered by one of the top three.

1. Is `VanillaQuesting.toc` directly inside `Interface\AddOns\VanillaQuesting\`? A folder nested
   one level too deep is the commonest install fault, and the symptom is "nothing happens".
2. Is it ticked in the AddOn list on the character select screen?
3. Does `/vq` open the options? If not, it is not loading at all and nothing else matters.
4. Does it survive a `/reload`?
5. Does it still happen with every other AddOn disabled?
6. Does `/vq off` make it stop?

### Then tell us

- What you did, what you expected, and what happened instead.
- The output of `/vq status`, which lists every option and its state.
- Your AddOn version and client build.
- Whether any other AddOns were running — and which, if you found a clash at step 5.

A screenshot settles most things.

## Support the project

This AddOn is free and stays free. Nothing is held back for anyone who chips in.

If it is making your adventures better, you can support development with a coffee:
**[☕ Ko-fi](https://ko-fi.com/wickoc)**

## Uninstalling

Run **`/vq off`** before you delete the folder.

Some of what this AddOn switches off are the game's own settings, not its own — and those stay
switched off after the folder is gone, with nothing left installed to explain why. Switching the
options off first hands them back while the AddOn is still loaded to do it.

## Licence

All rights reserved.

## Create a release

Releases → "Draft a new release" → Create new tag: `vX.X.X` → Publish. The workflow in
`.github/workflows/` builds the zip and fills in the notes from the changelog.
