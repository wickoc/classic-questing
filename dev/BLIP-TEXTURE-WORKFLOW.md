# Minimap blip sheet — how to blank the questgiver icons

Notes for the one part of this project that cannot be done from Lua.

## Why this exists

The questgiver `!` and `?` on the minimap are drawn by the engine, not by Lua. There are no
frames to hide, no globals, and no CVar. The only lever is `Minimap:SetBlipTexture(path)`,
which swaps the entire icon sheet. Blanking the questgiver cells in a copy of that sheet is
therefore the only route to removing those icons while keeping herbs, vendors and trainers.

## What we know for certain

- Default sheet: `Interface\MINIMAP\ObjectIconsAtlas`
- Restoring it takes effect immediately, no `/reload`. There is a setter but **no getter**, so
  the path above is the only way back.
- `Minimap:SetToDefaults()` **removes the entire minimap frame.** Never call it.
- `/unrecon blip <path>` and `/unrecon blipreset` let a candidate sheet be tested in seconds
  without touching the addon.

## What we deliberately stopped chasing

Which *index* the questgiver uses. `C_Minimap.GetPOITextureCoords(i)` maps an index to a
rectangle, but nothing exposes which index the engine picks for a questgiver blip, so no amount
of probing answers it. The probe's atlas viewers are left in place but are not the way to
resolve this — the image itself is.

Note also that the whole-sheet viewer's boxes do not line up with the art: the coords and the
atlas disagree about the grid. Treat the coords as arithmetic, not as a map.

## Converting a coord to a pixel rectangle

`GetPOITextureCoords` returns `left, right, top, bottom` as fractions of the sheet. Multiply by
the real file dimensions:

```
x0 = left   * width     x1 = right  * width
y0 = top    * height    y1 = bottom * height
```

Worked example — index 124, which renders as an exclamation mark:

```
uv 0.84766  0.91406  0.28320  0.31641

at 512 x 1024  ->  x 434..468, y 290..324   (34 x 34)
at 256 x  512  ->  x 217..234, y 145..162   (17 x 17)
```

Cells come out square when the sheet is twice as tall as it is wide, which is the arithmetic
telling us the true proportions even though the on-screen viewer never looked right.

## The workflow

1. Extract `Interface\MINIMAP\ObjectIconsAtlas.blp` from the game data with a BLP tool.
2. Note the real pixel dimensions. **Tell Claude the dimensions** — the formula above then gives
   exact rectangles for any index.
3. Erase the questgiver cells to full transparency. Erase the cell, do not paint it black; a
   black square is worse than the icon.
4. Save as a power-of-two texture the client will load, keeping the original dimensions, into
   the addon folder.
5. Test immediately: `/unrecon blip Interface\AddOns\ClassicQuestingMoP\<yourfile>`
   (no file extension in the path). `/unrecon blipreset` puts the real sheet back.
6. Check what else changed. Herb nodes, vendors, flight masters and trainers must be untouched.

## The open question, and the cheap way to answer it

The sheet contains several `!` and `?` icons and nothing says which is the questgiver's. The
likelihood is that they are variants of the same idea — normal, daily, low-level, repeatable,
turn-in — in which case a Classic experience wants all of them gone and the ambiguity does not
matter. That is a guess, not a finding.

Rather than reason about it: blank every `!` and `?` cell, load the sheet, and look. If
something that should have stayed has vanished, restore that one cell and retest. Two or three
iterations of step 5 will settle it faster than any amount of probing, because each test is
seconds and the result is unambiguous.

## If this ships

The addon would carry a modified copy of Blizzard's art. Several established addons do exactly
this (Chinchilla, KeyboardsMinimapIcons, DragonUI), but it is the first thing this project would
ship that is not purely subtractive, and it is the author's call rather than a technical one.
