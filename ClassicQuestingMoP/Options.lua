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
-- Some options only reach the world map when the UI is rebuilt. Refreshing the
-- map's data providers was tried and rejected: it re-runs the exploration
-- provider and wipes the fog-of-war state, which is far worse than a reload.
--
-- An Apply button was also tried and rejected: nothing forces the player to
-- press it, so a change could be left silently unapplied. Asking at the moment
-- of the change cannot be ignored, and Cancel puts the setting back.

local dim

-- Blizzard darkens the screen behind its confirmations, which is what makes
-- them read as modal. Ours does the same.
local function ensureDim()
	if dim then return dim end
	dim = CreateFrame("Frame", nil, UIParent)
	dim:SetAllPoints(UIParent)
	dim:SetFrameStrata("DIALOG")
	dim:SetFrameLevel(1)
	local t = dim:CreateTexture(nil, "BACKGROUND")
	t:SetAllPoints()
	t:SetColorTexture(0, 0, 0, 0.6)
	dim:Hide()
	return dim
end

local function snapshot()
	if not ns.db then return nil end
	local snap = { settings = {} }
	for k, v in pairs(ns.db.settings) do snap.settings[k] = v end
	return snap
end

local function restore(snap)
	if not snap or not ns.db then return end
	wipe(ns.db.settings)
	for k, v in pairs(snap.settings) do ns.db.settings[k] = v end
	ns:ApplyAll()
	ns.RefreshOptions()
end

-- Shown right after a change that cannot take effect until the UI is rebuilt.
local function promptReload(before, many)
	if type(StaticPopupDialogs) ~= "table" or type(StaticPopup_Show) ~= "function" then
		return
	end
	StaticPopupDialogs["CLASSICQUESTING_RELOAD"] = {
		text = many
			and "The UI needs to reload for some of these settings to take effect."
			or "The UI needs to reload for this setting to take effect.",
		button1 = "Reload",
		button2 = CANCEL or "Cancel",
		OnAccept = function()
			if dim then dim:Hide() end
			if type(ReloadUI) == "function" then ReloadUI() end
		end,
		OnCancel = function()
			if dim then dim:Hide() end
			restore(before)
		end,
		OnHide = function() if dim then dim:Hide() end end,
		timeout = 0, whileDead = true, hideOnEscape = true,
		preferredIndex = 3,
	}
	ensureDim():Show()
	local ok, dlg = pcall(StaticPopup_Show, "CLASSICQUESTING_RELOAD")
	if not ok then
		if dim then dim:Hide() end
		return
	end
	-- Keep the dialog above the dim without touching its strata, which is
	-- shared with every other popup in the game.
	if type(dlg) == "table" and type(dlg.SetFrameLevel) == "function" then
		pcall(dlg.SetFrameLevel, dlg, 20)
	end
end

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

-- Order as shown in the canvas fallback's two-state toggle. "custom" is not
-- offered there: it is what the control REPORTS when the settings match
-- neither preset, never something to pick.
local PRESET_ORDER = { "classic", "disabled" }

-- The native dropdown must list "custom" even though it is never a choice --
-- a dropdown cannot display a value that is not among its entries, and
-- "custom" is exactly what it displays most of the time. Reordered on request
-- to Full Classic experience, Custom, Disabled: reading "Classic" in that
-- instruction as the Custom entry, since those are the three that exist.
local PRESET_DROPDOWN_ORDER = { "classic", "custom", "disabled" }

-- What the settings actually look like right now.
--
-- "Right now" includes a change the player has made but not yet applied.
-- ns.EffectiveSetting is supplied by the native panel and knows about those;
-- it is read off the namespace rather than called as a local because it is
-- defined further down this file.
--
-- Experimental options do not enter into "Full Classic experience" at all.
-- They used to: switching one on dropped the preset to Custom, and picking
-- Full Classic switched it back off. Both are confusing, and the second is
-- worse -- a preset undoing a deliberate choice the player had made. The
-- experiments are not part of the Classic experience, so having one on does
-- not stop the rest of the settings being it.
--
-- "Disabled" is different, and does count them: it means nothing is on.
local function derivedPreset()
	if not ns.db then return "custom" end
	local allOff, allNormalOn = true, true
	for i = 1, #ns.modules do
		local m = ns.modules[i]
		local on
		if ns.EffectiveSetting then
			on = ns.EffectiveSetting(m.key)
		else
			on = ns.db.settings[m.key] and true or false
		end
		if on then allOff = false end
		if not m.experimental and not on then allNormalOn = false end
	end
	if allOff then return "disabled" end
	if allNormalOn then return "classic" end
	return "custom"
