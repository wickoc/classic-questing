# Changelog

What changed in each version. Newest first.

The long form — what a change cost to find, and why it was made that way — is the version history
in [`SPEC.md`](SPEC.md).

## 1.0.0

First release.

- Quest progress removed from tooltips now resizes the tooltip in the same frame, so it no longer
  grows and then shrinks. ([#2](https://github.com/wickoc/vanilla-questing/issues/2))
- Outline Mode states its known limitation on the option itself.
- The canvas fallback panel now shows an option's known limitation, which only the native panel
  did.
- The note that the Vanilla preset leaves experimental options alone now sits under the
  Experimental heading, out of chat and the preset tooltip.
- Experimental options are named in orange, in the panel and in `/vq status`.
- Changing an option from chat with the world map open now redraws the map's quest list, instead
  of leaving it stale until a reload. ([#11](https://github.com/wickoc/vanilla-questing/issues/11))

## 0.18.0

- Applied a full review of every player-visible string.
- Five option categories, in both panels.
- Turning off the minimap option now restores Blizzard's Track Quest POIs default.

## 0.17.0

- Fixed two pairs of options that could swap places in the panel between logins.
- Every option is guaranteed to appear in both the panel and `/vq status`.

## 0.16.1

- Fixed quest progress tooltips removing nothing when the tooltip was already on screen.

## 0.16.0

- Added: the framed questgiver portrait beside quest text.
- Added: quest progress appended to tooltips.
- One colour palette across the whole AddOn.

## 0.15.1

- Repository audit; the test suite moved into the repository.

## 0.14.3

- The Defaults button rebuilds the panel immediately.

## 0.14.1 – 0.14.2

- Blizzard's own checkboxes and this AddOn's options now follow each other in **both** directions,
  and chat says which way it went.

## 0.14.0

- Where an option overlaps a Blizzard setting, Blizzard's tooltip says so.
- Fixed the options panel closing by the wrong route.

## 0.13.0

- Added: Instant Quest Text.
- Added: the quest highlight on bag items.

## 0.12.1

- **Fixed a freeze** when opening any options panel.

## 0.12.0

- Added the tracker options: plain-text quest titles, and the quest item use buttons.

## 0.11.0

- Blizzard's own Apply button, and a section heading in the panel.

## 0.10.0

- The options panel is now built from Blizzard's own controls.

## 0.5.0 – 0.9.3

- Added the options panel, then reworked it to match Blizzard's.

## 0.4.0

- Added the experimental outline option.

## 0.3.0

- One name per feature, with a saved-variables migration.

## 0.2.0

- Opt-in CVar options; clearer tracking messages.

## 0.1.0

- Core, CVars and minimap quest markers.
