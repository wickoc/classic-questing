-- Vanilla Questing -- CVars
--
-- Every console variable this AddOn drives to a Classic-correct value.
-- Table-driven on purpose: adding another lever is one row, not another
-- module. Safety rule 4 -- a switch Blizzard maintains beats frame surgery.

local ADDON_NAME, ns = ...

local C = ns.color

local RULES = {
	{
		-- Tier 1. Removes the numbered quest pins, the blue quest area
		-- highlights, the "Track Quest" checkbox and the quest log panel
		-- inside the fullscreen map. Verified in game.
		key     = "hideMapQuestHelper",
		cvar       = "questPOI",
		wanted     = "0",
		needsApply = true,
		-- The on-screen quest helper only picks this up when the map pane is
		-- closed and reopened -- reported from play, and not fixed by asking
		-- the tracker to redraw. See refreshQuestUI.
		cyclesMap  = true,
		default = true,
		label   = "world map quest helper",
		onText  = "World map quest markers, blue areas and quest list removed.",
		offText = "World map quest helper restored.",
		group   = "Map and minimap",
		order   = 10,
		title   = "Hide World Map Quest Helper",
		desc    = "Removes the quest markers, the blue objective areas, the Track Quest checkbox and the quest list in the world map.",
	},
	{
		-- Tier 2, opt-in. Newly accepted quests stop auto-tracking. This is
		-- real quality of life, not clutter, so it ships off and the player
		-- chooses it rather than having it chosen for them.
		key     = "noAutoQuestTracking",
		cvar    = "autoQuestWatch",
		-- Blizzard shows this one as "Automatic Quest Tracking". Confirmed by
		-- [G19], which read the variable off Blizzard's own control.
		blizzOption = "Automatic Quest Tracking",
		wanted  = "0",
		-- Ships ON: the Full Classic experience is what people install this
		-- AddOn for, so a fresh install gives exactly that.
		default = true,
		label   = "automatic tracking of new quests",
		onText  = "Newly accepted quests are no longer tracked automatically.",
		offText = "Newly accepted quests are tracked automatically.",
		group   = "Quest Tracker",
		order   = 60,
		title   = "No Automatic Quest Tracking",
		desc    = "Stops quests from instantly appearing in the quest tracker when accepted.",
	},
	{
		-- The variable is not a guess. Probe v0.19 [G19] walked the settings
		-- registry and read it off Blizzard's own control: the option labelled
		-- "Instant Quest Text" is backed by the boolean `instantQuestText`.
		-- Earlier passes failed because they searched the CONSOLE, which this
		-- client cannot enumerate (C_Console.GetAllCommands is absent).
		--
		-- Classic-correct is OFF: quest text types out a line at a time rather
		-- than landing all at once, which is half of why reading it felt like
		-- reading rather than skipping.
		key     = "noInstantQuestText",
		cvar    = "instantQuestText",
		blizzOption = "Instant Quest Text",
		wanted  = "0",
		default = true,
		label   = "instant quest text",
		onText  = "Quest text appears slowly.",
		offText = "Quest text appears instantly.",
		group   = "Quests",
		order   = 40,
		title   = "No Instant Quest Text",
		desc    = "Quest text appears slowly, accompanied by the sound of a quill writing.",
	},
	{
		-- Tier 3, opt-in. The boss and creature portrait pins MoP puts on
		-- zone maps, which Classic never had. Confirmed working in game.
		-- Recon named the lever: provider 7 is EncounterJournalDataProvider
		-- carrying cvar=showBosses.
		key     = "hideBossPortraits",
		cvar       = "showBosses",
		wanted     = "0",
		needsApply = true,
		default = true,
		label   = "boss portraits",
		onText  = "Boss portraits removed from the world map.",
		offText = "Boss portraits restored.",
		group   = "Map and minimap",
		order   = 30,
		title   = "Hide Boss Portraits",
		desc    = "Hides the boss portraits on the world map.",
	},
	{
		-- Tier 3, opt-in, EXPERIMENTAL and off by default.
		--
		-- Unusually for this AddOn it turns something ON. Quest objects and
		-- herbs get either an outline or a sparkle, never both, so switching
		-- the outline on is what suppresses the glimmer -- but only on clients
		-- that can actually render outlines. On the development client the
		-- CVar changes correctly and nothing renders, including through
		-- Blizzard's own options window, so this is a graphics-side fault
		-- rather than anything an AddOn can fix. Offered as a maybe, never
		-- promised, and never part of "turn everything on".
		key          = "outlineMode",
		cvar         = "Outline",
		-- Not a boolean. Outline has four settings on this client, and 1, 2
		-- and 3 are all "outlines are on", differing in what they apply to.
		-- Only 0 is off, so only 0 leaves this option unticked, and a value
		-- the player already chose is never dragged down to `wanted`.
		onValues     = { ["1"] = true, ["2"] = true, ["3"] = true },
		blizzOption  = "Outline Mode",
		-- 2 is Blizzard's own default for this option, so switching it on
		-- from off lands where the game would have put it rather than on the
		-- narrowest setting.
		wanted       = "2",
		default      = false,
		experimental = true,
		label        = "outline mode",
		onText       = "Rendering outlines on quest objects.",
		offText      = "Rendering sparkles on quest objects.",
		group        = "Experimental",
		order        = 110,
		title        = "Outline Mode",
		desc         = "Removes the loot sparkles on quest objects, showing an outline instead.",
		limitation   = "Known limitation: either an outline or loot sparkles must be shown. If the outline fails to render, loot sparkles are shown automatically.",
	},
}

