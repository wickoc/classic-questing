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
			GameTooltip:AddLine(getTitle(), 1, 1, 1)
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

local function currentPreset()
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

local function applyPreset(which)
	if not ns.db then return end
	if which == "disabled" then
		for i = 1, #ns.modules do
			ns.db.settings[ns.modules[i].key] = false
		end
	elseif which == "classic" then
		for i = 1, #ns.modules do
			local m = ns.modules[i]
			ns.db.settings[m.key] = not m.experimental
		end
	else
		return -- "custom" applies nothing by definition
	end
	ns:ApplyAll()
	ns.RefreshOptions()
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
	local title = fs(panel, "GameFontNormalLarge", 1, 1, 1)
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
		defaults:SetScript("OnClick", function()
			ns:ResetDefaults(true)
			ns.RefreshOptions()
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
	local value = CreateFrame("Frame", nil, panel)
	value:SetSize(220, 22)
	value:SetPoint("TOPLEFT", 150, -58)
	local valueBg = value:CreateTexture(nil, "BACKGROUND")
	valueBg:SetAllPoints()
	valueBg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
	local valueText = fs(value, "GameFontHighlight", 1, 1, 1)
	valueText:SetPoint("CENTER")

	local right = makeButton(panel, 24, 22, ">")
	if left then left:SetPoint("RIGHT", value, "LEFT", -4, 0) end
	if right then right:SetPoint("LEFT", value, "RIGHT", 4, 0) end

	-- Arrows step between the two presets that mean something. "Custom" is a
	-- readout, not a destination: selecting it would have to do nothing, and a
	-- control that does nothing when chosen is worse than one that reports.
	local function step(dir)
		local now = currentPreset()
		if now == "disabled" then applyPreset("classic")
		elseif now == "classic" then applyPreset("disabled")
		else applyPreset(dir > 0 and "classic" or "disabled") end
	end
	if left then left:SetScript("OnClick", function() step(-1) end) end
	if right then right:SetScript("OnClick", function() step(1) end) end

	local function presetBody()
		return "Disabled: every option off, the game as Blizzard ships it.\n\n"
			.. "Full Classic experience: every option on, except experimental ones.\n\n"
			.. "Custom: shown automatically whenever your settings match neither of "
			.. "the above. Change any option below and this becomes Custom by itself."
	end
	attachTooltip(value, function() return "Preset" end, presetBody)
	if left then attachTooltip(left, function() return "Preset" end, presetBody) end
	if right then attachTooltip(right, function() return "Preset" end, presetBody) end

	preset.text = valueText

	---------------------------------------------------------------
	-- Option rows
	---------------------------------------------------------------

	local y = -100
	local lastGroup

	for _, m in ipairs(sortedModules()) do
		if m.group and m.group ~= lastGroup then
			lastGroup = m.group
			local head = fs(panel, "GameFontNormalLarge", 1, 1, 1)
			head:SetPoint("TOPLEFT", 16, y)
			head:SetText(m.group)
			y = y - 26
		end

		local cb = makeCheckbox(panel)
		if cb then
			cb:SetPoint("TOPLEFT", 24, y)

			-- Yellow label, as Blizzard's own option rows use.
			local label = fs(panel, "GameFontNormal")
			label:SetPoint("LEFT", cb, "RIGHT", 4, 0)
			label:SetText((m.title or m.key)
				.. (m.experimental and "  |cffff8800(experimental)|r" or ""))

			-- TODO(v1.0): remove the live status readout. It is useful while
			-- developing and meaningless to a player.
			local status = fs(panel, "GameFontDisableSmall", 0.5, 0.5, 0.5)
			status:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -20, y - 4)
			status:SetJustifyH("RIGHT")

			cb:SetScript("OnClick", function(self)
				ns:Set(m.key, self:GetChecked() and true or false)
				-- Read back rather than trusting the click: a module can refuse
				-- (a locked CVar, a missing frame) and the panel must show what
				-- is actually true.
				ns.RefreshOptions()
			end)

			attachTooltip(cb,
				function() return m.title or m.key end,
				function()
					local body = m.desc or ""
					if m.experimental then
						body = body .. "\n\nExperimental: not enabled by the Full Classic preset."
					end
					return body .. "\n\nSlash name: " .. m.key
				end)

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
		preset.text:SetText(PRESET_LABEL[currentPreset()] or "Custom")
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
