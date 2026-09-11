# CurseForge listing copy

The text for the CurseForge project page, kept here so it stays in step with the AddOn rather
than drifting once it is pasted in. **Not shipped.**

**CurseForge is marketing. The GitHub readme is "how do I use it".** Where the two overlap they
should agree, but this file is allowed to sell and the readme is not.

Three constraints from CurseForge's own rules shaped the layout, and they are the reason the
Ko-fi and GitHub links sit where they do:

- **Donation links belong at the bottom of the page**, civil in size. Never advertise features
  that are paywalled behind a donation — there are none here, and there will not be.
- **Links leading off the platform** (GitHub, issues) go at the bottom too, after the description.
- The **summary** says what the project does, not who made it or who it is for.

---

## Summary

One line, already set from the readme. Kept here for the record:

> Turn off the quest helper and experience questing as in the original game. Read the quest,
> explore, and immerse yourself in the World of Warcraft. You have full control, disable as much
> or as little as you like: no map/minimap markers, no progress in tooltips, instant quest text,
> vanilla quest tracker, and much more.

If a shorter one is ever wanted, this is the same idea at a third the length:

> Turns off Mists of Pandaria's quest helper so questing feels like the original game — read the
> quest, go and look. Twelve options, all individually switchable.

---

## Categories

Suggested, in order of fit. CurseForge allows up to four additional categories beyond the main
one, and picking ones that do not fit can get a project sent back.

- **Quests & Leveling** — the obvious home.
- **Map & Minimap** — half the options are map and minimap.
- **Tooltip** — quest progress in tooltips.
- **Bags & Inventory** — the quest highlight on bag items.

---

## Licence

**MIT.** CurseForge does not require a licence for WoW addons, but having one answers the question
before it is asked, and MIT is what this ecosystem runs on — DragonUI, and most of the addons this
project has read for reference, use it.

It fits this project specifically:

- **It lets someone port it.** Cross-expansion support is on the backlog; if that never happens
  here, MIT means somebody else can do it rather than starting over.
- **It is short enough to actually read**, which matters for something a player is installing into
  their game.
- **It asks nothing back.** The AddOn is free and stays free, so a licence that demands anything
  of the people using it would be odd.

The alternative worth a thought is **All Rights Reserved**, which is the default if nothing is
chosen. It prevents forks. That is the only reason to pick it, and preventing forks is not a goal
here.

**Not done yet** — a `LICENSE` file has to be added to the repository and the choice recorded, and
that is the author's call to make, not mine.

---

## Description

Everything below this line is the page body, in order. Image placements are marked; see the notes
at the foot of this file for what goes where and why.

---

`[IMAGE: description banner, full width, top of page]`

## Questing, the way it used to be

Mists of Pandaria tells you where to go. A numbered pin on the map, a glowing blob over the
objective, an arrow on the minimap, your progress in every tooltip you touch. You can finish a
quest without reading a word of it.

**Vanilla Questing turns that layer off.** You read the quest, you work out where it means, and
you go and look. The world stops being a checklist and goes back to being a place.

`[IMAGE: before/after — World Map Full]`

### Everything is a switch

Twelve options, each one individually switchable. Turn on the lot for the full experience, or keep
the two or three that were bothering you and leave the rest alone. Nothing is all-or-nothing.

Presets do the obvious thing: **Vanilla** turns on everything, **Disabled** turns off everything,
and **Custom** appears on its own the moment you change anything by hand.

`[IMAGE: the options panel]`

---

## What it turns off

### 🗺️ Map and minimap

- Numbered quest pins, the shaded objective areas, the Track Quest checkbox and the quest list
  inside the full-screen map
- Quest markers on the minimap
- Boss portrait pins on zone maps, which Classic never had

`[IMAGE: before/after — World Map Small]`
`[IMAGE: before/after — Mini Map]`
`[IMAGE: before/after — Boss Portraits]`

### 📜 Quest text

- **Instant Quest Text** off, so quest text types itself out a line at a time the way it did
- The framed questgiver portrait beside the quest text, in the offer window and the quest log

`[IMAGE: before/after — Instant Quest Text]`
`[IMAGE: before/after — Character Frame]`

### 🎯 Quest tracking

The tracker itself stays. Classic had one — you shift-click a quest in the log and it appears.
What goes is everything MoP bolted onto it.

- Clickable quest titles: no click-to-open-map, no right-click menu. Classic's tracker was text
  you read
- The quest item use buttons beside tracked quests. Quest items are used from your bags
- Automatic tracking of every quest you accept

`[IMAGE: before/after — Quest Tracker Clickable]`
`[IMAGE: before/after — Quest Item Buttons]`

### 🔍 Everything else

- Quest progress appended to tooltips — mousing over a creature no longer tells you which quest it
  belongs to or how many you still need
- The yellow highlight MoP puts on quest items in your bags, and the `!` on items that start a
  quest

`[IMAGE: before/after — Quest Progress Tooltips]`
`[IMAGE: before/after — Bag Quest Items]`

