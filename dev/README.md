# dev

Everything here is development material. **None of it ships with the AddOn.**

## `UnmarkedRecon/`

A throwaway probe AddOn, kept deliberately separate from Vanilla Questing so nothing
investigative can leak into the shipped code. It reports what this client actually has, rather
than what an AddOn author might expect it to have.

Its design rule is *discover, don't guess*: where an early pass asked "does the name I expect
exist?", it now enumerates what is really there — method tables, provider objects, tracking
types, registered settings — so a negative result means "not present" rather than "I guessed the
wrong name".

Sections are tagged `[G1]`..`[G27]` and map onto the conclusions in `../SPEC.md`. An `ACTIVE`
table at the top of `Recon.lua` decides which ones print; settled sections are switched off but
kept in full, one flag away from running again.

`Templates.xml` carries any frame template a probe section needs to render; `[G27]` is the
first to use one.

```
/unrecon              run it, summary to chat and the full report to SavedVariables
/unrecon print        dump the whole report to chat
/unrecon copy         a selectable box to copy out of
```

Then `/reload` to flush SavedVariables to disk and read
`_classic_\WTF\Account\<ACCOUNT>\SavedVariables\UnmarkedRecon.lua`.

## `knowledge/`

Reference material, and the one part of `dev/` that is not about this AddOn: what the client
exposes, how other people solved the same problems, and what a port to another client faces.

The find that started it is **Blizzard's own interface source for this exact build**. The `classic`
branch of `Gethe/wow-ui-source` reads `5.5.4.69585` in `version.txt` — this client, to the
revision — and it ships the client's generated API documentation with it. `fetch_client_source.sh`
clones it; `build_api_index.lua` turns the documentation into two committed index files so
"does this exist on 5.5.4" is answerable with no network and no client.

It does **not** replace `UnmarkedRecon/`. The source says what exists and what Blizzard's code does
with it; only the game says whether a call is protected, whether a write takes, and whether the
result looks right. Read the source first and probe what the source cannot answer — the one thing
that stays banned is asserting behaviour from memory.

Start at [`knowledge/CLIENT-SOURCE.md`](knowledge/CLIENT-SOURCE.md).

## `recon-log-*.txt`

The raw output of past probe runs, kept because **every conclusion in `SPEC.md` is evidence from
one of these**, and this client is old content on a new engine where the usual assumptions do not
hold. They are the reason a claim in the spec can be checked instead of trusted.

Named by probe version and run date. Superseded logs are kept rather than pruned: a later run
switches settled sections off, so the earlier file is the only remaining record of that answer.

## `tests/`

The off-client test suite. The AddOn cannot be run here, so `addon_harness.lua` stands up a stub
WoW environment — frames, CVars, events, the tracking API, the Settings API, bag and tracker
frames — and `run_tests.lua` drives the real AddOn files against it.

```sh
cd dev/tests && ./run.sh
```

Needs `lua5.1`, the client's own Lua version, so the same forward-reference and scoping rules
apply here as in game — a trap this project has hit twice.

Twelve scenarios, including the ones that matter for a subtractive AddOn: a client with no Settings
API, one that refuses a CVar write, one with no `C_Minimap`, and one where registration half
succeeds and the panel must fall back rather than half-work.

**The suite models the client, so a gap in the model is a gap in the testing.** It once passed
412 checks on a build that froze the game, because it had no `SettingsPanel` and so never called
the hook the freeze recursed through. When a bug gets through, the harness gets the fix too.

## Where bugs live

**GitHub Issues**, not a file in the repository. `BUGS.md` existed briefly and was the wrong
place: a bug is a conversation with a state, and a markdown file has neither.

## `BLIP-TEXTURE-WORKFLOW.md`

The manual texture-edit workflow for the questgiver `!` blips, including the UV-to-pixel formula
and a warning about `Minimap:SetToDefaults()`, which destroys the minimap frame.
