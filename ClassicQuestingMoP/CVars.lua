-- Classic Questing (MoP) -- CVars
--
-- Every console variable this addon drives to a Classic-correct value.
-- Table-driven on purpose: adding another lever is one row, not another
-- module. Safety rule 4 -- a switch Blizzard maintains beats frame surgery.

local ADDON_NAME, ns = ...

local RULES = {
	{
		-- Tier 1. Removes the numbered quest pins, the blue quest area
		-- highlights, the "Track Quest" checkbox and the quest log panel
		-- inside the fullscreen map. Verified in game.
		key     = "worldMapMarkers",
		cvar    = "questPOI",
		wanted  = "0",
		default = true,
		label   = "world map quest markers",
		onText  = "world map quest markers, blue areas and map quest log hidden",
		offText = "world map quest markers shown again",
	},
	{
		-- Tier 2, opt-in. Newly accepted quests stop auto-tracking. This is
		-- real quality of life, not clutter, so it ships off and the player
		-- chooses it rather than having it chosen for them.
		key     = "autoQuestTracking",
		cvar    = "autoQuestWatch",
		wanted  = "0",
		default = false,
		label   = "automatic tracking of new quests",
		onText  = "newly accepted quests are no longer tracked automatically",
		offText = "newly accepted quests are tracked automatically again",
	},
	{
		-- Tier 3, opt-in. The boss and creature portrait pins MoP puts on
		-- zone maps, which Classic never had. Confirmed working in game.
		-- Recon named the lever: provider 7 is EncounterJournalDataProvider
		-- carrying cvar=showBosses.
		key     = "mapCreaturePortraits",
		cvar    = "showBosses",
		wanted  = "0",
		default = false,
		label   = "world map creature portraits",
		onText  = "world map creature portraits hidden",
		offText = "world map creature portraits shown again",
	},
}

-- Guards re-entry: SetCVar itself fires CVAR_UPDATE.
local applying = false

-- questHelper on this client accepts a write and silently ignores it. Any
-- CVar can behave that way, so every write is read back and verified, and a
-- refused write stands down instead of retrying on every event forever.
local refused = {}

local function readCVar(name)
	local ok, v = pcall(GetCVar, name)
	if not ok then return nil end
	return v
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
	return true
end

local function makeModule(rule)
	local M = ns:RegisterModule(rule.key, {})
	M.rule = rule
	M.onText = rule.onText
	M.offText = rule.offText

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

		writeCVar(rule, rule.wanted)
	end

	function M:Disable()
		local original = ns.db and ns.db.state[rule.cvar]
		if original == nil or refused[rule.cvar] then return end
		applying = true
		pcall(SetCVar, rule.cvar, original)
		applying = false
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

-- Re-assert when anything changes a console variable. The first argument of
-- CVAR_UPDATE has not been consistent across client versions, so rather than
-- match on it, just re-check every value we own on any CVar change.
ns:RegisterEvent("CVAR_UPDATE", function()
	if applying or not ns.db then return end
	for i = 1, #RULES do
		local rule = RULES[i]
		if ns.db.settings[rule.key] and not refused[rule.cvar] then
			if readCVar(rule.cvar) ~= rule.wanted then
				writeCVar(rule, rule.wanted)
			end
		end
	end
end)