-- Guards re-entry: SetCVar itself fires CVAR_UPDATE.
local applying = false

-- questHelper on this client accepts a write and silently ignores it. Any
-- CVar can behave that way, so every write is read back and verified, and a
-- refused write stands down instead of retrying on every event forever.
local refused = {}

-- Whether a CVar's current value counts as this rule being on. Most are a
-- plain match against `wanted`; a rule with several "on" values lists them.
local function ruleIsOn(rule, value)
	if value == nil then return false end
	if rule.onValues then return rule.onValues[value] and true or false end
	return value == rule.wanted
end

local function readCVar(name)
	local ok, v = pcall(GetCVar, name)
	if not ok then return nil end
	return v
end

-- Redraw the frames whose contents depend on a variable we just changed.
--
-- Changing questPOI with the world map pane open updated the map but left the
-- quest tracker showing its old POI numbers: nothing tells the tracker that a
-- variable it reads has moved, so it keeps whatever it last drew until some
-- other event makes it rebuild. A reload fixed it, which is not a fix.
--
-- Both of these are confirmed present on this client by the probe (v0.9 log)
-- rather than assumed. Existence-checked and pcall'd anyway, per safety rule
-- 5: a client without one of them loses the redraw, not the feature.
--
-- The map is only refreshed when it is actually on screen. The tracker is
-- refreshed unconditionally -- it is always visible, and WatchFrame_Update is
-- what every other part of this AddOn already calls to make it rebuild.
local function mapIsOpen()
	if type(WorldMapFrame) ~= "table" or type(WorldMapFrame.IsShown) ~= "function" then
		return false
	end
	local ok, shown = pcall(WorldMapFrame.IsShown, WorldMapFrame)
	return ok and shown and true or false
end