end

-- What the control shows.
--
-- Derived from the options, never stored. A stored preset was tried and was
-- wrong in a way the player caught: turning options off one at a time set it
-- to "custom", and the stored value was then returned unconditionally -- so
-- reaching all-off by hand still read "Custom" and the control could never say
-- "Disabled" again. Reading the settings is the only answer that cannot go
-- stale, and v0.15.1 removed the stored key entirely: it had not been read for
-- four versions.
local function displayPreset()
	if not ns.db then return "custom" end
	return derivedPreset()
end

local applyPreset  -- defined below, after the prompt helpers it uses

function applyPreset(which)
	if not ns.db then return end
	local before = snapshot()
	local touchesMap = false
	if which ~= "custom" then
		for i = 1, #ns.modules do
			local m = ns.modules[i]
			if not (which == "classic" and m.experimental) then
				local want = (which == "classic")
				if m.needsApply and (ns.db.settings[m.key] and true or false) ~= want then
					touchesMap = true
				end
			end
		end
	end

	if ns.SetPresetApplying then ns.SetPresetApplying(true) end
	if which ~= "custom" then
		for i = 1, #ns.modules do
			local m = ns.modules[i]
			-- Full Classic leaves the experiments exactly as the player set
			-- them. Disabled means nothing is on, so it takes everything.
			if not (which == "classic" and m.experimental) then
				local want = (which == "classic")
				-- Native mode writes THROUGH the control, not around it.
				-- Writing ns.db.settings directly left Blizzard unaware that
				-- anything had changed, so a preset that moved a
				-- reload-needing option never lit the Apply button.
				if ns.SetNativeValue then
					ns.SetNativeValue(m.key, want)
				else
					ns.db.settings[m.key] = want
				end
			end
		end
	end
	if ns.SetPresetApplying then ns.SetPresetApplying(false) end
	-- "custom" changes nothing by definition; it only records the choice.
	ns:ApplyAll()
	ns.RefreshOptions()
	-- Native mode has Blizzard's Apply button for this; the prompt belongs to
	-- the canvas fallback only.
	if touchesMap and not ns.optionsNative then promptReload(before, true) end
end

