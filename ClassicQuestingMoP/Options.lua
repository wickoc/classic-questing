-- Classic Questing (MoP) -- Options
--
-- The settings panel, styled to sit alongside Blizzard's own: white headings,
-- yellow option labels, descriptions in hover tooltips rather than on the page.
--
-- Deliberately built as a CANVAS layout with hand-made controls rather than
-- through Settings.RegisterAddOnSetting / Settings.CreateCheckbox. Recon
-- confirmed those functions exist, but not their signatures, and this client
-- has already punished several confident guesses. RegisterCanvasLayoutCategory
-- only needs a frame, which is verifiable. If even that fails, the same frame
-- is shown as a standalone window instead, so /cq always opens something.

local ADDON_NAME, ns = ...

local panel
local rows = {}
local preset = {}
local standalone = false

---------------------------------------------------------------------
-- Tooltips
---------------------------------------------------------------------

-- Blizzard's shape: white title, yellow wrapped body.
local function attachTooltip(widget, getTitle, getBody)
	widget:SetScript("OnEnter", function(self)
		if not GameTooltip or type(GameTooltip.SetOwner) ~= "function" then return end
		pcall(function()
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			-- SetText renders line one in the tooltip HEADER font, which is
			-- what makes Blizzard's tooltip titles larger. AddLine would use
			-- the body font and look wrong.
			if type(GameTooltip.SetText) == "function" then
				GameTooltip:SetText(getTitle(), 1, 1, 1)
			else
				GameTooltip:AddLine(getTitle(), 1, 1, 1)
			end
			local body = getBody()
			if body and body ~= "" then
				GameTooltip:AddLine(body, 1, 0.82, 0, true)
			end
			GameTooltip:Show()
		end)
	end)
	widget:SetScript("OnLeave", function()
		if GameTooltip and type(GameTooltip.Hide) == "function" then
			pcall(GameTooltip.Hide, GameTooltip)
		end
	end)
end

---------------------------------------------------------------------
-- Widgets
---------------------------------------------------------------------

-- Template names vary between clients and a missing one is a hard error, so
-- try the candidates and keep the first that actually constructs.
local CHECK_TEMPLATES = {
	"InterfaceOptionsCheckButtonTemplate",
	"UICheckButtonTemplate",
	"OptionsBaseCheckButtonTemplate",
	"ChatConfigCheckButtonTemplate",
}

local function makeCheckbox(parent)
	for i = 1, #CHECK_TEMPLATES do
		local ok, cb = pcall(CreateFrame, "CheckButton", nil, parent, CHECK_TEMPLATES[i])
		if ok and cb then return cb end
	end
	-- Last resort: a bare button that still reports checked state, so the
	-- panel degrades to usable rather than failing outright.
	local ok, cb = pcall(CreateFrame, "Button", nil, parent)
	if not ok or not cb then return nil end
	cb:SetSize(26, 26)
	local bg = cb:CreateTexture(nil, "ARTWORK")
	bg:SetAllPoints()
	bg:SetColorTexture(0.25, 0.25, 0.25, 1)
	local mark = cb:CreateTexture(nil, "OVERLAY")
	mark:SetPoint("CENTER")
	mark:SetSize(14, 14)
	mark:SetColorTexture(1, 0.82, 0, 1)
	cb.__mark = mark
	cb.__checked = false
	cb.GetChecked = function(self) return self.__checked end
	cb.SetChecked = function(self, v)
		self.__checked = v and true or false
		self.__mark:SetShown(self.__checked)
	end
	cb:SetChecked(false)
	return cb
end

local function makeButton(parent, w, h, text)
	local ok, b = pcall(CreateFrame, "Button", nil, parent, "UIPanelButtonTemplate")
	if not ok or not b then
		ok, b = pcall(CreateFrame, "Button", nil, parent)
		if not ok or not b then return nil end
		local bg = b:CreateTexture(nil, "ARTWORK")
		bg:SetAllPoints()
		bg:SetColorTexture(0.2, 0.2, 0.2, 1)
		local t = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		t:SetPoint("CENTER")
		b.__label = t
		b.SetText = function(self, v) self.__label:SetText(v) end
	end
	b:SetSize(w, h)
	b:SetText(text)
	return b
