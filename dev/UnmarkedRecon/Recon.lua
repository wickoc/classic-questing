-- Unmarked Recon v0.3
-- Throwaway dev-only probe. Not part of Classic Questing, never shipped with it.
-- Probes which quest-helper UI pieces this client actually has.
--
-- /unrecon              run the probe (short summary to chat, full report to SavedVariables)
-- /unrecon print        run and dump the whole report to chat
-- /unrecon copy         open a selectable text box you can Ctrl+A / Ctrl+C out of
-- /unrecon set <cvar> <value>   set one of the four quest CVars, for the G5 effect test
--
-- After running it, type /reload to flush SavedVariables to disk, then read:
--   _classic_\WTF\Account\<ACCOUNT>\SavedVariables\UnmarkedRecon.lua
--
-- v0.3 targets the five gaps left open by the v0.2 run (see SPEC.md "What the log does
-- not settle"). Sections are tagged [G1]..[G5] so the output maps back to the spec.
--
-- Design rule for this probe: discover, don't guess. Where v0.2 asked "does the name I
-- expect exist?", v0.3 enumerates what is actually there -- method tables, provider
-- objects, tracking types, globals -- so a negative result means "not present" rather
-- than "I guessed the wrong name".

local RECON_VERSION = "0.3"

UnmarkedReconDB = UnmarkedReconDB or {}

local lines = {}

local function add(msg)
	lines[#lines + 1] = msg
end

local function head(title)
	add("")
	add("== " .. title .. " ==")
end

-- "OK" / "--" prefixes instead of colour codes, so the saved file stays clean.
local function mark(present, text)
	add((present and "OK   " or "--   ") .. text)
end

local function probe(name)
	local v = _G[name]
	if v == nil then
		mark(false, name)
	elseif type(v) == "table" and v.GetObjectType then
		mark(true, name .. "  [" .. v:GetObjectType() .. "]")
	else
		mark(true, name .. "  [" .. type(v) .. "]")
	end
end

local function probeMethod(obj, objName, method)
	mark(obj and type(obj[method]) == "function", objName .. ":" .. method)
end

local function probeCVar(name)
	local ok, value = pcall(GetCVar, name)
	if ok and value ~= nil then
		local line = "cvar " .. name .. " = " .. tostring(value)
		local ok2, _, default = pcall(GetCVarInfo, name)
		if ok2 and default ~= nil then
			line = line .. "  (default " .. tostring(default) .. ")"
		end
		mark(true, line)
	else
		mark(false, "cvar " .. name)
	end
end

---------------------------------------------------------------------
-- Discovery helpers
---------------------------------------------------------------------

-- Walk an object's metatable __index chain and collect every method name.
-- Returns a sorted array, or nil if the chain isn't enumerable from Lua
-- (which is itself a result worth reporting -- it means this probe cannot
-- see the method table, not that the object has no methods).
local function collectMethodNames(obj)
	local names, seen = {}, {}
	local ok = pcall(function()
		local mt = getmetatable(obj)
		local depth = 0
		while mt and depth < 10 do
			local idx = rawget(mt, "__index")
			if type(idx) ~= "table" then break end
			for k, v in pairs(idx) do
				if type(k) == "string" and type(v) == "function" and not seen[k] then
					seen[k] = true
					names[#names + 1] = k
				end
			end
			mt = getmetatable(idx)
			depth = depth + 1
		end
	end)
	if not ok then return nil end
	table.sort(names)
	return names
end

-- Report every method on obj whose name matches any of the patterns.
-- Prints the total method count too, so "0 matches out of 0 methods" (chain
-- not readable) is distinguishable from "0 matches out of 340" (really absent).
local function dumpMethods(obj, objName, patterns)
	if obj == nil then
		add("   " .. objName .. " does not exist.")
		return
	end
	local names = collectMethodNames(obj)
	if not names or #names == 0 then
		add("   " .. objName .. ": method table not enumerable from Lua - INCONCLUSIVE,")
		add("      this probe could not read the method chain. Absence here is not evidence.")
		return
	end
	add("   " .. objName .. ": " .. #names .. " methods visible.")
	local hits = 0
	for i = 1, #names do
		local n = names[i]
		for p = 1, #patterns do
			if n:lower():find(patterns[p]) then
				add("      " .. objName .. ":" .. n)
				hits = hits + 1
				break
			end
		end
	end
	if hits == 0 then
		add("      (no method name matches " .. table.concat(patterns, " / ") .. ")")
	end
end

-- Sorted list of every _G key whose lowercased name contains `needle`.
local function globalsMatching(needle, cap)
	local found = {}
	for k in pairs(_G) do
		if type(k) == "string" and k:lower():find(needle, 1, true) then
			found[#found + 1] = k
		end
	end
	table.sort(found)
	if cap and #found > cap then
		local trimmed = {}
		for i = 1, cap do trimmed[i] = found[i] end
		trimmed[cap + 1] = "... and " .. (#found - cap) .. " more"
		return trimmed, #found
	end
	return found, #found
end

local function listGlobals(label, needle, cap)
	local found, total = globalsMatching(needle, cap)
	add("   " .. label .. ": " .. total .. " global name(s)")
	for i = 1, #found do
		add("      " .. found[i])
	end
end

-- Enumerate a frame's children, named and unnamed alike. v0.2 only printed
-- named children, so anything anonymous was invisible in that log.
local function dumpChildren(frame, frameName)
	if not frame then
		add("   " .. frameName .. " does not exist.")
		return
	end
	local ok, kids = pcall(function() return { frame:GetChildren() } end)
	if not ok then
		add("   " .. frameName .. ": GetChildren failed.")
		return
	end
	add("   " .. frameName .. ": " .. #kids .. " child frame(s)")
	for i = 1, #kids do
		local k = kids[i]
		local name = k:GetName() or "<unnamed>"
		local otype = "?"
		pcall(function() otype = k:GetObjectType() end)
		local shown = "?"
		pcall(function() shown = k:IsShown() and "shown" or "hidden" end)
		add(string.format("      %2d  %-32s %-14s %s", i, name, otype, shown))
	end
end

local function dumpRegions(frame, frameName)
	if not frame then return end
	local ok, regions = pcall(function() return { frame:GetRegions() } end)
	if not ok then
		add("   " .. frameName .. ": GetRegions failed.")
		return
	end
	add("   " .. frameName .. ": " .. #regions .. " region(s)")
	for i = 1, #regions do
		local r = regions[i]
		local name = r:GetName() or "<unnamed>"
		local otype = "?"
		pcall(function() otype = r:GetObjectType() end)
		local extra = ""
		if otype == "Texture" then
			local okt, tex = pcall(function() return r:GetTexture() end)
			if okt and tex then extra = "  tex=" .. tostring(tex) end
		end
		add(string.format("      %2d  %-32s %-14s%s", i, name, otype, extra))
	end
end

---------------------------------------------------------------------
-- Sections
---------------------------------------------------------------------

-- [G1] With the Minimap:SetQuestBlob* family confirmed absent in v0.2, the
-- question is what this client has *instead*. Enumerate rather than guess.
local function sectionMinimapSurface()
	head("[G1] Minimap: what is actually on it")

	add("Method names on Minimap matching quest/blob/arch/poi/blip/track:")
	dumpMethods(Minimap, "Minimap", { "blob", "quest", "arch", "poi", "blip", "track" })

	add("")
	dumpChildren(Minimap, "Minimap")
	add("")
	dumpRegions(Minimap, "Minimap")

	add("")
	if MinimapCluster then
		dumpChildren(MinimapCluster, "MinimapCluster")
	else
		add("   MinimapCluster does not exist.")
	end

	add("")
	add("Is the minimap data-provider driven, like the world map?")
	mark(Minimap ~= nil and rawget(Minimap, "dataProviders") ~= nil, "Minimap.dataProviders")
	mark(MinimapCluster ~= nil and rawget(MinimapCluster, "dataProviders") ~= nil, "MinimapCluster.dataProviders")
	probeMethod(Minimap, "Minimap", "RemoveDataProvider")
	probeMethod(Minimap, "Minimap", "AddDataProvider")

	add("")
	listGlobals("Globals containing 'minimap'", "minimap", 90)
end

-- [G2] The tracking-menu route from the Tier 1 spec. Enumerate the tracking
-- types so we can see whether a quest-POI entry exists at all.
local function sectionTracking()
	head("[G2] Minimap tracking API")

	for _, n in ipairs({
		"C_Minimap", "SetTracking", "GetNumTrackingTypes", "GetTrackingInfo",
		"MiniMapTracking", "MiniMapTrackingFrame", "MiniMapTrackingButton",
		"MiniMapTrackingDropDown", "MiniMapTrackingIcon",
	}) do probe(n) end

	add("")
	if type(C_Minimap) == "table" then
		local keys = {}
		for k, v in pairs(C_Minimap) do
			if type(k) == "string" then keys[#keys + 1] = k .. "  [" .. type(v) .. "]" end
		end
		table.sort(keys)
		add("   C_Minimap members: " .. #keys)
		for i = 1, #keys do add("      C_Minimap." .. keys[i]) end
	else
		add("   C_Minimap is not a table - nothing to enumerate.")
	end

	add("")
	listGlobals("Globals containing 'tracking'", "tracking", 40)

	add("")
	add("Tracking types on this client:")
	local getCount = (type(C_Minimap) == "table" and C_Minimap.GetNumTrackingTypes) or GetNumTrackingTypes
	local getInfo = (type(C_Minimap) == "table" and C_Minimap.GetTrackingInfo) or GetTrackingInfo
	if type(getCount) ~= "function" or type(getInfo) ~= "function" then
		add("   No tracking count/info function found - the tracking-menu route is NOT available.")
		return
	end
	local okc, count = pcall(getCount)
	if not okc or type(count) ~= "number" then
		add("   Tracking count call failed: " .. tostring(count))
		return
	end
	add("   " .. count .. " tracking type(s)")
	for i = 1, count do
		local ok, a, b, c, d, e = pcall(getInfo, i)
		if ok then
			-- Return shape varies by client; print positionally and let the
			-- reader match it up rather than assuming names.
			if type(a) == "table" then
				add(string.format("      %2d  table: name=%s active=%s",
					i, tostring(a.name), tostring(a.active)))
			else
				add(string.format("      %2d  1=%s  2=%s  3=%s  4=%s  5=%s",
					i, tostring(a), tostring(b), tostring(c), tostring(d), tostring(e)))
			end
		else
			add(string.format("      %2d  call failed: %s", i, tostring(a)))
		end
	end
end

-- [G3] RemoveDataProvider takes a provider OBJECT. v0.2 gave us pin-pool
-- template NAMES, which is a different thing. Identify the providers.
local function sectionDataProviders()
	head("[G3] World map data providers - identifying them")

	if not (WorldMapFrame and WorldMapFrame.RemoveDataProvider) then
		add("   WorldMapFrame:RemoveDataProvider missing - re-check the map-style verdict.")
		return
	end

	dumpMethods(WorldMapFrame, "WorldMapFrame", { "dataprovider", "pin" })

	add("")
	-- Build a table -> global-name map so a provider can be identified by the
	-- mixin it was built from.
	local mixinName = {}
	local mixinCount = 0
	for k, v in pairs(_G) do
		if type(k) == "string" and type(v) == "table" and k:find("DataProvider") then
			mixinName[v] = k
			mixinCount = mixinCount + 1
		end
	end
	add("   Global *DataProvider* tables found: " .. mixinCount)
	do
		local names = {}
		for _, n in pairs(mixinName) do names[#names + 1] = n end
		table.sort(names)
		for i = 1, #names do add("      " .. names[i]) end
	end

	add("")
	local providers = {}
	for k, v in pairs(WorldMapFrame.dataProviders or {}) do
		-- Handle both [provider]=true and [i]=provider shapes.
		local p = (type(k) == "table" and k) or (type(v) == "table" and v) or nil
		if p then providers[#providers + 1] = p end
	end
	add("   Providers reachable: " .. #providers)

	local rows = {}
	for i = 1, #providers do
		local p = providers[i]

		-- Identify by mixin, walking the metatable chain.
		local ident
		local okid = pcall(function()
			if mixinName[p] then ident = mixinName[p] return end
			local mt = getmetatable(p)
			local depth = 0
			while mt and depth < 8 do
				local idx = rawget(mt, "__index")
				if type(idx) ~= "table" then break end
				if mixinName[idx] then ident = mixinName[idx] return end
				mt = getmetatable(idx)
				depth = depth + 1
			end
		end)
		if not okid then ident = nil end

		-- Ask the provider directly, if it will say.
		local template
		if type(p.GetPinTemplate) == "function" then
			local okt, t = pcall(p.GetPinTemplate, p)
			if okt then template = tostring(t) end
		end

		-- Own keys are often the most identifying thing a mixin-built table has.
		local keys = {}
		pcall(function()
			for k in pairs(p) do
				if type(k) == "string" then keys[#keys + 1] = k end
			end
		end)
		table.sort(keys)
		local shown = {}
		for j = 1, math.min(#keys, 12) do shown[j] = keys[j] end

		local text = {
			string.format("   provider @@  mixin=%s  GetPinTemplate=%s",
				tostring(ident), tostring(template)),
			"      own keys (" .. #keys .. "): " .. (next(shown) and table.concat(shown, ", ") or "none"),
		}

		-- If neither the mixin nor GetPinTemplate named it, fall back to its
		-- method names -- distinctive enough to tell providers apart by hand.
		if not ident and not template then
			local m = collectMethodNames(p)
			if m and #m > 0 then
				local pick = {}
				for j = 1, #m do
					local lm = m[j]:lower()
					if lm:find("pin") or lm:find("quest") or lm:find("blob") or lm:find("highlight")
					   or lm:find("map") or lm:find("refresh") then
						pick[#pick + 1] = m[j]
						if #pick >= 10 then break end
					end
				end
				if #pick == 0 then
					for j = 1, math.min(#m, 10) do pick[j] = m[j] end
				end
				text[#text + 1] = "      methods (" .. #m .. "): " .. table.concat(pick, ", ")
			else
				text[#text + 1] = "      methods: not enumerable - UNIDENTIFIABLE from this probe."
			end
		end

		rows[#rows + 1] = { sort = (ident or "zzz-unidentified") .. tostring(p), text = text }
	end

	-- Sort so two runs of the probe produce comparable output; pairs() order
	-- over dataProviders is not stable.
	table.sort(rows, function(a, b) return a.sort < b.sort end)
	for i = 1, #rows do
		for j = 1, #rows[i].text do
			add((rows[i].text[j]:gsub("provider @@", string.format("provider %2d", i), 1)))
		end
	end

	add("")
	if WorldMapFrame.pinPools and next(WorldMapFrame.pinPools) then
		add("   Pin pool templates currently spawned:")
		local pools = {}
		for template in pairs(WorldMapFrame.pinPools) do pools[#pools + 1] = tostring(template) end
		table.sort(pools)
		for i = 1, #pools do add("      " .. pools[i]) end
	else
		add("   No pin pools yet - open the world map, then run /unrecon again.")
	end
end

-- [G4] The panel is built last, but the slash command needs an opener.
local function sectionSettings()
	head("[G4] Settings API surface")

	for _, n in ipairs({ "Settings", "SettingsPanel", "InterfaceOptionsFrame" }) do probe(n) end

	if type(Settings) ~= "table" then
		add("   Settings is not a table - nothing to enumerate.")
		return
	end
	for _, m in ipairs({
		"RegisterCanvasLayoutCategory", "RegisterVerticalLayoutCategory",
		"RegisterAddOnCategory", "OpenToCategory", "RegisterAddOnSetting",
		"CreateCheckbox", "CreateCheckBox", "CreateControlTextContainer", "SetValue",
	}) do probeMethod(Settings, "Settings", m) end

	add("")
	local keys = {}
	for k, v in pairs(Settings) do
		if type(k) == "string" then
			local lk = k:lower()
			if lk:find("categor") or lk:find("open") or lk:find("register") then
				keys[#keys + 1] = k .. "  [" .. type(v) .. "]"
			end
		end
	end
	table.sort(keys)
	add("   Settings members matching register/open/category: " .. #keys)
	for i = 1, #keys do add("      Settings." .. keys[i]) end
end

-- [G5] The CVars exist; what they DO is untested. This section reports state
-- only. Use "/unrecon set questPOI 0" to run the actual effect test.
local function sectionCVarDetail()
	head("[G5] Quest CVar detail")
	for _, c in ipairs({ "questPOI", "questHelper", "autoQuestWatch", "trackQuestSorting" }) do
		probeCVar(c)
	end
	add("")
	add("   Effect is NOT tested here. Run: /unrecon set questPOI 0")
	add("   then look at the minimap and the world map, and set it back to 1.")
end

---------------------------------------------------------------------

local function collect()
	wipe(lines)

	local version, build, _, tocnum = GetBuildInfo()
	add("Unmarked Recon v" .. RECON_VERSION .. " - " .. date("%Y-%m-%d %H:%M"))
	add("Client " .. tostring(version) .. " build " .. tostring(build) .. ", interface number " .. tostring(tocnum))

	-- ---- v0.2 sections, kept so each run is a self-contained record ----

	head("Objective tracker (on-screen)")
	for _, n in ipairs({
		"WatchFrame", "WatchFrame_Update", "WatchFrame_Collapse",
		"ObjectiveTrackerFrame", "ObjectiveTracker_Update",
		"QuestWatchFrame", "AutoQuestPopUpTracker", "ObjectiveTrackerBlocksFrame",
	}) do probe(n) end

	head("World map")
	for _, n in ipairs({
		"WorldMapFrame", "WorldMapBlobFrame", "WorldMapPOIFrame",
		"WorldMapQuestShowObjectives", "WorldMapShowDropDown",
		"QuestMapFrame", "QuestScrollFrame", "QuestMapFrame_UpdateAll",
		"QuestMapFrame_ShowQuestDetails", "WorldMapTooltip",
	}) do probe(n) end

	head("Map style: old frame or modern canvas?")
	if WorldMapFrame and WorldMapFrame.RemoveDataProvider then
		add("MODERN CANVAS - WorldMapFrame:RemoveDataProvider exists.")
		local n = 0
		for _ in pairs(WorldMapFrame.dataProviders or {}) do n = n + 1 end
		add("Registered data providers: " .. n)
	else
		add("OLD-STYLE MAP - no RemoveDataProvider. Hide WorldMapBlobFrame / WorldMapPOIFrame directly.")
	end

	head("Quest POI system")
	for _, n in ipairs({
		"QuestPOIGetIconInfo", "QuestPOI_DisplayButton", "QuestPOI_GetButton",
		"QuestPOIUpdateIcons", "GetQuestPOILeaderboardInfo",
		"SetSuperTrackedQuestID", "GetSuperTrackedQuestID", "C_SuperTrack",
	}) do probe(n) end

	head("Minimap blob methods")
	for _, m in ipairs({
		"SetQuestBlobRingAlpha", "SetQuestBlobInsideAlpha", "SetQuestBlobRingScalar",
		"SetQuestBlobInsideTexture", "SetArchBlobRingAlpha", "SetArchBlobInsideAlpha",
	}) do probeMethod(Minimap, "Minimap", m) end

	head("Relevant CVars")
	for _, c in ipairs({
		"questPOI", "autoQuestWatch", "autoQuestProgress", "mapQuestDifficulty",
		"showQuestTrackingTooltips", "trackQuestSorting", "minimapTrackingShowAll",
		"questHelper", "worldMapFilterAccountCompletedQuests",
	}) do probeCVar(c) end

	head("Options panel API")
	for _, n in ipairs({ "Settings", "InterfaceOptions_AddCategory", "InterfaceOptionsFramePanelContainer" }) do
		probe(n)
	end
	if Settings and Settings.RegisterCanvasLayoutCategory then
		add("Modern Settings API available - use Settings.RegisterCanvasLayoutCategory.")
	else
		add("Legacy panel - use InterfaceOptions_AddCategory.")
	end

	-- ---- v0.3 gap sections ----

	sectionMinimapSurface()
	sectionTracking()
	sectionDataProviders()
	sectionSettings()
	sectionCVarDetail()

	return table.concat(lines, "\n")
end

---------------------------------------------------------------------
-- Copy window
---------------------------------------------------------------------

local copyFrame

local function buildCopyFrame()
	local f = CreateFrame("Frame", "UnmarkedReconCopyFrame", UIParent)
	f:SetSize(700, 500)
	f:SetPoint("CENTER")
	f:SetFrameStrata("DIALOG")
	f:EnableMouse(true)
	f:SetMovable(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)

	local bg = f:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0, 0, 0, 0.9)

	local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOP", 0, -10)
	title:SetText("Unmarked Recon - Ctrl+A then Ctrl+C, Escape to close")

	local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -4, -4)

	local scroll = CreateFrame("ScrollFrame", "UnmarkedReconScroll", f, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 14, -34)
	scroll:SetPoint("BOTTOMRIGHT", -34, 14)

	local edit = CreateFrame("EditBox", nil, scroll)
	edit:SetMultiLine(true)
	edit:SetFontObject(ChatFontNormal)
	edit:SetWidth(640)
	edit:SetAutoFocus(false)
	edit:SetScript("OnEscapePressed", function() f:Hide() end)
	scroll:SetScrollChild(edit)

	f.edit = edit
	f:Hide()
	return f
end

local function showCopy(text)
	copyFrame = copyFrame or buildCopyFrame()
	copyFrame.edit:SetText(text)
	copyFrame:Show()
	copyFrame.edit:SetFocus()
	copyFrame.edit:HighlightText()
end

---------------------------------------------------------------------
-- CVar effect test (G5)
---------------------------------------------------------------------

-- Whitelisted so a typo can't wander off into unrelated console variables.
local SETTABLE = {
	questpoi = "questPOI",
	questhelper = "questHelper",
	autoquestwatch = "autoQuestWatch",
	trackquestsorting = "trackQuestSorting",
}

local function setCVar(name, value)
	local real = SETTABLE[tostring(name):lower()]
	if not real then
		DEFAULT_CHAT_FRAME:AddMessage("|cffff5555[Recon]|r /unrecon set accepts only: questPOI, questHelper, autoQuestWatch, trackQuestSorting")
		return
	end
	if value == nil or value == "" then
		DEFAULT_CHAT_FRAME:AddMessage("|cffff5555[Recon]|r usage: /unrecon set " .. real .. " <value>")
		return
	end
	local okOld, old = pcall(GetCVar, real)
	local okSet, err = pcall(SetCVar, real, value)
	if not okSet then
		DEFAULT_CHAT_FRAME:AddMessage("|cffff5555[Recon]|r SetCVar failed: " .. tostring(err))
		return
	end
	local _, new = pcall(GetCVar, real)
	DEFAULT_CHAT_FRAME:AddMessage(string.format(
		"|cff66ccff[Recon]|r %s: %s -> %s   (put it back with /unrecon set %s %s)",
		real, okOld and tostring(old) or "?", tostring(new), real, okOld and tostring(old) or "?"))
end

---------------------------------------------------------------------

local function run(arg)
	local text = collect()

	UnmarkedReconDB.report = text
	UnmarkedReconDB.generated = date("%Y-%m-%d %H:%M:%S")
	UnmarkedReconDB.version = RECON_VERSION

	if arg == "copy" then
		showCopy(text)
		return
	end

	if arg == "print" then
		for i = 1, #lines do
			DEFAULT_CHAT_FRAME:AddMessage(lines[i])
		end
		return
	end

	-- Default: v0.3's report is long enough that dumping it all to chat is
	-- worse than useless. Print the headline findings and the section index.
	DEFAULT_CHAT_FRAME:AddMessage("|cff66ccff[Recon v" .. RECON_VERSION .. "]|r " .. #lines .. " lines collected.")
	for i = 1, #lines do
		local l = lines[i]
		if l:find("^== ") or l:find("^MODERN CANVAS") or l:find("^OLD%-STYLE") then
			DEFAULT_CHAT_FRAME:AddMessage("  " .. l)
		end
	end
	DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Saved. /reload to write it to disk, /unrecon copy for a copyable box, /unrecon print to dump it all here.|r")
end

-- Escape hatch: if the filtered dumps above miss the real mechanism because
-- it has an unexpected name, this lists EVERY method on a global.
local function dumpAllMethods(globalName)
	if not globalName or globalName == "" then
		DEFAULT_CHAT_FRAME:AddMessage("|cffff5555[Recon]|r usage: /unrecon methods Minimap")
		return
	end
	local obj = _G[globalName]
	if obj == nil then
		DEFAULT_CHAT_FRAME:AddMessage("|cffff5555[Recon]|r no global named " .. globalName)
		return
	end
	local names = collectMethodNames(obj)
	if not names or #names == 0 then
		DEFAULT_CHAT_FRAME:AddMessage("|cffff5555[Recon]|r " .. globalName .. ": method chain not enumerable.")
		return
	end
	DEFAULT_CHAT_FRAME:AddMessage("|cff66ccff[Recon]|r " .. globalName .. ": " .. #names .. " methods")
	-- Also park it in SavedVariables so it survives to disk with the report.
	UnmarkedReconDB.methodDumps = UnmarkedReconDB.methodDumps or {}
	UnmarkedReconDB.methodDumps[globalName] = table.concat(names, "\n")
	for i = 1, #names do
		DEFAULT_CHAT_FRAME:AddMessage("   " .. globalName .. ":" .. names[i])
	end
	DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Also saved to UnmarkedReconDB.methodDumps." .. globalName .. " - /reload to write it out.|r")
end

SLASH_UNRECON1 = "/unrecon"
SlashCmdList["UNRECON"] = function(msg)
	msg = msg or ""
	local cmd, a, b = msg:lower():match("^%s*(%a*)%s*(%S*)%s*(%S*)")
	if cmd == "methods" then
		local _, rawA = msg:match("^%s*(%a*)%s+(%S+)")
		dumpAllMethods(rawA)
		return
	end
	if cmd == "set" then
		-- Take the value from the original-case string so "top" etc. survive.
		local _, rawA, rawB = msg:match("^%s*(%a*)%s+(%S+)%s+(%S+)")
		setCVar(rawA or a, rawB or b)
		return
	end
	run(cmd)
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
	DEFAULT_CHAT_FRAME:AddMessage("|cff66ccff[Recon v" .. RECON_VERSION .. "]|r loaded. Open the world map, then |cffffd100/unrecon|r.")
end)