-- Take the world map through a close and an open, and leave it closed.
--
-- Asking the tracker to redraw was not enough: reported from play, the
-- on-screen quest helper only picks a questPOI change up when the map pane
-- closes and reopens. Whatever the map does on that round trip is not
-- reachable any other way that has been found, so this does the thing that
-- works rather than the thing that ought to.
--
-- The map ends CLOSED either way, which is the shape the author asked for
-- after testing it:
--
--   already open  ->  close, open, close
--   already shut  ->  open, close
--
-- So a shut map is opened for an instant. That is deliberate: the round trip
-- is what refreshes the helper, and half of one does not.
--
-- HideUIPanel and ShowUIPanel have never been probed on this client, so they
-- are existence-checked and the frame's own Hide and Show -- which every Frame
-- has -- are the fallback. The panel functions are preferred because they keep
-- the UI panel manager's idea of what is open in step with reality.
--
-- IN COMBAT TOO, at the author's request. This is the one place the AddOn
-- touches a UI panel during combat, and it is a considered exception rather
-- than an oversight: the world map is not a protected frame on this client, so
-- there is nothing here for the client to block. Every call is wrapped, and a
-- failure says so once instead of failing silently -- which is how this would
-- show up if a future build did protect it.
local function cycleWorldMap()
	if type(WorldMapFrame) ~= "table" then return false end

	local hide = (type(HideUIPanel) == "function") and HideUIPanel or WorldMapFrame.Hide
	local show = (type(ShowUIPanel) == "function") and ShowUIPanel or WorldMapFrame.Show
	if type(hide) ~= "function" or type(show) ~= "function" then return false end

	local ok = true
	local function step(fn)
		local done = pcall(fn, WorldMapFrame)
		ok = ok and done
	end

	if mapIsOpen() then step(hide) end
	step(show)
	step(hide)

	if not ok then
		ns:Warn("map:cycle",
			"could not reopen the world map to refresh the quest helper; " ..
			"open and close it yourself if it looks stale.")
	end
	return ok
end

local function refreshQuestUI(rule)
	if type(WatchFrame_Update) == "function" then
		pcall(WatchFrame_Update)
	end
	if type(QuestMapFrame_UpdateAll) == "function" and mapIsOpen() then
		pcall(QuestMapFrame_UpdateAll)
	end
	-- Only the rules the map and the tracker actually read. Cycling the map
	-- for a variable it does not look at would be a visible jolt for nothing,
	-- and this now fires whether or not the map is already open.
	if rule and rule.cyclesMap then cycleWorldMap() end
end

local function writeCVar(rule, value)
	if refused[rule.cvar] then return false end

	applying = true
	local ok = pcall(SetCVar, rule.cvar, value)
	applying = false

	if not ok then
		refused[rule.cvar] = true
		ns:Warn("cvar:set:" .. rule.cvar,
			"could not set " .. rule.cvar .. "; skipping " .. rule.label .. ".")
		return false
	end


	local now = readCVar(rule.cvar)
	if now ~= value then
		refused[rule.cvar] = true
		ns:Warn("cvar:refused:" .. rule.cvar,
			rule.cvar .. " would not change (asked for " .. tostring(value) ..
			", still " .. tostring(now) .. "). Skipping " .. rule.label .. ".")
		return false
	end
	refreshQuestUI(rule)
	return true
end

local function makeModule(rule)
	local M = ns:RegisterModule(rule.key, {})
	M.onText = rule.onText
	M.offText = rule.offText
	M.experimental = rule.experimental
	M.group = rule.group
	M.title = rule.title
	M.order = rule.order
	M.desc = rule.desc
	M.needsApply = rule.needsApply
	-- A cost the player should read before choosing, not after.
	M.limitation = rule.limitation
	-- The label Blizzard shows for the same thing, where it shows one at all.
	-- Used to annotate Blizzard's control and to decide who wins a conflict.
	M.blizzOption = rule.blizzOption
	M.blizzVariable = rule.blizzOption and rule.cvar or nil

	-- One name: the module key is the saved-settings key is the handle the
	-- player types. The CVar name stays an implementation detail in `rule`.
	ns:RegisterDefaults({ [rule.key] = rule.default })

	function M:Enable()
		if type(GetCVar) ~= "function" or type(SetCVar) ~= "function" then
			ns:Warn("cvar:missing", "GetCVar/SetCVar missing; skipping " .. rule.label .. ".")
			return
		end

		local current = readCVar(rule.cvar)
		if current == nil then
			ns:Warn("cvar:absent:" .. rule.cvar,
				rule.cvar .. " does not exist on this client; skipping " .. rule.label .. ".")
			return
		end

		-- Remember what the player had before we touched it, once, so Disable
		-- restores it rather than guessing at Blizzard's default.
		if ns.db.state[rule.cvar] == nil then
			ns.db.state[rule.cvar] = current
		end

		-- Already at a value that counts as on -- Outline 2 or 3, say -- is
		-- left where the player put it rather than dragged down to `wanted`.
		if not ruleIsOn(rule, current) then
			writeCVar(rule, rule.wanted)
		end
	end

	function M:Disable()
		local original = ns.db and ns.db.state[rule.cvar]
		if original == nil or refused[rule.cvar] then return end

		-- Only when it actually moves. ApplyAll re-applies every module on
		-- every change, so an unconditional restore here writes a value the
		-- variable already holds -- harmless in itself, but it used to drag
		-- refreshQuestUI along with it and cycle the world map every time any
		-- unrelated option was touched.
		if readCVar(rule.cvar) == original then return end

		applying = true
		pcall(SetCVar, rule.cvar, original)
		applying = false
		refreshQuestUI(rule)
	end

	function M:Status()
		local v = readCVar(rule.cvar)
		if v == nil then return rule.cvar .. " missing" end
		if refused[rule.cvar] then
			return rule.cvar .. " = " .. tostring(v) .. " (write refused)"
		end
		return rule.cvar .. " = " .. tostring(v)
	end

	return M
