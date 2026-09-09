# Classic Questing (MoP)

A World of Warcraft AddOn for **Mists of Pandaria Classic** (5.5.4) that strips out MoP's
quest-helper layer, so questing feels like Classic again: you read the quest text and go and
look, instead of following a marker.

**Everything it does is subtractive.** It hides or switches off parts of Blizzard's UI. It never
adds quest data of its own, never tells you where anything is, and leaves no trace when turned
off — every value it changes is remembered first and put back.

In game it is called **Classic Questing**. Type `/cq` for the options panel, `/cq help` for the
commands.

## What it removes

**Map and minimap**

- Numbered quest pins, shaded objective areas, the Track Quest checkbox and the quest list
  inside the full-screen map
- Quest markers on the minimap
- Boss and creature portrait pins on zone maps, which Classic never had

**Quest text and bags**

- Instant Quest Text, so quest text types out a line at a time as it did in Classic
- The yellow highlight MoP puts on quest items in your bags, and the `!` on items that start a
  quest — one option, since Blizzard draws both with the same texture

**Quest tracker**

- Clickable quest titles — no click-to-open-map, no right-click menu. Classic's tracker was text
  you read
- Quest item use buttons beside tracked quests. Quest items are used from your bags
- Automatic tracking of newly accepted quests
- Turn-in pop-up bubbles *(experimental)*

Every option is individually switchable, and the **Full Classic experience** preset turns on
everything except the experiments.

## Known limitations

These are things this client will not let an AddOn do cleanly. They are listed here rather than
quietly worked around.

### Achievement tracker lines also stop being clickable

Turning on **Make tracker quests plain text** also stops achievement lines in the tracker
responding to clicks. The tracker draws quest titles and achievement titles from a single pool of
buttons and does not mark which is which, so there is no way to disable one without the other.

If you track achievements and want them clickable, leave that one option off. Everything else
still works.

### Quest object sparkles cannot be removed

Quest objects in the world glimmer with a sparkle effect that Classic did not have. The client
is supposed to draw an outline instead, and Blizzard's own **Outline** option is meant to control
it — but on this client the outline does not render at all, and the game falls back to the
sparkles. This is a client rendering fault, not something an AddOn can reach: setting the CVar
works, and changes nothing. `particleDensity` and `ffxGlow` were both tried and rejected.

The **Quest object outline** option is offered as an experiment in case a future client build
fixes the rendering. It is off by default because on this build it does nothing.

Note that the same sparkle marks lootable corpses, which *is* Classic behaviour — so removing it
wholesale would cost more than it gained even if it were possible.

### Questgiver `!` marks on the minimap

MoP shows an exclamation mark on the minimap for nearby questgivers; Classic never did. The mark
comes from a shared texture atlas the client packs many icons into, so it cannot be switched off
without replacing the artwork. Parked rather than solved.

## Where it overlaps Blizzard's own options

Three of these settings have a Blizzard checkbox of their own: **Instant Quest Text**,
**Automatic Quest Tracking** and **Outline Mode**. Their tooltips are annotated to say Classic
Questing is driving them, so a checkbox that moves on its own is not a mystery.

Change one of those in Blizzard's options and **Classic Questing follows you** — the matching
option turns off, and turns back on if you put the setting back. Whichever window you use, the two
agree, and the AddOn says in chat which way it went. Your interface wins.

## Compatibility

Built and tested against interface **50504**, client 5.5.4 build 69585. It reads its own version
from the `.toc` rather than carrying it in code, and every Blizzard function it touches is checked
for existence before use — a missing one disables that feature and says so, rather than breaking
the UI.

## Commands

| Command | What it does |
| --- | --- |
| `/cq` | Open the options panel |
| `/cq on` | Turn on the full Classic experience |
| `/cq off` | Disable the AddOn |
| `/cq on <option>` | Turn one option on |
| `/cq off <option>` | Turn one option off |
| `/cq status` | Show what each option is doing |
| `/cq reset` | Restore the default settings |
| `/cq help` | List the commands |
