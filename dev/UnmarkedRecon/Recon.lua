-- Unmarked Recon v0.2
-- Probes which quest-helper UI pieces this client actually has.
--
-- /unrecon        run the probe (prints to chat, stores to SavedVariables)
-- /unrecon copy   open a selectable text box you can Ctrl+A / Ctrl+C out of
--
-- After running it, type /reload to flush SavedVariables to disk, then read:
--   _classic_\WTF\Account\<ACCOUNT>\SavedVariables\UnmarkedRecon.lua

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
		mark(true, "cvar " .. name .. " = " .. tostring(value))
	else
		mark(false, "cvar " .. name)
	end
end

local function collect()
	wipe(lines)

	local version, build, _, tocnum = GetBuildInfo()
	add("Unmarked Recon - " .. date("%Y-%m-%d %H:%M"))
	add("Client " .. tostring(version) .. " build " .. tostring(build) .. ", interface number " .. tostring(tocnum))

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
		if WorldMapFrame.pinPools and next(WorldMapFrame.pinPools) then
			add("Pin pool templates (these name the pins to remove):")
			for template in pairs(WorldMapFrame.pinPools) do
				add("   " .. tostring(template))
			end
		else
			add("No pin pools yet - open the world map, then run /unrecon again.")
		end
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

	head("Named Minimap children")
	local kids = { Minimap:GetChildren() }
	for i = 1, #kids do
		local n = kids[i]:GetName()
		if n then add("   " .. n) end
	end

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

local function run(arg)
	local text = collect()

	UnmarkedReconDB.report = text
	UnmarkedReconDB.generated = date("%Y-%m-%d %H:%M:%S")

	if arg == "copy" then
		showCopy(text)
		return
	end

	for i = 1, #lines do
		DEFAULT_CHAT_FRAME:AddMessage(lines[i])
	end
	DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Saved. Type /reload to write it to disk, or /unrecon copy for a copyable box.|r")
end

SLASH_UNRECON1 = "/unrecon"
SlashCmdList["UNRECON"] = function(msg)
	run((msg or ""):lower():match("^%s*(%a*)"))
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
	DEFAULT_CHAT_FRAME:AddMessage("|cff66ccff[Recon]|r loaded. Open the world map, then |cffffd100/unrecon|r.")
end)
