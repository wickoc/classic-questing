-- Classic Questing in MoP -- CVars
--
-- Tier 1 world map. The whole world map job is one console variable:
-- questPOI 0 removes the numbered quest pins, the blue quest area
-- highlights, the "Track Quest" checkbox, and the quest log panel inside
-- the fullscreen map. Verified in game; see SPEC.md conclusion G5.
--
-- This is why there is no WorldMap.lua. Safety rule 4 prefers a switch
-- Blizzard maintains over frame surgery that a patch will break.

local ADDON_NAME, ns = ...

local M = ns:RegisterModule("worldMapMarkers", {})
M.setting = "worldMapQuestPOI"

ns:RegisterDefaults({
	-- Tier 1 ships default-on.
	worldMapQuestPOI = true,
})

local CVAR = "questPOI"
local WANTED = "0"

-- Guards re-entry: SetCVar itself fires CVAR_UPDATE.
local applying = false

-- questHelper on this client accepts a write and silently ignores it. Any
-- CVar can behave that way, so every write is read back and verified, and
-- a refused write stops rather than retrying on every event forever.
local refused = false

local function readCVar()
	local ok, v = pcall(GetCVar, CVAR)
	if not ok then return nil end
	return v
end

local function writeCVar(value)
	if refused then return false end
	applying = true
	local ok = pcall(SetCVar, CVAR, value)
	applying = false

	if not ok then
		refused = true
		ns:Warn("cvar:set:" .. CVAR, "could not set " .. CVAR .. "; skipping world map markers.")
		return false
	end

	local now = readCVar()
	if now ~= value then
		refused = true
		ns:Warn("cvar:refused:" .. CVAR,
			CVAR .. " would not change (asked for " .. tostring(value) ..
			", still " .. tostring(now) .. "). Skipping world map markers.")
		return false
	end
	return true
end

local function enforce()
	if applying or refused then return end
	if not ns.db or not ns.db.settings[M.setting] then return end
	if readCVar() ~= WANTED then
		writeCVar(WANTED)
	end
end

function M:Enable()
	if type(GetCVar) ~= "function" or type(SetCVar) ~= "function" then
		ns:Warn("cvar:missing", "GetCVar/SetCVar missing; skipping world map markers.")
		return
	end

	local current = readCVar()
	if current == nil then
		ns:Warn("cvar:absent:" .. CVAR, CVAR .. " does not exist on this client; skipping world map markers.")
		return
	end

	-- Remember what the player had before we touched it, once, so Disable
	-- can restore it rather than guessing at Blizzard's default.
	if ns.db.state[CVAR] == nil then
		ns.db.state[CVAR] = current
	end

	writeCVar(WANTED)
end

function M:Disable()
	local original = ns.db and ns.db.state[CVAR]
	if original == nil or refused then return end
	applying = true
	pcall(SetCVar, CVAR, original)
	applying = false
end

function M:Status()
	local v = readCVar()
	if v == nil then return "questPOI missing" end
	if refused then return "questPOI = " .. tostring(v) .. " (write refused)" end
	return "questPOI = " .. tostring(v)
end

-- Re-assert when anything changes a console variable. The first argument of
-- CVAR_UPDATE has not been consistent across client versions, so rather than
-- match on it, just re-check our own value on any CVar change.
ns:RegisterEvent("CVAR_UPDATE", enforce)