### 🧪 Experimental

Off by default, and never switched on by the Vanilla preset.

- Turn-in pop-up bubbles
- Loot sparkles on quest objects, replaced with an outline

---

## Commands

Type `/vq` to open the options. Everything can also be driven from chat.

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

---

## It leaves no trace

Everything this AddOn does is **subtractive**. It hides or switches off parts of Blizzard's own
interface. It never adds quest data of its own, never tells you where anything is, and never
phones home.

Every value it changes is **remembered before it is touched and put back when you turn the option
off**. Uninstall it and your interface is exactly as you left it.

Where an option overlaps a Blizzard setting — Instant Quest Text, Automatic Quest Tracking,
Outline Mode — the two stay in step whichever window you change. Blizzard's own tooltips are
annotated to say so, so a checkbox that moves on its own is never a mystery.

---

## Known limitations

Listed here rather than quietly worked around.

**Achievement tracker lines also stop being clickable** when *Make tracker quests plain text* is
on. The tracker draws quest and achievement titles from one pool of buttons and does not mark
which is which, so there is no way to disable one without the other. If you track achievements and
want them clickable, leave that one option off — everything else still works.

**Quest objects show either an outline or loot sparkles, never neither.** The two are alternatives
in the engine, so the sparkles cannot simply be taken away. *Outline Mode* asks for the outline
instead; where a client fails to render it, loot sparkles come back on their own. That is why it
is experimental and off by default.

**Questgiver `!` marks on the minimap are still there.** The mark lives in a shared texture atlas,
so removing it means replacing artwork rather than flipping a switch. Not solved yet, and tracked
rather than abandoned.

---

## Compatibility

Built and tested against **Mists of Pandaria Classic**, 5.5.4 (build 69585), interface `50504`.

Every Blizzard function it touches is checked for existence before use. A missing one disables
that one feature and says so in chat, rather than breaking your interface.

Support for other Classic versions is planned — the AddOn is deliberately named without one.

---

## Bugs and requests

Found something, or want something? **[Open an issue on
GitHub](https://github.com/wickoc/vanilla-questing/issues)** — it gets read, and it gets a reply.

Bug reports are genuinely welcome. This AddOn is developed without a second pair of eyes, and
nearly every fix in it came from someone saying "that still looks wrong".

---

## ❤️ Support the project

This AddOn is free, and it will stay free. Everything in it is switched on for everyone, and
nothing is held back for anyone who chips in.

If it is making your adventures more enjoyable, you can support development with a coffee. It
helps pay for the time spent maintaining it and keeping it working as Classic moves on.

**[☕ Support the project on Ko-fi](https://ko-fi.com/wickoc)**

---

## Links

- **[Source and issues on GitHub](https://github.com/wickoc/vanilla-questing)**
- **[Changelog](https://github.com/wickoc/vanilla-questing/blob/main/CHANGELOG.md)**

*Vanilla Questing is a fan-made AddOn and is not affiliated with or endorsed by Blizzard
Entertainment.*

---
---

# Notes on the images

Not part of the page body.

## Where images go, and why both places

CurseForge gives a project **two** separate places for images, and they do different jobs:

- **The gallery** (the Images tab). These appear as a carousel near the top of the project page
  and in search results. They are what someone sees *before* they have read anything.
- **Inline in the description.** These appear where you put them, next to the words they
  illustrate.

**Use both.** They are not duplicates doing the same work:

- Put **every** before/after in the **gallery**, titled by feature. Someone browsing wants to flick
  through and see what it looks like without reading.
- Embed the **same images inline** next to the feature each one shows, as marked above. Someone
  reading the "Map and minimap" section wants to see the map, right there, not scroll back up.

The one genuine risk is a wall of images making the description tiring. If ten inline feels like
too many, cut the inline set to the four strongest — World Map Full, Mini Map, Quest Progress
Tooltips, Character Frame — and let the gallery carry the rest. The gallery loses nothing.

## The before/after shots

- **One combined image per feature**, not two separate ones. A reader should not have to hold two
  images in their head. Side by side if the feature is wide (maps), stacked if it is tall.
- **Label the halves in the image itself** — "Before" and "After", or "MoP" and "Vanilla
  Questing". Do not rely on a caption; the gallery does not always show one.
- **Same camera position, same zoom, same time of day, same quests in the log.** The only thing
  that should differ between the halves is the thing the AddOn changed. A shot where the character
  has moved makes the reader hunt for the difference.
- **Crop tight to the change.** A full-screen shot of a map with one pin missing reads as nothing.
- Take them at a **consistent resolution** so the carousel does not jump about.

## The logo

- **At least 400×400 px, 1:1, PNG.** Anything larger is downscaled.
- It must be **original artwork** — not the World of Warcraft logo, not a Blizzard icon, not a
  plain coloured square. CurseForge rejects all three.

## The banner

Goes at the very top of the description, full width. Worth making sure the AddOn's name is legible
in it at small sizes, since it is the first thing on the page.