---------------------------------------------------------------------
-- Build
---------------------------------------------------------------------

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
		-- Settings" is Blizzard's to offer, not ours -- this AddOn only owns
		-- its own -- so the choice is these settings or cancel.
		-- Two confirmations in a row for one action is one too many, and the
		-- second one lost the dim because the first dialog's OnHide fired
		-- underneath it. Fold the reload into the same question instead: one
		-- decision, one dialog.
		local function needsReloadToReset()
			if not ns.db then return false end
			for i = 1, #ns.modules do
				local m = ns.modules[i]
				if m.needsApply then
					local now = ns.db.settings[m.key] and true or false
					local def = ns.defaults[m.key] and true or false
					if now ~= def then return true end
				end
			end
			return false
		end

		local function doReset(reload)
			ns:ResetDefaults(true)
			ns.RefreshOptions()
			if reload and type(ReloadUI) == "function" then ReloadUI() end
		end
		panel.OnDefault = function() doReset(needsReloadToReset()) end

		defaults:SetScript("OnClick", function()
			local reload = needsReloadToReset()
			if type(StaticPopupDialogs) == "table" and type(StaticPopup_Show) == "function" then
				local text = "Do you want to reset " .. ns.title .. " settings to their defaults?"
				if reload then
					text = text .. "\n\nNote: The UI will reload."
				end
				StaticPopupDialogs["CLASSICQUESTING_DEFAULTS"] = {
					-- The question is phrased as a question, so the answers are
					-- Yes and No. Pairing "Yes" with "Cancel" is a mismatched
					-- pair; Blizzard uses YES/NO for questions like this too,
					-- so this is both sounder and consistent.
					text = text,
					button1 = YES or "Yes",
					button2 = NO or "No",
					OnAccept = function() doReset(reload) end,
					OnHide = function() if dim then dim:Hide() end end,
					timeout = 0, whileDead = true, hideOnEscape = true,
					preferredIndex = 3,
				}
				ensureDim():Show()
				local shown, dlg = pcall(StaticPopup_Show, "CLASSICQUESTING_DEFAULTS")
				if not shown then
					if dim then dim:Hide() end
					doReset(reload)
				elseif type(dlg) == "table" and type(dlg.SetFrameLevel) == "function" then
					pcall(dlg.SetFrameLevel, dlg, 20)
				end
			else
				doReset(reload)
			end
		end)

		attachTooltip(defaults,
			function() return "Defaults" end,
			function()
				return "Returns every option to the state a fresh install has: "
					.. "the full Classic experience, with experimental options off."
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
		-- 0 when the current state is Custom, so the next step lands on the
		-- first preset going right and the last going left, rather than
		-- silently picking whichever happened to be index 1.
		local idx = 0
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
		-- Leading break so the first white heading does not sit against the
		-- white tooltip title.
		return "\n|cffffffffFull Classic experience:|r Every option on, except experimental ones.\n\n"
			.. "|cffffffffDisabled:|r Every option off, the game as Blizzard ships it.\n\n"
			.. "|cffffffffCustom:|r Your own mix. It cannot be selected; it is chosen "
			.. "automatically as soon as you change any option below."
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

	for _, m in ipairs(ns:SortedModules()) do
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

			-- TODO(v1.0): remove the live status readout. Useful while
			-- developing, meaningless to a player.
			local status = fs(row, "GameFontDisableSmall", 0.45, 0.45, 0.45)
			status:SetPoint("RIGHT", row, "RIGHT", -12, 0)
			status:SetJustifyH("RIGHT")

			-- Toggle from the saved value, not the checkbox: a row click never
			-- moves the box, so reading the box would invert the wrong thing.
			local function toggle()
				local before = snapshot()
				local now = ns.db and ns.db.settings[m.key]
				ns:Set(m.key, not now)
				ns.RefreshOptions()
				if m.needsApply then promptReload(before, false) end
			end
			cb:SetScript("OnClick", toggle)
			row:SetScript("OnClick", toggle)

			local function body()
				local text = m.desc or ""
				if m.experimental then
					text = text .. "\n\n|cffff8019Experimental: not part of the Full Classic experience, which leaves it exactly as you set it. Switch it on by hand.|r"
				end
				-- Tooltip lines cannot be resized -- AddLine has no font
				-- argument and the body font is Blizzard-wide -- so the slash
				-- handle is set apart by colour instead.
				return text .. "\n\n|cff808080/" .. m.key .. "|r"
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
	if ns.optionsNative then
		if ns.RefreshNative then ns.RefreshNative() end
		return
	end
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
-- Native panel -- Blizzard's own controls
---------------------------------------------------------------------
--
-- Everything below is built from calls the v0.15 probe verified by READBACK,
-- not by acceptance. RegisterAddOnSetting turned out to accept every argument
-- order it was offered, so "the call worked" proved nothing; the shape used
-- here is the one whose sentinels all came back in the right slots:
--
--   Settings.RegisterAddOnSetting(category, variable, variableKey,
--                                 variableTbl, variableType, name, default)
--
-- and CreateCheckbox / CreateControlTextContainer / CreateDropdown were each
-- driven with a real setting object afterwards to confirm they accept one.
--
-- The payoff is that these are Blizzard's controls, not lookalikes: the real
-- checkbox, the real dropdown, and eventually the real Apply button. If any
-- step fails, registerNative returns false and the hand-built canvas panel
-- takes over unchanged, so the worst case is the panel we already had.

local nativeCategory
local nativeLayout
local nativeSettings = {}   -- module key -> Blizzard setting object
local nativePresetSetting

-- Writing a value back into a control fires its changed-callback again, so
-- every programmatic write is bracketed by these and the callbacks stand down
-- while one is in flight.
--
-- A COUNTER, not a boolean. As a boolean this froze the game: the Apply-button
-- hook re-enters RefreshNative, and when the inner call finished it cleared
-- the flag while the OUTER loop was still writing -- so every remaining
-- SetValue fired its callback, which refreshed again, without bound. A depth
-- count cannot be cleared by someone else's exit.
local suppressDepth = 0
local function pushSuppress() suppressDepth = suppressDepth + 1 end
local function popSuppress() suppressDepth = math.max(0, suppressDepth - 1) end
local function suppressed() return suppressDepth > 0 end

-- Second belt on the same trousers: RefreshNative never runs inside itself,
-- whatever route the re-entry takes.
local refreshing = false

-- The dropdown gets its own backing table rather than a saved setting. The
-- preset is not stored anywhere: it is derived from the options every time it
-- is needed, which is the only answer that cannot go stale.
local presetProxy = { preset = "classic" }

-- Tooltip colours. These are the canvas panel's, unchanged.
--
-- Moving to native controls I repainted the body white, which was an unforced
-- change and wrong: the canvas panel drew bodies with AddLine(text, 1, 0.82, 0)
-- -- Blizzard's yellow -- and only used white for the headings inside the
-- preset tooltip. Nothing about native controls required that to change, so it
-- is back to yellow bodies and white headings.
local WHITE  = "|cffffffff"
local YELLOW = "|cffffd100"   -- 1, 0.82, 0: the colour AddLine was giving them
local ORANGE = "|cffff8019"
local GREY   = "|cff808080"

local function varType(which)
	local t = Settings and Settings.VarType
	if type(t) == "table" and t[which] then return t[which] end
	return which:lower()
end

-- Blizzard paints the tooltip's first line -- the setting's name -- white by
-- itself, so this builds only the body. Same text and same colours as the
-- canvas panel, including the grey slash handle at the foot: tooltip lines
-- cannot be resized, so the handle is set apart by colour instead.
local function tooltipFor(m)
	local tip = YELLOW .. (m.desc or "") .. "|r"
	-- A known cost of the option, stated where the player decides rather than
	-- only in a readme they may never open.
	if m.limitation then
		tip = tip .. "|n|n" .. ORANGE .. m.limitation .. "|r"
	end
	if m.experimental then
		tip = tip .. "|n|n" .. ORANGE .. "Experimental: not part of the Full Classic experience, which leaves it exactly as you set it. Switch it on by hand." .. "|r"
	end
	return tip .. "|n|n" .. GREY .. "/" .. m.key .. "|r"
end

-- White heading, a white colon, then the yellow body on the same row. The
-- leading break keeps the first heading off the tooltip's own white title.
local function presetTooltip()
	local function row(headingKey, body)
		return WHITE .. PRESET_LABEL[headingKey] .. ":|r " .. YELLOW .. body .. "|r"
	end
	return "|n"
		.. row("classic", "Every normal option on. Experimental ones are left exactly as you set them.") .. "|n|n"
		.. row("custom", "Your own mix. It cannot be selected; it is chosen automatically as soon as you change any option below.") .. "|n|n"
		.. row("disabled", "Every option off, experimental ones included: the game as Blizzard ships it.") .. "|n|n"
		.. GREY .. "/cq on, /cq off" .. "|r"
end

-- What happens when a control's value moves. Shared by every checkbox.
--
-- The reload dialog used to live here. It is gone: it kept Blizzard's Apply
-- button from ever appearing, and it fought the Defaults button, which resets
-- settings one at a time and so raised the dialog once per setting.
--
-- In its place, options that need a rebuild are registered with the commit
-- flags Apply and Revertable, which is what puts the change behind Blizzard's
-- own Apply button. When Apply commits it, this callback runs inside the
-- commit -- Settings.IsCommitInProgress() says so -- and that is the moment to
-- reload. If a client ever ignores the flag, the callback simply runs outside
-- a commit and nothing reloads: the map is correct the next time it opens,
-- which is the same behaviour the slash commands already have.
local applyingPreset = false

-- What the reload-needing options looked like when the panel was opened, so a
-- reset that moves nothing does not rebuild the UI for no reason.
local rebuildBaseline = {}

local function captureRebuildBaseline()
	wipe(rebuildBaseline)
	if not ns.db then return end
	for i = 1, #ns.modules do
		local m = ns.modules[i]
		if m.needsApply then
			rebuildBaseline[m.key] = ns.db.settings[m.key] and true or false
		end
	end
end

-- True only if a reload-needing option is somewhere other than where it was
-- when this panel visit started. Toggling one and back again leaves nothing
-- to do.
local function rebuildStillNeeded()
	if not ns.db then return false end
	for key, was in pairs(rebuildBaseline) do
		if (ns.db.settings[key] and true or false) ~= was then return true end
	end
	return false
end

local applyingPreset = false

-- Apply NEVER asks. Pressing Apply IS the confirmation, and Blizzard already
-- asks its own question on Cancel; a dialog on top of that is two questions
-- for one decision.
--
-- Neither does Defaults. Blizzard's Defaults button reloads the UI by itself
-- when a setting it reset needs one, so a change arriving that way is already
-- a decision the player made and confirmed in Blizzard's own dialog. Two
-- earlier attempts here -- lighting the Apply button by hand, then raising an
-- AddOn dialog on close -- were both built on a guess about what that button
-- does, made without testing it. It does the reload itself.
local function doRebuild()
	-- Once per visit. Defaults fires the changed-callback once per setting it
	-- resets, so without this every reload-needing option in the list would
	-- ask for its own rebuild.
	wipe(rebuildBaseline)
	if type(ReloadUI) == "function" then ReloadUI() end
end

local function onSettingChanged(m)
	if suppressed() then return end
	ns:ApplyAll()
	if applyingPreset then return end

	ns.RefreshOptions()

	if not m.needsApply then return end

	local committing = false
	if type(Settings.IsCommitInProgress) == "function" then
		local ok, c = pcall(Settings.IsCommitInProgress)
		committing = ok and c or false
	end

	-- Committing means Apply was pressed. Arriving outside a commit means
	-- Defaults wrote it straight through -- [G20] confirmed SetValueToDefault
	-- ignores the Apply flag. Either way the player has decided, so rebuild;
	-- the only question is whether anything reload-worthy actually moved.
	if committing or rebuildStillNeeded() then
		doRebuild()
	end
end

-- Set a value through Blizzard's control rather than around it, so a change
-- that needs Apply is parked for Apply instead of quietly taking effect.
-- Set while a preset is driving every control at once, so the per-setting
-- callback does not mark the preset "custom" halfway through applying it.
function ns.SetPresetApplying(v) applyingPreset = v and true or false end

function ns.SetNativeValue(key, want)
	local setting = nativeSettings[key]
	if not setting or type(setting.SetValue) ~= "function" then
		if ns.db then ns.db.settings[key] = want end
		return
	end
	pcall(setting.SetValue, setting, want and true or false)
end

-- What a setting will be once Apply is pressed.
--
-- A setting waiting on Apply holds a pending value, and IsModified says so.
-- These are all booleans and Blizzard only parks an actual change, so a
-- modified boolean is by definition the opposite of the committed one -- no
-- guess about what GetValue returns for a pending setting is needed.
function ns.EffectiveSetting(key)
	local committed = ns.db and ns.db.settings[key] and true or false
	local setting = nativeSettings[key]
	if setting and type(setting.IsModified) == "function" then
		local ok, modified = pcall(setting.IsModified, setting)
		if ok and modified then return not committed end
	end
	return committed
end

-- Ask for the Apply button. AddCommitFlag takes one flag at a time, which
-- avoids guessing whether SetCommitFlags wants a list or a bitmask.
local function askForApply(setting)
	local flags = Settings and Settings.CommitFlag
	if type(flags) ~= "table" or type(setting.AddCommitFlag) ~= "function" then return end
	if flags.Apply then pcall(setting.AddCommitFlag, setting, flags.Apply) end
	if flags.Revertable then pcall(setting.AddCommitFlag, setting, flags.Revertable) end
end

-- A heading in the list, the way Interface > Display and Raid Frames have
-- them. The initializer is a plain global on this client, and the layout to
-- add it to is the SECOND value RegisterVerticalLayoutCategory returns.
local function addSectionHeader(text, colour)
	if not nativeLayout or type(nativeLayout.AddInitializer) ~= "function" then return false end
	if type(CreateSettingsListSectionHeaderInitializer) ~= "function" then return false end
	-- Colour escapes are honoured by font strings generally, so orange is
	-- worth asking for; if this header draws its text some other way the
	-- codes will simply not take and the heading is still there.
	local ok, init = pcall(CreateSettingsListSectionHeaderInitializer, colour .. text .. "|r")
	if not ok or type(init) ~= "table" then return false end

	-- The heading was showing a tooltip on hover, which a heading has no use
	-- for. Only one argument is passed in, so the tooltip is being defaulted
	-- from the name somewhere inside the initializer; clear both places it
	-- could be sitting. Probe [G17] dumps the initializer to confirm which.
	pcall(function()
		if type(init.data) == "table" then init.data.tooltip = nil end
		init.tooltip = nil
	end)

	return pcall(nativeLayout.AddInitializer, nativeLayout, init)
end

-- Say so on Blizzard's own controls.
--
-- Where this AddOn drives something Blizzard also shows a checkbox for --
-- Instant Quest Text, Automatic Quest Tracking, Outline Mode -- a player who
-- finds that checkbox has no way of knowing why it keeps moving. The same
-- problem the minimap tracking tooltip solved, in the same way: say it where
-- they are looking.
--
-- The route is the one [G19] proved out. Blizzard's registered settings are
-- reachable through SettingsPanel.categoryLayouts: each layout carries
-- initializers, each initializer has GetSetting() and a data table, and [G17]
-- showed the tooltip string lives at data.tooltip.
local ANNOTATION = "|cff66ccffManaged by " .. ns.title .. ".|r"
local annotated = {}

function ns.AnnotateBlizzardOptions()
	if type(SettingsPanel) ~= "table" then return end
	local layouts = rawget(SettingsPanel, "categoryLayouts")
	if type(layouts) ~= "table" then return end

	-- Which Blizzard variables this AddOn drives, and what it calls them.
	local ours = {}
	for i = 1, #ns.modules do
		local m = ns.modules[i]
		if m.blizzVariable then ours[m.blizzVariable] = m end
	end
	if not next(ours) then return end

	for _, layout in pairs(layouts) do
		local inits = type(layout) == "table" and rawget(layout, "initializers")
		if type(inits) == "table" then
			for i = 1, #inits do
				local init = inits[i]
				if type(init) == "table" and not annotated[init]
					and type(init.GetSetting) == "function" then

					local ok, setting = pcall(init.GetSetting, init)
					local var
					if ok and type(setting) == "table" and type(setting.GetVariable) == "function" then
						local okv, v = pcall(setting.GetVariable, setting)
						var = okv and v or nil
					end

					local m = var and ours[var]
					-- Skip this AddOn's own controls: they do not need telling
					-- who manages them.
					if m and not tostring(var):find("ClassicQuestingMoP", 1, true) then
						annotated[init] = true
						local data = rawget(init, "data")
						if type(data) == "table" then
							local tip = data.tooltip
							-- The note and nothing else. A slash handle was
							-- tried here and read as clutter on someone
							-- else's tooltip.
							if type(tip) == "string" then
								if not tip:find(ANNOTATION, 1, true) then
									data.tooltip = tip .. "|n|n" .. ANNOTATION
								end
							elseif tip == nil then
								data.tooltip = ANNOTATION
							end
							-- A tooltip that is a function is left alone: its
							-- shape is unverified, and probe [G21] asks what
							-- it is before anything is done to it.
						end
					end
				end
			end
		end
	end
end

local function annotateBlizzardOptions()
	pcall(ns.AnnotateBlizzardOptions)
end

local function registerNative()
	if type(Settings) ~= "table" then return false end
	for _, fn in ipairs({
		"RegisterVerticalLayoutCategory", "RegisterAddOnSetting",
		"RegisterAddOnCategory", "CreateCheckbox",
		"CreateControlTextContainer", "CreateDropdown",
	}) do
		if type(Settings[fn]) ~= "function" then return false end
	end
	if not ns.db or type(ns.db.settings) ~= "table" then return false end

	local ok, category, layout = pcall(Settings.RegisterVerticalLayoutCategory, ns.title)
	if not ok or type(category) ~= "table" then return false end
	if category.ID == nil then category.ID = ns.title end
	nativeLayout = (type(layout) == "table") and layout or nil

	-- The preset selector goes first: it is the coarse control, and the
	-- checkboxes below it are the fine one.
	local okp, presetSetting = pcall(Settings.RegisterAddOnSetting,
		category, "ClassicQuestingMoP_preset", "preset", presetProxy,
		varType("String"), "Preset", "classic")
	if not okp or type(presetSetting) ~= "table" then return false end

	local okd = pcall(function()
		Settings.CreateDropdown(category, presetSetting, function()
			local c = Settings.CreateControlTextContainer()
			for _, id in ipairs(PRESET_DROPDOWN_ORDER) do c:Add(id, PRESET_LABEL[id]) end
			return c:GetData()
		end,
		presetTooltip())
	end)
	if not okd then return false end

	-- Read the value from the ARGUMENTS, not back off the setting.
	--
	-- Blizzard tells the panel its Apply state may have moved as soon as a
	-- value lands, which is BEFORE this callback runs -- and the hook further
	-- down reacts by refreshing, which writes the derived preset back over the
	-- one the player just picked. By the time this ran, GetValue() had already
	-- been overwritten with the old value, so choosing "Disabled" re-applied
	-- "Full Classic experience" instead.
	--
	-- Which argument slot carries the value is not documented on this client,
	-- so take the first one that is a preset this AddOn knows.
	pcall(presetSetting.SetValueChangedCallback, presetSetting, function(...)
		if suppressed() then return end
		local picked
		for i = 1, select("#", ...) do
			local a = select(i, ...)
			if type(a) == "string" and PRESET_LABEL[a] then picked = a break end
		end
		if not picked then
			local okv, v = pcall(presetSetting.GetValue, presetSetting)
			picked = okv and type(v) == "string" and v or nil
		end
		if picked then applyPreset(picked) end
	end)
	nativePresetSetting = presetSetting

	-- One checkbox per module, in the single ordering ns:SortedModules owns,
	-- so this panel and /cq status cannot drift apart. The experiments come
	-- last so a heading can be put in front of them.
	local ordered = ns:SortedModules()
	local plain, experiments = {}, {}
	for i = 1, #ordered do
		local m = ordered[i]
		if m.experimental then experiments[#experiments + 1] = m else plain[#plain + 1] = m end
	end

	local function addCheckbox(m)
		local oks, setting = pcall(Settings.RegisterAddOnSetting,
			category, "ClassicQuestingMoP_" .. m.key, m.key, ns.db.settings,
			varType("Boolean"), m.title or m.key, ns.defaults[m.key] and true or false)
		if not oks or type(setting) ~= "table" then return false end

		if m.needsApply then askForApply(setting) end

		if not pcall(Settings.CreateCheckbox, category, setting, tooltipFor(m)) then return false end

		pcall(setting.SetValueChangedCallback, setting, function() onSettingChanged(m) end)
		nativeSettings[m.key] = setting
		return true
	end

	for i = 1, #plain do
		if not addCheckbox(plain[i]) then return false end
	end
	if #experiments > 0 then
		addSectionHeader("Experimental", ORANGE)
		for i = 1, #experiments do
			if not addCheckbox(experiments[i]) then return false end
		end
	end

	-- The version, which the native layout has nowhere else to put.
	--
	-- Two places were possible. At the top it would sit above the preset
	-- dropdown, and a section header at the top of a Blizzard list reads as a
	-- heading FOR what follows -- so "v0.12.0" would look like the name of the
	-- options beneath it. At the foot it reads as a footer, which is what it
	-- is. Grey, as asked, using the same colour escape the orange heading
	-- proved works.
	addSectionHeader("v" .. tostring(ns.version), GREY)

	if not pcall(Settings.RegisterAddOnCategory, category) then return false end

	nativeCategory = category
	ns.optionsCategory = category
	ns.optionsNative = true

	annotateBlizzardOptions()

	-- A baseline before the panel has ever been shown, so nothing depends on
	-- an OnShow that a given client might not fire.
	captureRebuildBaseline()

	-- Registration leaves every control showing its registration-time value.
	-- Without this the dropdown read "Full Classic experience" on a fresh
	-- login no matter what the checkboxes said.
	ns.RefreshNative()

	-- And re-read whenever the panel is opened, so a change made from chat
	-- while it was closed is on screen when it comes back.
	if SettingsPanel and type(SettingsPanel.HookScript) == "function" then
		pcall(SettingsPanel.HookScript, SettingsPanel, "OnShow", function()
			-- A fresh visit starts from where things actually are.
			captureRebuildBaseline()
			ns.RefreshOptions()
			annotateBlizzardOptions()
		end)
		-- Closing the panel ends the visit, whichever button did it.
		--
		-- Closing ends the visit; the next one takes a fresh baseline.
		pcall(SettingsPanel.HookScript, SettingsPanel, "OnHide", function()
			wipe(rebuildBaseline)
		end)
	end

	-- Ticking a box that needs Apply parks the value and fires no callback, so
	-- the preset dropdown had nothing to tell it the settings had moved. The
	-- Apply button changing state IS that signal, and hooking it is the only
	-- place the information exists.
	if SettingsPanel and type(hooksecurefunc) == "function"
		and type(SettingsPanel.SetApplyButtonEnabled) == "function" then
		pcall(hooksecurefunc, SettingsPanel, "SetApplyButtonEnabled", function()
			-- Blizzard calls this while committing our own writes too. Acting
			-- on those is how the recursion started -- and mid-preset it would
			-- also read the half-applied state as "Custom" and write that back
			-- over the preset the player just chose.
			if suppressed() or refreshing or applyingPreset then return end
			pcall(ns.RefreshOptions)
		end)
	end

	return true
end

-- Push the AddOn's state into Blizzard's controls. Lives on the namespace, not
-- as a local: ns.RefreshOptions is defined above this point, and a local would
-- resolve to a nil global there -- the forward-reference trap that has already
-- cost this project two silent failures.
function ns.RefreshNative()
	if not ns.db or refreshing then return end
	refreshing = true
	pushSuppress()

	local ok, err = pcall(ns.RefreshNativeBody)

	popSuppress()
	refreshing = false

	-- An error inside must not leave the guards raised, or the panel would go
	-- permanently deaf; report it once and carry on.
	if not ok then ns:Warn("options:refresh", "could not refresh the panel: " .. tostring(err)) end
end

function ns.RefreshNativeBody()
	for key, setting in pairs(nativeSettings) do
		-- A setting waiting on Apply holds a pending value. Writing over it
		-- here would silently discard what the player just clicked.
		local pending = false
		if type(setting.IsModified) == "function" then
			local okm, mod = pcall(setting.IsModified, setting)
			pending = okm and mod or false
		end
		if not pending then
			pcall(setting.SetValue, setting, ns.db.settings[key] and true or false)
		end
	end
	if nativePresetSetting then
		presetProxy.preset = displayPreset()
		pcall(nativePresetSetting.SetValue, nativePresetSetting, presetProxy.preset)
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
	if not ns.optionsNative then build() end

	if ns.optionsCategory and type(Settings) == "table" and type(Settings.OpenToCategory) == "function" then
		if pcall(Settings.OpenToCategory, ns.optionsCategory.ID or ns.optionsCategory) then
			return true
		end
	end

	build()
	makeStandalone()
	panel:Show()
	ns.RefreshOptions()
	return true
end

ns:RegisterEvent("PLAYER_LOGIN", function()
	-- Blizzard's own controls if this client will give them, the hand-built
	-- canvas if not, and a standalone window if even that is refused. Each
	-- fallback is strictly worse-looking and strictly as functional.
	if registerNative() then return end

	build()
	if not register() then
		ns:Warn("options:register",
			"could not add the panel to Blizzard's settings; /cq opens it as its own window instead.")
	end
end)
