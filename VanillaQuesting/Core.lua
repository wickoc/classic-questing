-- Vanilla Questing -- Core
--
-- AddOn table, saved variables, event dispatch, slash command.
-- Modules register themselves here and are driven from the saved settings.

local ADDON_NAME, ns = ...

-- What the player sees, everywhere. The folder and the CurseForge listing
-- keep the (MoP) suffix so the right build can be identified for download;
-- inside the game it is just the AddOn's name.
ns.title = "Vanilla Questing"

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

-- One palette, one definition.
--
-- The yellows and whites are the GAME's own colour codes where the client
-- offers them, not values typed in here: NORMAL_FONT_COLOR_CODE is what
-- Blizzard's own tooltips and option labels use, so taking it from the client
-- means this AddOn cannot drift away from the interface it is trying to sit
-- inside. The literals are fallbacks for a client that does not define them,
-- and they are the same values those globals hold.
ns.color = {
	-- Blizzard's own
	body        = NORMAL_FONT_COLOR_CODE    or "|cffffd100",  -- the standard yellow
	highlight   = NORMAL_FONT_COLOR_CODE    or "|cffffd100",
	title       = HIGHLIGHT_FONT_COLOR_CODE or "|cffffffff",
	muted       = GRAY_FONT_COLOR_CODE      or "|cff808080",
	close       = FONT_COLOR_CODE_CLOSE     or "|r",

	-- This AddOn's own. One orange, used for every warning-ish thing:
	-- the Experimental heading, the experimental note, and known limitations.
	-- There were two near-identical oranges; this is the survivor.
	brand        = "|cff66ccff",
	experimental = "|cffff8019",
	warning      = "|cffff9955",
	on           = "|cff55ff55",
	off          = "|cffff5555",
}

local C = ns.color

local PREFIX = C.brand .. "[" .. ns.title .. "]" .. C.close .. " "

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
		DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. C.warning .. tostring(msg) .. C.close)
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

-- One ordering, used by the options panel and by /vq status alike, so the two
-- cannot drift apart.
function ns:SortedModules()
	local list = {}
	for i = 1, #ns.modules do list[#list + 1] = ns.modules[i] end
	table.sort(list, function(a, b) return (a.order or 999) < (b.order or 999) end)
	return list
end

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
local DB_VERSION = 3

-- v1 gave every feature two names: a display key ("hideBossPortraits") and
-- a saved-setting name mirroring the CVar ("showBosses"). That was a mistake.
-- It made the name /vq printed different from the name /vq accepted, and it
-- made "showBosses turned on" mean the portraits were hidden. v2 uses one
-- name per feature, describing what the AddOn does rather than what Blizzard
-- calls the underlying switch.
local RENAMED_IN_V2 = {
	worldMapQuestPOI = "hideMapQuestHelper",
	minimapQuestPOI  = "hideMinimapQuestHelper",
	autoQuestWatch   = "noAutoQuestTracking",
	showBosses       = "hideBossPortraits",
}

-- Modules add their own defaults at file scope, before ADDON_LOADED fires.
ns.defaults = {}

function ns:RegisterDefaults(tbl)
	for k, v in pairs(tbl) do
		ns.defaults[k] = v
	end
end

local function initDB()
	VanillaQuestingDB = VanillaQuestingDB or {}
	local db = VanillaQuestingDB

	db.settings = db.settings or {}
	-- Pre-AddOn values live here so Disable() can put the game back exactly
	-- as it found it. Subtractive AddOns should leave no trace when off.
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
			-- The remembered pre-AddOn tracking state moves with the rename;
			-- losing it would leave Disable unable to restore what the player
			-- actually had.
			if db.state.minimapQuestPOITracking ~= nil and db.state.minimapMarkersTracking == nil then
				db.state.minimapMarkersTracking = db.state.minimapQuestPOITracking
			end
			db.state.minimapQuestPOITracking = nil
		end
		if db.dbVersion < 3 then
			-- The preset was stored as well as derived, and the stored copy
			-- went unread from v0.11.0 onwards -- the panel has computed it
			-- from the options ever since. Clear the orphan rather than leave
			-- a key in everyone's saved variables that nothing consults.
			db.preset = nil
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

-- No reload notice here. Tested in game: after a slash toggle the next time
-- the world map opens it is already correct, so telling the player to /reload
-- would be advice for a problem they do not have.

