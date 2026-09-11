# AGENT.md — read this first, every run

Notes to myself about this repository: where things live, what has to move together, and the
rules that have been paid for with a bug. **This file is part of the work.** When a rule changes,
or a new place appears that has to be kept in step with another, it is updated in the same pass
as the change itself.

---

## What this is

**Vanilla Questing** — a World of Warcraft AddOn for **Mists of Pandaria Classic**, 5.5.4 (build
69585), interface `50504`. It turns off MoP's quest-helper layer so questing feels like the
original game.

**Everything it does is subtractive.** It hides or switches off Blizzard UI. It never adds quest
data of its own, and it leaves no trace when disabled — every value it changes is remembered
first and put back.

---

## The one rule that matters most

**I cannot run this.** There is no client here. The AddOn is tested off-client against a stub
harness, and the harness only catches what it models — which has now failed five times in a row
on exactly the things a stub cannot know: the client's timing, its layout order, its resize
order.

So:

- **Every change ships with a numbered in-game checklist** in the reply. That is the only real
  test there is.
- **Never guess an API name from training data.** This is old content on a new engine and the
  usual assumptions do not hold. The recon log wins over the spec, the spec wins over memory, and
  a contradiction between them gets flagged, not quietly resolved.
- When a fix depends on *when* it runs, **prove the moment before tuning the value.**
- When a report from the game contradicts the model, **the model is wrong.** Fix the harness
  first, watch it go red, then fix the code.

---

## Where everything lives

### Shipped

```
VanillaQuesting/
  VanillaQuesting.toc   <- the ONLY place the version number exists
  Templates.xml         the description row for the settings list; Blizzard has none
  Core.lua              addon table, palette, events, saved variables, slash commands
  CVars.lua             table-driven console-variable rules (RULES)
  Minimap.lua           minimap quest markers, via C_Minimap tracking
  QuestFrame.lua        the questgiver portrait frame
  Tooltip.lua           quest progress appended to tooltips
  Tracker.lua           WatchFrame: plain text, item buttons, turn-in popups
  Bags.lua              the quest highlight on bag items
  Options.lua           settings panel; loaded last because it walks every module
```

### Not shipped

```
AGENT.md                this file
CHANGELOG.md            short, per-version, user-facing. The release workflow reads it.
.github/workflows/release.yml   builds the zip and publishes on a version tag
SPEC.md                 the living record: work list, architecture, rules, version history,
                        recon conclusions. Long. Structured as
                        core -> Version history -> Recon results.
STRINGS.md              every player-visible string, labelled. A RECORD of what ships.
README.md               the public front page
dev/README.md           what the probe is, why old logs are kept, how to run the tests
dev/UnmarkedRecon/      the probe AddOn. Dev-only, never folded into Vanilla Questing.
                        Recon.lua + Templates.xml. Sections G1..G27; the ACTIVE
                        table switches them on and off.
dev/recon-log-*.txt     raw probe output. Every conclusion in SPEC.md is evidence from one.
                        Kept, never pruned: a later run switches settled sections off, so an
                        earlier log is often the only remaining record of an answer.
dev/BLIP-TEXTURE-WORKFLOW.md   how the minimap blip atlas would be replaced
dev/tests/              the off-client suite. ./run.sh: static checks first
                        (lint_forward_refs.py, luac on every Lua file including
                        the probe, XML well-formedness), then twelve scenarios.
```

---

## What has to move together

Change one of these and the others are part of the same change, not a follow-up.

| If I change… | …then also |
| --- | --- |
| **The version** | `VanillaQuesting.toc` **only** — everything reads it back through `GetAddOnMetadata`. Then the stub in `dev/tests/addon_harness.lua`, a `## <version>` section in `CHANGELOG.md`, and the tag (see Releasing). |
| **Any player-visible string** | `STRINGS.md`, in the same pass. Both panels if it appears in both. |
| **An option's description or limitation** | `STRINGS.md`, `README.md` if it is user-facing behaviour, the native tooltip *and* the canvas fallback tooltip — they have drifted apart twice. |
| **A module** | Give it a unique `order`; add it to the panel and to `/vq status` (all three are guarded by tests). Update `SPEC.md`'s work list. |
| **Anything about what the AddOn can't do** | `README.md` Known limitations and `SPEC.md` Known limitations. Both say the same thing or one of them is wrong. |
| **A feature, or a command** | Flag it for the **CurseForge page**, which is edited by hand in the dashboard and is not in this repository. A listing is a public promise and goes stale silently, and nothing here can check it. |
| **A rule I learn the hard way** | This file. |

