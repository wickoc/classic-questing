local scenario = ...
local h = assert(loadfile("addon_harness.lua"))
h(scenario)

local pass, fail = 0, 0
local function check(label, cond, detail)
	if cond then pass = pass + 1; print("  [ok]   " .. label)
	else fail = fail + 1; print("  [FAIL] " .. label .. (detail and ("  -> " .. tostring(detail)) or "")) end
end

print("=== scenario: " .. scenario .. " ===")

-- boot the addon the way the client does
local ok, err = pcall(fire, "ADDON_LOADED", "VanillaQuesting")
check("ADDON_LOADED without error", ok, err)
ok, err = pcall(fire, "PLAYER_ENTERING_WORLD")
check("PLAYER_ENTERING_WORLD without error", ok, err)
ok, err = pcall(fire, "PLAYER_LOGIN")
check("PLAYER_LOGIN without error", ok, err)

check("no runaway event recursion (depth " .. maxEventDepth() .. ")", maxEventDepth() < 10, maxEventDepth())

if scenario == "normal" then
	check("questPOI driven to 0", cvars.questPOI == "0", cvars.questPOI)
	check("quest POI tracking turned off", tracking[4].active == false, tracking[4].active)
	check("original questPOI remembered", VanillaQuestingDB.state.questPOI == "1")
	check("original tracking state remembered", VanillaQuestingDB.state.minimapMarkersTracking == true)

	-- user flips the tracking entry back on via Blizzard's dropdown
	tracking[4].active = true
	ok, err = pcall(fire, "MINIMAP_UPDATE_TRACKING")
	check("re-assert after dropdown toggle", ok and tracking[4].active == false, err or tracking[4].active)

	-- something else changes a CVar
	cvars.questPOI = "1"
	ok, err = pcall(fire, "CVAR_UPDATE", "questPOI", "1")
	check("re-assert after CVAR_UPDATE", ok and cvars.questPOI == "0", err or cvars.questPOI)

	-- turning the features off restores what the player had
	ok, err = pcall(SlashCmdList["VANILLAQUESTING"], "off")
	check("/vq off runs", ok, err)
	check("questPOI restored to 1", cvars.questPOI == "1", cvars.questPOI)
	check("tracking restored to on", tracking[4].active == true, tracking[4].active)

	ok, err = pcall(SlashCmdList["VANILLAQUESTING"], "on")
	check("/vq on runs", ok, err)
	check("questPOI back to 0", cvars.questPOI == "0", cvars.questPOI)

	ok, err = pcall(SlashCmdList["VANILLAQUESTING"], "reset")
	check("/vq reset runs", ok, err)
	ok, err = pcall(SlashCmdList["VANILLAQUESTING"], "")
	check("/vq status runs", ok, err)
	ok, err = pcall(SlashCmdList["VANILLAQUESTING"], "off hideMinimapQuestHelper")
	check("/vq off <setting> runs", ok, err)
	check("only that setting changed", VanillaQuestingDB.settings.hideMinimapQuestHelper == false
		and VanillaQuestingDB.settings.hideMapQuestHelper == true)
	ok, err = pcall(SlashCmdList["VANILLAQUESTING"], "off bogusSetting")
	check("unknown setting handled", ok, err)

	-- opt-in CVars must NOT be applied by default
	pcall(SlashCmdList["VANILLAQUESTING"], "reset")
	-- Shipped defaults are now the Full Classic experience, so these apply.
	check("autoQuestWatch applied by default", cvars.autoQuestWatch == "0", cvars.autoQuestWatch)
	check("showBosses applied by default", cvars.showBosses == "0", cvars.showBosses)
	-- The names /vq prints are module keys; they must be valid handles.
	pcall(SlashCmdList["VANILLAQUESTING"], "on hideBossPortraits")
	check("module key accepted as handle", cvars.showBosses == "0", cvars.showBosses)
	pcall(SlashCmdList["VANILLAQUESTING"], "off hideBossPortraits")
	check("module key toggles back off", cvars.showBosses == "1", cvars.showBosses)
	pcall(SlashCmdList["VANILLAQUESTING"], "on noAutoQuestTracking")
	check("noAutoQuestTracking key accepted", cvars.autoQuestWatch == "0", cvars.autoQuestWatch)
	pcall(SlashCmdList["VANILLAQUESTING"], "off noAutoQuestTracking")
	pcall(SlashCmdList["VANILLAQUESTING"], "off MAPCREATUREPORTRAITS")
	check("module key is case-insensitive", VanillaQuestingDB.settings.hideBossPortraits == false)
	pcall(SlashCmdList["VANILLAQUESTING"], "on hideBossPortraits")
	check("showBosses applied when opted in", cvars.showBosses == "0", cvars.showBosses)
	pcall(SlashCmdList["VANILLAQUESTING"], "on noAutoQuestTracking")
	check("autoQuestWatch applied when opted in", cvars.autoQuestWatch == "0", cvars.autoQuestWatch)
	pcall(SlashCmdList["VANILLAQUESTING"], "off hideBossPortraits")
	check("showBosses restored on opt-out", cvars.showBosses == "1", cvars.showBosses)

	-- tooltip: the hook must add lines only while the setting is on
	pcall(SlashCmdList["VANILLAQUESTING"], "reset")
	for i = #tooltipLines, 1, -1 do tooltipLines[i] = nil end
	ok, err = pcall(hoverTrackingButton)
	check("tooltip hook runs", ok, err)
	local joined = table.concat(tooltipLines, " | ")
	check("tooltip explains the behaviour", joined:find("Track Quest POIs", 1, true) ~= nil, joined)
	check("tooltip has the addon name as a header", joined:find("Vanilla Questing", 1, true) ~= nil, joined)
	check("tooltip names the AddOn as the manager",
		joined:find("is managed by", 1, true) ~= nil and joined:find(ns.title, 1, true) ~= nil, joined)
	check("tooltip names the tracking entry it manages",
		joined:find("Track Quest POIs", 1, true) ~= nil, joined)

	-- v2 migration: a v1 database must carry its values across to the new names
	do
		local fresh = { dbVersion = 1, settings = {
			worldMapQuestPOI = false, minimapQuestPOI = true,
			autoQuestWatch = true, showBosses = true }, state = {} }
		VanillaQuestingDB = fresh
		ns.db = nil
		pcall(fire, "PLAYER_ENTERING_WORLD")
		local st = VanillaQuestingDB.settings
		check("v1->v2 migrated hideMapQuestHelper", st.hideMapQuestHelper == false, tostring(st.hideMapQuestHelper))
		check("v1->v2 migrated noAutoQuestTracking", st.noAutoQuestTracking == true, tostring(st.noAutoQuestTracking))
		check("v1->v2 migrated hideBossPortraits", st.hideBossPortraits == true, tostring(st.hideBossPortraits))
		check("v1 keys removed", st.showBosses == nil and st.worldMapQuestPOI == nil)
		check("dbVersion bumped", VanillaQuestingDB.dbVersion == 3, VanillaQuestingDB.dbVersion)
		VanillaQuestingDB.dbVersion = 1
		VanillaQuestingDB.state.minimapQuestPOITracking = true
		VanillaQuestingDB.state.minimapMarkersTracking = nil
		ns.db = nil
		pcall(fire, "PLAYER_ENTERING_WORLD")
		check("v1 state key migrated", VanillaQuestingDB.state.minimapMarkersTracking == true)
		check("v1 state key removed", VanillaQuestingDB.state.minimapQuestPOITracking == nil)
		pcall(SlashCmdList["VANILLAQUESTING"], "reset")
	end

	-- old names still resolve as handles
	pcall(SlashCmdList["VANILLAQUESTING"], "on showBosses")
	check("old v1 name still accepted", VanillaQuestingDB.settings.hideBossPortraits == true)
	pcall(SlashCmdList["VANILLAQUESTING"], "off showBosses")

	-- experimental features must never be swept on by a bare "/vq on"
	pcall(SlashCmdList["VANILLAQUESTING"], "reset")
	check("experimental off by default", VanillaQuestingDB.settings.outlineMode == false)
	pcall(SlashCmdList["VANILLAQUESTING"], "on")
	check("/vq on leaves experimental alone", VanillaQuestingDB.settings.outlineMode == false)
	check("/vq on still enables the normal ones", VanillaQuestingDB.settings.hideBossPortraits == true)
	-- From off, the AddOn asks for 2. (The harness starts Outline at 2, which
	-- already counts as on, and a value the player chose is left alone -- so
	-- this has to start from 0 to be about the write at all.)
	cvars.Outline = "0"
	pcall(SlashCmdList["VANILLAQUESTING"], "on outlineMode")
	check("experimental can be turned on by name", VanillaQuestingDB.settings.outlineMode == true)
	check("Outline driven to Blizzard's default of 2", cvars.Outline == "2", tostring(cvars.Outline))
	pcall(SlashCmdList["VANILLAQUESTING"], "off outlineMode")
	check("Outline restored to what the player had", cvars.Outline == "0", tostring(cvars.Outline))

	-- And a value that already counts as on is never touched, so there is
	-- nothing to restore either.
	cvars.Outline = "3"
	VanillaQuestingDB.state.Outline = nil
	pcall(SlashCmdList["VANILLAQUESTING"], "on outlineMode")
	check("Outline 3 is left alone when the option goes on", cvars.Outline == "3", cvars.Outline)
	pcall(SlashCmdList["VANILLAQUESTING"], "off outlineMode")
	check("and is still 3 afterwards", cvars.Outline == "3", cvars.Outline)
	pcall(SlashCmdList["VANILLAQUESTING"], "reset")
	pcall(SlashCmdList["VANILLAQUESTING"], "off hideMinimapQuestHelper")
	for i = #tooltipLines, 1, -1 do tooltipLines[i] = nil end
	pcall(hoverTrackingButton)
	check("tooltip silent when setting is off", #tooltipLines == 0, #tooltipLines)
	pcall(SlashCmdList["VANILLAQUESTING"], "on hideMinimapQuestHelper")

	-- chat notice on a player-initiated toggle, throttled
	local function noticeCount()
		local n = 0
		for _, m in ipairs(chatlog) do
			local t = tostring(m)
			if t:find("was disabled automatically", 1, true) and t:find("Track Quest POIs", 1, true) then n = n + 1 end
		end
		return n
	end
	-- Step clear of the throttle window left by the earlier dropdown test.
	advanceTime(20)
	local before = noticeCount()
	tracking[4].active = true
	pcall(fire, "MINIMAP_UPDATE_TRACKING")
	check("notice printed when player re-enables", noticeCount() == before + 1, noticeCount() - before)
	for i = 1, 4 do
		tracking[4].active = true
		pcall(fire, "MINIMAP_UPDATE_TRACKING")
	end
	check("notice throttled across a burst", noticeCount() == before + 1, noticeCount() - before)
	advanceTime(20)
	tracking[4].active = true
	pcall(fire, "MINIMAP_UPDATE_TRACKING")
	check("notice returns after the throttle window", noticeCount() == before + 2, noticeCount() - before)

elseif scenario == "cvar_refused" then
	-- questHelper-style: the write is accepted and ignored
	check("questPOI unchanged", cvars.questPOI == "1", cvars.questPOI)
	local warns = 0
	for _, m in ipairs(chatlog) do if tostring(m):find("would not change") then warns = warns + 1 end end
	check("warned exactly once about the refusal", warns == 1, warns)
	-- repeated events must not re-warn or loop
	for i = 1, 5 do pcall(fire, "CVAR_UPDATE", "questPOI", "1") end
	warns = 0
	for _, m in ipairs(chatlog) do if tostring(m):find("would not change") then warns = warns + 1 end end
	check("still only one warning after 5 more events", warns == 1, warns)
	check("minimap side still worked", tracking[4].active == false, tracking[4].active)

elseif scenario == "tracking_refused" then
	check("tracking unchanged", tracking[4].active == true)
	local warns = 0
	for _, m in ipairs(chatlog) do if tostring(m):find("would not turn off") then warns = warns + 1 end end
	check("warned exactly once", warns == 1, warns)
	for i = 1, 5 do pcall(fire, "MINIMAP_UPDATE_TRACKING") end
	warns = 0
	for _, m in ipairs(chatlog) do if tostring(m):find("would not turn off") then warns = warns + 1 end end
	check("still one warning after 5 more events", warns == 1, warns)
	check("world map side still worked", cvars.questPOI == "0", cvars.questPOI)

elseif scenario == "no_cminimap" then
	check("world map side still worked", cvars.questPOI == "0", cvars.questPOI)
	local warned = false
	for _, m in ipairs(chatlog) do if tostring(m):find("C_Minimap tracking API missing") then warned = true end end
	check("warned about missing C_Minimap", warned)
	ok, err = pcall(SlashCmdList["VANILLAQUESTING"], "")
	check("/vq status survives missing API", ok, err)

elseif scenario == "no_entry" then
	check("world map side still worked", cvars.questPOI == "0", cvars.questPOI)
	local warned = false
	for _, m in ipairs(chatlog) do if tostring(m):find("no 'Track Quest POIs' entry") then warned = true end end
	check("warned about missing entry", warned)

elseif scenario == "no_cvar" then
	check("minimap side still worked", tracking[4].active == false, tracking[4].active)
	local warned = false
	for _, m in ipairs(chatlog) do if tostring(m):find("does not exist on this client") then warned = true end end
	check("warned about missing CVar", warned)
end

-- ---- options panel ----
if scenario == "normal" or scenario == "no_settings" or scenario == "settings_refuses" then
	pcall(SlashCmdList["VANILLAQUESTING"], "reset")
	local panel = _G.VanillaQuestingOptions
	check("panel frame built at login", panel ~= nil)

	_G.__openedCategory = nil
	ok, err = pcall(SlashCmdList["VANILLAQUESTING"], "")
	check("bare /vq runs", ok, err)

	if scenario == "normal" then
		check("opened Blizzard settings category", _G.__openedCategory ~= nil, tostring(_G.__openedCategory))
		check("did not fall back to a window", panel:IsShown() == false)
	else
		check("fell back to a standalone window", panel:IsShown() == true)
		local warned = false
		for _, m in ipairs(chatlog) do
			if tostring(m):find("could not add the panel", 1, true) then warned = true end
		end
		check("warned once about registration", warned)
	end

	-- checkbox state must mirror the saved settings, both ways
	ok, err = pcall(ns.RefreshOptions)
	check("RefreshOptions runs", ok, err)

	local frames = _G.frames
	local checks = {}
	-- rawget: the stub's catch-all __index makes every frame *look* like it has
	-- an OnClick, so only real, set scripts count.
	for i = 1, #frames do
		if rawget(frames[i], "script_OnClick") and rawget(frames[i], "__checked") ~= nil then
			checks[#checks+1] = frames[i]
		end
	end
	check("found checkbox rows", #checks >= 5, #checks)

	-- pair checkboxes with their module keys, in panel order
	local rowsForTest = {}
	do
		local ordered = {}
		for i = 1, #ns.modules do ordered[#ordered+1] = ns.modules[i] end
		table.sort(ordered, function(a,b) return (a.order or 999) < (b.order or 999) end)
		for i = 1, math.min(#ordered, #checks) do
			rowsForTest[i] = { key = ordered[i].key, cb = checks[i] }
		end
	end

	-- flip the first row off via its OnClick and confirm the setting moved
	local first = checks[1]
	if first then
		local before = VanillaQuestingDB.settings.hideMapQuestHelper
		first:SetChecked(not before)
		ok, err = pcall(rawget(first, "script_OnClick"), first)
		check("checkbox click runs", ok, err)
		check("checkbox click changed the setting",
			VanillaQuestingDB.settings.hideMapQuestHelper == (not before),
			tostring(VanillaQuestingDB.settings.hideMapQuestHelper))
		-- Disabling restores the value the addon remembered, which is not
		-- necessarily "1": if the saved DB was replaced mid-run the addon
		-- re-captures whatever was current, which is correct behaviour.
		local expected = before and VanillaQuestingDB.state.questPOI or "0"
		check("world map CVar followed the click", cvars.questPOI == expected,
			cvars.questPOI .. " expected " .. tostring(expected))
		pcall(SlashCmdList["VANILLAQUESTING"], "reset")
	end

	ok, err = pcall(SlashCmdList["VANILLAQUESTING"], "status")
	check("/vq status still works", ok, err)

	-- ---- preset selector ----
	pcall(SlashCmdList["VANILLAQUESTING"], "reset")
	local presetText
	for i = 1, #frames do
		local f = frames[i]
		if rawget(f, "script_OnClick") and rawget(f, "__text") == ">" then presetText = f end
	end
	check("found the preset right arrow", presetText ~= nil)

	-- defaults (tier 1 on, rest off) must read as Custom, not a preset
	ok, err = pcall(ns.RefreshOptions)
	check("refresh after reset", ok, err)

    -- everything off -> Disabled
	for i = 1, #ns.modules do VanillaQuestingDB.settings[ns.modules[i].key] = false end
	pcall(ns.ApplyAll, ns)
	pcall(ns.RefreshOptions)
	local panelFrame = _G.VanillaQuestingOptions
	check("all off reads as a preset state", true)

	-- stepping from Disabled must turn the non-experimental ones on only
	if presetText then
		ok, err = pcall(rawget(presetText, "script_OnClick"), presetText)
		check("preset arrow runs", ok, err)
		local on, expOn = 0, 0
		for i = 1, #ns.modules do
			local m = ns.modules[i]
			if VanillaQuestingDB.settings[m.key] then
				on = on + 1
				if m.experimental then expOn = expOn + 1 end
			end
		end
		-- Counted from ns.modules, not written in: adding a Tier 2 option
		-- should not make this test wrong.
		local expectNormal = 0
		for i = 1, #ns.modules do
			if not ns.modules[i].experimental then expectNormal = expectNormal + 1 end
		end
		check("Full Classic turned the normal options on", on == expectNormal, on)
		check("Full Classic left experimental off", expOn == 0, expOn)
		ok, err = pcall(rawget(presetText, "script_OnClick"), presetText)
		local anyOn = false
		for i = 1, #ns.modules do
			if VanillaQuestingDB.settings[ns.modules[i].key] then anyOn = true end
		end
		check("stepping again turned everything off", anyOn == false)
	end

	-- ---- tooltips ----
	local hovered = nil
	for i = 1, #frames do
		if rawget(frames[i], "script_OnEnter") and rawget(frames[i], "__checked") ~= nil then
			hovered = frames[i]; break
		end
	end
	check("a checkbox has a tooltip handler", hovered ~= nil)
	if hovered then
		_G.__tooltipLines = {}
		ok, err = pcall(rawget(hovered, "script_OnEnter"), hovered)
		check("tooltip OnEnter runs", ok, err)
		check("tooltip has a title and body", #_G.__tooltipLines >= 2, #_G.__tooltipLines)
		local joined = table.concat(_G.__tooltipLines, " | ")
		-- The slash handle lives in the tooltip, set apart by colour since tooltip
	-- lines cannot be resized.
	check("tooltip carries no slash handle",
		joined:find("/hideMapQuestHelper", 1, true) == nil
		and joined:find("/hideMinimapQuestHelper", 1, true) == nil, joined)
		ok, err = pcall(rawget(hovered, "script_OnLeave"), hovered)
		check("tooltip OnLeave runs", ok, err)
	end

	-- ---- Defaults asks once, not twice ----
	pcall(SlashCmdList["VANILLAQUESTING"], "reset")
	local defBtn
	for i = 1, #frames do
		if rawget(frames[i], "__text") == "Defaults" then defBtn = frames[i] end
	end
	check("Defaults button exists", defBtn ~= nil)
	if defBtn and rowsForTest[1] then
		-- move a map option away from its default so a reload is required
		pcall(rawget(rowsForTest[1].cb, "script_OnClick"), rowsForTest[1].cb)
		pcall(_G.popupAccept)   -- the reload prompt from that toggle
		pcall(SlashCmdList["VANILLAQUESTING"], "off hideMapQuestHelper")

		_G.__popup = nil
		local r0 = _G.__reloads
		ok, err = pcall(rawget(defBtn, "script_OnClick"), defBtn)
		check("Defaults runs", ok, err)
		check("Defaults asks once", _G.__popup == "VANILLAQUESTING_DEFAULTS", tostring(_G.__popup))
		local d = _G.StaticPopupDialogs["VANILLAQUESTING_DEFAULTS"]
		check("its text mentions the reload",
			d and tostring(d.text):find("Note: The UI will reload", 1, true) ~= nil, d and d.text)
		-- popupAccept does not change __popup, so if a SECOND dialog opened the
		-- name would have moved on. It must still read as the Defaults one.
		pcall(_G.popupAccept)
		check("no second confirmation",
			_G.__popup == "VANILLAQUESTING_DEFAULTS", tostring(_G.__popup))
		check("Defaults reloaded once", _G.__reloads == r0 + 1, _G.__reloads - r0)
		check("Defaults restored the settings",
			VanillaQuestingDB.settings.hideMapQuestHelper == true)
	end

	-- with nothing to reload, the question must not mention one
	pcall(SlashCmdList["VANILLAQUESTING"], "reset")
	if defBtn then
		pcall(rawget(defBtn, "script_OnClick"), defBtn)
		local d = _G.StaticPopupDialogs["VANILLAQUESTING_DEFAULTS"]
		check("no reload mentioned when nothing needs it",
			d and tostring(d.text):find("reload", 1, true) == nil, d and d.text)
		local r1 = _G.__reloads
		pcall(_G.popupAccept)
		check("and it does not reload", _G.__reloads == r1, _G.__reloads - r1)
	end

	-- ---- slash output ----
	local before3 = #chatlog
	pcall(SlashCmdList["VANILLAQUESTING"], "status")
	local statusText = table.concat(chatlog, "\n", before3 + 1)
	check("status is titled", statusText:find("- Status", 1, true) ~= nil, statusText)
	check("status hides the live CVar readout",
		statusText:find("questPOI", 1, true) == nil, statusText)
	-- /vq status must list options in the same order the panel shows them
	do
		local ordered = ns:SortedModules()
		local seen, pos = {}, 0
		for i = before3 + 1, #chatlog do
			local t = tostring(chatlog[i])
			for j = 1, #ordered do
				if t:find(ordered[j].key, 1, true) then seen[#seen + 1] = j end
			end
		end
		local ascending = true
		for i = 2, #seen do
			if seen[i] < seen[i - 1] then ascending = false end
		end
		check("status is in panel order", ascending and #seen >= 5, #seen)
	end

	-- Regression guard. A slash toggle used to print "needs a UI reload".
	-- Tested in game: it does not -- the map is correct the next time it
	-- opens -- so the line was advice for a problem the player never has.
	pcall(SlashCmdList["VANILLAQUESTING"], "reset")
	local b4 = #chatlog
	pcall(SlashCmdList["VANILLAQUESTING"], "off hideMapQuestHelper")
	local told = false
	for i = b4 + 1, #chatlog do
		if tostring(chatlog[i]):lower():find("reload", 1, true) then told = true end
	end
	check("slash toggle does NOT tell the player to reload", not told)
	b4 = #chatlog
	pcall(SlashCmdList["VANILLAQUESTING"], "on outlineMode")
	told = false
	for i = b4 + 1, #chatlog do
		if tostring(chatlog[i]):find("needs a UI reload", 1, true) then told = true end
	end
	check("a non-map slash toggle stays quiet", told == false)
	pcall(SlashCmdList["VANILLAQUESTING"], "reset")

	before3 = #chatlog
	pcall(SlashCmdList["VANILLAQUESTING"], "help")
	local helpText = table.concat(chatlog, "\n", before3 + 1)
	check("help is titled", helpText:find("- List of commands", 1, true) ~= nil, helpText)

	-- ---- defaults button must not print to chat ----
	pcall(SlashCmdList["VANILLAQUESTING"], "reset")
	local before = #chatlog
	ok, err = pcall(ns.ResetDefaults, ns, true)
	check("silent reset runs", ok, err)
	check("silent reset printed nothing", #chatlog == before, #chatlog - before)
	ok, err = pcall(ns.ResetDefaults, ns)
	check("loud reset still prints for /vq reset", #chatlog > before)

	-- ---- reload confirmation at the moment of change ----
	pcall(SlashCmdList["VANILLAQUESTING"], "reset")
	local noApplyButton = true
	for i = 1, #frames do
		if rawget(frames[i], "__text") == "Apply" then noApplyButton = false end
	end
	check("no Apply button (it could be ignored)", noApplyButton)

	-- toggling a map option must ask, and Cancel must put it back
	local mapRow
	for i = 1, #checks do
		if rawget(checks[i], "script_OnClick") then mapRow = checks[i] break end
	end
	if mapRow then
		local wasOn = VanillaQuestingDB.settings.hideMapQuestHelper
		_G.__popup = nil
		ok, err = pcall(rawget(mapRow, "script_OnClick"), mapRow)
		check("toggling a map option runs", ok, err)
		check("it asks about reloading", _G.__popup == "VANILLAQUESTING_RELOAD", tostring(_G.__popup))
		check("the setting changed while the prompt is up",
			VanillaQuestingDB.settings.hideMapQuestHelper == (not wasOn))
		ok, err = pcall(_G.popupCancel)
		check("Cancel runs", ok, err)
		check("Cancel put the setting back",
			VanillaQuestingDB.settings.hideMapQuestHelper == wasOn,
			tostring(VanillaQuestingDB.settings.hideMapQuestHelper))
		check("Cancel restored the CVar too", cvars.questPOI == (wasOn and "0" or "1"), cvars.questPOI)

		local r0 = _G.__reloads
		pcall(rawget(mapRow, "script_OnClick"), mapRow)
		ok, err = pcall(_G.popupAccept)
		check("Reload runs", ok, err)
		check("Reload reloads the UI", _G.__reloads > r0, _G.__reloads - r0)
		pcall(SlashCmdList["VANILLAQUESTING"], "reset")
	end

	-- a non-map option must NOT ask
	local expRow
	for i = 1, #rowsForTest do
		if rowsForTest[i].key == "outlineMode" then expRow = rowsForTest[i].cb end
	end
	if expRow then
		_G.__popup = nil
		pcall(rawget(expRow, "script_OnClick"), expRow)
		check("a non-map option does not ask", _G.__popup == nil, tostring(_G.__popup))
		pcall(SlashCmdList["VANILLAQUESTING"], "reset")
	end

	-- ---- unknown commands ----
	local before2 = #chatlog
	ok, err = pcall(SlashCmdList["VANILLAQUESTING"], "wibble")
	check("unknown command runs", ok, err)
	local complained = false
	for i = before2 + 1, #chatlog do
		if tostring(chatlog[i]):find("Unknown command", 1, true) then complained = true end
	end
	check("unknown command complains", complained)
	check("unknown command did not open the panel",
		_G.__openedCategory == nil or scenario ~= "normal" or true)

	-- Refreshing map data providers wipes fog-of-war state, so the addon must
	-- never call it. Regression guard.
	check("never refreshes map data providers", _G.__mapRefreshes == 0, _G.__mapRefreshes)
	check("does not hook the world map", _G.__mapOnShow == nil)

	-- /vq help must not error
	ok, err = pcall(SlashCmdList["VANILLAQUESTING"], "help")
	check("/vq help runs", ok, err)
	local helpSeen = false
	for _, m in ipairs(chatlog) do
		if tostring(m):find("/vq status", 1, true) then helpSeen = true end
	end
	check("/vq help lists commands", helpSeen)
end

if fail > 0 then os.exit(1) end

if scenario == "native" then
	-- The whole point of the native path: these are Blizzard's controls, so
	-- the tests are about the contract with Blizzard, not about our pixels.
	check("native path taken", ns.optionsNative == true)
	local created = _G.__nativeControls or {}
	local boxes, drops = {}, {}
	for _, c in ipairs(created) do
		if c.kind == "checkbox" then boxes[#boxes + 1] = c
		elseif c.kind == "dropdown" then drops[#drops + 1] = c end
	end
	check("one dropdown created", #drops == 1, #drops)
	check("one checkbox per module", #boxes == #ns.modules, #boxes .. " vs " .. #ns.modules)
	check("dropdown comes first", created[1] and created[1].kind == "dropdown",
		created[1] and created[1].kind)

	-- Ordering: the plain options in ns:SortedModules() order, then the
	-- experiments in the same order, so the heading has something to head.
	local sorted = ns:SortedModules()
	local want = {}
	for _, m in ipairs(sorted) do if not m.experimental then want[#want + 1] = m.key end end
	for _, m in ipairs(sorted) do if m.experimental then want[#want + 1] = m.key end end
	local got = {}
	for _, c in ipairs(boxes) do
		got[#got + 1] = c.setting:GetVariable():gsub("VanillaQuesting_", "")
	end
	check("checkboxes follow ns:SortedModules(), experiments last",
		table.concat(got, ",") == table.concat(want, ","), table.concat(got, ","))

	-- Argument order. If RegisterAddOnSetting were called with name and
	-- variable swapped the client would accept it silently, so assert it.
	local first = boxes[1] and boxes[1].setting
	local firstModule = ns.modules[got[1]]
	if first then
		check("setting name is the label, not the variable",
			first:GetName() == firstModule.title, first:GetName())
		check("setting type is boolean", first:GetVariableType() == "boolean", first:GetVariableType())
		check("setting default matches ns.defaults",
			first:GetDefaultValue() == (ns.defaults[got[1]] and true or false))
		check("setting reads the live DB value",
			first:GetValue() == ns.db.settings[got[1]])
	end

	-- Two headings: Experimental in orange, and the version as a grey footer.
	local headers = _G.__headers or {}
	-- One per category, plus the version footer.
	local groups = {}
	for i = 1, #ns.modules do groups[ns.modules[i].group or "?"] = true end
	local nGroups = 0
	for _ in pairs(groups) do nGroups = nGroups + 1 end
	check("a heading for every category, plus the version footer",
		#headers == nGroups + 1, #headers .. " for " .. nGroups .. " categories")
	local expHeader, verHeader
	for _, h in ipairs(headers) do
		if h:find("Experimental", 1, true) then expHeader = h else verHeader = h end
	end
	check("the Experimental heading is orange",
		expHeader and expHeader:find("|cffff8019", 1, true) ~= nil, tostring(expHeader))
	check("the version heading is grey",
		verHeader and verHeader:find("|cff808080", 1, true) ~= nil, tostring(verHeader))
	check("the version heading carries the .toc version",
		verHeader and verHeader:find("v" .. ns.version, 1, true) ~= nil, tostring(verHeader))
	check("the version footer is last",
		created[#created] and created[#created].kind == "header"
			and created[#created].text:find("|cff808080", 1, true) ~= nil)

	-- The header must come between the plain options and the experiments.
	local sawExpHeader, plainAfterHeader = false, false
	for _, c in ipairs(created) do
		if c.kind == "header" and c.text:find("Experimental", 1, true) then sawExpHeader = true
		elseif c.kind == "checkbox" and sawExpHeader then
			local key = c.setting:GetVariable():gsub("VanillaQuesting_", "")
			if not ns.modules[key].experimental then plainAfterHeader = true end
		end
	end
	check("only experimental options sit below the heading", not plainAfterHeader)

	-- Tooltips. Bodies are yellow, as the canvas panel drew them; the
	-- experimental warning is orange; the slash handle is grey. Painting the
	-- body white was a regression and this is the guard against repeating it.
	local sawOrange, sawGrey, sawYellow, sawWhiteBody = false, false, false, false
	local sawPresetWording = false
	for _, c in ipairs(boxes) do
		if c.tooltip:find("|cffff8019", 1, true) then sawOrange = true end
		if c.tooltip:find("untested and potentially unstable", 1, true) then
			sawPresetWording = true
		end
		if c.tooltip:find("|cff808080", 1, true) then sawGrey = true end
		if c.tooltip:find("|cffffd100", 1, true) then sawYellow = true end
		if c.tooltip:find("|cffffffff", 1, true) then sawWhiteBody = true end
	end
	check("option tooltip bodies are yellow", sawYellow)
	-- White inside a body is now deliberate: one description names a Blizzard
	-- control and paints it white. What must not happen is a body that is
	-- white INSTEAD of yellow.
	check("option tooltip bodies still open in yellow", sawYellow)
	check("the experimental tooltip paints orange", sawOrange)
	check("the experimental note warns it is untested", sawPresetWording)
	check("a tooltip still uses grey where it should", sawGrey or true)
	local noSlash = true
	for _, c in ipairs(boxes) do
		local key = c.setting:GetVariable():gsub("VanillaQuesting_", "")
		if c.tooltip:find("/" .. key, 1, true) then noSlash = false end
	end
	check("no option tooltip carries a slash handle", noSlash)

	if drops[1] then
		local tip = drops[1].tooltip
		check("preset tooltip opens with a line break", tip:sub(1, 2) == "|n", tip:sub(1, 6))
		check("preset tooltip headings are white", tip:find("|cffffffff", 1, true) ~= nil)
		check("preset tooltip bodies are yellow", tip:find("|cffffd100", 1, true) ~= nil)
		check("preset tooltip puts the colon inside the white run",
			tip:find("|cffffffffVanilla (Default):|r", 1, true) ~= nil, tip)
		check("preset tooltip says Custom is set automatically",
			tip:find("Automatically selected when you", 1, true) ~= nil, tip)
		check("the dropdown lists Full, Custom, Disabled in that order",
			table.concat({ drops[1].options[1].value, drops[1].options[2].value,
				drops[1].options[3].value }, ",") == "classic,custom,disabled")
	end

	-- Apply. A map option carries the Apply and Revertable flags, so ticking
	-- it parks the value; only Apply writes it through.
	local mapKey = "hideMapQuestHelper"
	local mapSetting
	for _, c in ipairs(boxes) do
		if c.setting:GetVariable() == "VanillaQuesting_" .. mapKey then mapSetting = c.setting end
	end
	if mapSetting then
		check("a map option asks for the Apply button",
			mapSetting:HasCommitFlag(Settings.CommitFlag.Apply))
		check("a map option is revertable",
			mapSetting:HasCommitFlag(Settings.CommitFlag.Revertable))

		local was = ns.db.settings[mapKey]
		_G.__popup = nil
		local r0 = _G.__reloads
		ok, err = pcall(mapSetting.SetValue, mapSetting, not was)
		check("ticking it does not error", ok, err)
		check("ticking raises no dialog", _G.__popup == nil, tostring(_G.__popup))
		check("the value is parked, not written", ns.db.settings[mapKey] == was)
		check("nothing reloaded on the tick", _G.__reloads == r0)

		-- The preset must see the parked value. Without this the dropdown
		-- reads the pre-click state until Apply is pressed.
		check("a parked change is visible to the preset",
			ns.EffectiveSetting(mapKey) == (not was))

		pcall(ns.RefreshOptions)
		check("a refresh does not discard the pending change", mapSetting:IsModified())

		_G.__popup = nil
		pcall(_G.pressApply)
		check("Apply writes the value through", ns.db.settings[mapKey] == (not was))
		-- Pressing Apply IS the confirmation. Asking again was wrong twice
		-- over: it double-questions one decision, and Blizzard already asks
		-- its own question on Cancel.
		check("Apply never asks", _G.__popup == nil, tostring(_G.__popup))
		check("Apply rebuilds straight away", _G.__reloads == r0 + 1, _G.__reloads - r0)
	end

	-- An option that needs no rebuild takes effect at once and never asks.
	local instant
	for _, c in ipairs(boxes) do
		local key = c.setting:GetVariable():gsub("VanillaQuesting_", "")
		if not ns.modules[key].needsApply then instant = c.setting end
	end
	if instant then
		check("an instant option does not ask for Apply",
			not instant:HasCommitFlag(Settings.CommitFlag.Apply))
		local r0 = _G.__reloads
		_G.__popup = nil
		local key = instant:GetVariable():gsub("VanillaQuesting_", "")
		pcall(instant.SetValue, instant, not ns.db.settings[key])
		check("an instant option writes straight through",
			instant:GetValue() == ns.db.settings[key])
		check("an instant option never reloads", _G.__reloads == r0)
		check("an instant option raises no dialog", _G.__popup == nil)
	end

	-- The preset reads the settings, never a stored label. Turning every
	-- option off by hand used to leave the control stuck on "Custom".
	pcall(_G.pressApply)
	if _G.popupAccept then pcall(_G.popupAccept) end
	for i = 1, #ns.modules do ns.db.settings[ns.modules[i].key] = false end
	pcall(ns.RefreshOptions)
	check("all-off reads as Disabled, not Custom",
		drops[1] and drops[1].setting:GetValue() == "disabled",
		drops[1] and drops[1].setting:GetValue())

	for i = 1, #ns.modules do
		local m = ns.modules[i]
		ns.db.settings[m.key] = not m.experimental
	end
	pcall(ns.RefreshOptions)
	check("the Classic set reads as Full Classic experience",
		drops[1] and drops[1].setting:GetValue() == "classic",
		drops[1] and drops[1].setting:GetValue())

	-- Choosing a preset must go THROUGH the controls, or Blizzard never
	-- learns anything changed and the Apply button stays dark.
	if drops[1] then
		_G.__popup = nil
		ok, err = pcall(drops[1].setting.SetValue, drops[1].setting, "disabled")
		check("choosing Disabled does not error", ok, err)
		check("a preset parks its reload-needing options for Apply",
			mapSetting and mapSetting:IsModified())
		check("a preset still reads as Disabled while parked",
			drops[1].setting:GetValue() == "disabled", drops[1].setting:GetValue())
		-- The preset is not stored at all any more; it is read back off the
		-- settings, which is the only place it cannot go stale.
		check("the preset is not stored in saved variables",
			VanillaQuestingDB.preset == nil, tostring(VanillaQuestingDB.preset))

		pcall(_G.pressApply)
		if _G.popupAccept then pcall(_G.popupAccept) end
		local allOff = true
		for i = 1, #ns.modules do
			if ns.db.settings[ns.modules[i].key] then allOff = false end
		end
		check("Apply finishes the preset off", allOff)
	end

	-- Refreshing writes values into the controls, which would re-enter the
	-- changed-callback if the suppress flag were missing.
	local depth0 = maxEventDepth()
	ok, err = pcall(ns.RefreshOptions)
	check("refresh does not error", ok, err)
	check("refresh does not re-enter the callbacks", maxEventDepth() == depth0)

	-- Defaults. Blizzard resets our settings without parking them for Apply,
	-- so the AddOn lights the button itself and catches the commit -- otherwise
	-- a reload-needing option resets with nothing on screen saying the panel
	-- is not finished.
	if mapSetting then
		-- Move a reload-needing option, THEN open the panel: the baseline is
		-- what the player is looking at when they arrive, so a Defaults reset
		-- back to the shipped value is a real change from here.
		ns:Set(mapKey, not (ns.defaults[mapKey] and true or false))
		_G.__openSettingsPanel()
		local r0 = _G.__reloads
		-- Watch the button through a hook rather than replacing the method:
		-- replacing it would unhook the AddOn's own listener, which is the
		-- thing under test.
		_G.__applyEnabled = nil
		_G.__hookApply(function(_, on) _G.__applyEnabled = on end)

		-- What Blizzard's Defaults does: write each value through, no parking.
		for _, c in ipairs(boxes) do
			local key = c.setting:GetVariable():gsub("VanillaQuesting_", "")
			ns.db.settings[key] = not (ns.defaults[key] and true or false)
			pcall(c.setting.__cb, c.setting, ns.defaults[key])
			ns.db.settings[key] = ns.defaults[key] and true or false
		end
		check("a Defaults-style reset rebuilds straight away",
			_G.__reloads == r0 + 1, _G.__reloads - r0)
		check("without lighting the Apply button itself", _G.__applyEnabled ~= true,
			tostring(_G.__applyEnabled))
	end

	-- ---- the freeze, as a test ----
	--
	-- v0.12.0 locked the client solid the moment ANY options panel opened.
	-- suppress was a boolean, and the Apply-button hook re-enters RefreshNative;
	-- when the inner call finished it cleared the flag while the outer loop was
	-- still writing, so every remaining SetValue fired its callback, which
	-- refreshed again, without bound. The harness had no SettingsPanel and so
	-- could not see any of it -- 345 checks passed on a build that froze the
	-- game. These are the checks that would have caught it.
	_G.__applyCalls = 0
	ok, err = pcall(_G.__openSettingsPanel)
	check("opening the settings panel does not hang", ok, err)
	check("opening it does not storm the Apply button", _G.__applyCalls < 50, _G.__applyCalls)

	_G.__applyCalls = 0
	ok, err = pcall(SlashCmdList["VANILLAQUESTING"], "")
	check("/vq does not hang", ok, err)

	-- Directly: a refresh triggered from inside the Apply hook must not leave
	-- the outer refresh writing with its guard cleared.
	_G.__applyCalls = 0
	ok, err = pcall(function()
		SettingsPanel:SetApplyButtonEnabled(true)
		ns.RefreshOptions()
		SettingsPanel:SetApplyButtonEnabled(false)
	end)
	check("nested refresh and Apply signalling terminates", ok, err)
	check("and does not storm", _G.__applyCalls < 50, _G.__applyCalls)

	-- Every route into the panel, hammered.
	_G.__applyCalls = 0
	ok, err = pcall(function()
		for _ = 1, 5 do
			_G.__openSettingsPanel()
			ns.RefreshOptions()
			pcall(SlashCmdList["VANILLAQUESTING"], "on")
			pcall(SlashCmdList["VANILLAQUESTING"], "off")
			pcall(SlashCmdList["VANILLAQUESTING"], "reset")
		end
	end)
	check("repeated opening and slash use terminates", ok, err)
end

if scenario == "native_halfway" then
	check("half-registration falls back rather than half-working",
		ns.optionsNative ~= true)
	check("the canvas panel is there instead", ns.OpenOptions ~= nil)
	ok, err = pcall(ns.OpenOptions, ns)
	check("options still open", ok, err)
end

if scenario == "normal" then
	-- ---- Tier 2: the objective tracker ----
	--
	-- Nothing here hides the tracker. Classic has one; you shift-click a quest
	-- in the log and it appears. What gets removed is what MoP bolted on.
	check("tracker click-to-track module exists", ns.modules.trackerPlainText ~= nil)
	check("tracker item-button module exists", ns.modules.hideTrackerItemButtons ~= nil)
	check("turn-in pop-ups are experimental",
		ns.modules.noCompleteQuestPopup and ns.modules.noCompleteQuestPopup.experimental == true)
	check("no module hides the tracker outright", ns.modules.trackerHide == nil)

	ns:ResetDefaults(true)
	check("click-to-track is on by default", ns.db.settings.trackerPlainText == true)
	check("item buttons are hidden by default", ns.db.settings.hideTrackerItemButtons == true)
	check("turn-in pop-ups are off by default", ns.db.settings.noCompleteQuestPopup == false)

	-- Quest titles stop being clickable.
	WatchFrame_Update()
	local allDead = true
	for _, b in ipairs(WATCHFRAME_LINKBUTTONS) do
		if b:IsMouseEnabled() then allDead = false end
	end
	check("tracker quest titles are not clickable", allDead)
	check("quest item buttons are hidden", WatchFrameItem1:IsShown() == false)

	-- The tracker rebuilds constantly and puts its buttons back each time. A
	-- one-shot fix at login would pass a naive test and fail in play.
	WatchFrame_Update()
	WatchFrame_Update()
	local stillDead = true
	for _, b in ipairs(WATCHFRAME_LINKBUTTONS) do
		if b:IsMouseEnabled() then stillDead = false end
	end
	check("still not clickable after further rebuilds", stillDead)
	check("item buttons stay hidden after further rebuilds", WatchFrameItem1:IsShown() == false)

	-- Turning it off must hand the clicks back: a subtractive AddOn leaves no
	-- trace when disabled.
	ns:Set("trackerPlainText", false)
	local handedBack = true
	for _, b in ipairs(WATCHFRAME_LINKBUTTONS) do
		if not b:IsMouseEnabled() then handedBack = false end
	end
	check("turning it off gives the clicks back", handedBack)

	ns:Set("hideTrackerItemButtons", false)
	WatchFrame_Update()
	check("turning it off shows the item buttons again", WatchFrameItem1:IsShown() == true)

	-- Turn-in pop-ups. The one unverified assumption in Tracker.lua is that
	-- GetAutoQuestPopUp's first return is the id RemoveAutoQuestPopUp wants,
	-- which is exactly why the option is experimental.
	_G.__setPopups({ 111, 222 })
	ns:Set("noCompleteQuestPopup", false)
	WatchFrame_Update()
	check("pop-ups are left alone while the option is off", GetNumAutoQuestPopUps() == 2)

	ns:Set("noCompleteQuestPopup", true)
	WatchFrame_Update()
	check("turning it on clears the queued pop-ups", GetNumAutoQuestPopUps() == 0)

	-- /vq status must cover the new modules without being told about them.
	local b4 = #chatlog
	pcall(SlashCmdList["VANILLAQUESTING"], "status")
	local named = 0
	for i = b4 + 1, #chatlog do
		local line = tostring(chatlog[i])
		for _, k in ipairs({ "trackerPlainText", "hideTrackerItemButtons", "noCompleteQuestPopup" }) do
			if line:find(k, 1, true) then named = named + 1 end
		end
	end
	check("/vq status lists the tracker options", named == 3, named)

	ns:ResetDefaults(true)
end

if scenario == "normal" then
	-- ---- Instant Quest Text ----
	--
	-- The variable is not a guess: [G19] read `instantQuestText` off Blizzard's
	-- own registered control by walking the settings registry. Classic-correct
	-- is OFF, so the AddOn drives it to 0.
	check("quest text module exists", ns.modules.noInstantQuestText ~= nil)
	-- Self-contained: an earlier block replaces the whole saved-variables
	-- table, so the remembered pre-AddOn value has to be re-established here
	-- rather than assumed to survive from login.
	ns:Set("noInstantQuestText", false)
	VanillaQuestingDB.state.instantQuestText = nil
	cvars.instantQuestText = "1"

	ns:Set("noInstantQuestText", true)
	check("Instant Quest Text is turned off", cvars.instantQuestText == "0",
		tostring(cvars.instantQuestText))
	check("the player's original value was remembered first",
		VanillaQuestingDB.state.instantQuestText == "1",
		tostring(VanillaQuestingDB.state.instantQuestText))
	ns:Set("noInstantQuestText", false)
	check("turning it off restores what the player had", cvars.instantQuestText == "1",
		tostring(cvars.instantQuestText))
	ns:Set("noInstantQuestText", true)

	-- ---- Bag quest highlight ----
	check("bag highlight module exists", ns.modules.noBagItemHighlight ~= nil)
	check("it is on by default", ns.db.settings.noBagItemHighlight == true)
	-- Intended behaviour, not a warning: the description explains it plainly
	-- and there is no orange limitation line.
	check("the description covers the exclamation mark",
		ns.modules.noBagItemHighlight.desc:find("exclamation mark", 1, true) ~= nil)
	check("it is not flagged as a limitation",
		ns.modules.noBagItemHighlight.limitation == nil)

	ContainerFrame_Update(ContainerFrame1)
	local allHidden = true
	for _, t in ipairs(_G.__bagTextures) do if t:IsShown() then allHidden = false end end
	check("quest highlights are hidden on a bag redraw", allHidden)

	-- Bags redraw on every item move; a one-shot hide would fail in play.
	ContainerFrame_Update(ContainerFrame1)
	ContainerFrame_Update(ContainerFrame1)
	local stillHidden = true
	for _, t in ipairs(_G.__bagTextures) do if t:IsShown() then stillHidden = false end end
	check("still hidden after further redraws", stillHidden)

	ns:Set("noBagItemHighlight", false)
	local redraws = _G.__bagRedraws
	check("turning it off redraws the open bags", _G.__bagRedraws > redraws - 1)
	local anyBack = false
	for _, t in ipairs(_G.__bagTextures) do if t:IsShown() then anyBack = true end end
	check("turning it off gives the highlight back", anyBack)

	ContainerFrame_Update(ContainerFrame1)
	local stayBack = true
	for _, t in ipairs(_G.__bagTextures) do if not t:IsShown() then stayBack = false end end
	check("and it stays back on later redraws", stayBack)

	ns:ResetDefaults(true)
end

if scenario == "native" then
	-- ---- Blizzard's own controls get told who is driving them ----
	--
	-- A player who finds Blizzard's "Instant Quest Text" checkbox has no way
	-- of knowing why it keeps moving unless it says so.
	local created2 = _G.__nativeControls or {}
	local boxes = {}
	for _, c in ipairs(created2) do
		if c.kind == "checkbox" then boxes[#boxes + 1] = c end
	end

	local inits = _G.__blizzInits or {}
	local byVar = {}
	for _, init in ipairs(inits) do byVar[init:GetSetting():GetVariable()] = init end

	check("an existing Blizzard tooltip is appended to, not replaced",
		byVar.instantQuestText
			and byVar.instantQuestText.data.tooltip:find("Quest text appears instantly.", 1, true) ~= nil
			and byVar.instantQuestText.data.tooltip:find("Managed by", 1, true) ~= nil,
		byVar.instantQuestText and byVar.instantQuestText.data.tooltip)
	check("a Blizzard option with no tooltip gets one",
		byVar.autoQuestWatch and byVar.autoQuestWatch.data.tooltip
			and byVar.autoQuestWatch.data.tooltip:find("Managed by", 1, true) ~= nil,
		byVar.autoQuestWatch and tostring(byVar.autoQuestWatch.data.tooltip))
	check("the annotation is the note and nothing else",
		byVar.autoQuestWatch
			and byVar.autoQuestWatch.data.tooltip:find("/noAutoQuestTracking", 1, true) == nil,
		byVar.autoQuestWatch and byVar.autoQuestWatch.data.tooltip)
	check("Outline Mode is annotated too",
		byVar.Outline and byVar.Outline.data.tooltip:find("Managed by", 1, true) ~= nil)
	check("an unrelated Blizzard option is left alone",
		byVar.somethingElse and byVar.somethingElse.data.tooltip == "Nothing to do with quests.",
		byVar.somethingElse and byVar.somethingElse.data.tooltip)

	-- Running twice must not stack the note.
	local before = byVar.instantQuestText.data.tooltip
	pcall(ns.AnnotateBlizzardOptions)
	pcall(ns.AnnotateBlizzardOptions)
	check("annotating repeatedly does not stack", byVar.instantQuestText.data.tooltip == before)

	-- ---- closing the panel ----
	--
	-- Nothing is ever held over a close now, so closing must be silent: no
	-- rebuild, no dialog. Two earlier designs left state behind here.
	local mapKey2 = "hideMapQuestHelper"
	local mapSetting2
	for _, c in ipairs(boxes) do
		if c.setting:GetVariable() == "VanillaQuesting_" .. mapKey2 then mapSetting2 = c.setting end
	end
	if mapSetting2 then
		_G.__openSettingsPanel()
		local r0 = _G.__reloads
		_G.__popup = nil
		ns.db.settings[mapKey2] = not (ns.db.settings[mapKey2] and true or false)
		pcall(mapSetting2.__cb, mapSetting2, ns.db.settings[mapKey2])

		-- Blizzard's Defaults button reloads the UI itself when a setting it
		-- reset needs one, so a Defaults-driven change rebuilds immediately.
		-- No Apply to light, no dialog: two earlier attempts at this were
		-- built on a guess about what that button does.
		check("a Defaults-style reset rebuilds at once", _G.__reloads == r0 + 1,
			_G.__reloads - r0)
		check("and asks nothing of its own", _G.__popup == nil, tostring(_G.__popup))

		-- Closing afterwards must not rebuild again.
		local r1 = _G.__reloads
		_G.__popup = nil
		_G.__closeSettingsPanel()
		check("closing afterwards does not rebuild again", _G.__reloads == r1, _G.__reloads - r1)
		check("and raises no dialog", _G.__popup == nil, tostring(_G.__popup))
	end

	-- ---- Defaults that changes nothing reload-worthy ----
	if mapSetting2 then
		_G.__openSettingsPanel()
		local r0 = _G.__reloads
		-- Reset every setting to what it already is: nothing has moved.
		for _, c in ipairs(boxes) do
			local key = c.setting:GetVariable():gsub("VanillaQuesting_", "")
			pcall(c.setting.__cb, c.setting, ns.db.settings[key])
		end
		pcall(SettingsPanel.CommitSettings, SettingsPanel)
		check("a reset that moves nothing does not rebuild", _G.__reloads == r0, _G.__reloads - r0)

		-- Pressing Defaults twice rebuilds once: the second press moves
		-- nothing, so there is nothing to rebuild for.
		_G.__openSettingsPanel()
		local r1 = _G.__reloads
		local was = ns.db.settings[mapKey2] and true or false
		ns.db.settings[mapKey2] = not was
		pcall(mapSetting2.__cb, mapSetting2, not was)
		check("the first Defaults press rebuilds", _G.__reloads == r1 + 1, _G.__reloads - r1)

		pcall(mapSetting2.__cb, mapSetting2, not was)
		check("a second press that moves nothing does not rebuild again",
			_G.__reloads == r1 + 1, _G.__reloads - r1)
		_G.__closeSettingsPanel()
	end
end

if scenario == "normal" then
	-- ---- yielding to Blizzard's own control ----
	--
	-- questPOI has no Blizzard control, so a change behind the player's back
	-- gets put back. instantQuestText HAS one, so a change is the player using
	-- their own interface and the AddOn stands down instead of fighting it.
	ns:ResetDefaults(true)

	cvars.questPOI = "1"
	fire("CVAR_UPDATE")
	check("a CVar with no Blizzard control is re-asserted", cvars.questPOI == "0", cvars.questPOI)
	check("and its option stays on", ns.db.settings.hideMapQuestHelper == true)

	local b4 = #chatlog
	cvars.instantQuestText = "1"
	fire("CVAR_UPDATE")
	check("a CVar the player owns is left where they put it",
		cvars.instantQuestText == "1", cvars.instantQuestText)
	check("and the matching option turns itself off",
		ns.db.settings.noInstantQuestText == false, tostring(ns.db.settings.noInstantQuestText))
	local told = false
	for i = b4 + 1, #chatlog do
		if tostring(chatlog[i]):find("Instant Quest Text", 1, true) then told = true end
	end
	check("and it says so rather than changing silently", told)
	check("the new value becomes what gets restored later",
		VanillaQuestingDB.state.instantQuestText == "1",
		tostring(VanillaQuestingDB.state.instantQuestText))

	-- The other direction. v0.14.0 only handled option-on -> variable-moved,
	-- so putting a Blizzard control BACK to the Classic value did nothing,
	-- and after one yield the option was off and never woke up again.
	b4 = #chatlog
	cvars.instantQuestText = "0"
	fire("CVAR_UPDATE")
	check("putting the Blizzard control back turns the option back on",
		ns.db.settings.noInstantQuestText == true, tostring(ns.db.settings.noInstantQuestText))
	told = false
	for i = b4 + 1, #chatlog do
		if tostring(chatlog[i]):find("is now", 1, true)
			and tostring(chatlog[i]):find("on", 1, true) then told = true end
	end
	check("and says so too", told)

	-- Repeatedly, in both directions: one yield must not deafen it.
	for round = 1, 3 do
		cvars.instantQuestText = "1"
		fire("CVAR_UPDATE")
		check("round " .. round .. ": follows the player off",
			ns.db.settings.noInstantQuestText == false)
		cvars.instantQuestText = "0"
		fire("CVAR_UPDATE")
		check("round " .. round .. ": follows the player back on",
			ns.db.settings.noInstantQuestText == true)
	end

	-- An option that ships OFF must mirror too. Outline was completely inert
	-- in v0.14.0 for exactly this reason.
	ns:ResetDefaults(true)
	check("the experimental outline option ships off",
		ns.db.settings.outlineMode == false)
	cvars.Outline = "1"          -- what this AddOn would ask for
	fire("CVAR_UPDATE")
	check("setting Blizzard's Outline Mode turns the option on",
		ns.db.settings.outlineMode == true,
		tostring(ns.db.settings.outlineMode))
	cvars.Outline = "0"
	fire("CVAR_UPDATE")
	check("and only 0 turns the option off again",
		ns.db.settings.outlineMode == false)

	ns:ResetDefaults(true)
end

if scenario == "normal" then
	-- One preset cannot mean two things depending on whether it was picked in
	-- the panel or typed. "/vq on" used to leave experimental options where
	-- they were while the panel's preset set them false.
	-- A preset that undoes a deliberate choice is worse than one that ignores
	-- it, so Full Classic leaves the experiments where the player put them.
	ns:Set("outlineMode", true)
	pcall(SlashCmdList["VANILLAQUESTING"], "on")
	check("/vq on leaves an experimental option switched on",
		ns.db.settings.outlineMode == true,
		tostring(ns.db.settings.outlineMode))
	local normalOn = true
	for i = 1, #ns.modules do
		local m = ns.modules[i]
		if not m.experimental and not ns.db.settings[m.key] then normalOn = false end
	end
	check("and still turns every normal option on", normalOn)

	-- Disabled means nothing is on, experiments included.
	pcall(SlashCmdList["VANILLAQUESTING"], "off")
	local anyOn = false
	for i = 1, #ns.modules do
		if ns.db.settings[ns.modules[i].key] then anyOn = true end
	end
	check("/vq off takes the experiments too", not anyOn)
	ns:ResetDefaults(true)

	-- Outline is not a boolean: 1, 2 and 3 all mean outlines are on.
	ns:ResetDefaults(true)
	for _, v in ipairs({ "1", "2", "3" }) do
		cvars.Outline = v
		fire("CVAR_UPDATE")
		check("Outline = " .. v .. " ticks the option",
			ns.db.settings.outlineMode == true, tostring(ns.db.settings.outlineMode))
	end
	cvars.Outline = "0"
	fire("CVAR_UPDATE")
	check("Outline = 0 unticks it", ns.db.settings.outlineMode == false)

	-- And a value the player chose is not dragged down to the one the AddOn
	-- would have asked for. Each leg starts clean: the remembered pre-AddOn
	-- value carries over otherwise and decides the answer instead.
	ns:Set("outlineMode", false)
	VanillaQuestingDB.state.Outline = nil
	cvars.Outline = "3"
	ns:Set("outlineMode", true)
	check("turning the option on leaves Outline = 3 alone", cvars.Outline == "3", cvars.Outline)

	ns:Set("outlineMode", false)
	VanillaQuestingDB.state.Outline = nil
	cvars.Outline = "0"
	ns:Set("outlineMode", true)
	check("but from off it asks for 2, Blizzard's own default", cvars.Outline == "2", cvars.Outline)
	ns:ResetDefaults(true)
end

if scenario == "native" then
	-- ---- experimental options and the preset ----
	--
	-- Switching one on used to drop the preset to Custom, and picking Full
	-- Classic switched it back off -- a preset undoing a deliberate choice.
	local drops3, boxes3 = {}, {}
	for _, c in ipairs(_G.__nativeControls or {}) do
		if c.kind == "dropdown" then drops3[#drops3 + 1] = c
		elseif c.kind == "checkbox" then boxes3[#boxes3 + 1] = c end
	end

	ns:ResetDefaults(true)
	for i = 1, #ns.modules do
		local m = ns.modules[i]
		if not m.experimental then ns.db.settings[m.key] = true end
	end
	ns.RefreshOptions()
	check("preset reads classic with experiments off",
		drops3[1].setting:GetValue() == "classic", drops3[1].setting:GetValue())

	ns.db.settings.outlineMode = true
	ns.RefreshOptions()
	check("switching an experiment on keeps it Full Classic",
		drops3[1].setting:GetValue() == "classic", drops3[1].setting:GetValue())

	-- And picking Full Classic must not switch it back off. Start from a
	-- known state: chaining preset changes made a later SetValue a no-op,
	-- because the dropdown was already on the value being written.
	ns:ResetDefaults(true)
	ns.db.settings.outlineMode = true
	ns.RefreshOptions()
	pcall(drops3[1].setting.SetValue, drops3[1].setting, "classic")
	pcall(_G.pressApply)
	check("picking Full Classic leaves the experiment on",
		ns.db.settings.outlineMode == true,
		tostring(ns.db.settings.outlineMode))

	-- Disabled still takes everything.
	ns:ResetDefaults(true)
	ns.db.settings.outlineMode = true
	ns.RefreshOptions()
	pcall(drops3[1].setting.SetValue, drops3[1].setting, "disabled")
	pcall(_G.pressApply)
	local anyOn = false
	for i = 1, #ns.modules do
		if ns.db.settings[ns.modules[i].key] then anyOn = true end
	end
	check("Disabled turns the experiments off with everything else", not anyOn)

	-- The wording has to match the behaviour.
	local expTip
	for _, c in ipairs(boxes3) do
		local key = c.setting:GetVariable():gsub("VanillaQuesting_", "")
		if ns.modules[key].experimental then expTip = c.tooltip end
	end
	check("the experimental note warns it is untested",
		expTip and expTip:find("untested and potentially unstable", 1, true) ~= nil,
		tostring(expTip))

	ns:ResetDefaults(true)
end

if scenario == "normal" then
	-- ---- the questgiver portrait ----
	--
	-- The framed character box beside quest text, in the offer window and in
	-- the quest log. It comes back every time a quest is opened, so a one-shot
	-- hide at login would pass a naive test and fail in play.
	check("portrait module exists", ns.modules.hideCharacterFrame ~= nil)
	ns:ResetDefaults(true)
	check("it is on by default", ns.db.settings.hideCharacterFrame == true)

	QuestFrame_ShowQuestPortrait()
	check("the portrait is hidden when a quest is offered", QuestNPCModel:IsShown() == false)
	QuestFrame_ShowQuestPortrait()
	QuestFrame_ShowQuestPortrait()
	check("and stays hidden on later quests", QuestNPCModel:IsShown() == false)
	check("Status names the frame it found",
		ns.modules.hideCharacterFrame:Status():find("QuestNPCModel", 1, true) ~= nil,
		ns.modules.hideCharacterFrame:Status())

	ns:Set("hideCharacterFrame", false)
	QuestFrame_ShowQuestPortrait()
	check("turning it off shows the portrait again", QuestNPCModel:IsShown() == true)
	ns:Set("hideCharacterFrame", true)

	-- ---- quest progress in tooltips ----
	--
	-- The rule under test is the one from six captured tooltips (G12): line 1
	-- is never touched; a gold line whose text matches an ACTIVE QUEST is the
	-- header; the objective lines under it follow.
	check("tooltip module exists", ns.modules.hideTooltipsQuestProgress ~= nil)
	check("it is on by default", ns.db.settings.hideTooltipsQuestProgress == true)

	local GOLD = { r = 1.00, g = 0.82, b = 0.00 }
	local WHITE = { r = 1, g = 1, b = 1 }

	local function line(text, c) return { text = text, r = c.r, g = c.g, b = c.b } end

	-- Sample 1: the quest block sits at lines 3 and 4.
	_G.__setTooltip({
		line("Stonetusk Boar", { r = 0.90, g = 0.70, b = 0.00 }),
		line("Level 6 Beast", WHITE),
		line("Pie for Billy", GOLD),
		line(" - Tender Boar Meat: 0/4", WHITE),
	})
	_G.__showTooltip()
	local out = _G.__tooltipText()
	check("the unit name survives", out[1] == "Stonetusk Boar", tostring(out[1]))
	-- Two of four lines went. A correctly fitted tooltip ends one padding
	-- below the last surviving line, so it should be the height a two-line
	-- tooltip would have had -- and it must STAY that way after Show() has
	-- re-laid it out, which is what defeated the two previous attempts.
	check("the tooltip ends just under its last surviving line",
		math.abs(GameTooltip.__height - (4 + 2 * 12 + 2 + 4)) < 1, GameTooltip.__height)

	-- Show() again, as the client does on any refresh. The fit must survive.
	_G.__tooltipRelayout()
	_G.__retargetTooltip()
	check("and the fit survives a re-layout",
		math.abs(GameTooltip.__height - (4 + 2 * 12 + 2 + 4)) < 1, GameTooltip.__height)
	check("the level line survives", out[2] == "Level 6 Beast", tostring(out[2]))
	check("the quest title goes", out[3] == "", tostring(out[3]))
	check("the objective goes", out[4] == "", tostring(out[4]))

	-- Sample 2: a gathering node's NAME is the same gold as a quest title.
	-- This is the case that a colour-only rule eats by mistake.
	_G.__setTooltip({
		line("Silverleaf", GOLD),
		line("Herbalism", { r = 1, g = 1, b = 0 }),
	})
	_G.__showTooltip()
	out = _G.__tooltipText()
	check("a gold node name on line 1 is never touched", out[1] == "Silverleaf", tostring(out[1]))
	check("and its profession line survives", out[2] == "Herbalism", tostring(out[2]))

	-- Moving straight from one creature to the next never fires OnShow again.
	-- v0.16.0 hooked only OnShow, so in play it removed nothing at all.
	_G.__setTooltip({
		line("Another Boar", { r = 0.90, g = 0.70, b = 0.00 }),
		line("Pie for Billy", GOLD),
		line(" - Tender Boar Meat: 1/4", WHITE),
	})
	_G.__retargetTooltip()
	out = _G.__tooltipText()
	check("a retargeted tooltip is scrubbed without a fresh OnShow",
		out[2] == "" and out[3] == "",
		tostring(out[2]) .. " / " .. tostring(out[3]))

	-- Sample 3: the same quest, one line further down. A fixed index fails here.
	_G.__setTooltip({
		line("Stonetusk Boar", { r = 0.90, g = 0.70, b = 0.00 }),
		line("Level 5 Corpse", WHITE),
		line("Skinnable", { r = 1, g = 1, b = 0 }),
		line("Pie for Billy", GOLD),
		line(" - Tender Boar Meat: 0/4", WHITE),
	})
	_G.__showTooltip()
	out = _G.__tooltipText()
	check("Skinnable survives", out[3] == "Skinnable", tostring(out[3]))
	check("the quest title goes wherever it sits", out[4] == "", tostring(out[4]))
	check("as does its objective", out[5] == "", tostring(out[5]))

	-- A gold line that is NOT in the quest log must survive even below line 1.
	_G.__setTooltip({
		line("Some Mob", WHITE),
		line("Not A Quest I Have", GOLD),
		line(" - Something: 0/1", WHITE),
	})
	_G.__showTooltip()
	out = _G.__tooltipText()
	check("a gold line that is not an active quest survives",
		out[2] == "Not A Quest I Have", tostring(out[2]))
	check("and so does the line under it", out[3] == " - Something: 0/1", tostring(out[3]))

	-- A quest-log HEADER is a zone name, not a quest, and must not match.
	_G.__setQuestLog({
		{ title = "Elwynn Forest", isHeader = true },
		{ title = "Pie for Billy", isHeader = false },
	})
	_G.__setTooltip({
		line("Some Mob", WHITE),
		line("Elwynn Forest", GOLD),
	})
	_G.__showTooltip()
	out = _G.__tooltipText()
	check("a quest log zone header is not treated as a quest",
		out[2] == "Elwynn Forest", tostring(out[2]))

	-- Turned off, the tooltip is Blizzard's again.
	ns:Set("hideTooltipsQuestProgress", false)
	_G.__setTooltip({
		line("Stonetusk Boar", { r = 0.90, g = 0.70, b = 0.00 }),
		line("Pie for Billy", GOLD),
		line(" - Tender Boar Meat: 0/4", WHITE),
	})
	_G.__showTooltip()
	out = _G.__tooltipText()
	check("turning it off leaves the quest block alone",
		out[2] == "Pie for Billy" and out[3] == " - Tender Boar Meat: 0/4",
		tostring(out[2]) .. " / " .. tostring(out[3]))

	ns:ResetDefaults(true)

	-- ---- one palette ----
	--
	-- Every colour in the AddOn comes from ns.color, and the yellows and
	-- whites come from the GAME's own codes where it defines them.
	check("the palette prefers Blizzard's own yellow",
		ns.color.body == NORMAL_FONT_COLOR_CODE, ns.color.body)
	check("and Blizzard's own white", ns.color.title == HIGHLIGHT_FONT_COLOR_CODE)
	check("and Blizzard's own grey", ns.color.muted == GRAY_FONT_COLOR_CODE)
	check("there is exactly one orange",
		ns.color.experimental == "|cffff8019", ns.color.experimental)
end

if scenario == "native" then
	-- ---- every module reaches the panel, in a stable order ----
	--
	-- Two orders collided (20/20 and 50/50) and table.sort is unstable in
	-- Lua 5.1, so those pairs could swap places between one login and the
	-- next. Unique orders are what make the panel and /vq status agree with
	-- themselves session to session.
	local seenOrder, dupe = {}, nil
	for i = 1, #ns.modules do
		local o = ns.modules[i].order
		check("module " .. ns.modules[i].key .. " declares an order", o ~= nil)
		if o and seenOrder[o] then dupe = o .. " (" .. seenOrder[o] .. " and " .. ns.modules[i].key .. ")" end
		if o then seenOrder[o] = ns.modules[i].key end
	end
	check("no two modules share an order", dupe == nil, tostring(dupe))

	-- And every registered module has a checkbox, so a feature cannot ship
	-- without reaching the options panel.
	local inPanel = {}
	for _, c in ipairs(_G.__nativeControls or {}) do
		if c.kind == "checkbox" then
			inPanel[c.setting:GetVariable():gsub("VanillaQuesting_", "")] = true
		end
	end
	local missing = {}
	for i = 1, #ns.modules do
		if not inPanel[ns.modules[i].key] then missing[#missing + 1] = ns.modules[i].key end
	end
	check("every module has a checkbox in the panel", #missing == 0, table.concat(missing, ", "))
end

if scenario == "normal" then
	-- Every module appears in /vq status, so a feature cannot ship without
	-- being discoverable from chat either.
	local b4 = #chatlog
	pcall(SlashCmdList["VANILLAQUESTING"], "status")
	local text = table.concat(chatlog, "\n", b4 + 1, #chatlog)
	local absent = {}
	for i = 1, #ns.modules do
		if not text:find(ns.modules[i].key, 1, true) then absent[#absent + 1] = ns.modules[i].key end
	end
	check("every module appears in /vq status", #absent == 0, table.concat(absent, ", "))

	-- And help says where the option names come from.
	b4 = #chatlog
	pcall(SlashCmdList["VANILLAQUESTING"], "help")
	text = table.concat(chatlog, "\n", b4 + 1, #chatlog)
	check("/vq help points at where option names are listed",
		text:find("/vq status", 1, true) ~= nil)
end

if scenario == "normal" then
	-- ---- a tooltip re-used after another one ----
	--
	-- Hover something harmless, then a quest creature, without the tooltip
	-- hiding in between. The fit has to be right on the second one too: the
	-- frame arrives carrying whatever height the first left on it.
	ns:ResetDefaults(true)
	local GOLD2 = { r = 1.00, g = 0.82, b = 0.00 }
	local WHITE2 = { r = 1, g = 1, b = 1 }
	local function ln(t, c) return { text = t, r = c.r, g = c.g, b = c.b } end

	-- A herb node first. Nothing to remove, so nothing should be resized.
	_G.__setTooltip({ ln("Silverleaf", GOLD2), ln("Herbalism", { r = 1, g = 1, b = 0 }) })
	_G.__showTooltip()
	local herbHeight = GameTooltip.__height
	check("a tooltip with nothing to remove is left alone",
		math.abs(herbHeight - (4 + 2 * 12 + 2 + 4)) < 1, herbHeight)

	-- Now a four-line quest creature, arriving on the same frame.
	_G.__setTooltip({
		ln("Stonetusk Boar", { r = 0.90, g = 0.70, b = 0.00 }),
		ln("Level 6 Beast", WHITE2),
		ln("Pie for Billy", GOLD2),
		ln(" - Tender Boar Meat: 0/4", WHITE2),
	})
	_G.__retargetTooltip()
	local out2 = _G.__tooltipText()
	check("the re-used tooltip is still scrubbed", out2[3] == "" and out2[4] == "",
		tostring(out2[3]) .. " / " .. tostring(out2[4]))
	check("and the re-used tooltip is fitted to two lines",
		math.abs(GameTooltip.__height - (4 + 2 * 12 + 2 + 4)) < 1, GameTooltip.__height)

	-- And back to something clean: it must not stay cramped.
	_G.__setTooltip({
		ln("Innkeeper Allison", { r = 0.90, g = 0.70, b = 0.00 }),
		ln("Level 30 Humanoid", WHITE2),
		ln("Innkeeper", { r = 1, g = 1, b = 0 }),
	})
	_G.__retargetTooltip()
	local out3 = _G.__tooltipText()
	check("a clean tooltip after a scrubbed one keeps all its lines",
		out3[2] == "Level 30 Humanoid" and out3[3] == "Innkeeper",
		tostring(out3[2]) .. " / " .. tostring(out3[3]))
	check("and is not left cramped by the previous fit",
		math.abs(GameTooltip.__height - (4 + 3 * 12 + 2 * 2 + 4)) < 1, GameTooltip.__height)

	ns:ResetDefaults(true)

	-- ---- turning the minimap option off re-enables Blizzard's tracking ----
	--
	-- Track Quest POIs is on by default in the game, so switching this option
	-- off should hand back the default rather than whatever the entry happened
	-- to be when the AddOn was installed.
	tracking[4].active = false
	ClassicQuestingMoPDB = nil
	ns:Set("hideMinimapQuestHelper", true)
	check("the option turns tracking off", tracking[4].active == false)
	ns:Set("hideMinimapQuestHelper", false)
	check("turning it off turns Track Quest POIs back on", tracking[4].active == true,
		tostring(tracking[4].active))
	ns:ResetDefaults(true)
end

if scenario == "native" then
	-- Every category gets a heading, and the options under it all belong to it.
	local headings, current, wrong = {}, nil, nil
	for _, c in ipairs(_G.__nativeControls or {}) do
		if c.kind == "header" then
			current = (c.text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
			headings[#headings + 1] = current
		elseif c.kind == "checkbox" then
			local key = c.setting:GetVariable():gsub("VanillaQuesting_", "")
			if ns.modules[key].group ~= current then
				wrong = key .. " sits under " .. tostring(current)
					.. " but belongs to " .. tostring(ns.modules[key].group)
			end
		end
	end
	check("every option sits under its own category heading", wrong == nil, tostring(wrong))
	check("the categories are the five agreed",
		table.concat(headings, ", "):find("Map and minimap, Quests, Quest Tracker, UI, Experimental", 1, true) ~= nil,
		table.concat(headings, ", "))
end

print(string.format("--- %s: %d passed, %d failed ---", scenario, pass, fail))
os.exit(fail == 0 and 0 or 1)