end

for i = 1, #RULES do
	makeModule(RULES[i])
end

-- Something changed a console variable. The first argument of CVAR_UPDATE has
-- not been consistent across client versions, so rather than match on it, just
-- re-check every value we own on any CVar change.
--
-- What happens next depends on whether Blizzard shows a control for it:
--
--   No Blizzard control -- questPOI, showBosses. Nothing in the interface
--   claims to own these, so the AddOn re-asserts. Something moved it behind
--   the player's back and putting it back is the whole job.
--
--   Blizzard HAS a control -- Instant Quest Text, Automatic Quest Tracking,
--   Outline Mode. Then the AddOn's option simply MIRRORS the variable, in both
--   directions. Safety rule 4: do not fight the player's UI.
--
-- v0.14.0 got the second case half right and it showed. It only handled "our
-- option is on and the variable moved away", so:
--
--   * Outline never responded at all -- that option ships OFF, so the branch
--     was unreachable.
--   * Automatic Quest Tracking yielded once and then went dead, because after
--     yielding the option was off and the branch was unreachable again.
--   * Turning a Blizzard control back to what this AddOn wants never turned
--     the matching option back on.
--
-- One direction is not a sync. Mirroring both ways is.
ns:RegisterEvent("CVAR_UPDATE", function()
	if applying or not ns.db then return end

	for i = 1, #RULES do
		local rule = RULES[i]
		if not refused[rule.cvar] then
			local now = readCVar(rule.cvar)
			local on = ns.db.settings[rule.key] and true or false

			if now == nil then
				-- nothing to compare against

			elseif rule.blizzOption then
				-- The player owns this one. Follow it, whichever way it went.
				local shouldBeOn = ruleIsOn(rule, now)
				if shouldBeOn ~= on then
					ns.db.settings[rule.key] = shouldBeOn

					if shouldBeOn then
						-- Adopted rather than applied: the player set this
						-- themselves, so there is no pre-AddOn value to
						-- remember that has not been remembered already.
						ns:Print(C.highlight .. rule.blizzOption .. C.close ..
							" was changed in Blizzard's options, so " .. C.highlight ..
							rule.key .. C.close .. " is now " .. C.on .. "on" .. C.close .. ".")
					else
						-- What the player has now IS what to restore later.
						ns.db.state[rule.cvar] = now
						ns:Print(C.highlight .. rule.blizzOption .. C.close ..
							" was changed in Blizzard's options, so " .. C.highlight ..
							rule.key .. C.close .. " is now " .. C.off .. "off" .. C.close .. ".")
					end

					if ns.RefreshOptions then ns.RefreshOptions() end
				end

			elseif on and not ruleIsOn(rule, now) then
				writeCVar(rule, rule.wanted)
			end
		end
	end
end)
