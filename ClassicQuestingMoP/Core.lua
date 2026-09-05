-- Classic Questing in MoP -- Core
--
-- Addon table, saved variables, event dispatch, slash command.
-- Modules register themselves here and are driven from the saved settings.

local ADDON_NAME, ns = ...

ns.title = "Classic Questing (MoP)"

---------------------------------------------------------------------
-- Identity
---------------------------------------------------------------------

-- The .toc is the single source of truth for the version. Never hardcode
-- one here: the recon probe shipped a build announcing 0.4 in chat while
-- its .toc still said 0.3, because the number lived in two places.
local function addonVersion()
	local getter = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
	if type(getter) ~= "function" then return "?" end
	local ok, v = pcall(getter, ADDON_NAME, "Version")
	return (ok and v) or "?"
end

ns.version = addonVersion()

---------------------------------------------------------------------
-- Output
---------------------------------------------------------------------

local PREFIX = "|cff66ccff[Classic Questing]|r "

function ns:Print(msg)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. tostring(msg))
	end
end

-- Safety rule 5: when something expected is missing, say so once and skip
-- the feature. Keyed so a per-frame or per-event failure cannot spam chat.
local warned = {}
function ns:Warn(key, msg)
	if warned[key] then return end
	warned[key] = true
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. "|cffff9955" .. tostring(msg) .. "|r")
	end
end

---------------------------------------------------------------------
-- Event dispatch
---------------------------------------------------------------------

local dispatcher = CreateFrame("Frame")
local handlers = {}

