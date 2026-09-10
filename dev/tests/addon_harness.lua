-- Stub WoW env for Vanilla Questing.
-- Models the two feedback loops that matter: SetCVar fires CVAR_UPDATE and
-- SetTracking fires MINIMAP_UPDATE_TRACKING, exactly as the client does.

local scenario = ...

wipe = function(t) for k in pairs(t) do t[k]=nil end return t end
local chat = {}
_G.__tooltipLines = {}
_G.__mapRefreshes = 0
WorldMapFrame = {
	RefreshAllDataProviders = function() _G.__mapRefreshes = _G.__mapRefreshes + 1 end,
	HookScript = function(self, which, fn)
		if which == "OnShow" then _G.__mapOnShow = fn end
	end,
}
_G.openWorldMap = function() if _G.__mapOnShow then _G.__mapOnShow() end end

DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) chat[#chat+1]=m; print("CHAT| "..tostring(m)) end }
SlashCmdList = {}

local frames = {}
_G.frames = frames
_G.fontstrings = {}

-- Permissive widget: named methods below behave, anything else is a no-op, so
-- layout calls do not need stubbing one by one. Templates are checked so the
-- addon's template probing is genuinely exercised.
local KNOWN_TEMPLATES = {
	UICheckButtonTemplate = true,
	UIPanelButtonTemplate = true,
	UIPanelCloseButton = true,
	UIPanelScrollFrameTemplate = true,
}
StaticPopupDialogs = {}
StaticPopup_Show = function(which)
	_G.__popup = which
	local d = _G.StaticPopupDialogs[which]
	if d and d.OnShow then d.OnShow() end
	local frame = { SetFrameLevel = function() end }
	_G.__popupFrame = frame
	return frame
end
_G.popupAccept = function()
	local d = _G.StaticPopupDialogs[_G.__popup]
	if d and d.OnAccept then d.OnAccept() end
	if d and d.OnHide then d.OnHide() end
end
_G.popupCancel = function()
	local d = _G.StaticPopupDialogs[_G.__popup]
	if d and d.OnCancel then d.OnCancel() end
	if d and d.OnHide then d.OnHide() end
end
CANCEL = "Cancel"
YES = "Yes"
NO = "No"
_G.__reloads = 0
ReloadUI = function() _G.__reloads = _G.__reloads + 1 end
_G.KNOWN_TEMPLATES = KNOWN_TEMPLATES

local function noop() end

local function makeWidget(objType, name)
	local f = { events = {}, __type = objType, __name = name }

	function f:RegisterEvent(e) self.events[e] = true end
	function f:UnregisterEvent(e) self.events[e] = nil end
	function f:IsEventRegistered(e) return self.events[e] end
	function f:SetScript(which, fn)
		if which == "OnUpdate" then self.onUpdate = fn
		elseif which == "OnEvent" then self.onEvent = fn
		else self["script_" .. tostring(which)] = fn end
	end
	function f:HookScript(which, fn) self["hook_" .. tostring(which)] = fn end
	function f:GetName() return self.__name end
	function f:GetObjectType() return self.__type or "Frame" end
	function f:SetText(v) self.__text = v end
	function f:GetText() return self.__text end
	function f:GetStringHeight() return 12 end
	function f:SetChecked(v) self.__checked = v and true or false end
	function f:GetChecked() return self.__checked end
	function f:IsShown() return self.__shown and true or false end
	function f:Show() self.__shown = true if self.script_OnShow then self.script_OnShow(self) end end
	function f:Hide() self.__shown = false end
	function f:SetShown(v) if v then self:Show() else self:Hide() end end
	function f:CreateTexture() return makeWidget("Texture") end
	function f:CreateFontString()
		local t = makeWidget("FontString")
		table.insert(_G.fontstrings, t)
		return t
	end

	setmetatable(f, { __index = function(_, k)
		if type(k) == "string" then return noop end
	end })
	return f
end
_G.makeWidget = makeWidget

CreateFrame = function(objType, name, parent, template)
	if template and not KNOWN_TEMPLATES[template] then
		error("Unknown template: " .. tostring(template))
	end
	local f = makeWidget(objType, name)
	frames[#frames+1] = f
	if name then _G[name] = f end
	return f
end

local fireDepth, maxDepth, fireCount = 0, 0, {}
local function fire(event, ...)
	fireDepth = fireDepth + 1
	if fireDepth > maxDepth then maxDepth = fireDepth end
	fireCount[event] = (fireCount[event] or 0) + 1
	if fireDepth > 40 then
		fireDepth = fireDepth - 1
		error("RUNAWAY EVENT RECURSION on " .. event)
	end
	for i = 1, #frames do
		local f = frames[i]
		if f.events[event] and f.onEvent then f.onEvent(f, event, ...) end
	end
	fireDepth = fireDepth - 1
end
_G.fire = fire
_G.fireCount = fireCount
_G.maxEventDepth = function() return maxDepth end

C_AddOns = { GetAddOnMetadata = function(_, k) if k == "Version" then return "0.17.1" end end }

Settings = {
	RegisterCanvasLayoutCategory = function(frame, name)
		if not frame then error("no frame") end
		return { ID = nil, name = name }
	end,
	RegisterAddOnCategory = function(cat) if not cat then error("no cat") end return true end,
	OpenToCategory = function(id) _G.__openedCategory = id return true end,
}
local clock = 0
GetTime = function() return clock end
_G.advanceTime = function(n) clock = clock + n end

local tooltipLines = {}
_G.tooltipLines = tooltipLines
local tooltipOwner
MiniMapTrackingButton = {
	scripts = {},
	HookScript = function(self, which, fn) self.scripts[which] = self.scripts[which] or {}; table.insert(self.scripts[which], fn) end,
}
_G.hoverTrackingButton = function()
	tooltipOwner = MiniMapTrackingButton
	local list = MiniMapTrackingButton.scripts.OnEnter or {}
	for i = 1, #list do list[i](MiniMapTrackingButton) end
end
GameTooltip = {
	-- One stub serves both the minimap tracking tooltip (tooltipLines) and the
	-- options panel tooltips (_G.__tooltipLines).
	SetOwner = function() _G.__tooltipLines = {} end,
	AddLine = function(_, text)
		tooltipLines[#tooltipLines+1] = tostring(text)
		table.insert(_G.__tooltipLines, tostring(text))
	end,
	Show = function() end,
	Hide = function() end,
	GetOwner = function() return tooltipOwner end,
}

-- ---- CVars ----
local cvars = { questPOI = "1", autoQuestWatch = "1", showBosses = "1", Outline = "2", instantQuestText = "1" }
local lockedCVars = {}
GetCVar = function(n) return cvars[n] end
SetCVar = function(n, v)
	if lockedCVars[n] then return true end        -- accepts the write, ignores it
	if cvars[n] == nil then return true end
	local old = cvars[n]
	cvars[n] = tostring(v)
	if old ~= cvars[n] then fire("CVAR_UPDATE", n, tostring(v)) end
	return true
end
_G.cvars = cvars
_G.lockCVar = function(n) lockedCVars[n] = true end

-- ---- Minimap tracking ----
MINIMAP_TRACKING_QUEST_POIS = "Track Quest POIs"
local tracking = {
	{ name = "Find Herbs",         active = false },
	{ name = "Low Level Quests",   active = false },
	{ name = "Points of Interest", active = false },
	{ name = "Track Quest POIs",   active = true  },   -- ON, so the addon must act
	{ name = "Track Digsites",     active = false },
}
local trackingLocked = false
C_Minimap = {
	GetNumTrackingTypes = function() return #tracking end,
	GetTrackingInfo = function(i) return tracking[i] end,
	SetTracking = function(i, on)
		if trackingLocked then return true end
		if tracking[i] and tracking[i].active ~= on then
			tracking[i].active = on and true or false
			fire("MINIMAP_UPDATE_TRACKING")
		end
		return true
	end,
}
_G.tracking = tracking
_G.lockTracking = function() trackingLocked = true end


-- ---- objective tracker (Tier 2) ----
--
-- Modelled on the v0.15 probe: WATCHFRAME_LINKBUTTONS is one Button per
-- tracked quest title, WatchFrameItem<N> are the quest item buttons, and
-- WatchFrame_Update is what rebuilds both. Post-hooks run after it, which is
-- what makes re-applying on every rebuild work.
-- Bags. [G18] found no CVar: the highlight is a texture per slot, put back on
-- every redraw, so the AddOn has to survive repeated ContainerFrame_Update.
local bagTextures = {}
local function mkTex(name)
	local t = { __name = name, __shown = true }
	function t:Hide() self.__shown = false end
	function t:Show() self.__shown = true end
	function t:IsShown() return self.__shown end
	return t
end
for slot = 1, 3 do
	local n = "ContainerFrame1Item" .. slot .. "IconQuestTexture"
	bagTextures[slot] = mkTex(n)
	_G[n] = bagTextures[slot]
end
_G.__bagTextures = bagTextures

ContainerFrame1 = {
	GetName = function() return "ContainerFrame1" end,
	IsShown = function() return true end,
}
_G.__bagRedraws = 0

local postHooks = {}
local hookedShow = {}
hooksecurefunc = function(a, b, c)
	if type(a) == "table" then
		-- Object form: hooksecurefunc(frame, "Method", fn).
		if a == GameTooltip and b == "Show" then
			hookedShow[#hookedShow + 1] = c
			return
		end
		if a == SettingsPanel then
			if b == "SetApplyButtonEnabled" and _G.__hookApply then _G.__hookApply(c) end
			if b == "CommitSettings" and _G.__hookCommit then _G.__hookCommit(c) end
		end
		return
	end
	postHooks[a] = postHooks[a] or {}
	table.insert(postHooks[a], b)
end

local function mkButton(name)
	local b = { __name = name, __mouse = true, __shown = true }
	function b:EnableMouse(v) self.__mouse = v and true or false end
	function b:IsMouseEnabled() return self.__mouse end
	function b:Hide() self.__shown = false end
	function b:Show() self.__shown = true end
	function b:IsShown() return self.__shown end
	return b
end

WATCHFRAME_MAXQUESTS = 10
WATCHFRAME_LINKBUTTONS = { mkButton("link1"), mkButton("link2") }
WatchFrameItem1 = mkButton("WatchFrameItem1")
_G.WatchFrameItem1 = WatchFrameItem1

-- The tracker puts its buttons back every rebuild, which is exactly the
-- condition the AddOn has to survive: a one-shot fix at login would pass a
-- naive test and fail in play.
_G.__watchUpdates = 0
WatchFrame_Update = function()
	_G.__watchUpdates = _G.__watchUpdates + 1
	for _, b in ipairs(WATCHFRAME_LINKBUTTONS) do b.__mouse = true end
	WatchFrameItem1.__shown = true
	for _, fn in ipairs(postHooks["WatchFrame_Update"] or {}) do fn() end
end

local popups = {}
_G.__setPopups = function(list) popups = list end
GetNumAutoQuestPopUps = function() return #popups end
GetAutoQuestPopUp = function(i) return popups[i] end
RemoveAutoQuestPopUp = function(id)
	for i = #popups, 1, -1 do
		if popups[i] == id then table.remove(popups, i) return true end
	end
	return false
end
WatchFrameAutoQuest_ClearPopUp = function() end

ContainerFrame_Update = function(frame)
	_G.__bagRedraws = _G.__bagRedraws + 1
	-- The game decides which slots carry a highlight and puts them all back.
	for _, t in ipairs(bagTextures) do t.__shown = true end
	for _, fn in ipairs(postHooks["ContainerFrame_Update"] or {}) do fn(frame) end
end


-- ---- quest frame portrait, and quest progress in tooltips ----
--
-- Blizzard's own colour codes, which the palette prefers over literals.
NORMAL_FONT_COLOR_CODE = "|cffffd100"
HIGHLIGHT_FONT_COLOR_CODE = "|cffffffff"
GRAY_FONT_COLOR_CODE = "|cff808080"
FONT_COLOR_CODE_CLOSE = "|r"

local questFrameShown = true
QuestNPCModel = {
    __shown = true,
    scripts = {},
    GetName = function() return "QuestNPCModel" end,
    GetObjectType = function() return "Frame" end,
    Hide = function(self) self.__shown = false end,
    Show = function(self) self.__shown = true end,
    IsShown = function(self) return self.__shown end,
    GetParent = function() return QuestFrameDetailPanel end,
    HookScript = function(self, which, fn)
        self.scripts[which] = self.scripts[which] or {}
        table.insert(self.scripts[which], fn)
    end,
}
QuestFrameDetailPanel = { IsShown = function() return questFrameShown end }
_G.__setQuestFrameShown = function(v) questFrameShown = v end

-- What Blizzard calls when a quest is offered or opened in the log. The
-- portrait comes BACK every time, which is why a one-shot hide would pass a
-- naive test and fail in play.
QuestFrame_ShowQuestPortrait = function()
    QuestNPCModel.__shown = true
    for _, fn in ipairs(postHooks["QuestFrame_ShowQuestPortrait"] or {}) do fn() end
    for _, fn in ipairs(QuestNPCModel.scripts.OnShow or {}) do fn(QuestNPCModel) end
end

-- The quest log the tooltip matcher reads titles from.
local questLog = {
    { title = "Elwynn Forest", isHeader = true },
    { title = "Pie for Billy", isHeader = false },
}
_G.__setQuestLog = function(t) questLog = t end
GetNumQuestLogEntries = function() return #questLog end
GetQuestLogTitle = function(i)
    local e = questLog[i]
    if not e then return nil end
    return e.title, 0, 0, e.isHeader
end

-- A tooltip whose lines carry per-line colours, as the captured samples in
-- G12 report them.
--
-- EXTENDS the existing GameTooltip stub rather than replacing it. Redefining
-- it wholesale is a mistake this harness has already made once: the second
-- definition silently ate the first, and the minimap tracking tooltip tests
-- went green while testing nothing.
local tipLines = {}
GameTooltip.scripts = GameTooltip.scripts or {}
GameTooltip.__height = 100
GameTooltip.GetName = function() return "GameTooltip" end
GameTooltip.NumLines = function() return #tipLines end
GameTooltip.GetHeight = function(self) return self.__height end
GameTooltip.SetHeight = function(self, h) self.__height = h end
GameTooltip.GetTop = function() return 1000 end
GameTooltip.GetBottom = function(self) return 1000 - self.__height end

-- What the client does and the harness did not: Show() re-lays the tooltip
-- out from its line count, which puts the height back. Two attempts at the
-- trailing pad were undone by exactly this, invisibly, because the harness
-- had no re-layout to undo them.
local function relayout()
    local n = #tipLines
    -- padding + text + the gaps BETWEEN lines + padding. The trailing gap
    -- does not exist, which is the detail a per-line estimate gets wrong.
    GameTooltip.__height = (n > 0) and (4 + n * 12 + (n - 1) * 2 + 4) or 0
end
_G.__tooltipRelayout = relayout
-- The canvas panel uses SetText for a tooltip's first line, so it has to be
-- recorded like AddLine or that panel's tooltip tests see a headless body.
GameTooltip.SetText = function(_, text)
    tooltipLines[#tooltipLines + 1] = tostring(text)
    if _G.__tooltipLines then table.insert(_G.__tooltipLines, tostring(text)) end
end
GameTooltip.HookScript = function(self, which, fn)
    self.scripts[which] = self.scripts[which] or {}
    table.insert(self.scripts[which], fn)
end
_G.__setTooltip = function(lines)
    tipLines = {}
    for i, l in ipairs(lines) do
        local fs = { __text = l.text, __r = l.r, __g = l.g, __b = l.b }
        function fs:GetText() return self.__text end
        function fs:SetText(t) self.__text = t end
        function fs:GetTextColor() return self.__r, self.__g, self.__b end
        function fs:GetHeight() return 12 end
        -- Laid out top-down from the frame's top: 4px of padding, then 12px
        -- of text per line with 2px of spacing between lines.
        function fs:GetTop() return 1000 - 4 - ((i - 1) * 14) end
        function fs:GetBottom() return self:GetTop() - 12 end
        tipLines[i] = fs
        _G["GameTooltipTextLeft" .. i] = fs
    end
    -- Clear any leftovers from a longer previous tooltip.
    local i = #lines + 1
    while _G["GameTooltipTextLeft" .. i] do _G["GameTooltipTextLeft" .. i] = nil; i = i + 1 end
end
-- The client's real order, which is the thing v0.16.0 got wrong: the tooltip
-- becomes VISIBLE first, with no lines in it yet, and the content-set script
-- fires afterwards once the lines exist. A hook on OnShow alone therefore sees
-- an empty tooltip and removes nothing.
_G.__showTooltip = function()
    local pending = tipLines
    tipLines = {}                                    -- OnShow: nothing in it yet
    for _, fn in ipairs(GameTooltip.scripts.OnShow or {}) do fn(GameTooltip) end
    tipLines = pending                               -- now the lines arrive
    relayout()
    for _, fn in ipairs(GameTooltip.scripts.OnTooltipSetUnit or {}) do fn(GameTooltip) end
    -- Show() re-lays out FIRST, then the post-hooks run. That ordering is the
    -- whole reason a one-shot SetHeight never survived.
    relayout()
    for _, fn in ipairs(hookedShow or {}) do fn(GameTooltip) end
end

-- Moving from one creature straight to the next: the tooltip never hides, so
-- OnShow does not fire again. Only the content-set script does.
_G.__retargetTooltip = function()
    relayout()
    for _, fn in ipairs(GameTooltip.scripts.OnTooltipSetUnit or {}) do fn(GameTooltip) end
    relayout()
    for _, fn in ipairs(hookedShow or {}) do fn(GameTooltip) end
end
_G.__tooltipText = function()
    local out = {}
    for i = 1, #tipLines do out[i] = tipLines[i]:GetText() end
    return out
end

-- ---- scenario tweaks, applied BEFORE the addon loads ----
if scenario == "cvar_refused" then lockCVar("questPOI")
elseif scenario == "tracking_refused" then lockTracking()
elseif scenario == "no_cminimap" then C_Minimap = nil
elseif scenario == "no_entry" then
	tracking[4].name = "Something Else"
elseif scenario == "no_cvar" then cvars.questPOI = nil
elseif scenario == "no_settings" then Settings = nil
elseif scenario == "settings_refuses" then
	Settings.RegisterCanvasLayoutCategory = function() error("nope") end
elseif scenario == "native" or scenario == "native_halfway" then
	-- The real client's Settings API, modelled on the v0.15 probe readback:
	-- the argument order below is the one that scored 4/4, so a mistake in
	-- Options.lua shows up here as a scrambled setting rather than passing.
	_G.__nativeControls = {}
	local created = _G.__nativeControls

	local function makeSetting(variable, key, tbl, vtype, name, default)
		if tbl[key] == nil then tbl[key] = default end
		local s = { __variable = variable, __key = key, __tbl = tbl }
		function s:GetName() return name end
		function s:GetVariable() return variable end
		function s:GetVariableType() return vtype end
		function s:GetDefaultValue() return default end
		function s:GetValue() return tbl[key] end
		s.__flags = 0
		function s:AddCommitFlag(f) s.__flags = s.__flags + f end
		function s:HasCommitFlag(f) return s.__flags % (f * 2) >= f end
		function s:IsModified() return s.__pendingValue ~= nil end
		function s:SetValue(v)
			-- Every attempt tells the panel to re-evaluate its Apply state,
			-- whether or not the value moved. The client does this; modelling
			-- only the moving case hid a recursion that froze the game.
			if SettingsPanel then SettingsPanel:SetApplyButtonEnabled(s:IsModified()) end
			-- Blizzard only fires the callback when the value actually moves.
			if tbl[key] == v then return end
			if s:HasCommitFlag(Settings.CommitFlag.Apply) and not Settings.IsCommitInProgress() then
				-- Parked until Apply, exactly as the real client does.
				s.__pendingValue = v
				_G.__pending[s] = v
				if SettingsPanel then SettingsPanel:SetApplyButtonEnabled(true) end
				return
			end
			tbl[key] = v
			if SettingsPanel then SettingsPanel:SetApplyButtonEnabled(false) end
			if s.__cb then s.__cb(s, v) end
		end
		function s:SetValueChangedCallback(fn) s.__cb = fn end
		return s
	end

	-- Values read straight off the v0.16 probe.
	Settings.VarType = { Boolean = "boolean", Number = "number", String = "string" }
	Settings.CommitFlag = {
		None = 0, ClientRestart = 1, GxRestart = 2, UpdateWindow = 4,
		SaveBindings = 8, Revertable = 16, Apply = 32, IgnoreApply = 64,
		KioskProtected = 128,
	}

	-- Blizzard defers a setting carrying the Apply flag: SetValue parks the
	-- value and only Apply writes it through. Modelling that is the point --
	-- it is the difference between the Apply button working and the AddOn
	-- reloading the UI the instant a box is ticked.
	local committing = false
	_G.__pending = {}
	Settings.IsCommitInProgress = function() return committing end
	_G.pressApply = function()
		committing = true
		for setting, v in pairs(_G.__pending) do
			setting.__tbl[setting.__key] = v
			setting.__pendingValue = nil
			if setting.__cb then setting.__cb(setting, v) end
		end
		_G.__pending = {}
		committing = false
	end

	_G.__headers = {}
	CreateSettingsListSectionHeaderInitializer = function(text, tooltip)
		return { kind = "header", text = text, data = { name = text, tooltip = tooltip } }
	end

	-- SettingsPanel. The real client calls SetApplyButtonEnabled whenever a
	-- pending change appears or clears -- INCLUDING while committing writes
	-- the AddOn made itself. Not modelling that is how a recursion that froze
	-- the game passed the whole suite.
	_G.__applyCalls = 0
	local hookedFns, commitHooks = {}, {}
	SettingsPanel = {
		scripts = {},
		HookScript = function(self, which, fn)
			self.scripts[which] = self.scripts[which] or {}
			table.insert(self.scripts[which], fn)
		end,
		-- The guard here is DEPTH, not a running total. It was a total, and
		-- once there were enough modules an ordinary run crossed the limit and
		-- reported a recursion that was not happening. Depth is what the real
		-- fault looked like -- a hook re-entering the thing that called it --
		-- so depth is what to watch.
		SetApplyButtonEnabled = function(self, on)
			_G.__applyCalls = _G.__applyCalls + 1
			_G.__applyDepth = (_G.__applyDepth or 0) + 1
			if _G.__applyDepth > 20 then
				_G.__applyDepth = 0
				error("runaway SetApplyButtonEnabled recursion")
			end
			for _, fn in ipairs(hookedFns) do fn(self, on) end
			_G.__applyDepth = _G.__applyDepth - 1
		end,
		-- What the Apply button calls. Post-hooks run after it, which is how
		-- a rebuild held back by Defaults gets finished.
		CommitSettings = function(self)
			for _, fn in ipairs(commitHooks) do fn(self) end
		end,
	}
	_G.__hookApply = function(fn) table.insert(hookedFns, fn) end
	_G.__hookCommit = function(fn) table.insert(commitHooks, fn) end
	_G.__openSettingsPanel = function()
		for _, fn in ipairs(SettingsPanel.scripts.OnShow or {}) do fn(SettingsPanel) end
	end
	_G.__closeSettingsPanel = function()
		for _, fn in ipairs(SettingsPanel.scripts.OnHide or {}) do fn(SettingsPanel) end
	end

	-- Blizzard's own registered controls, reachable the way [G19] proved:
	-- categoryLayouts -> initializers -> GetSetting() / data.tooltip.
	local function blizzInit(variable, name, tooltip)
		local setting = { GetVariable = function() return variable end,
		                  GetName = function() return name end }
		return { GetSetting = function() return setting end,
		         data = { name = name, tooltip = tooltip } }
	end
	SettingsPanel.categoryLayouts = {
		blizzardInterface = { initializers = {
			blizzInit("instantQuestText", "Instant Quest Text", "Quest text appears instantly."),
			blizzInit("autoQuestWatch", "Automatic Quest Tracking", nil),
			blizzInit("Outline", "Outline Mode", "Outlines interactive objects."),
			blizzInit("somethingElse", "Unrelated Option", "Nothing to do with quests."),
		} },
	}
	_G.__blizzInits = SettingsPanel.categoryLayouts.blizzardInterface.initializers

	Settings.VarType = Settings.VarType
	Settings.RegisterVerticalLayoutCategory = function(name)
		local layout = {
			initializers = {},
			AddInitializer = function(self, init)
				self.initializers[#self.initializers + 1] = init
				_G.__nativeControls[#_G.__nativeControls + 1] = init
				if init.kind == "header" then
					_G.__headers[#_G.__headers + 1] = init.text
				end
			end,
		}
		return { ID = nil, name = name, __vertical = true }, layout
	end
	Settings.RegisterAddOnSetting = function(category, variable, key, tbl, vtype, name, default)
		if type(category) ~= "table" then error("category must be a table") end
		if type(variable) ~= "string" then error("variable must be a string") end
		if type(key) ~= "string" then error("variableKey must be a string") end
		if type(tbl) ~= "table" then error("variableTbl must be a table") end
		if type(vtype) ~= "string" then error("variableType must be a string") end
		if type(name) ~= "string" then error("name must be a string") end
		return makeSetting(variable, key, tbl, vtype, name, default)
	end
	Settings.CreateCheckbox = function(category, setting, tooltip)
		if type(setting) ~= "table" or type(setting.GetVariable) ~= "function" then
			error("CreateCheckbox needs a setting object")
		end
		created[#created + 1] = { kind = "checkbox", setting = setting, tooltip = tooltip }
		return created[#created]
	end
	Settings.CreateControlTextContainer = function()
		local c = { data = {} }
		function c:Add(value, label) self.data[#self.data + 1] = { value = value, label = label } end
		function c:GetData() return self.data end
		return c
	end
	Settings.CreateDropdown = function(category, setting, getOptions, tooltip)
		if type(setting) ~= "table" or type(setting.GetVariable) ~= "function" then
			error("CreateDropdown needs a setting object")
		end
		if type(getOptions) ~= "function" then error("CreateDropdown needs an options function") end
		created[#created + 1] = { kind = "dropdown", setting = setting,
			options = getOptions(), tooltip = tooltip }
		return created[#created]
	end
	if scenario == "native_halfway" then
		-- Registration gets most of the way, then the client refuses. The
		-- canvas panel must still come up rather than the player getting
		-- nothing: a half-registered category is the worst realistic case.
		Settings.CreateDropdown = function() error("refused") end
	end
end

-- ---- load the addon exactly as the .toc orders it ----
local ns = {}
-- Repo-relative, so the suite runs wherever the checkout lives. Set
-- VQ_ADDON_DIR to point it somewhere else.
local base = os.getenv("VQ_ADDON_DIR") or "../../VanillaQuesting/"
for _, f in ipairs({ "Core.lua", "CVars.lua", "Minimap.lua", "QuestFrame.lua",
                     "Tooltip.lua", "Tracker.lua", "Bags.lua", "Options.lua" }) do
	local chunk = assert(loadfile(base .. f))
	chunk("VanillaQuesting", ns)
end
_G.ns = ns
_G.chatlog = chat