### Backlog and bugs do **not** live in a file

They are [GitHub Issues](https://github.com/wickoc/vanilla-questing/issues). `SPEC.md` points at
the tracker and does not list them — a copy goes stale the first time an issue is closed
elsewhere.

**Every issue I open gets:** a label, the repository owner as assignee, and a body that says what
the behaviour is, why it matters, and what has already been ruled out.

**The CurseForge page is not in this repository.** It is written and edited by hand in the
CurseForge dashboard; there is no API for page content, and CurseForge is egress-blocked from this
session anyway. When a change affects what the listing claims, say so in the reply — that is the
only mechanism there is.

**I cannot create releases or push tags** — this session's GitHub token is refused for both.
Milestones, issues and comments do work. What
I can do is get everything ready and say precisely what is left to run. The author tags, or uses
the **Releases → Draft a new release** page on GitHub, which creates the tag itself.

---

## Conventions

- **Versioning.** `MAJOR.MINOR.PATCH`. The `.toc` is the single source of truth — a version
  string hardcoded in Lua is how the probe once shipped announcing 0.4 while its `.toc` said 0.3.
- **Branch.** Work lands on `main` directly.
- **"AddOn"**, not "addon", in every user-visible string and in comments.
- **One name per feature.** The module key is the saved-settings key is the name the player
  types. The CVar name stays an implementation detail inside `CVars.lua`.
- **Report the effect, not the switch.** `/vq on X` says what changed, never the CVar transition.
- **Colours come from `ns.color` in `Core.lua`.** Nowhere else. The yellows and whites are the
  game's own globals so the AddOn cannot drift from the interface it sits inside.
- **Commit messages** say what changed and what it cost to find. No model identifiers anywhere in
  the repository.

---

## Lua traps this project has actually hit

1. **Forward references.** A `local` declared halfway down a file resolves as a **nil global** in
   everything above it. Four times now: three silent failures inside `pcall`s in the AddOn, and
   once in the probe, where it stopped `/unrecon` running at all. `luac -p` accepts it and every
   scenario passes over it. **File-level locals go at the top of the file**, and
   `dev/tests/lint_forward_refs.py` (run first by `run.sh`) now catches it.
2. **`table.sort` is not stable in 5.1.** Two modules sharing an `order` could swap between
   logins. Every module has a unique order, and a test guards it.
3. **A guard flag raised too early.** An early `return` past the reset leaves the guard stuck on,
   which silently switches the feature off. Raise it around the part that needs it, not at the
   top of the function.
4. **Re-entrancy through Blizzard's own callbacks.** Writing a setting can signal the panel, which
   refreshes, which writes. One boolean was not enough — it took a depth counter. That bug froze
   the client on *any* options panel opening, with 345 green checks.
5. **`pcall` hides a missing method as easily as a failing one.** Existence-check first when the
   difference matters. It also hides a function that was never defined: a whole helper once went
   missing from `Options.lua` and the only symptom was the native panel quietly falling back.
6. **An edit script that fails an assert part-way leaves the file untouched.** One did, I moved
   on, and half a feature was missing for two rounds of debugging. **One edit per script**, and
   re-read the file when an assert fires.
7. **A test that reads back what was just written proves nothing about the screen.** Every CVar
   check here read the variable back, and all of them passed while the UI sat stale. Count the
   redraw, not the value.
8. **A conditional diagnostic fires exactly when you do not need it.** A probe's template census
   was gated behind "found nothing", one false-positive match satisfied the gate, and the useful
   half never printed. Dumps are cheap; print them unconditionally.
9. **An enumeration is only a negative for the thing it enumerates.** Listing the ways to *build*
   an element is not listing the elements that *exist*. Where the game visibly does something, "I
   found no API for it" is a statement about my search, not about the client. Go at it from the
   live UI instead — that is how `instantQuestText` was found, twice over.
10. **The safety rules are not a checklist to reason around.** Safety rule 1 says never touch a
   protected frame in combat; I decided the world map was an exception on an assumption I had not
   probed, and it threw in play — twice, because the second attempt only moved when it ran. When a
   rule and a guess disagree, the rule wins.
11. **A cosmetic win is never worth a visible defect.** Where a nicety and a correctness
   requirement are drawn from the same thing, take the correct one and drop the nicety — do not
   ship both half-working. The AddOn takes the orange label only when it can also keep the tooltip
   title white.
12. **A guard that cannot fail is not a guard.** Break the fix and watch the check go red before
   believing it. One tracker assertion passed whether or not the fix existed, because another
   code path was already calling the same function.

---

## Client facts worth not re-deriving

- **`WatchFrame`**, not `ObjectiveTrackerFrame`. Unprotected. `WATCHFRAME_LINKBUTTONS`,
  `WatchFrameItem<N>`, `WatchFrameAutoQuest_*`.
- **`QuestModelScene`** is the questgiver portrait frame. `QuestNPCModel` is only a region prefix.
- **`Settings.RegisterVerticalLayoutCategory` returns `category, layout`** — two values.
- **`CreateSettingsListSectionHeaderInitializer(name[, tooltip])`** is a plain global; the second
  argument **does** land in `data.tooltip` (`[G23]`), and `GetTemplate()` is
  `SettingsListSectionHeaderTemplate`.
- **No Blizzard settings element takes a paragraph** (`[G23]`, `[G25]`, `[G26]`) — but
  **`Settings.CreateElementInitializer` renders a template the AddOn ships itself**, confirmed in
  game by `[G27]`. That is `Templates.xml`, and it is how the Experimental note is drawn. A
  FontString with a fixed width and **no height** is what makes it wrap instead of ellipsising.
- **`--` is illegal inside an XML comment** and takes the whole file down with it, which the
  client then reports as a missing template three steps later. `run.sh` parses every XML file now.
- **An initializer this client ACCEPTS is not one it can RENDER.** Three templates built without
  error, added without error, and drew no frame. Building it proves nothing; only looking does.
- **Three wrong answers on one question came from reasoning about lists instead of rendering
  something.** When the question is "can this be drawn", draw it.
- **A checkbox's label and its tooltip title both come from `data.name`, and there is no
  `SetTooltipFunc`** (`[G23b]`). One string, one colour — so an option's name cannot be coloured
  in the native panel without colouring its tooltip title too. Settled; do not retry.
- **`HideUIPanel` / `ShowUIPanel` / `ToggleWorldMap` have never been probed.** Existence-check
  them; `Frame:Hide`/`Show` are the certain fallback.
- **The world map is protected in combat.** Cycling it mid-fight throws "Interface action failed
  because of an AddOn" and does nothing — and deferring to `PLAYER_REGEN_ENABLED` throws the same
  error, so there is no way round it. Guard with `InCombatLockdown` and move on; this is settled
  and not worth revisiting.
- **`Outline` is not a boolean.** 1, 2 and 3 all mean on; only 0 is off. `2` is Blizzard's default.
- **`C_Console.GetAllCommands` is absent**, so CVars cannot be enumerated. Blizzard's settings
  registry (`SettingsPanel.categoryLayouts` → `initializers` → `init:GetSetting()`) is the
  discovery route, and it is how `instantQuestText` was found.
- **A tooltip's height is set by the client *after* every hook in the frame.** The only correction
  that is not a frame late is inside `OnSizeChanged`.
- **Nothing tells a frame that a CVar it reads has changed.** It keeps what it last drew. After
  writing one, ask for the redraw: `WatchFrame_Update`, and `QuestMapFrame_UpdateAll` when the map
  is on screen. Both confirmed present by the v0.9 probe.

---

## Releasing

`.github/workflows/release.yml` does it. Push a tag and it runs the tests, builds
`VanillaQuesting-<version>.zip` with a top-level `VanillaQuesting/` folder (so it extracts
straight into `Interface\AddOns\`), takes the release notes from that version's section of
`CHANGELOG.md`, and publishes.

```
git tag -a v1.2.3 -m "v1.2.3" && git push origin v1.2.3
```

The job **fails on purpose** if the tag and the `.toc` disagree about the version. That is the
check, not an inconvenience.

---

## Running the tests

```
cd dev/tests && ./run.sh
```

Ten scenarios, every one of which exists because something escaped. A new guard belongs with the
bug that earned it, and it should be checked by breaking the fix and watching it go red — a guard
that has never failed has never been shown to measure anything.
