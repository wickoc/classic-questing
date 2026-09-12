# Retail: what a port would have to remove

Nobody on this project has played retail. Everything here is second-hand, and the source of each
claim is named so it can be checked rather than inherited. **None of it is verified.** It exists so
that when the retail port starts (issue #5) it starts from a list instead of a blank page.

Verification is cheap now: the same mirror that holds this client's source holds retail's.

```sh
dev/knowledge/fetch_client_source.sh live /tmp/wow-ui-live
```

## Reported by a player, unverified

Passed to this project as suggestions from someone who plays retail. Quoted so the wording is not
laundered into a fact:

> "Have you considered using the Zone Map instead of the minimap? It doesn't show all the things
> that the minimap or World map does. Enable it with Shift+M"

A different feature from anything this AddOn touches — not a removal but an alternative surface.
Worth knowing; not obviously ours to switch on for someone.

> "Turn off outline mode, will enable the sparkles. If you turn off Particle Density in Graphics
> options, it will remove the sparkles. I can't find any other way to disable them. There is no
> CVAR or other way to do it in lua."

**This matches what this project found on 5.5.4 independently**, which is the strongest signal in
the whole page: outline and sparkle are alternatives in the engine, and `particleDensity` takes the
sparkle away along with the particles on lootable corpses. Two clients, ten years apart, same
answer. It raises the confidence that the Outline Mode limitation is a property of the engine rather
than of this expansion.

> "You can disable the yellow circles around quest mobs, with `/console ShowQuestUnitCircles 0`"

**`ShowQuestUnitCircles` is also on 5.5.4** — it is in this client's own settings code
(`Blizzard_SettingsDefinitions_Frame/Nameplates.lua:373`), driven from the nameplate options. So
this is not a retail-only lever; it is a lever this AddOn does not currently pull on either client.
See `CLIENT-SOURCE.md`.

> "Afraid, I can't find a way to easily disable the quest information on tooltips. Blizzard removed
> the CVAR to do so in Shadowlands. It's quite a big task, to go in and edit the tooltip manually.
> I've tried that before, and getting it aligned probably was a bitch."

The CVar meant is almost certainly `showQuestTrackingTooltips`, which Advanced Interface Options
still carries in its catalogue and which does not appear anywhere in the 5.5.4 interface source.

The second half of that quote is the interesting half: **editing the tooltip by hand and keeping it
aligned is exactly the module this AddOn already ships**, and the alignment problem they gave up on
is the one that took six attempts and landed in `OnSizeChanged`. On retail the tooltip is built
through `C_TooltipInfo` and `TooltipDataProcessor` rather than by appending lines, so the technique
will not port — but the problem is known-solved once, which is more than the person who tried had.

## The two threads, as evidence of demand

Given to this project as "things the AddOn likely needs to remove in the retail client". **Neither
has been read** — both domains are blocked from the development environment — so there is no
summary here, deliberately.

- <https://www.mmo-champion.com/threads/2644576-Should-the-game-remove-quest-assistance-area-maps-and-focus-more-on-exploration>
- <https://eu.forums.blizzard.com/en/wow/t/please-allow-to-turn-off-the-quest-helper/529991>

Read them on a machine that can, and pull the named features into a checklist. A thread full of
people saying which specific thing they want gone is a feature list written by the audience.

### And then post in them

**Once the retail port ships, say so in both threads.** They are people asking for this AddOn
before it existed for their client, which is the least cold audience it will ever have. Recorded on
issue #5 so it is not remembered only here.

Same tone as everywhere else: what it does, that it is free, one link. Not a pitch.

## What is known to be structurally different

From reading MapCleaner (retail) beside this client's source — see `REFERENCE-ADDONS.md`:

| | 5.5.4 | retail |
| --- | --- | --- |
| Map quest pins | `questPOI` + `questHelper` CVars gate Blizzard's own code | no such gate; pins come from data providers and must be removed per-pin |
| Quest tracker | `WatchFrame`, `WATCHFRAME_LINKBUTTONS` | `ObjectiveTrackerFrame` and its modules |
| Tooltip quest lines | appended lines, removable by editing the tooltip | built through `C_TooltipInfo` / `TooltipDataProcessor` |
| Typewriter quest text | `instantQuestText` off, and the client types it | gone from the client; AddOns re-implement it in Lua |
| Minimap quest markers | `C_Minimap` tracking entry | unverified |
| Quest unit circles | `ShowQuestUnitCircles` | `ShowQuestUnitCircles` |

Four of the twelve options are a rewrite rather than a port, on this reading. That is the number
issue #5 should be sized against.