function ns:RegisterEvent(event, fn)
	if not handlers[event] then
		handlers[event] = {}
		dispatcher:RegisterEvent(event)
	end
	local list = handlers[event]
	list[#list + 1] = fn
end

dispatcher:SetScript("OnEvent", function(_, event, ...)
	local list = handlers[event]
	if not list then return end
	for i = 1, #list do
		-- One module throwing must not stop the others, and must not take
		-- the user's UI with it.
		local ok, err = pcall(list[i], event, ...)
		if not ok then
			ns:Warn("evt:" .. event .. ":" .. i,
				"error handling " .. event .. ": " .. tostring(err))
		end
	end
end)

---------------------------------------------------------------------
-- Modules
---------------------------------------------------------------------

-- A module is a table with Enable(), Disable(), and a `setting` key naming
-- the saved variable that drives it. Optional Status() returns one line for
-- the slash command and, later, the options panel.
ns.modules = {}

function ns:RegisterModule(key, module)
	module.key = key
	ns.modules[#ns.modules + 1] = module
	ns.modules[key] = module
	return module
end

---------------------------------------------------------------------
-- Saved variables
---------------------------------------------------------------------

-- Account-wide (see the .toc): someone who wants this wants it everywhere.
local DB_VERSION = 2

-- v1 gave every feature two names: a display key ("mapCreaturePortraits") and
-- a saved-setting name mirroring the CVar ("showBosses"). That was a mistake.
-- It made the name /cq printed different from the name /cq accepted, and it
-- made "showBosses turned on" mean the portraits were hidden. v2 uses one
-- name per feature, describing what the addon does rather than what Blizzard
-- calls the underlying switch.
local RENAMED_IN_V2 = {
	worldMapQuestPOI = "worldMapMarkers",
	minimapQuestPOI  = "minimapMarkers",
	autoQuestWatch   = "autoQuestTracking",
	showBosses       = "mapCreaturePortraits",
}

-- Modules add their own defaults at file scope, before ADDON_LOADED fires.
ns.defaults = {}

function ns:RegisterDefaults(tbl)
	for k, v in pairs(tbl) do
		ns.defaults[k] = v
	end
end

local function initDB()
	ClassicQuestingMoPDB = ClassicQuestingMoPDB or {}
	local db = ClassicQuestingMoPDB

	db.settings = db.settings or {}
	-- Pre-addon values live here so Disable() can put the game back exactly
	-- as it found it. Subtractive addons should leave no trace when off.
	db.state = db.state or {}

	if db.dbVersion == nil then
		db.dbVersion = DB_VERSION
	elseif db.dbVersion < DB_VERSION then
		if db.dbVersion < 2 then
			for old, new in pairs(RENAMED_IN_V2) do
				if db.settings[old] ~= nil and db.settings[new] == nil then
					db.settings[new] = db.settings[old]
				end
				db.settings[old] = nil
			end
			-- The remembered pre-addon tracking state moves with the rename;
			-- losing it would leave Disable unable to restore what the player
			-- actually had.
			if db.state.minimapQuestPOITracking ~= nil and db.state.minimapMarkersTracking == nil then
				db.state.minimapMarkersTracking = db.state.minimapQuestPOITracking
			end
			db.state.minimapQuestPOITracking = nil
		end
		db.dbVersion = DB_VERSION
	end

	for k, v in pairs(ns.defaults) do
		if db.settings[k] == nil then
			db.settings[k] = v
		end
	end

	ns.db = db
end

---------------------------------------------------------------------
-- Applying settings
---------------------------------------------------------------------

function ns:ApplyAll()
	if not ns.db then return end
	for i = 1, #ns.modules do
		local m = ns.modules[i]
		local on = ns.db.settings[m.key]
		local fn = on and m.Enable or m.Disable
		if type(fn) == "function" then
			local ok, err = pcall(fn, m)
			if not ok then
				ns:Warn("apply:" .. tostring(m.key),
					"could not " .. (on and "enable" or "disable") .. " " ..
					tostring(m.key) .. ": " .. tostring(err))
			end
		end
	end
end

-- Toggling takes effect immediately; no /reload.
function ns:Set(key, value)
	if not ns.db then return end
	ns.db.settings[key] = value
	ns:ApplyAll()
end

function ns:ResetDefaults()
	if not ns.db then return end
	wipe(ns.db.settings)
	for k, v in pairs(ns.defaults) do
		ns.db.settings[k] = v
	end
	ns:ApplyAll()
	ns:Print("Settings restored to defaults.")
end

---------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------

ns:RegisterEvent("ADDON_LOADED", function(_, loaded)
	if loaded ~= ADDON_NAME then return end
	initDB()
	ns:ApplyAll()
end)

-- Re-assert on every world entry: login, /reload, zone change and loading
-- screens are all places a setting can quietly drift back.
ns:RegisterEvent("PLAYER_ENTERING_WORLD", function()
	if not ns.db then initDB() end
	ns:ApplyAll()
end)

---------------------------------------------------------------------
-- Slash command
---------------------------------------------------------------------

local function status()
	ns:Print(ns.title .. " v" .. tostring(ns.version))
	for i = 1, #ns.modules do
		local m = ns.modules[i]
		local on = ns.db and ns.db.settings[m.key]
		local line = "  " .. (on and "|cff55ff55on |r" or "|cffff5555off|r") ..
			"  |cffffd100" .. tostring(m.key) .. "|r"
		if type(m.Status) == "function" then
			local ok, extra = pcall(m.Status, m)
			if ok and extra then line = line .. "  -- " .. extra end
		end
		ns:Print(line)
	end
end

SLASH_CLASSICQUESTINGMOP1 = "/cq"
SLASH_CLASSICQUESTINGMOP2 = "/classicquesting"

-- Accept whatever /cq actually printed. Modules have a display key
-- ("mapCreaturePortraits") and a saved-setting name ("showBosses"), and the
-- status list shows the key -- so the key must be a valid handle for
-- /cq on|off. Taking only the setting name made every name on screen an
-- "Unknown setting". Both work now, case-insensitively.
local function resolveSetting(arg)
	if not arg or arg == "" or not ns.db then return nil end
	if ns.db.settings[arg] ~= nil then return arg end

	local lower = arg:lower()
	for k in pairs(ns.db.settings) do
		if k:lower() == lower then return k end
	end
	-- Old v1 names still work, so muscle memory and older notes keep working.
	for old, new in pairs(RENAMED_IN_V2) do
		if old:lower() == lower then return new end
	end
	return nil
end

SlashCmdList["CLASSICQUESTINGMOP"] = function(msg)
	msg = msg or ""
	local cmd = msg:match("^%s*(%S*)") or ""
	cmd = cmd:lower()
	local arg = msg:match("^%s*%S*%s+(%S+)") or ""

	if cmd == "reset" then
		ns:ResetDefaults()

	elseif cmd == "on" or cmd == "off" then
		local want = (cmd == "on")
		if arg == "" then
			for k in pairs(ns.defaults) do ns.db.settings[k] = want end
			ns:ApplyAll()
			ns:Print("All features turned " .. cmd .. ".")
		else
			local key = resolveSetting(arg)
			if key then
				ns:Set(key, want)
				local m = ns.modules[key]
				-- "showBosses turned on" read as though the portraits were
				-- being shown. Say what actually happened instead.
				local effect = m and (want and m.onText or m.offText)
				ns:Print("|cffffd100" .. key .. "|r " .. cmd ..
					(effect and (" -- " .. effect .. ".") or "."))
			else
				ns:Print("Unknown setting '" .. arg .. "'. Try /cq for the list.")
			end
		end

	else
		status()
		local example = ns.modules[1] and ns.modules[1].key or "worldMapMarkers"
		ns:Print("Toggle one with |cffffd100/cq off " .. example ..
			"|r, or all with |cffffd100/cq on|off|r. |cffffd100/cq reset|r restores defaults.")
		ns:Print("The options panel arrives with the Options module.")
	end
end