end

local function fs(parent, font, r, g, b)
	local t = parent:CreateFontString(nil, "ARTWORK", font or "GameFontNormal")
	if r then t:SetTextColor(r, g, b) end
	return t
end

---------------------------------------------------------------------
-- Presets
---------------------------------------------------------------------

-- Derived, never stored. "Custom" is what the panel shows when the settings
-- match neither preset, which is exactly the "selects itself automatically"
-- behaviour without a stored flag that could drift out of step with reality.
local PRESET_LABEL = {
	disabled = "Disabled",
	classic  = "Full Classic experience",
	custom   = "Custom",
}

local function nonExperimental()
	local list = {}
	for i = 1, #ns.modules do
		local m = ns.modules[i]
		if not m.experimental then list[#list + 1] = m end
	end
	return list
end

local PRESET_ORDER = { "disabled", "classic", "custom" }

-- What the settings actually look like right now.
local function derivedPreset()
	if not ns.db then return "custom" end
	local allOff, allOn = true, true
	for i = 1, #ns.modules do
		local m = ns.modules[i]
		local on = ns.db.settings[m.key] and true or false
		if on then allOff = false end
		if not m.experimental and not on then allOn = false end
		-- An experimental option being on is never "Full Classic".
		if m.experimental and on then allOn = false end
	end
	if allOff then return "disabled" end
	if allOn then return "classic" end
	return "custom"
end

-- What the control shows. The stored choice is honoured so that picking
-- "Custom" sticks, but a stored preset that no longer matches the settings is
-- downgraded to Custom rather than left lying.
local function displayPreset()
	if not ns.db then return "custom" end
	local stored = ns.db.preset
	if stored == nil then return derivedPreset() end
	if stored ~= "custom" and derivedPreset() ~= stored then return "custom" end
	return stored
end

local function applyPreset(which)
	if not ns.db then return end
	ns.db.preset = which
	if which == "disabled" then
		for i = 1, #ns.modules do
			ns.db.settings[ns.modules[i].key] = false
		end
	elseif which == "classic" then
		for i = 1, #ns.modules do
			local m = ns.modules[i]
			ns.db.settings[m.key] = not m.experimental
		end
	end
	-- "custom" changes nothing by definition; it only records the choice.
	ns:ApplyAll()
	ns.RefreshOptions()
end

-- Any individual change means the settings are no longer a named preset.
function ns.MarkCustomPreset()
	if ns.db then ns.db.preset = "custom" end
end

---------------------------------------------------------------------
-- Build
---------------------------------------------------------------------

local function sortedModules()
	local list = {}
	for i = 1, #ns.modules do list[#list + 1] = ns.modules[i] end
	table.sort(list, function(a, b) return (a.order or 999) < (b.order or 999) end)
	return list
end

local function build()
	if panel then return panel end

	panel = CreateFrame("Frame", "ClassicQuestingMoPOptions", UIParent)
	panel:SetSize(620, 560)
	panel:Hide()
	panel.name = ns.title

	-- Header: white title, small grey version, hairline rule. Blizzard's shape.
	local title = fs(panel, "GameFontNormalHuge", 1, 1, 1)
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText(ns.title)

	local version = fs(panel, "GameFontDisableSmall", 0.5, 0.5, 0.5)
	version:SetPoint("LEFT", title, "RIGHT", 8, -1)
	version:SetText("v" .. tostring(ns.version))

	local rule = panel:CreateTexture(nil, "ARTWORK")
	rule:SetColorTexture(0.4, 0.4, 0.4, 0.8)
	rule:SetPoint("TOPLEFT", 16, -44)
	rule:SetPoint("TOPRIGHT", -16, -44)
	rule:SetHeight(1)

	local defaults = makeButton(panel, 110, 22, "Defaults")
	if defaults then
		defaults:SetPoint("TOPRIGHT", -16, -14)
		-- Blizzard confirms before resetting a panel; do the same. "All
		-- Settings" is Blizzard's to offer, not ours -- this addon only owns
		-- its own -- so the choice is these settings or cancel.
		local function doReset()
			ns:ResetDefaults(true)
			if ns.db then ns.db.preset = nil end
			ns.RefreshOptions()
		end
		panel.OnDefault = doReset   -- honoured if Blizzard drives it

		defaults:SetScript("OnClick", function()
			if type(StaticPopupDialogs) == "table" and type(StaticPopup_Show) == "function" then
				StaticPopupDialogs["CLASSICQUESTING_DEFAULTS"] = {
					text = "Restore " .. ns.title .. " to its default settings?",
					button1 = "These Settings",
					button2 = CANCEL or "Cancel",
					OnAccept = doReset,
					timeout = 0, whileDead = true, hideOnEscape = true,
					preferredIndex = 3,
				}
				if not pcall(StaticPopup_Show, "CLASSICQUESTING_DEFAULTS") then doReset() end
			else
				doReset()
			end
		end)
		attachTooltip(defaults,
			function() return "Defaults" end,
			function()
				return "Returns every option to the state a fresh install has: "
					.. "map and minimap markers hidden, everything else off."
			end)
	end

	---------------------------------------------------------------
	-- Preset selector
	---------------------------------------------------------------

	local presetLabel = fs(panel, "GameFontNormal")
	presetLabel:SetPoint("TOPLEFT", 24, -62)
	presetLabel:SetText("Preset")

	local left = makeButton(panel, 24, 22, "<")

	-- Blizzard's selector is arrows plus a clickable value that drops a list.
	-- The real template could not be identified from recon, so this is built
	-- by hand to behave the same rather than guessed at by name.
	local value = CreateFrame("Button", nil, panel)
	value:SetSize(220, 22)
	value:SetPoint("TOPLEFT", 150, -58)
	local valueBg = value:CreateTexture(nil, "BACKGROUND")
	valueBg:SetAllPoints()
	valueBg:SetColorTexture(0.12, 0.12, 0.12, 0.9)
	local valueEdge = value:CreateTexture(nil, "BORDER")
	valueEdge:SetPoint("TOPLEFT", -1, 1)
	valueEdge:SetPoint("BOTTOMRIGHT", 1, -1)
	valueEdge:SetColorTexture(0.45, 0.4, 0.3, 1)
	valueEdge:SetDrawLayer("BORDER", -1)
	local valueHl = value:CreateTexture(nil, "HIGHLIGHT")
	valueHl:SetAllPoints()
	valueHl:SetColorTexture(1, 0.82, 0, 0.12)
	local valueText = fs(value, "GameFontNormal", 1, 0.82, 0)
	valueText:SetPoint("CENTER")
	-- the little downward nub Blizzard puts under an openable value
	local nub = value:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	nub:SetPoint("BOTTOM", value, "BOTTOM", 0, -7)
	nub:SetTextColor(1, 0.82, 0)
	nub:SetText("v")

	local right = makeButton(panel, 24, 22, ">")
	if left then left:SetPoint("RIGHT", value, "LEFT", -4, 0) end
	if right then right:SetPoint("LEFT", value, "RIGHT", 4, 0) end

	-- The dropped list.
	local menu = CreateFrame("Frame", nil, panel)
	menu:SetSize(220, #PRESET_ORDER * 20 + 8)
	menu:SetPoint("TOPLEFT", value, "BOTTOMLEFT", 0, -2)
	menu:SetFrameStrata("DIALOG")
	menu:Hide()
	local menuBg = menu:CreateTexture(nil, "BACKGROUND")
	menuBg:SetAllPoints()
	menuBg:SetColorTexture(0.05, 0.05, 0.05, 0.95)
	local menuEdge = menu:CreateTexture(nil, "BORDER")
	menuEdge:SetPoint("TOPLEFT", -1, 1)
	menuEdge:SetPoint("BOTTOMRIGHT", 1, -1)
	menuEdge:SetColorTexture(0.45, 0.4, 0.3, 1)
	menuEdge:SetDrawLayer("BORDER", -1)

	for i = 1, #PRESET_ORDER do
		local id = PRESET_ORDER[i]
		local item = CreateFrame("Button", nil, menu)
		item:SetSize(212, 18)
		item:SetPoint("TOPLEFT", 4, -4 - (i - 1) * 20)
		local hl = item:CreateTexture(nil, "HIGHLIGHT")
		hl:SetAllPoints()
		hl:SetColorTexture(1, 0.82, 0, 0.2)
		local t = item:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		t:SetPoint("LEFT", 6, 0)
		t:SetText(PRESET_LABEL[id])
		item:SetScript("OnClick", function()
			menu:Hide()
			applyPreset(id)
		end)
	end

	value:SetScript("OnClick", function()
		if menu:IsShown() then menu:Hide() else menu:Show() end
	end)

	-- Arrows cycle every value, as Blizzard's arrows do.
	local function step(dir)
		local now = displayPreset()
		local idx = 1
		for i = 1, #PRESET_ORDER do
			if PRESET_ORDER[i] == now then idx = i end
		end
		idx = idx + dir
		if idx < 1 then idx = #PRESET_ORDER elseif idx > #PRESET_ORDER then idx = 1 end
		menu:Hide()
		applyPreset(PRESET_ORDER[idx])
	end
	if left then left:SetScript("OnClick", function() step(-1) end) end
	if right then right:SetScript("OnClick", function() step(1) end) end

	local function presetBody()
		return "|cffffffffDisabled|r  Every option off, the game as Blizzard ships it.\n\n"
			.. "|cffffffffFull Classic experience|r  Every option on, except experimental ones.\n\n"
			.. "|cffffffffCustom|r  Your own mix. Selecting it changes nothing, and it is "
			.. "chosen automatically as soon as you change any option below."
	end
	attachTooltip(value, function() return "Preset" end, presetBody)
	if left then attachTooltip(left, function() return "Preset" end, presetBody) end
	if right then attachTooltip(right, function() return "Preset" end, presetBody) end

	preset.menu = menu
	preset.text = valueText

	---------------------------------------------------------------
	-- Option rows
	---------------------------------------------------------------

	local GROUP_COLOR = { ["Experimental"] = { 1, 0.5, 0.1 } }

	local y = -110
	local lastGroup

	for _, m in ipairs(sortedModules()) do
		if m.group and m.group ~= lastGroup then
			lastGroup = m.group
			local c = GROUP_COLOR[m.group] or { 1, 1, 1 }
			local head = fs(panel, "GameFontNormalLarge", c[1], c[2], c[3])
			head:SetPoint("TOPLEFT", 16, y)
			head:SetText(m.group)
			y = y - 26
		end

		-- The whole row is clickable and hoverable, as Blizzard's rows are.
		local row = CreateFrame("Button", nil, panel)
		row:SetSize(580, 26)
		row:SetPoint("TOPLEFT", 12, y + 4)
		local hl = row:CreateTexture(nil, "HIGHLIGHT")
		hl:SetAllPoints()
		hl:SetColorTexture(1, 1, 1, 0.07)

		local cb = makeCheckbox(row)
		if cb then
			cb:SetPoint("LEFT", 12, 0)

			local label = fs(row, "GameFontNormal")
			label:SetPoint("LEFT", cb, "RIGHT", 4, 0)
			label:SetText(m.title or m.key)

			-- The slash handle, small and dim, so the label stays the label.
			local slash = fs(row, "GameFontDisableSmall", 0.45, 0.45, 0.45)
			slash:SetPoint("LEFT", label, "RIGHT", 8, -1)
			slash:SetText("/" .. m.key)

			-- TODO(v1.0): remove the live status readout. Useful while
			-- developing, meaningless to a player.
			local status = fs(row, "GameFontDisableSmall", 0.45, 0.45, 0.45)
			status:SetPoint("RIGHT", row, "RIGHT", -12, 0)
			status:SetJustifyH("RIGHT")

			-- Toggle from the saved value, not the checkbox: a row click never
			-- moves the box, so reading the box would invert the wrong thing.
			local function toggle()
				local now = ns.db and ns.db.settings[m.key]
				ns.MarkCustomPreset()
				ns:Set(m.key, not now)
				ns.RefreshOptions()
			end
			cb:SetScript("OnClick", toggle)
			row:SetScript("OnClick", toggle)

			local function body()
				local text = m.desc or ""
				if m.experimental then
					text = text .. "\n\nExperimental: not enabled by the Full Classic preset."
				end
				return text
			end
			attachTooltip(row, function() return m.title or m.key end, body)
			attachTooltip(cb, function() return m.title or m.key end, body)

			rows[#rows + 1] = { module = m, check = cb, status = status }
			y = y - 30
		end
	end

	panel:SetScript("OnShow", function() ns.RefreshOptions() end)
	return panel
end

---------------------------------------------------------------------
-- Refresh
---------------------------------------------------------------------

function ns.RefreshOptions()
	if not ns.db then return end
	for i = 1, #rows do
		local row = rows[i]
		local on = ns.db.settings[row.module.key] and true or false
		pcall(row.check.SetChecked, row.check, on)
		local text = ""
		if type(row.module.Status) == "function" then
			local ok, s = pcall(row.module.Status, row.module)
			if ok and s then text = s end
		end
		row.status:SetText(text)
	end
	if preset.text then
		preset.text:SetText(PRESET_LABEL[displayPreset()] or "Custom")
	end
end

---------------------------------------------------------------------
-- Registration
---------------------------------------------------------------------

local function register()
	if type(Settings) ~= "table"
		or type(Settings.RegisterCanvasLayoutCategory) ~= "function"
		or type(Settings.RegisterAddOnCategory) ~= "function" then
		return false
	end

	local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, panel, ns.title)
	if not ok or type(category) ~= "table" then return false end

	-- Some builds want an explicit ID before the category can be opened.
	if category.ID == nil then category.ID = ns.title end

	if not pcall(Settings.RegisterAddOnCategory, category) then return false end

	ns.optionsCategory = category
	return true
end

-- Fallback: dress the same frame as its own window.
local function makeStandalone()
	if standalone then return end
	standalone = true

	panel:SetParent(UIParent)
	panel:SetPoint("CENTER")
	panel:SetFrameStrata("DIALOG")
	panel:EnableMouse(true)
	panel:SetMovable(true)
	panel:RegisterForDrag("LeftButton")
	panel:SetScript("OnDragStart", panel.StartMoving)
	panel:SetScript("OnDragStop", panel.StopMovingOrSizing)

	local bg = panel:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0, 0, 0, 0.92)

	pcall(function()
		local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
		close:SetPoint("TOPRIGHT", -4, -4)
	end)
end

function ns:OpenOptions()
	build()

	if ns.optionsCategory and type(Settings) == "table" and type(Settings.OpenToCategory) == "function" then
		if pcall(Settings.OpenToCategory, ns.optionsCategory.ID or ns.optionsCategory) then
			return true
		end
	end

	makeStandalone()
	panel:Show()
	ns.RefreshOptions()
	return true
end

ns:RegisterEvent("PLAYER_LOGIN", function()
	build()
	if not register() then
		ns:Warn("options:register",
			"could not add the panel to Blizzard's settings; /cq opens it as its own window instead.")
	end
end)