-- silent: the options panel resets in place and the player can see the result,
-- so it does not need a chat line.
function ns:ResetDefaults(silent)
	if not ns.db then return end
	wipe(ns.db.settings)
	for k, v in pairs(ns.defaults) do
		ns.db.settings[k] = v
	end
	ns:ApplyAll()
	if not silent then
		ns:Print("Restored default options.")
	end
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
	ns:Print(ns.title .. " v" .. tostring(ns.version) .. " - Status and list of options")
	local ordered = ns:SortedModules()
	for i = 1, #ordered do
		local m = ordered[i]
		local on = ns.db and ns.db.settings[m.key]
		-- The live CVar readout is for developer eyes; the player wants to
		-- know what is on.
		ns:Print("  " .. (on and (C.on .. "on " .. C.close) or (C.off .. "off " .. C.close)) ..
			"  " .. C.highlight .. tostring(m.key) .. C.close ..
			(m.experimental and (" " .. C.experimental .. "(experimental)" .. C.close) or ""))
	end
end

SLASH_VANILLAQUESTING1 = "/vq"
SLASH_VANILLAQUESTING2 = "/vanillaquesting"

-- Accept whatever /vq actually printed. Modules have a display key
-- ("hideBossPortraits") and a saved-setting name ("showBosses"), and the
-- status list shows the key -- so the key must be a valid handle for
-- /vq on|off. Taking only the setting name made every name on screen an
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

SlashCmdList["VANILLAQUESTING"] = function(msg)
	msg = msg or ""
	local cmd = msg:match("^%s*(%S*)") or ""
	cmd = cmd:lower()
	local arg = msg:match("^%s*%S*%s+(%S+)") or ""

	if cmd == "reset" then
		ns:ResetDefaults()

	elseif cmd == "on" or cmd == "off" then
		local want = (cmd == "on")
		if arg == "" then
			-- "/vq on" means the Classic experience, not the experiments.
			-- Experimental features are only ever turned on by name.
			--
			-- Left exactly as the player set them, in both directions of the
			-- earlier confusion. v0.14.3 made "/vq on" turn them off, to
			-- match the panel's preset; the panel was the one that was wrong.
			-- A preset that undoes a deliberate choice is worse than a preset
			-- that ignores it.
			--
			-- "/vq off" still takes them, because Disabled means nothing is on.
			for k in pairs(ns.defaults) do
				local m = ns.modules[k]
				if want and m and m.experimental then
					-- leave it alone
				else
					ns.db.settings[k] = want
				end
			end
			ns:ApplyAll()
			ns:Print(want and "Enabled all vanilla options."
				or "Disabled all options.")
		else
			local key = resolveSetting(arg)
			if key then
				ns:Set(key, want)
				local m = ns.modules[key]
				-- "showBosses turned on" read as though the portraits were
				-- being shown. Say what actually happened instead.
				local effect = m and (want and m.onText or m.offText)
				ns:Print(C.highlight .. key .. C.close .. " " ..
					(want and (C.on .. "on" .. C.close) or (C.off .. "off" .. C.close)) ..
					"." .. (effect and (" " .. effect) or ""))
			else
				ns:Print(C.warning .. "Unknown option '" .. arg .. "'." .. C.close ..
					" Try " .. C.highlight .. "/vq help" .. C.close .. " for list of commands.")
			end
		end

	elseif cmd == "help" then
		ns:Print(ns.title .. " v" .. tostring(ns.version) .. " - List of commands")
		-- The game font is not monospaced, so padding to a column would still
		-- come out ragged. A fixed separator makes every gap identical instead.
		local function line(cmd, what)
			ns:Print("  " .. C.highlight .. cmd .. C.close .. "  -  " .. what)
		end
		line("/vq", "Open the options panel")
		line("/vq on", "Enable all vanilla options")
		line("/vq off", "Disable all options")
		line("/vq status", "List every option and its current state")
		line("/vq on <option>", "Turn one option on")
		line("/vq off <option>", "Turn one option off")
		line("/vq reset", "Restore default options")

	elseif cmd == "status" then
		status()

	elseif cmd == "" then
		-- Only a bare /vq opens the panel. An unrecognised word is a mistake,
		-- and silently opening the panel would hide that.
		if type(ns.OpenOptions) == "function" then
			ns:OpenOptions()
		else
			status()
			ns:Print(C.warning .. "Options panel unavailable." .. C.close .. " Use " ..
				C.highlight .. "/vq on|off <option>" .. C.close .. ".")
		end

	else
		ns:Print(C.warning .. "Unknown command '" .. cmd .. "'." .. C.close ..
			" Try " .. C.highlight .. "/vq help" .. C.close .. " for list of commands.")
	end
end
