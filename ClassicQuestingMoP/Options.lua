-- Classic Questing (MoP) -- Options
--
-- The settings panel. Every feature the addon has is a row here, and toggling
-- a row applies immediately -- no /reload.
--
-- Deliberately built as a CANVAS layout with hand-made checkboxes rather than
-- through Settings.RegisterAddOnSetting / Settings.CreateCheckbox. Recon
-- confirmed those functions exist, but not their signatures, and this client
-- has already punished several confident guesses. RegisterCanvasLayoutCategory
-- only needs a frame, which is verifiable. If even that fails, the same frame
-- is shown as a standalone window instead, so /cq always opens something.

local ADDON_NAME, ns = ...

local panel
local rows = {}
local standalone = false

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
	bg:SetColorTexture(0.3, 0.3, 0.3, 1)
	local mark = cb:CreateTexture(nil, "OVERLAY")
	mark:SetPoint("CENTER")
	mark:SetSize(16, 16)
	mark:SetColorTexture(0.2, 1, 0.2, 1)
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

local function fs(parent, font, r, g, b)
	local t = parent:CreateFontString(nil, "ARTWORK", font or "GameFontHighlight")
	if r then t:SetTextColor(r, g, b) end
	return t
end

---------------------------------------------------------------------
-- Build
---------------------------------------------------------------------

local function sortedModules()
	local list = {}
	for i = 1, #ns.modules do list[#list + 1] = ns.modules[i] end
	table.sort(list, function(a, b)
		return (a.order or 999) < (b.order or 999)
	end)
	return list
end

local function build()
	if panel then return panel end

	panel = CreateFrame("Frame", "ClassicQuestingMoPOptions", UIParent)
	panel:SetSize(620, 520)
	panel:Hide()
	panel.name = ns.title

	local title = fs(panel, "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText(ns.title)

	local version = fs(panel, "GameFontDisableSmall")
	version:SetPoint("LEFT", title, "RIGHT", 8, 0)
	version:SetText("v" .. tostring(ns.version))

	local blurb = fs(panel, "GameFontHighlightSmall", 0.8, 0.8, 0.8)
	blurb:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
	blurb:SetWidth(560)
	blurb:SetJustifyH("LEFT")
	blurb:SetText("Everything here takes effect at once. Nothing needs a reload.")

	local y = -70
	local lastGroup

	for _, m in ipairs(sortedModules()) do
		if m.group and m.group ~= lastGroup then
			lastGroup = m.group
			local head = fs(panel, "GameFontNormal", 1, 0.82, 0)
			head:SetPoint("TOPLEFT", 16, y)
			head:SetText(m.group)
			y = y - 22
		end

		local cb = makeCheckbox(panel)
		if cb then
			cb:SetPoint("TOPLEFT", 20, y + 2)

			local label = fs(panel, "GameFontHighlight")
			label:SetPoint("LEFT", cb, "RIGHT", 4, 0)
			label:SetText(m.key .. (m.experimental and "  |cffff8800(experimental)|r" or ""))

			local status = fs(panel, "GameFontDisableSmall", 0.6, 0.6, 0.6)
			status:SetPoint("TOPRIGHT", panel, "TOPLEFT", 600, y)
			status:SetJustifyH("RIGHT")

			local desc = fs(panel, "GameFontDisableSmall", 0.65, 0.65, 0.65)
			desc:SetPoint("TOPLEFT", 48, y - 20)
			desc:SetWidth(540)
			desc:SetJustifyH("LEFT")
			desc:SetText(m.desc or "")

			cb:SetScript("OnClick", function(self)
				local want = self:GetChecked() and true or false
				ns:Set(m.key, want)
				-- Read back rather than trusting the click: a module can
				-- refuse (a locked CVar, a missing frame) and the panel must
				-- show what is actually true.
				ns.RefreshOptions()
			end)

			rows[#rows + 1] = { module = m, check = cb, status = status }

			-- Two lines per row: the control, then its description.
			local descH = 14
			pcall(function() descH = desc:GetStringHeight() or 14 end)
			y = y - 24 - math.max(descH, 12) - 8
		end
	end

	local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	if reset then
		reset:SetSize(140, 22)
		reset:SetPoint("TOPLEFT", 20, y - 6)
		reset:SetText("Restore defaults")
		reset:SetScript("OnClick", function()
			ns:ResetDefaults()
			ns.RefreshOptions()
		end)
	end

	local footer = fs(panel, "GameFontDisableSmall", 0.55, 0.55, 0.55)
	footer:SetPoint("BOTTOMLEFT", 16, 14)
	footer:SetWidth(580)
	footer:SetJustifyH("LEFT")
	footer:SetText("Experimental options are never enabled by /cq on. Turn them on by name.")

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

	local ok2 = pcall(Settings.RegisterAddOnCategory, category)
	if not ok2 then return false end

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
		local ok = pcall(Settings.OpenToCategory, ns.optionsCategory.ID or ns.optionsCategory)
		if ok then return true end
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
