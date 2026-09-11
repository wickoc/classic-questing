-- Unmarked Recon v0.3
-- Throwaway dev-only probe. Not part of Vanilla Questing, never shipped with it.
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
-- Sections are tagged [G1]..[G15] so the output maps back to SPEC.md.
--
-- v0.15 stops printing the settled sections. See the ACTIVE table below: every
-- section is still here in full, but only the open questions run, so a report
-- is a few hundred lines instead of 85KB. Flip a flag to bring one back.
--
-- Design rule for this probe: discover, don't guess. Where v0.2 asked "does the name I
-- expect exist?", v0.3 enumerates what is actually there -- method tables, provider
-- objects, tracking types, globals -- so a negative result means "not present" rather
-- than "I guessed the wrong name".

-- One source of truth: read it from the .toc rather than repeating it here.
-- v0.4 shipped announcing 0.4 in chat while the .toc still said 0.3.
local RECON_VERSION = (function()
	local getter = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
	if type(getter) ~= "function" then return "?" end
	local ok, v = pcall(getter, "UnmarkedRecon", "Version")
	return (ok and v) or "?"
end)()

UnmarkedReconDB = UnmarkedReconDB or {}

-- ---------------------------------------------------------------------
-- Which sections print.
--
-- The report had grown to 85KB, and most of it was ground already settled and
-- written into SPEC.md. Nothing is deleted -- every section below still exists
-- in full and is one "false -> true" away from running again -- but a run now
-- prints only what is still an open question. Flip a flag back on when a
-- settled answer needs re-checking against a new client build.
local ACTIVE = {
	baseline = false, -- the v0.2 existence roll-call
	g1  = false, -- minimap surface
	g2  = false, -- minimap tracking API
	g3  = false, -- world map data providers
	g4  = false, -- Settings API surface
	g5  = false, -- quest CVar detail
	g6  = false, -- CVar discovery / tracking entry fields
	g7  = false, -- map clutter
	g8  = false, -- settings registry (the 460-line one)
	g9  = false, -- questgiver blips        (tabled: waiting on an edited texture)
	g10 = false, -- blip atlas              (closed: cell identity does not matter)
	g11 = false, -- outline and sparkles    (closed: client rendering fault)
	g12 = false, -- quest progress tooltip  (matching rule settled)
	g13 = false, -- Blizzard selector frame surface

	g13c = false, -- ANSWERED v0.15: (category, variable, variableKey,
	              --   variableTbl, variableType, name, default) scored 4/4
	g14  = false, -- ANSWERED v0.15: WatchFrame is unprotected, 3 children
	g15  = false, -- ANSWERED v0.15, except the turn-in pop-up, which cannot
	              --   be probed until one is actually on screen

	g16 = false, -- ANSWERED v0.16: CommitFlag.Apply = 32, Revertable = 16;
	             --   CreateSettingsListSectionHeaderInitializer is a global;
	             --   RegisterVerticalLayoutCategory returns category, layout

	g17 = false, -- ANSWERED v0.18: data.tooltip is nil when only a name is
	             --   passed, so the hover text comes from
	             --   SettingsListSectionHeaderMixin's own OnEnter

	g18 = false, -- ANSWERED v0.19: no CVar exists; the highlight is the
	             --   texture ContainerFrame<N>Item<M>IconQuestTexture
	g19 = false, -- ANSWERED v0.19: the variable is instantQuestText, read off
	             --   Blizzard's own registered setting

	g20 = false, -- ANSWERED v0.20: SetValueToDefault writes straight through
	             --   and leaves IsModified false, so it ignores the Apply flag

	g21 = false, -- ANSWERED v0.21: all three are strings, and all three took
	             --   the annotation

	g22 = false, -- ANSWERED v0.22: QuestModelScene is the portrait frame, and
	             --   there is no CVar for quest tooltips

	g23 = false, -- ANSWERED v0.24: nine initializer globals and none of them
	             --   is a description; the header's second argument DOES land
	             --   in data.tooltip; a checkbox initializer has no
	             --   SetTooltipFunc, and label and tooltip title share
	             --   data.name

	g24 = false, -- ANSWERED v0.25: CreateSettingsAddOnDisabledLabelInitializer
	             --   renders SettingsAddOnDisabledLabelTemplate with an EMPTY
	             --   data table and ignores anything passed to it

	g25 = false, -- ANSWERED v0.27: 625 initializers, 0 hits, and the template
	             --   census shows 22 templates -- all controls, section
	             --   headers or purpose-built widgets. The paragraphs are
	             --   baked into ColorblindSelectorTemplate and the RTTS/STT
	             --   templates, not drawn by any reusable element.

	g26 = false, -- ANSWERED v0.28: of five candidates only two render at all.
	             --   The header draws a heading; SettingsLanguageRestartNeeded
	             --   draws an option ROW -- text in the label column, ellipsised
	             --   at the width a control label gets. The other three draw
	             --   nothing. No Blizzard element takes a paragraph.

	-- Still open.
	g27 = true, -- does a template the ADDON ships render in Blizzard's
	            --   settings list? If so, description text is solved.
}

---------------------------------------------------------------------
-- [G27] The description row's frame script.
--
-- A global rather than a mixin table, and hung on the frame by hand in
-- OnLoad, because the point of this probe is to find out whether an
-- AddOn-supplied template renders AT ALL. Anything clever in here would
-- become a second thing that could be the reason it did not.
--
-- Init is the method Blizzard's settings list calls on an element frame,
-- passing the initializer. Everything is existence-checked: if the list calls
-- something else instead, the row renders with its placeholder text and that
-- is itself the finding.
---------------------------------------------------------------------

function UnmarkedRecon_DescriptionOnLoad(self)
	self.Init = function(frame, initializer)
		local data
		if initializer then
			if type(initializer.GetData) == "function" then
				local ok, d = pcall(initializer.GetData, initializer)
				if ok then data = d end
			end
			data = data or rawget(initializer, "data")
		end
		local text = type(data) == "table" and data.name or nil
		if frame.Text then
			frame.Text:SetText(text or "INIT CALLED, but no data.name")
		end
	end
	if self.Text then
		-- Visible if Init is never called, which is the other answer worth
		-- being able to tell apart.
		self.Text:SetText("OnLoad ran, Init did NOT")
	end
end


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
		local ok2, _, default, _, _, locked, secure, readonly = pcall(GetCVarInfo, name)
		if ok2 and default ~= nil then
			line = line .. "  (default " .. tostring(default) .. ")"
		end
		if ok2 and (locked or secure or readonly) then
			line = line .. "  [" ..
				(locked and "LOCKED " or "") ..
				(secure and "SECURE " or "") ..
				(readonly and "READONLY" or "") .. "]"
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
		-- Own keys first: objects built with CreateFromMixins carry their
		-- methods directly, not via a metatable. v0.3 missed all of these.
		for k, v in pairs(obj) do
			if type(k) == "string" and type(v) == "function" and not seen[k] then
				seen[k] = true
				names[#names + 1] = k
			end
		end
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
--
-- v0.4: these providers are built with CreateFromMixins, which COPIES each
-- mixin method onto the object rather than linking a metatable. That is why
-- v0.3 reported mixin=nil for all 15. Identify them instead by fingerprint:
-- for each candidate mixin, count how many of its functions the provider
-- holds by reference identity. An exact copy scores 1.00.
local function sectionDataProviders()
	head("[G3] World map data providers - identifying them")

	if not (WorldMapFrame and WorldMapFrame.RemoveDataProvider) then
		add("   WorldMapFrame:RemoveDataProvider missing - re-check the map-style verdict.")
		return
	end

	dumpMethods(WorldMapFrame, "WorldMapFrame", { "dataprovider", "pin" })

	add("")
	local mixins = {}
	local mixinCount = 0
	for k, v in pairs(_G) do
		if type(k) == "string" and type(v) == "table" and k:find("DataProvider") then
			mixins[k] = v
			mixinCount = mixinCount + 1
		end
	end
	add("   Global *DataProvider* tables found: " .. mixinCount)

	add("")
	local providers = {}
	for k, v in pairs(WorldMapFrame.dataProviders or {}) do
		local p = (type(k) == "table" and k) or (type(v) == "table" and v) or nil
		if p then providers[#providers + 1] = p end
	end
	add("   Providers reachable: " .. #providers)

	-- Keys every provider has are the shared base; the rest is what identifies one.
	local keyCount = {}
	for i = 1, #providers do
		pcall(function()
			for k in pairs(providers[i]) do
				if type(k) == "string" then keyCount[k] = (keyCount[k] or 0) + 1 end
			end
		end)
	end

	local rows = {}
	for i = 1, #providers do
		local p = providers[i]

		-- Fingerprint against every candidate mixin by function identity.
		-- A small mixin scores 1.00 as easily as a specific one, so report
		-- every exact match (largest first) rather than one "winner".
		local exact, best, bestScore, bestHits, bestTotal = {}, nil, 0, 0, 0
		for name, mixin in pairs(mixins) do
			local total, hits = 0, 0
			pcall(function()
				for k, v in pairs(mixin) do
					if type(k) == "string" and type(v) == "function" then
						total = total + 1
						if rawequal(rawget(p, k), v) then hits = hits + 1 end
					end
				end
			end)
			if total > 0 then
				local score = hits / total
				if score >= 0.999 then
					exact[#exact + 1] = { name = name, total = total }
				end
				if score > bestScore then
					best, bestScore, bestHits, bestTotal = name, score, hits, total
				end
			end
		end
		table.sort(exact, function(a, b) return a.total > b.total end)

		local template
		if type(p.GetPinTemplate) == "function" then
			local okt, t = pcall(p.GetPinTemplate, p)
			if okt then template = tostring(t) end
		end

		-- Distinctive keys: those this provider has that not every provider has.
		local distinct, scalars = {}, {}
		pcall(function()
			for k, v in pairs(p) do
				if type(k) == "string" then
					if type(v) == "function" then
						if (keyCount[k] or 0) < #providers then distinct[#distinct + 1] = k end
					elseif type(v) == "string" or type(v) == "number" or type(v) == "boolean" then
						-- A CVar-gated provider parks the CVar name in a field
						-- like this; that is exactly what we want to see.
						scalars[#scalars + 1] = k .. "=" .. tostring(v)
					end
				end
			end
		end)
		table.sort(distinct)
		table.sort(scalars)

		local shown = {}
		for j = 1, math.min(#distinct, 22) do shown[j] = distinct[j] end

		local idLine
		if #exact > 0 then
			local parts = {}
			for j = 1, #exact do
				parts[j] = exact[j].name .. "(" .. exact[j].total .. ")"
			end
			idLine = "EXACT: " .. table.concat(parts, " + ")
		elseif bestScore > 0 then
			idLine = string.format("partial best=%s %.2f (%d/%d fns)",
				tostring(best), bestScore, bestHits, bestTotal)
		else
			idLine = "NO MIXIN MATCH"
		end

		rows[#rows + 1] = {
			sort = string.format("%s%.3f", (#exact > 0 and "0" or "1"), 1 - bestScore) .. tostring(best),
			text = {
				string.format("   provider @@  %s", idLine),
				"      GetPinTemplate=" .. tostring(template),
				"      distinctive fns (" .. #distinct .. "): " ..
					(next(shown) and table.concat(shown, ", ") or "none"),
				"      fields: " .. (next(scalars) and table.concat(scalars, ", ") or "none"),
			},
		}
	end

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

local function dumpTable(t, name, cap)
	cap = cap or 200
	if type(t) ~= "table" then
		add("   " .. name .. " is not a table (" .. type(t) .. ").")
		return
	end
	local keys = {}
	local ok = pcall(function()
		for k, v in pairs(t) do
			if type(k) == "string" then keys[#keys + 1] = k .. "  [" .. type(v) .. "]" end
		end
	end)
	if not ok then add("   " .. name .. ": not enumerable."); return end
	table.sort(keys)
	add("   " .. name .. ": " .. #keys .. " string keys")
	for i = 1, math.min(#keys, cap) do add("      " .. name .. "." .. keys[i]) end
	if #keys > cap then add("      ... and " .. (#keys - cap) .. " more") end
end

-- [G8] C_Console.GetAllCommands turned out to be missing on this client, so
-- the console cannot be enumerated and an unknown CVar name cannot be found
-- that way. Blizzard's own options registry is the remaining principled
-- route: anything with a checkbox in the options window is registered
-- somewhere reachable, including "Instant Quest Text".
local function sectionSettingsRegistry()
	head("[G8] Settings registry - finding option-backed CVars")

	add("   Reminder: C_Console.GetAllCommands is absent here (see G6).")
	add("")
	dumpTable(Settings, "Settings", 300)

	add("")
	dumpMethods(SettingsPanel, "SettingsPanel", { "categor", "setting", "list", "variable" })

	add("")
	dumpTable(SettingsPanel, "SettingsPanel", 120)

	add("")
	dumpTable(Settings and Settings.CategorySet, "Settings.CategorySet", 80)

	-- Try every plausible way to reach the category list and report which,
	-- if any, actually returns something. Absence here is a real answer.
	add("")
	add("   Attempting to reach a category list:")
	local attempts = {
		{ "SettingsPanel:GetCategoryList()", function() return SettingsPanel:GetCategoryList() end },
		{ "SettingsPanel:GetAllCategories()", function() return SettingsPanel:GetAllCategories() end },
		{ "SettingsPanel:GetSettingsList()", function() return SettingsPanel:GetSettingsList() end },
		{ "SettingsPanel.settings", function() return rawget(SettingsPanel, "settings") end },
		{ "SettingsPanel.categoryLayouts", function() return rawget(SettingsPanel, "categoryLayouts") end },
	}
	local reached = {}
	for i = 1, #attempts do
		local okc, res = pcall(attempts[i][2])
		if okc and type(res) == "table" then
			local n = 0
			for _ in pairs(res) do n = n + 1 end
			add("      OK   " .. attempts[i][1] .. "  -> table with " .. n .. " entries")
			reached[attempts[i][1]] = res
		else
			add("      --   " .. attempts[i][1])
		end
	end

	-- v0.6 guessed at the shape of a category (name / settings / layout) and
	-- printed "category: nil" for all 42. Don't guess: dump the actual keys of
	-- a few entries and let the next pass use what is really there.
	local sample = reached["SettingsPanel:GetCategoryList()"] or reached["SettingsPanel:GetAllCategories()"]
	if sample then
		add("")
		add("   Shape of the first few category entries:")
		local shown = 0
		for k, v in pairs(sample) do
			if shown >= 3 then break end
			shown = shown + 1
			add("      entry key: " .. tostring(k) .. "  value type: " .. type(v))
			if type(v) == "table" then
				dumpTable(v, "      entry" .. shown, 40)
				local mt = getmetatable(v)
				local idx = mt and rawget(mt, "__index")
				if type(idx) == "table" then
					dumpTable(idx, "      entry" .. shown .. ".__index", 40)
				end
			end
		end
	end

	-- v0.8 result: SettingsPanel.settings holds CATEGORY objects (CreateSubcategory,
	-- subcategories, name, order), not settings -- hence 0 quest matches. The real
	-- settings must hang off the layouts, so walk those too.
	local layouts = reached["SettingsPanel.categoryLayouts"]
	if layouts then
		add("")
		add("   Shape of two categoryLayouts entries:")
		local ln = 0
		for k, v in pairs(layouts) do
			if ln >= 2 then break end
			ln = ln + 1
			add("      --- layout " .. ln .. " (key type " .. type(k) .. ", value type " .. type(v) .. ")")
			if type(v) == "table" then
				dumpTable(v, "         layout", 40)
				local mt = getmetatable(v)
				local idx = mt and rawget(mt, "__index")
				if type(idx) == "table" then dumpTable(idx, "         layout.__index", 40) end
				-- initializers are the usual home of the actual settings
				for _, field in ipairs({ "initializers", "elements", "settings" }) do
					local sub = rawget(v, field)
					if type(sub) == "table" then
						local n = 0
						for _ in pairs(sub) do n = n + 1 end
						add("         layout." .. field .. ": " .. n .. " entries")
						local sn = 0
						for _, e in pairs(sub) do
							if sn >= 2 then break end
							sn = sn + 1
							if type(e) == "table" then dumpTable(e, "            " .. field .. sn, 30) end
						end
					end
				end
			end
		end
	end

	-- The settings registry is the real prize, but v0.7 guessed that a setting
	-- carried .variable or .name and got the CATEGORY name back for all 295.
	-- Don't guess the shape: dump a few entries whole, then search every
	-- entry's own fields for "quest" and print whatever matches.
	local reg = reached["SettingsPanel.settings"]
	if reg then
		add("")
		add("   Shape of three registry entries:")
		local shown = 0
		for k, v in pairs(reg) do
			if shown >= 3 then break end
			shown = shown + 1
			add("      --- entry " .. shown .. " (key: " .. tostring(k) .. ", type " .. type(v) .. ")")
			if type(v) == "table" then
				dumpTable(v, "         entry", 40)
				local mt = getmetatable(v)
				local idx = mt and rawget(mt, "__index")
				if type(idx) == "table" then dumpTable(idx, "         entry.__index", 40) end
			end
		end

		add("")
		add("   Entries whose fields mention 'quest' (shape-agnostic search):")
		local hits = 0
		for k, v in pairs(reg) do
			local matched, fields = false, {}
			pcall(function()
				if type(k) == "string" and k:lower():find("quest", 1, true) then matched = true end
				if type(v) == "table" then
					for fk, fv in pairs(v) do
						local t = type(fv)
						if t == "string" or t == "number" or t == "boolean" then
							fields[#fields + 1] = tostring(fk) .. "=" .. tostring(fv)
							if type(fk) == "string" and fk:lower():find("quest", 1, true) then matched = true end
							if t == "string" and fv:lower():find("quest", 1, true) then matched = true end
						end
					end
				end
			end)
			if matched and hits < 40 then
				hits = hits + 1
				table.sort(fields)
				add("      key=" .. tostring(k))
				add("         " .. table.concat(fields, ", "))
			end
		end
		add("      " .. hits .. " matching entries")
	else
		add("")
		add("   SettingsPanel.settings not reachable.")
	end
end

-- [G9] The questgiver "!" blips. Everything else came back negative: no
-- tracking entry covers questgivers, there are zero globals containing
-- "blip", and the console cannot be enumerated. The only lever left in
-- evidence is Minimap:SetBlipTexture, which swaps the whole POI icon sheet.
local function sectionBlips()
	head("[G9] Questgiver blips - what is left to try")

	probeMethod(Minimap, "Minimap", "SetBlipTexture")
	probeMethod(Minimap, "Minimap", "GetBlipTexture")
	probeMethod(Minimap, "Minimap", "UpdateBlips")
	probeMethod(Minimap, "Minimap", "SetIconTexture")
	probeMethod(Minimap, "Minimap", "SetPOIArrowTexture")

	probeMethod(Minimap, "Minimap", "SetToDefaults")

	add("")
	add("   CONFIRMED in game: /unrecon blip 136458 turned every minimap POI icon")
	add("   into a grey square, questgiver ! and ? included. So the lever reaches")
	add("   them -- but it swaps the whole sheet, and /reload did NOT undo it;")
	add("   only a full client restart did.")
	add("")
	add("   RESOLVED, and badly. Minimap:SetToDefaults() REMOVED THE ENTIRE MINIMAP")
	add("   FRAME. Do not call it. It is no longer used by this probe.")
	add("   SetBlipTexture(nil) / (\"\") removed every blip instead of restoring")
	add("   them, and that survived /reload. Only a full client restart restores")
	add("   the real icons.")
	add("")
	add("   So: blips CAN be removed (set an empty blip texture -- no shipped art")
	add("   needed), but it is all-or-nothing and cannot be undone in session.")
	add("")
	add("   Test with:  /unrecon blip 136458")
	add("   That swaps the POI icon sheet for an unrelated texture. If the minimap")
	add("   questgiver icons change or vanish, the lever works and the addon would")
	add("   need its own transparent sheet. If nothing changes, this route is dead")
	add("   and the ! blips are not addon-reachable on this client.")
end

-- [G6] The questgiver "!" blips. Classic never showed these; MoP does, and no
-- switch for them turned up in v0.2-v0.4. Rather than guess at CVar names,
-- enumerate the whole console command list and filter it -- a name that is
-- not in that list does not exist, which is a real answer either way.
local function sectionCVarDiscovery()
	head("[G6] CVar discovery - full console command list")

	if not (C_Console and type(C_Console.GetAllCommands) == "function") then
		add("   C_Console.GetAllCommands missing - cannot enumerate the CVar space.")
		add("   Without it there is no principled way to find an unknown CVar name.")
		return
	end

	local ok, cmds = pcall(C_Console.GetAllCommands)
	if not ok or type(cmds) ~= "table" then
		add("   GetAllCommands failed: " .. tostring(cmds))
		return
	end
	add("   Total console commands: " .. #cmds)

	local PATTERNS = { "quest", "poi", "blip", "minimap", "track", "helper",
	                   "boss", "npc", "objective", "marker", "icon" }
	local hits = {}
	for i = 1, #cmds do
		local c = cmds[i]
		local name = type(c) == "table" and c.command or tostring(c)
		if type(name) == "string" then
			local lower = name:lower()
			for p = 1, #PATTERNS do
				if lower:find(PATTERNS[p], 1, true) then
					local value = select(2, pcall(GetCVar, name))
					hits[#hits + 1] = string.format("%-42s = %-18s %s",
						name, tostring(value),
						(type(c) == "table" and c.help and tostring(c.help):sub(1, 60)) or "")
					break
				end
			end
		end
	end
	table.sort(hits)
	add("   Matching quest/POI/blip/minimap/track/boss/icon: " .. #hits)
	for i = 1, #hits do add("      " .. hits[i]) end
end

-- [G6 cont.] Everything the tracking system will tell us about each entry,
-- not just name and active. A questgiver-blip switch could live here.
local function sectionTrackingDetail()
	head("[G6] Tracking entries - every field")

	local C = C_Minimap
	if type(C) ~= "table" or type(C.GetNumTrackingTypes) ~= "function" then
		add("   C_Minimap tracking API missing.")
		return
	end
	local okc, count = pcall(C.GetNumTrackingTypes)
	if not okc or type(count) ~= "number" then
		add("   Could not read tracking count.")
		return
	end
	for i = 1, count do
		local ok, info = pcall(C.GetTrackingInfo, i)
		if ok and type(info) == "table" then
			local keys = {}
			for k, v in pairs(info) do
				if type(k) == "string" then keys[#keys + 1] = k .. "=" .. tostring(v) end
			end
			table.sort(keys)
			add(string.format("   %2d  %s", i, table.concat(keys, ", ")))
		else
			add(string.format("   %2d  (not a table: %s)", i, tostring(info)))
		end
	end

	add("")
	if type(C.GetPOITextureCoords) == "function" then
		add("   C_Minimap.GetPOITextureCoords by index:")
		for i = 1, 24 do
			local ok, a, b, c, d = pcall(C.GetPOITextureCoords, i)
			if ok and a ~= nil then
				add(string.format("      %2d  %s, %s, %s, %s", i,
					tostring(a), tostring(b), tostring(c), tostring(d)))
			end
		end
	else
		add("   C_Minimap.GetPOITextureCoords missing.")
	end

	add("")
	listGlobals("Globals containing 'blip'", "blip", 40)
end

-- [G7] The world map boss portraits in Pandaria zones. v0.4 already named the
-- likely lever: provider 7 is EncounterJournalDataProviderMixin carrying
-- cvar=showBosses. This just reports the state so it can be tested live.
local function sectionMapClutter()
	head("[G7] World map clutter - boss portraits and dig sites")
	add("   v0.4 identified these providers and the CVar field each carries:")
	add("      provider  7  EncounterJournalDataProviderMixin  cvar=showBosses")
	add("      provider  6  DigSiteDataProviderMixin           cvar=digSites")
	add("")
	for _, c in ipairs({ "showBosses", "digSites" }) do probeCVar(c) end
	add("")
	add("   Test with: /unrecon set showBosses 0   (then look at a Pandaria zone map)")
end

-- [G11] The "Outline" option and the sparkle/glimmer on quest objects.
-- Research points at two CVars; neither has ever been probed on this client.
local function sectionOutline()
	head("[G11] Quest object outline and sparkles")
	add("   Research (No Questgiver Sparkles addon; Blizzard forum threads) names")
	add("   a CVar 'Outline' for the option in Blizzard's menu, and")
	add("   'graphicsOutlineMode' (0 disabled / 1 good / 2 high) for outline density.")
	add("   Neither has been checked on THIS client until now.")
	add("")
	for _, c in ipairs({ "Outline", "graphicsOutlineMode", "ffxGlow",
	                     "particleDensity", "particleMTDensity", "ffxDeath",
	                     "shadowMode", "highlightOutlineQuality" }) do
		probeCVar(c)
	end
	add("")
	add("   LIVE RESULTS -- CORRECTED:")
	add("      Outline EXISTS and WRITES CORRECTLY. Values 0/1/2/3 all take.")
	add("      Nothing renders at any value -- and Blizzard's OWN options window")
	add("      does not change anything either. So this is a CLIENT RENDERING")
	add("      FAULT, not a dead CVar and not something an addon can reach.")
	add("      graphicsOutlineMode is absent, as expected: added in Patch 7.0.3,")
	add("      long after 5.4.")
	add("")
	add("   Because outline and sparkle are alternatives, an outline that never")
	add("   renders means the sparkle is always shown. That is the whole cause.")
	add("")
	add("   REJECTED, both tested live:")
	add("      particleDensity 0  -- does remove the glimmer, but also removes")
	add("                            the particles on lootable bodies, which")
	add("                            Classic had. Not a fix.")
	add("      ffxGlow 0          -- visible change elsewhere, does not touch")
	add("                            the particle glow at all. Not a fix.")
	add("")
	add("   Target behaviour, for the record: sparkles OFF for quest objectives")
	add("   and herb/mining nodes, but KEPT on lootable bodies. No lever found")
	add("   so far separates those three, and the only CVar that would (Outline)")
	add("   cannot render on this client.")
	add("")
	add("   Shipped as an EXPERIMENTAL opt-in anyway: turning Outline ON is a")
	add("   semi-fix for anyone whose client CAN render outlines. 1 is enough;")
	add("   2 and 3 also work. Never on by default, never part of /vq on.")
end

-- [G12] The quest progress tooltip that appears on mouseover.
local function sectionQuestTooltip()
	head("[G12] Quest progress tooltip on mouseover")
	add("   showQuestTrackingTooltips is the documented CVar, but it is ABSENT on")
	add("   this client (see the CVar section above). So the fallback is to strip")
	add("   the quest lines from GameTooltip, which IS Lua-reachable.")
	add("")
	for _, n in ipairs({ "GameTooltip", "GameTooltipTextLeft1", "GameTooltipTextLeft2" }) do probe(n) end
	for _, m in ipairs({ "NumLines", "GetUnit", "SetOwner", "ClearLines", "Show", "HookScript" }) do
		probeMethod(GameTooltip, "GameTooltip", m)
	end
	add("")
	add("   Line-object naming lets an addon blank individual lines in place,")
	add("   which is how the quest progress rows would be removed.")
	local n = 0
	while _G["GameTooltipTextLeft" .. (n + 1)] do n = n + 1 if n > 60 then break end end
	add("   GameTooltipTextLeft<N> font strings that exist right now: " .. n)

	add("")
	add("   Observed shape (from live testing): the quest NAME is its own line,")
	add("   followed by one line per objective, e.g. \" - Riverpaw Gnoll Clue: 0/1\".")
	add("   The line NUMBER varies, so a matcher must key off text and colour.")
	add("   Quest log APIs, needed to match a line against real quest titles:")
	for _, n2 in ipairs({
		"GetNumQuestLogEntries", "GetQuestLogTitle", "GetQuestLogLeaderBoard",
		"C_QuestLog", "GetQuestObjectiveInfo",
	}) do probe(n2) end
	add("")
	add("   Capture a real tooltip with: /unrecon tipwatch, hover, /unrecon tipdump")
end

-- [G10] Which atlas cell is the questgiver "!"?
-- Research settled the default sheet path; GetPOITextureCoords gives the UV
-- rect per index. Drawing each cell with its index number turns "which one is
-- the ! ?" from a guess into something that can simply be read off screen.
local function sectionBlipAtlas()
	head("[G10] Blip atlas")
	add("   Default sheet (from a Mists-targeted addon that restores it on logout):")
	add("      Interface\\MINIMAP\\ObjectIconsAtlas")
	add("   Restoring it needs no /reload, which makes an on/off toggle possible.")
	add("")
	add("   /unrecon blipreset          restore the default sheet (no argument needed)")
	add("   /unrecon atlas [w] [h]      the WHOLE sheet, every index boxed on it")
	add("   /unrecon cell <index>       ONE index, big, at three aspects")
	add("")
	add("   KNOWN PROBLEM: at 256x256 and 512x512 the sheet renders correctly but")
	add("   the red boxes do NOT line up with the art, so GetPOITextureCoords and")
	add("   this texture disagree about the grid. Use /unrecon cell to settle what")
	add("   a given index actually points at.")
	add("")
	add("   Note: the documented 8x2 / 256x64 layout describes the OLD ObjectIcons")
	add("   sheet. GetPOITextureCoords on this client steps by 0.0703125 across and")
	add("   0.03515625 down, so this atlas is far larger. Any replacement art must")
	add("   match THIS grid, not the documented one.")
end

-- [G13] Blizzard's combined selector -- arrows plus a value that drops a list,
-- as used for Outline Mode, Status Text and Display Aggro Warning. The options
-- panel hand-builds an equivalent because this control could not be named.
-- Find the real template so it can be swapped in.
local function sectionSelector()
	head("[G13] Blizzard's arrow+dropdown selector")

	add("   Templates that actually construct on this client:")
	local CANDIDATES = {
		"UIDropDownMenuTemplate", "UIDropDownMenuButtonTemplate",
		"OptionsDropDownMenuTemplate", "InterfaceOptionsDropDownTemplate",
		"SettingsDropdownTemplate", "SettingsDropDownControlTemplate",
		"SettingsSelectionDropdownTemplate", "DropdownButtonTemplate",
		"WowStyle1DropdownTemplate", "UIPanelSquareButton",
		"OptionsSliderTemplate",
	}
	local host = CreateFrame("Frame")
	for i = 1, #CANDIDATES do
		local ok = pcall(CreateFrame, "Frame", nil, host, CANDIDATES[i])
		if not ok then
			ok = pcall(CreateFrame, "Button", nil, host, CANDIDATES[i])
		end
		mark(ok, CANDIDATES[i])
	end

	add("")
	listGlobals("Globals containing 'dropdown'", "dropdown", 60)
	add("")
	listGlobals("Globals containing 'selection'", "selection", 30)

	-- Constructing a template proves it exists; it does not show how to drive
	-- it. Dump what a constructed one actually offers.
	add("")
	for _, name in ipairs({ "SettingsDropDownControlTemplate", "WowStyle1DropdownTemplate" }) do
		local ok, f = pcall(CreateFrame, "Frame", nil, host, name)
		if not ok or not f then
			ok, f = pcall(CreateFrame, "Button", nil, host, name)
		end
		if ok and f then
			add("   --- " .. name .. " ---")
			dumpMethods(f, "      " .. name, { "set", "get", "option", "select", "value", "init", "text" })
			dumpTable(f, "      " .. name .. " keys", 40)
		else
			add("   --- " .. name .. ": could not construct ---")
		end
	end

	add("")
	add("   How Blizzard's own Apply button is driven, for the reload prompt:")
	for _, m in ipairs({ "SetApplyButtonEnabled", "HasUnappliedSettings", "CommitSettings",
	                     "CheckApplyButton", "RegisterSetting" }) do
		probeMethod(SettingsPanel, "SettingsPanel", m)
	end
	mark(SettingsPanel ~= nil and rawget(SettingsPanel, "ApplyButton") ~= nil, "SettingsPanel.ApplyButton")
	for _, n in ipairs({ "Settings.RegisterAddOnSetting", "Settings.SetOnValueChangedCallback" }) do
		add("   (see the Settings dump above for " .. n .. ")")
	end

	add("")
	add("   Blizzard drives these through helper functions; report which exist:")
	for _, n in ipairs({
		"UIDropDownMenu_Initialize", "UIDropDownMenu_SetSelectedValue",
		"UIDropDownMenu_SetText", "UIDropDownMenu_AddButton",
		"UIDropDownMenu_SetWidth", "Settings_CreateDropdown",
	}) do probe(n) end
end

-- [G13b] The keystone. Blizzard's dropdown wants a registered Setting object,
-- and Settings.CreateDropdown builds the control from one. Both functions
-- exist; only their signatures are unknown. Rather than guess a sixth time,
-- CALL them with each plausible shape and report which one is accepted.
--
-- NOTE: a successful call registers a real setting, so a stray entry may sit
-- in Blizzard's options until you /reload. That is the price of finding out.
local function sectionSettingSignature()
	head("[G13b] Settings.RegisterAddOnSetting -- which signature works?")

	if type(Settings) ~= "table" or type(Settings.RegisterAddOnSetting) ~= "function" then
		add("   Settings.RegisterAddOnSetting missing; nothing to try.")
		return
	end

	local category
	if type(Settings.RegisterVerticalLayoutCategory) == "function" then
		local ok, cat = pcall(Settings.RegisterVerticalLayoutCategory, "Unmarked Recon Probe")
		if ok then category = cat end
	end
	mark(category ~= nil, "test category created")

	UnmarkedReconProbeVars = UnmarkedReconProbeVars or {}
	local tbl = UnmarkedReconProbeVars
	local vtype = (Settings.VarType and Settings.VarType.Boolean) or "boolean"

	local shapes = {
		{ "(category, variable, varTbl, varType, name, default)",
		  function() return Settings.RegisterAddOnSetting(category, "URP1", "URP1", tbl, vtype, "Probe 1", false) end },
		{ "(category, variable, varKey, varTbl, varType, name, default)",
		  function() return Settings.RegisterAddOnSetting(category, "URP2", "URP2", tbl, vtype, "Probe 2", false) end },
		{ "(category, name, variable, varTbl, varType, default)",
		  function() return Settings.RegisterAddOnSetting(category, "Probe 3", "URP3", tbl, vtype, false) end },
		{ "(name, variable, varTbl, varType, default)",
		  function() return Settings.RegisterAddOnSetting("Probe 4", "URP4", tbl, vtype, false) end },
		{ "(variable, name, varTbl, varType, default)",
		  function() return Settings.RegisterAddOnSetting("URP5", "Probe 5", tbl, vtype, false) end },
	}

	local winner
	for i = 1, #shapes do
		local ok, res = pcall(shapes[i][2])
		if ok and type(res) == "table" then
			add("   OK   " .. shapes[i][1])
			winner = winner or res
		elseif ok then
			add("   ??   " .. shapes[i][1] .. "  -> returned " .. type(res))
		else
			add("   --   " .. shapes[i][1] .. "  -> " .. tostring(res):sub(1, 90))
		end
	end

	if winner then
		add("")
		dumpMethods(winner, "   setting object", { "get", "set", "value", "variable", "default" })
		dumpTable(winner, "   setting object keys", 30)
	else
		add("")
		add("   No shape accepted. The dropdown cannot be driven this way.")
	end

	add("")
	add("   Menu API, which WowStyle1DropdownTemplate needs to fill its list:")
	for _, n in ipairs({ "MenuUtil", "Menu", "MenuResponse", "CreateContextMenu" }) do probe(n) end
	local okd, dd = pcall(CreateFrame, "Button", nil, UIParent, "WowStyle1DropdownTemplate")
	if okd and dd then
		probeMethod(dd, "WowStyle1Dropdown", "SetupMenu")
		local mm = rawget(dd, "menuMixin")
		if type(mm) == "table" then
			dumpTable(mm, "   menuMixin", 40)
		else
			add("   menuMixin is not a readable table.")
		end
	end
	for _, n in ipairs({ "CreateDropdown", "CreateDropdownInitializer", "CreateControlTextContainer" }) do
		probeMethod(Settings, "Settings", n)
	end
end

-- [G14] Tier 2: the on-screen objective tracker. Nothing here has been probed
-- beyond confirming WatchFrame exists.
local function sectionTracker()
	head("[G14] Tier 2 -- the WatchFrame tracker")

	if not WatchFrame then
		add("   WatchFrame missing; Tier 2 has nothing to act on.")
		return
	end

	local prot, explicit = nil, nil
	pcall(function() prot, explicit = WatchFrame:IsProtected() end)
	add("   WatchFrame:IsProtected() -> " .. tostring(prot) .. ", explicit " .. tostring(explicit))
	add("   (safety rule 1: a protected frame must never be hidden in combat)")

	add("")
	dumpChildren(WatchFrame, "WatchFrame")
	add("")
	dumpRegions(WatchFrame, "WatchFrame")
	add("")
	dumpMethods(WatchFrame, "WatchFrame", { "collapse", "expand", "update", "link", "quest" })

	add("")
	add("   Globals that drive it:")
	for _, n in ipairs({
		"WatchFrame_Update", "WatchFrame_Collapse", "WatchFrame_Expand",
		"WatchFrame_ClearDisplay", "WatchFrame_GetRemainingSpace",
		"WATCHFRAME_QUESTLINES", "WATCHFRAME_ACTIVE_ACHIEVEMENTS",
		"AUTOQUEST_POPUP_ENABLED", "AutoQuestPopUp_Show",
		"QuestPOI_UpdateButton", "WatchFrameAutoQuest_ClearPopUp",
	}) do probe(n) end

	add("")
	listGlobals("Globals containing 'watchframe'", "watchframe", 60)
	add("")
	listGlobals("Globals containing 'autoquest'", "autoquest", 30)
end

---------------------------------------------------------------------

-- [G13c] v0.14 asked "which signature is accepted?" and got the useless answer
-- "all five". RegisterAddOnSetting does not validate its arguments, so a call
-- with the wrong order still builds a setting -- just a scrambled one.
--
-- So stop asking whether the call is accepted and ask where each argument
-- LANDED. Every shape is passed sentinel strings, then read back through
-- GetName / GetVariable / GetVariableType / GetDefaultValue. The shape whose
-- sentinels all come back in the right slots is the real signature; the rest
-- will show the name in the variable slot, or a nil type, or a lost default.
--
-- NOTE: this registers real settings, so a stray "Unmarked Recon Probe"
-- category may sit in Blizzard's options until you /reload.
local function sectionSettingReadback()
	head("[G13c] RegisterAddOnSetting -- where does each argument land?")

	if type(Settings) ~= "table" or type(Settings.RegisterAddOnSetting) ~= "function" then
		add("   Settings.RegisterAddOnSetting missing; nothing to try.")
		return
	end

	local category
	if type(Settings.RegisterVerticalLayoutCategory) == "function" then
		local ok, cat = pcall(Settings.RegisterVerticalLayoutCategory, "Unmarked Recon Probe")
		if ok then category = cat end
	end
	mark(category ~= nil, "test category created")
	add("")

	UnmarkedReconProbeVars = UnmarkedReconProbeVars or {}
	local tbl = UnmarkedReconProbeVars
	local vtype = (Settings.VarType and Settings.VarType.Boolean) or "boolean"

	-- Sentinels are distinct per shape so a value cannot be matched by luck,
	-- and the default is true while the backing table starts empty -- if
	-- GetValue comes back true, the default slot was genuinely read.
	local shapes = {
		{ "(category, variable, varTbl, varType, name, default)",
		  "VARa", "NAMEa",
		  function() return Settings.RegisterAddOnSetting(category, "VARa", tbl, vtype, "NAMEa", true) end },

		{ "(category, variable, varKey, varTbl, varType, name, default)",
		  "VARb", "NAMEb",
		  function() return Settings.RegisterAddOnSetting(category, "VARb", "VARb", tbl, vtype, "NAMEb", true) end },

		{ "(category, name, variable, varTbl, varType, default)",
		  "VARc", "NAMEc",
		  function() return Settings.RegisterAddOnSetting(category, "NAMEc", "VARc", tbl, vtype, true) end },

		{ "(category, variable, name, varTbl, varType, default)",
		  "VARd", "NAMEd",
		  function() return Settings.RegisterAddOnSetting(category, "VARd", "NAMEd", tbl, vtype, true) end },

		{ "(variable, name, varTbl, varType, default)",
		  "VARe", "NAMEe",
		  function() return Settings.RegisterAddOnSetting("VARe", "NAMEe", tbl, vtype, true) end },

		{ "(category, varTbl, varType, variable, name, default)",
		  "VARf", "NAMEf",
		  function() return Settings.RegisterAddOnSetting(category, tbl, vtype, "VARf", "NAMEf", true) end },
	}

	local function readback(obj, method)
		if type(obj[method]) ~= "function" then return "<no " .. method .. ">" end
		local ok, v = pcall(obj[method], obj)
		if not ok then return "<error>" end
		return tostring(v)
	end

	local best, bestScore = nil, -1
	for i = 1, #shapes do
		local desc, wantVar, wantName, call = shapes[i][1], shapes[i][2], shapes[i][3], shapes[i][4]
		local ok, res = pcall(call)
		if not ok then
			add("   --   " .. desc)
			add("           rejected: " .. tostring(res):sub(1, 100))
		elseif type(res) ~= "table" then
			add("   --   " .. desc .. "  -> returned " .. type(res))
		else
			local gotName = readback(res, "GetName")
			local gotVar  = readback(res, "GetVariable")
			local gotType = readback(res, "GetVariableType")
			local gotDef  = readback(res, "GetDefaultValue")
			local gotVal  = readback(res, "GetValue")

			local score = 0
			if gotName == wantName then score = score + 1 end
			if gotVar  == wantVar  then score = score + 1 end
			if gotType == "boolean" then score = score + 1 end
			if gotDef  == "true"   then score = score + 1 end

			add("   " .. (score == 4 and ">>>>" or "    ") .. "  " .. desc)
			add("           GetName        = " .. gotName .. (gotName == wantName and "   <- correct" or "   (wanted " .. wantName .. ")"))
			add("           GetVariable    = " .. gotVar  .. (gotVar  == wantVar  and "   <- correct" or "   (wanted " .. wantVar .. ")"))
			add("           GetVariableType= " .. gotType .. (gotType == "boolean" and "   <- correct" or "   (wanted boolean)"))
			add("           GetDefaultValue= " .. gotDef  .. (gotDef  == "true"    and "   <- correct" or "   (wanted true)"))
			add("           GetValue       = " .. gotVal)
			add("           score " .. score .. "/4")

			if score > bestScore then best, bestScore = res, score end
		end
		add("")
	end

	if bestScore == 4 then
		add("   VERDICT: a shape scored 4/4 -- that is the real signature.")
	elseif best then
		add("   VERDICT: no shape scored 4/4 (best was " .. bestScore .. "/4).")
		add("   Read the slots above: whichever field holds NAME* tells you where")
		add("   the name argument really goes.")
	else
		add("   VERDICT: nothing registered. This route is closed.")
	end

	-- Second half: does a setting object actually drive Blizzard's controls?
	-- Getting the signature right is worthless if CreateDropdown then refuses.
	add("")
	add("   Can the winning setting drive Blizzard's own controls?")
	if best then
		if type(Settings.CreateCheckbox) == "function" then
			local okc, errc = pcall(Settings.CreateCheckbox, category, best, "probe tooltip")
			mark(okc, "Settings.CreateCheckbox(category, setting, tooltip)")
			if not okc then add("           " .. tostring(errc):sub(1, 100)) end
		end

		if type(Settings.CreateControlTextContainer) == "function" and type(Settings.CreateDropdown) == "function" then
			local okg, container = pcall(Settings.CreateControlTextContainer)
			mark(okg, "Settings.CreateControlTextContainer()")
			if okg and type(container) == "table" then
				dumpTable(container, "   container", 20)
				local oka = pcall(function() container:Add(true, "Yes") container:Add(false, "No") end)
				mark(oka, "container:Add(value, label)")
				local okd, errd = pcall(Settings.CreateDropdown, category, best,
					function() return container:GetData() end, "probe tooltip")
				mark(okd, "Settings.CreateDropdown(category, setting, getOptions, tooltip)")
				if not okd then add("           " .. tostring(errd):sub(1, 120)) end
			end
		end
	else
		add("   (skipped -- no setting object to test with)")
	end

	add("")
	add("   Other registration routes, in case the above stays scrambled:")
	for _, n in ipairs({
		"RegisterProxySetting", "RegisterAddOnSetting", "SetOnValueChangedCallback",
		"CreateSettingInitializer", "CreateElementInitializer", "RegisterInitializer",
	}) do probeMethod(Settings, "Settings", n) end
end

-- [G15] Tier 2 internals. v0.14 established the outside of the tracker:
-- WatchFrame is unprotected, has three children, and is driven by a family of
-- WatchFrame_* and WatchFrameAutoQuest_* globals. What it did not show is what
-- a tracked quest looks like from the inside -- and that is exactly what
-- "strip it to Classic form" needs.
--
-- READ THIS BEFORE RUNNING: this section is only worth anything with at least
-- one quest TRACKED and, ideally, a quest with an item button (a quest that
-- gives you a usable item). With an empty tracker it will honestly report
-- nothing, which is a wasted run rather than a wrong answer.
local function sectionTrackerInternals()
	head("[G15] Tier 2 internals -- tracker lines, item buttons, popups")

	if not WatchFrame then
		add("   WatchFrame missing; nothing to inspect.")
		return
	end

	local tracked = 0
	if type(GetNumQuestWatches) == "function" then
		local ok, n = pcall(GetNumQuestWatches)
		if ok then tracked = n or 0 end
	end
	add("   Quests currently tracked: " .. tracked)
	if tracked == 0 then
		add("   *** Track at least one quest and run this again, or the rest of")
		add("   *** this section has nothing to describe.")
	end
	add("")

	-- The visible line pool. Classic form is "quest name, then objective
	-- counts" and nothing else, so what matters is which of these are text
	-- and which are clickable.
	dumpChildren(WatchFrameLines, "WatchFrameLines")
	add("")
	dumpRegions(WatchFrameLines, "WatchFrameLines")
	add("")

	-- WATCHFRAME_QUESTLINES is an array, so dumpTable's string-key view is
	-- blind to it. Walk it by index instead and read the text out.
	local function dumpArray(t, name, cap)
		if type(t) ~= "table" then
			add("   " .. name .. " is not a table (" .. type(t) .. ").")
			return
		end
		local n = #t
		add("   " .. name .. ": " .. n .. " entr" .. (n == 1 and "y" or "ies"))
		for i = 1, math.min(n, cap or 20) do
			local e = t[i]
			local desc = type(e)
			if type(e) == "table" then
				local nm, txt, otype
				pcall(function() nm = e.GetName and e:GetName() end)
				pcall(function() otype = e.GetObjectType and e:GetObjectType() end)
				pcall(function() txt = e.GetText and e:GetText() end)
				desc = (nm or "<unnamed>") .. "  [" .. tostring(otype) .. "]"
				if txt then desc = desc .. "  text=\"" .. tostring(txt) .. "\"" end
				local hasClick
				pcall(function() hasClick = e.GetScript and e:GetScript("OnClick") ~= nil end)
				if hasClick then desc = desc .. "  HAS OnClick" end
			end
			add(string.format("      %2d  %s", i, desc))
		end
		if n > (cap or 20) then add("      ... and " .. (n - (cap or 20)) .. " more") end
	end

	dumpArray(WATCHFRAME_QUESTLINES, "WATCHFRAME_QUESTLINES", 25)
	add("")
	dumpArray(WATCHFRAME_LINKBUTTONS, "WATCHFRAME_LINKBUTTONS", 25)
	add("")

	-- Quest item buttons: Classic had none, so these are a removal target.
	add("   Quest item buttons:")
	local foundItem = false
	for i = 1, 8 do
		local f = _G["WatchFrameItem" .. i]
		if f then
			foundItem = true
			local shown, parent = "?", "?"
			pcall(function() shown = f:IsShown() and "shown" or "hidden" end)
			pcall(function() local p = f:GetParent() parent = (p and p:GetName()) or "<unnamed>" end)
			add(string.format("      WatchFrameItem%d  %s  parent=%s", i, shown, parent))
		end
	end
	if not foundItem then add("      none exist under that name.") end
	add("")

	-- Sorting. trackQuestSorting is a real CVar on this client (v0.14 read it
	-- as "top"), and these constants are what the tracker compares it against.
	add("   Sorting and filtering constants:")
	for _, n in ipairs({
		"WATCHFRAME_SORT_TYPE", "WATCHFRAME_SORT_MANUAL",
		"WATCHFRAME_SORT_DIFFICULTY_HIGH", "WATCHFRAME_SORT_DIFFICULTY_LOW",
		"WATCHFRAME_FILTER_TYPE", "WATCHFRAME_FILTER_NONE",
		"WATCHFRAME_FILTER_COMPLETED_QUESTS", "WATCHFRAME_FILTER_REMOTE_ZONES",
		"WATCHFRAME_FILTER_ACHIEVEMENTS", "WATCHFRAME_MAXQUESTS",
		"WATCHFRAME_NUM_ITEMS", "WATCHFRAME_NUM_POPUPS", "WATCHFRAME_ITEM_WIDTH",
		"WATCHFRAME_QUEST_OFFSET", "WATCHFRAME_TYPE_OFFSET", "WATCHFRAME_LINEHEIGHT",
	}) do
		local v = _G[n]
		if v == nil then
			add("   --   " .. n)
		else
			add("   OK   " .. n .. " = " .. tostring(v) .. "  [" .. type(v) .. "]")
		end
	end
	probeCVar("trackQuestSorting")
	add("")

	-- The turn-in pop-up. v0.14 found the whole WatchFrameAutoQuest_* family;
	-- what is still unknown is the shape of the data behind it, which decides
	-- whether the pop-up can be removed at the source rather than hidden after
	-- the fact. Reads only -- nothing here removes a live pop-up.
	add("   Auto-quest turn-in pop-ups:")
	if type(GetNumAutoQuestPopUps) == "function" then
		local ok, n = pcall(GetNumAutoQuestPopUps)
		add("      GetNumAutoQuestPopUps() -> " .. (ok and tostring(n) or "error"))
		if ok and (n or 0) > 0 and type(GetAutoQuestPopUp) == "function" then
			local okp, a, b, c, d = pcall(GetAutoQuestPopUp, 1)
			if okp then
				add("      GetAutoQuestPopUp(1) -> " .. tostring(a) .. ", " .. tostring(b) ..
					", " .. tostring(c) .. ", " .. tostring(d))
				add("      (first return is most likely the questID that")
				add("       RemoveAutoQuestPopUp would take)")
			else
				add("      GetAutoQuestPopUp(1) errored: " .. tostring(a):sub(1, 80))
			end
		elseif ok then
			add("      No pop-up live right now. Accept a quest that auto-completes,")
			add("      or finish one, then run this again to catch the data shape.")
		end
	else
		add("      GetNumAutoQuestPopUps missing.")
	end
	for _, n in ipairs({
		"AddAutoQuestPopUp", "GetAutoQuestPopUp", "RemoveAutoQuestPopUp",
		"WatchFrameAutoQuest_DisplayAutoQuestPopUps", "WatchFrameAutoQuest_SlideIn",
		"WatchFrameAutoQuest_GetOrCreateFrame", "WatchFrameAutoQuest_ClearPopUp",
		"WatchFrameAutoQuest_ClearPopUpByLogIndex", "WatchFrameAutoQuest_OnUpdate",
	}) do probe(n) end
	add("")

	-- v0.14 cut this list at 60 of 150. The remaining 90 are where the line
	-- templates and item-button plumbing will be named.
	listGlobals("Globals containing 'watchframe'", "watchframe", 200)
end

-- [G16] The last two unknowns on the native-panel route.
--
-- v0.15 settled the signature and confirmed the controls, and the panel is now
-- built from Blizzard's own checkbox and dropdown. Two things did not come
-- across from the hand-built version and are the reason the reload dialog is
-- still there:
--
--   1. Blizzard's Apply button. The setting object carries Commit, Revert,
--      IsModified, SetCommitFlags and SetPendingValue -- the whole vocabulary
--      -- but the flag VALUES that ask for an Apply are unknown. Guessing a
--      number here is exactly the kind of guess this project keeps paying for.
--   2. A section header, to put "Experimental" back above the experiments,
--      and a Defaults button for the category.
--
-- Read-only apart from one category registration.
local function sectionNativePanel()
	head("[G16] Native panel -- Apply, defaults, section headers")

	if type(Settings) ~= "table" then
		add("   Settings missing.")
		return
	end

	-- Values, not just names: an enum is useless without its numbers.
	local function dumpEnum(t, name)
		if type(t) ~= "table" then
			add("   --   " .. name .. " (" .. type(t) .. ")")
			return
		end
		local keys = {}
		for k, v in pairs(t) do
			if type(k) == "string" then keys[#keys + 1] = k .. " = " .. tostring(v) end
		end
		table.sort(keys)
		add("   OK   " .. name .. ": " .. #keys .. " member(s)")
		for i = 1, #keys do add("           " .. keys[i]) end
	end

	dumpEnum(Settings.CommitFlag, "Settings.CommitFlag")
	dumpEnum(Settings.VarType, "Settings.VarType")
	dumpEnum(Settings.Default, "Settings.Default")
	dumpEnum(Settings.UpdateReason, "Settings.UpdateReason")
	add("")

	-- The whole Settings table, unfiltered. Every previous pass filtered on a
	-- guessed word and so could only find what was already suspected.
	dumpTable(Settings, "   Settings", 250)
	add("")

	-- The category object, and whatever RegisterVerticalLayoutCategory hands
	-- back alongside it -- the layout is where initializers are added.
	local cat, layout
	if type(Settings.RegisterVerticalLayoutCategory) == "function" then
		local ok, a, b = pcall(Settings.RegisterVerticalLayoutCategory, "Unmarked Recon Probe")
		if ok then cat, layout = a, b end
	end
	mark(cat ~= nil, "category created")
	if cat then
		dumpTable(cat, "   category", 60)
		dumpMethods(cat, "   category", { "default", "layout", "header", "add", "set" })
	end
	add("")
	if layout ~= nil then
		add("   RegisterVerticalLayoutCategory returned a SECOND value: " .. type(layout))
		if type(layout) == "table" then
			dumpTable(layout, "   layout", 60)
			dumpMethods(layout, "   layout", { "add", "initializer", "header", "create" })
		end
	else
		add("   RegisterVerticalLayoutCategory returned ONE value only.")
		add("   (so the layout must be fetched -- see Settings.GetLayout / AssignLayoutToCategory above)")
	end
	add("")

	-- Section headers: what builds one, under any of the names Blizzard has
	-- used for it. Names are enumerated rather than guessed one at a time.
	add("   Section header candidates:")
	for _, n in ipairs({
		"CreateSettingsListSectionHeaderInitializer", "SettingsListSectionHeaderMixin",
		"CreateSettingsCheckboxInitializer", "SettingsListSectionHeaderTemplate",
	}) do probe(n) end
	for _, n in ipairs({
		"CreateElementInitializer", "CreateSettingInitializer", "RegisterInitializer",
		"CreateSectionHeader", "CreateSectionHeaderInitializer", "GetLayout",
		"AssignLayoutToCategory", "CreateCategory", "SetCategoryDefaultsCallback",
	}) do probeMethod(Settings, "Settings", n) end
	add("")
	listGlobals("Globals containing 'sectionheader'", "sectionheader", 30)
	add("")

	-- The Apply button itself, so its enabling condition can be read rather
	-- than inferred.
	add("   SettingsPanel and its Apply button:")
	probe("SettingsPanel")
	if SettingsPanel then
		for _, n in ipairs({
			"SetApplyButtonEnabled", "HasUnappliedSettings", "CommitSettings",
			"SetCurrentCategorySettings", "GetCurrentCategory", "Commit",
		}) do probeMethod(SettingsPanel, "SettingsPanel", n) end
		local ab = rawget(SettingsPanel, "ApplyButton")
		mark(ab ~= nil, "SettingsPanel.ApplyButton")
		if ab then
			local shown, enabled = "?", "?"
			pcall(function() shown = ab:IsShown() and "shown" or "hidden" end)
			pcall(function() enabled = ab:IsEnabled() and "enabled" or "disabled" end)
			add("           currently " .. shown .. ", " .. enabled)
		end
	end
end

-- [G17] One loose end from the native panel: the Experimental section header
-- renders in orange as asked, but shows a tooltip on hover that a heading has
-- no use for. Only the name is passed in, so the tooltip is being defaulted
-- from it somewhere inside the initializer. v0.12.0 clears the two fields it
-- could plausibly be; this says which one is real, or names a third.
local function sectionHeaderTooltip()
	head("[G17] Section header -- where its tooltip comes from")

	if type(CreateSettingsListSectionHeaderInitializer) ~= "function" then
		add("   CreateSettingsListSectionHeaderInitializer missing.")
		return
	end

	local ok, init = pcall(CreateSettingsListSectionHeaderInitializer, "PROBEHEADER")
	if not ok or type(init) ~= "table" then
		add("   could not build one: " .. tostring(init):sub(1, 90))
		return
	end

	dumpTable(init, "   initializer", 40)
	dumpMethods(init, "   initializer", { "tooltip", "name", "data", "text" })

	local data = rawget(init, "data")
	if type(data) == "table" then
		add("")
		add("   initializer.data, with values:")
		for k, v in pairs(data) do
			if type(k) == "string" then
				add("      data." .. k .. " = " .. tostring(v) .. "  [" .. type(v) .. "]")
			end
		end
	else
		add("   initializer.data is " .. type(data) .. ", so the tooltip is not there.")
	end

	-- Two arguments would explain it too, if the second defaults to the first.
	local ok2, init2 = pcall(CreateSettingsListSectionHeaderInitializer, "PROBEHEADER", "PROBETOOLTIP")
	mark(ok2, "it accepts a second argument (a tooltip)")
	if ok2 and type(init2) == "table" and type(init2.data) == "table" then
		for k, v in pairs(init2.data) do
			if type(k) == "string" and tostring(v):find("PROBETOOLTIP", 1, true) then
				add("           the second argument landed in data." .. k)
			end
		end
	end

	add("")
	if type(SettingsListSectionHeaderMixin) == "table" then
		dumpTable(SettingsListSectionHeaderMixin, "   SettingsListSectionHeaderMixin", 30)
	end
end

-- [G18] Quest items get a yellow border in the bags. Classic had no such
-- thing. Two ways it could be reachable, and this checks both rather than
-- assuming either: a console variable, or a named texture on each bag slot
-- that can be hidden after the container redraws.
local function sectionBagQuestBorder()
	head("[G18] Bag quest-item border")

	add("   Candidate CVars (existence only -- nothing is written):")
	for _, c in ipairs({
		"questItemHighlight", "bagQuestItemHighlight", "highlightQuestItems",
		"showQuestItemBorder", "containerQuestHighlight", "questItemBorder",
		"displayFreeBagSlots", "bagsHighlight",
	}) do probeCVar(c) end
	add("")

	-- The border is drawn per bag slot, so if it is a texture it has a name
	-- built from the button's. Read one live button rather than guess.
	add("   A live bag slot, region by region:")
	local button = _G["ContainerFrame1Item1"]
	if not button then
		add("   ContainerFrame1Item1 does not exist. Open your bags and run this again.")
	else
		dumpRegions(button, "ContainerFrame1Item1")
		add("")
		dumpTable(button, "   ContainerFrame1Item1 keys", 40)
		add("")
		add("   Named children of that button:")
		for _, suffix in ipairs({
			"IconQuestTexture", "IconBorder", "IconOverlay", "IconOverlay2",
			"NormalTexture", "Border", "questTexture", "IconTexture",
		}) do
			local r = _G["ContainerFrame1Item1" .. suffix] or rawget(button, suffix)
			if r == nil then
				add("   --   ContainerFrame1Item1" .. suffix)
			else
				local shown, tex = "?", ""
				pcall(function() shown = r.IsShown and (r:IsShown() and "shown" or "hidden") or "?" end)
				pcall(function() local t = r.GetTexture and r:GetTexture() if t then tex = "  tex=" .. tostring(t) end end)
				add("   OK   ContainerFrame1Item1" .. suffix .. "  " .. shown .. tex)
			end
		end
	end
	add("")

	add("   The functions that draw it:")
	for _, n in ipairs({
		"ContainerFrame_Update", "ContainerFrame_UpdateItemUpgradeIcons",
		"GetContainerItemQuestInfo", "C_Container",
		"SetItemButtonQuality", "SetItemButtonTexture",
		"QuestItemHighlight_Update", "ContainerFrameItemButton_OnUpdate",
	}) do probe(n) end
	add("")
	listGlobals("Globals containing 'questtexture'", "questtexture", 30)
	add("")
	listGlobals("Globals containing 'iconborder'", "iconborder", 30)
end

-- [G19] Instant Quest Text. The player can set it in Blizzard's own options,
-- which means it IS a registered setting -- so rather than guessing CVar names
-- a sixth time, find the setting Blizzard registered and read its variable off
-- it. Settings.GetSetting takes a variable, so the trick is finding the name;
-- the localised label is in a global string constant, and the registry can be
-- walked from the layouts Blizzard's own categories carry.
local function sectionInstantQuestText()
	head("[G19] Instant Quest Text -- find the variable Blizzard uses")

	add("   The label, as a global string constant:")
	listGlobals("Globals containing 'instant'", "instant", 40)
	add("")
	listGlobals("Globals containing 'questtext'", "questtext", 40)
	add("")

	-- Walk every registered category's layout and read each initializer's
	-- setting. This is the whole options tree, so it is filtered to anything
	-- whose name or variable mentions quest.
	add("   Registered settings whose name or variable mentions 'quest':")
	local seen, found = {}, 0

	local function inspect(setting, where)
		if type(setting) ~= "table" or seen[setting] then return end
		seen[setting] = true
		local name, var, vtype
		pcall(function() name = setting.GetName and setting:GetName() end)
		pcall(function() var = setting.GetVariable and setting:GetVariable() end)
		pcall(function() vtype = setting.GetVariableType and setting:GetVariableType() end)
		local hay = (tostring(name) .. " " .. tostring(var)):lower()
		if hay:find("quest") then
			found = found + 1
			add(string.format("      %-42s variable=%-32s [%s]  %s",
				tostring(name), tostring(var), tostring(vtype), where))
		end
	end

	local function walkLayout(layout, where)
		if type(layout) ~= "table" then return end
		local inits = rawget(layout, "initializers")
		if type(inits) ~= "table" then
			if type(layout.GetInitializers) == "function" then
				local ok, r = pcall(layout.GetInitializers, layout)
				if ok then inits = r end
			end
		end
		if type(inits) ~= "table" then return end
		for i = 1, #inits do
			local init = inits[i]
			if type(init) == "table" and type(init.GetSetting) == "function" then
				local ok, setting = pcall(init.GetSetting, init)
				if ok then inspect(setting, where) end
			end
		end
	end

	-- Categories live under Settings.GetCategory / the panel's own list; try
	-- every container that might hold them rather than betting on one.
	local containers = {}
	if type(Settings) == "table" then
		for _, k in ipairs({ "CategorySet" }) do
			if type(Settings[k]) == "table" then containers[#containers + 1] = { Settings[k], "Settings." .. k } end
		end
	end
	if SettingsPanel then
		for k, v in pairs(SettingsPanel) do
			if type(v) == "table" and (tostring(k):lower():find("categor") or tostring(k):lower():find("layout")) then
				containers[#containers + 1] = { v, "SettingsPanel." .. tostring(k) }
			end
		end
	end

	for _, pair in ipairs(containers) do
		local tbl, where = pair[1], pair[2]
		for k, v in pairs(tbl) do
			if type(v) == "table" then
				walkLayout(v, where .. "." .. tostring(k))
				local lay = rawget(v, "layout")
				if lay then walkLayout(lay, where .. "." .. tostring(k) .. ".layout") end
			end
		end
	end

	if found == 0 then
		add("      none found by walking. What was searched:")
		for _, pair in ipairs(containers) do add("         " .. pair[2]) end
		if #containers == 0 then add("         nothing -- no category container was reachable.") end
		add("")
		add("   Fallback: Settings.GetSetting against the constants above.")
		if type(Settings) == "table" and type(Settings.GetSetting) == "function" then
			for _, guess in ipairs({ "instantQuestText", "questTextInstant", "instantquesttext" }) do
				local ok, st = pcall(Settings.GetSetting, guess)
				mark(ok and type(st) == "table", "Settings.GetSetting(\"" .. guess .. "\")")
			end
		end
	end
	add("")
	add("   (Set Instant Quest Text ON in Blizzard's options, /reload, then run")
	add("    this again: whichever variable above changed value is the one.)")
	for _, n in ipairs({ "GetCVar", "GetCVarInfo", "GetCVarDefault" }) do probe(n) end
end

-- [G20] Blizzard's Defaults button resets our settings, but does not light the
-- Apply button the way a click does -- so a reload-needing option can be reset
-- with nothing on screen saying the panel is not finished.
--
-- The likely reason is that Defaults writes through SetValueToDefault, which
-- may ignore the Apply commit flag and write straight away. v0.13.0 works
-- around it by lighting Apply itself and catching CommitSettings. This says
-- whether the workaround is needed at all, or whether there is a cleaner
-- switch that makes Defaults park like everything else.
local function sectionDefaultsAndApply()
	head("[G20] Does SetValueToDefault respect the Apply flag?")

	if type(Settings) ~= "table" or type(Settings.RegisterAddOnSetting) ~= "function" then
		add("   Settings API missing.")
		return
	end

	local category
	if type(Settings.RegisterVerticalLayoutCategory) == "function" then
		local ok, cat = pcall(Settings.RegisterVerticalLayoutCategory, "Unmarked Recon Probe")
		if ok then category = cat end
	end
	if not category then add("   could not make a test category."); return end

	UnmarkedReconProbeVars = UnmarkedReconProbeVars or {}
	local tbl = UnmarkedReconProbeVars
	tbl.URPD = true

	-- The signature settled by [G13c]: category, variable, variableKey,
	-- variableTbl, variableType, name, default.
	local ok, setting = pcall(Settings.RegisterAddOnSetting, category,
		"URPDefaults", "URPD", tbl, Settings.VarType.Boolean, "Probe defaults", true)
	if not ok or type(setting) ~= "table" then
		add("   could not register a test setting: " .. tostring(setting):sub(1, 90))
		return
	end

	local flags = Settings.CommitFlag
	pcall(setting.AddCommitFlag, setting, flags.Apply)
	pcall(setting.AddCommitFlag, setting, flags.Revertable)
	if type(setting.HasCommitFlag) == "function" then
		local okh, has = pcall(setting.HasCommitFlag, setting, flags.Apply)
		mark(okh and has, "test setting carries CommitFlag.Apply")
	end

	local function state(label)
		local mod, val, panelHas = "?", "?", "?"
		pcall(function() mod = tostring(setting:IsModified()) end)
		pcall(function() val = tostring(setting:GetValue()) end)
		if SettingsPanel and type(SettingsPanel.HasUnappliedSettings) == "function" then
			pcall(function() panelHas = tostring(SettingsPanel:HasUnappliedSettings()) end)
		end
		add(string.format("   %-26s IsModified=%-6s GetValue=%-6s backing=%-6s panel.HasUnapplied=%s",
			label, mod, val, tostring(tbl.URPD), panelHas))
	end

	state("at registration")

	-- A normal write: does the Apply flag park it?
	pcall(setting.SetValue, setting, false)
	state("after SetValue(false)")
	add("   ^ IsModified true here means the Apply flag DOES park a click.")
	add("")

	-- Put it back, then the question that matters.
	pcall(setting.SetValue, setting, true)
	if type(setting.ClearPendingValue) == "function" then pcall(setting.ClearPendingValue, setting) end
	tbl.URPD = false
	state("backing forced to false")

	if type(setting.SetValueToDefault) == "function" then
		pcall(setting.SetValueToDefault, setting)
		state("after SetValueToDefault()")
		add("   ^ IsModified FALSE with backing back to true means Defaults")
		add("     writes straight through and ignores the Apply flag, which is")
		add("     exactly the behaviour v0.13.0 works around.")
	else
		add("   setting:SetValueToDefault is missing.")
	end
	add("")

	-- Is there a switch that changes this?
	add("   Related knobs on the setting object:")
	for _, n in ipairs({
		"SetIgnoreApplyOverride", "SetCommitOrder", "GetCommitOrder",
		"LockPendingValue", "ClearPendingValue", "SetPendingValue",
		"Revert", "Commit", "NotifyUpdate", "ApplyValue",
	}) do probeMethod(setting, "   setting", n) end

	add("")
	add("   And on the panel, for the same question from the other side:")
	for _, n in ipairs({
		"HasUnappliedSettings", "CommitSettings", "SetApplyButtonEnabled",
		"GetCurrentCategory", "Commit", "Cancel", "Revert",
	}) do probeMethod(SettingsPanel, "   SettingsPanel", n) end
end

-- [G21] Annotating Blizzard's own controls.
--
-- v0.14.0 appends "Managed by Vanilla Questing" to the tooltip of the Blizzard
-- options this AddOn drives, by walking SettingsPanel.categoryLayouts and
-- editing data.tooltip -- the field [G17] found the header's tooltip in.
--
-- What is NOT known is whether Blizzard's own controls store a tooltip STRING
-- there or a function. A string can be appended to; a function cannot, not
-- without knowing what it is called with. v0.14.0 leaves functions alone
-- rather than guessing. This reports which it is for each one.
local function sectionBlizzardTooltips()
	head("[G21] Blizzard option tooltips -- string or function?")

	if type(SettingsPanel) ~= "table" then
		add("   SettingsPanel missing.")
		return
	end
	local layouts = rawget(SettingsPanel, "categoryLayouts")
	if type(layouts) ~= "table" then
		add("   SettingsPanel.categoryLayouts is " .. type(layouts) .. ".")
		return
	end

	-- The three this AddOn drives that Blizzard also shows a control for.
	local watch = {
		instantQuestText = "Instant Quest Text",
		autoQuestWatch   = "Automatic Quest Tracking",
		Outline          = "Outline Mode",
	}

	local found = 0
	for _, layout in pairs(layouts) do
		local inits = type(layout) == "table" and rawget(layout, "initializers")
		if type(inits) == "table" then
			for i = 1, #inits do
				local init = inits[i]
				if type(init) == "table" and type(init.GetSetting) == "function" then
					local ok, setting = pcall(init.GetSetting, init)
					local var, name
					if ok and type(setting) == "table" then
						pcall(function() var = setting:GetVariable() end)
						pcall(function() name = setting:GetName() end)
					end
					if var and watch[var] then
						found = found + 1
						add("")
						add("   " .. watch[var] .. "  (variable " .. var .. ", name \"" .. tostring(name) .. "\")")

						local data = rawget(init, "data")
						add("      initializer.data is " .. type(data))
						if type(data) == "table" then
							for k, v in pairs(data) do
								if type(k) == "string" then
									local shown = tostring(v)
									if type(v) == "string" and #shown > 70 then shown = shown:sub(1, 70) .. "..." end
									add("         data." .. k .. " = " .. shown .. "  [" .. type(v) .. "]")
								end
							end
						end

						if type(init.GetTooltip) == "function" then
							local okt, tip = pcall(init.GetTooltip, init)
							add("      GetTooltip() -> " .. (okt and type(tip) or "error"))
							if okt and type(tip) == "string" then
								add("         \"" .. tip:sub(1, 90) .. "\"")
							end
						end

						-- Did v0.14.0's annotation actually land?
						if type(data) == "table" and type(data.tooltip) == "string"
							and data.tooltip:find("Managed by", 1, true) then
							add("      >>> the AddOn's annotation IS present on this one.")
						else
							add("      >>> the AddOn's annotation is NOT present.")
						end
					end
				end
			end
		end
	end

	if found == 0 then
		add("   None of the three were found. Open Blizzard's options once, then")
		add("   run this again -- the layouts may not be built until then.")
	end
	add("")
	add("   (If any tooltip is a function, that is the case the AddOn skips.")
	add("    The fix would need to know what the function is called with, which")
	add("    the data dump above should show.)")
end

-- [G22] Two features shipped in v0.16.0 on names that have NOT been probed on
-- this client, which is a first for this project and worth correcting in the
-- same breath.
--
--   1. The questgiver portrait. v0.16.0 tries three frame names and two show
--      functions and uses whichever exists. This says which is real.
--   2. Quest progress in tooltips. v0.16.0 blanks the lines by text and
--      colour, which works but is surgery. If Blizzard registers a SETTING
--      for it, that is a switch instead -- and the settings registry is
--      exactly where instantQuestText was found after the console search
--      failed. So look there before settling for the surgery.
-- [G23] The Experimental heading needs a sentence under it, before the first
-- checkbox -- the shape Blizzard's own panels use where a heading needs
-- explaining. The AddOn currently draws that with
-- CreateSettingsListSectionHeaderInitializer, the one text element known to
-- work here, so it renders in the heading font.
--
-- The question is whether this client has a real description element. Nothing
-- assumed: this enumerates every CreateSettings*Initializer global that
-- actually exists, dumps what a header initializer is made of so its template
-- name can be read off it, and lists the layout's own methods. A negative
-- result is an answer -- it means the heading font is the best available and
-- the AddOn should stop looking.
local function sectionListDescription()
	head("[G23] A description element for the settings list?")

	-- Every global whose name looks like a settings-list initializer. Walking
	-- _G rather than testing a list of names I expect: that is the difference
	-- between "not present" and "I guessed wrong".
	local found = {}
	for k, v in pairs(_G) do
		if type(k) == "string" and type(v) == "function"
			and (k:find("^CreateSettings") or k:find("^SettingsList")) then
			found[#found + 1] = k
		end
	end
	table.sort(found)
	if #found == 0 then
		add("   no CreateSettings*/SettingsList* globals at all.")
	else
		add("   " .. #found .. " initializer-shaped globals:")
		for i = 1, #found do add("	 " .. found[i]) end
	end

	-- Mixins carry the template names. A description element would have one.
	local mixins = {}
	for k, v in pairs(_G) do
		if type(k) == "string" and type(v) == "table" and k:find("^SettingsList") then
			mixins[#mixins + 1] = k
		end
	end
	table.sort(mixins)
	add("   SettingsList* mixins: " .. (#mixins > 0 and table.concat(mixins, ", ") or "none"))

	-- What a header initializer is actually made of. Its frameTemplate names
	-- the XML template, which is the thing a description element would have a
	-- sibling of.
	if type(CreateSettingsListSectionHeaderInitializer) == "function" then
		local ok, init = pcall(CreateSettingsListSectionHeaderInitializer, "PROBE", "PROBETIP")
		if ok and type(init) == "table" then
			dumpTable(init, "   header initializer", 40)
			local data = rawget(init, "data")
			if type(data) == "table" then dumpTable(data, "   header .data", 40) end
			if type(init.GetTemplate) == "function" then
				local okt, tmpl = pcall(init.GetTemplate, init)
				add("   GetTemplate() -> " .. (okt and tostring(tmpl) or "error"))
			end
			-- Did the second argument land? This is also the check on whether
			-- passing a tooltip works at all on this client.
			add("   tooltip from arg 2: " ..
				tostring(type(data) == "table" and data.tooltip or init.tooltip))
		else
			add("   could not build a header initializer.")
		end
	end

	-- The layout object takes the initializers. If it has an AddAnchorPoint,
	-- AddDescription or similar, that is the answer outright.
	if type(Settings) == "table"
		and type(Settings.RegisterVerticalLayoutCategory) == "function" then
		local ok, _, layout = pcall(Settings.RegisterVerticalLayoutCategory, "PROBE G23")
		if ok and type(layout) == "table" then
			dumpMethods(layout, "   layout", { "add", "desc", "text", "header", "init" })
		else
			add("   could not build a layout to inspect.")
		end
	else
		add("   Settings.RegisterVerticalLayoutCategory missing.")
	end

	-- And the checkbox initializer, which is the other half of the question:
	-- an experimental option's NAME should be orange while its tooltip TITLE
	-- stays white, and both are currently drawn from the same string. If this
	-- initializer carries SetTooltipFunc, or keeps the label and the title in
	-- separate fields, that is the way to have both.
	if type(Settings) == "table"
		and type(Settings.RegisterVerticalLayoutCategory) == "function"
		and type(Settings.RegisterAddOnSetting) == "function"
		and type(Settings.CreateCheckbox) == "function" then
		local okc, cat2 = pcall(Settings.RegisterVerticalLayoutCategory, "PROBE G23b")
		if okc and type(cat2) == "table" then
			local tbl = {}
			local oks, setting = pcall(Settings.RegisterAddOnSetting, cat2,
				"UnmarkedReconProbe", "probeKey", tbl, "boolean", "PROBE NAME", false)
			if oks and type(setting) == "table" then
				local oki, init = pcall(Settings.CreateCheckbox, cat2, setting, "PROBE TIP")
				if oki and type(init) == "table" then
					dumpTable(init, "   checkbox initializer", 40)
					local d = rawget(init, "data")
					if type(d) == "table" then dumpTable(d, "   checkbox .data", 40) end
					dumpMethods(init, "   checkbox init",
						{ "tooltip", "name", "text", "label", "template" })
				else
					add("   could not build a checkbox initializer.")
				end
			else
				add("   could not register a probe setting.")
			end
		end
	end
end

-- [G24] One loose end from [G23]. Of the nine initializer globals this client
-- has, eight are controls or headings -- but one is a LABEL:
-- CreateSettingsAddOnDisabledLabelInitializer. Blizzard uses it to say an
-- AddOn is switched off, which means it renders a sentence rather than a
-- heading, which is exactly the shape the Experimental note needs.
--
-- Nothing assumed. This calls it with a string and with no argument at all,
-- dumps whatever comes back, and reads GetTemplate() off it -- the same route
-- that identified SettingsListSectionHeaderTemplate. If it takes arbitrary
-- text, the note stops being a tooltip. If it ignores what it is given, the
-- tooltip is the final answer and this line of enquiry closes.
local function sectionDescriptionLabel()
	head("[G24] CreateSettingsAddOnDisabledLabelInitializer as description text")

	local fn = _G.CreateSettingsAddOnDisabledLabelInitializer
	if type(fn) ~= "function" then
		add("   absent. [G23] listed it, so this is a contradiction worth knowing.")
		return
	end

	for _, args in ipairs({
		{ label = "with a string", value = "PROBE DESCRIPTION TEXT" },
		{ label = "with nothing",  value = nil },
	}) do
		local ok, init = pcall(fn, args.value)
		if not ok or type(init) ~= "table" then
			add("   " .. args.label .. ": could not build one -- " ..
				tostring(init):sub(1, 80))
		else
			add("   " .. args.label .. ":")
			if type(init.GetTemplate) == "function" then
				local okt, tmpl = pcall(init.GetTemplate, init)
				add("      GetTemplate() -> " .. (okt and tostring(tmpl) or "error"))
			end
			add("      frameTemplate -> " .. tostring(rawget(init, "frameTemplate")))
			local d = rawget(init, "data")
			if type(d) == "table" then
				dumpTable(d, "      .data", 20)
				-- Did the string survive into the data at all? If it did not,
				-- this element draws its own text and cannot be borrowed.
				local found = false
				for k, v in pairs(d) do
					if type(v) == "string" and v:find("PROBE DESCRIPTION", 1, true) then
						add("      the text landed in .data." .. tostring(k))
						found = true
					end
				end
				if args.value and not found then
					add("      the text did NOT land anywhere in .data.")
				end
			else
				add("      no .data table.")
			end
		end
	end

	-- And the generic route, for completeness: if an element initializer can
	-- be built against an arbitrary template, the header template's siblings
	-- become reachable by name.
	if type(Settings) == "table" and type(Settings.CreateElementInitializer) == "function" then
		add("   Settings.CreateElementInitializer exists.")
	else
		add("   Settings.CreateElementInitializer missing.")
	end
end

-- [G25] [G23] concluded there is no description element, and [G23] was asking
-- the wrong question. It enumerated CONSTRUCTOR globals -- nine of them, none
-- a description -- and took that for the whole answer. But Blizzard's own
-- options render plain paragraphs: "For more information see our Privacy
-- Policy" sits in one panel and "Try each colorblind filter to see which looks
-- the best to you." in another. Something draws those.
--
-- So stop enumerating constructors and go at it from the other end, which is
-- the direction that has worked every time on this client -- it is how
-- instantQuestText was found. Walk Blizzard's OWN registered layouts, find the
-- initializers carrying those exact strings, and read the template and the
-- data shape straight off them.
--
-- A hit names the template. Settings.CreateElementInitializer exists (v0.25
-- confirmed), so a template name is all that is needed to build one.
local function sectionDescriptionText()
	head("[G25] What draws Blizzard's own description paragraphs?")

	if type(SettingsPanel) ~= "table" or type(SettingsPanel.categoryLayouts) ~= "table" then
		add("   SettingsPanel.categoryLayouts missing; cannot walk Blizzard's layouts.")
		return
	end

	-- Fragments of the two strings seen in game. Matched case-insensitively on
	-- a lowered copy so wording drift does not hide a hit.
	--
	-- "colorblind filter" is dropped: v0.26 matched it against a SLIDER's
	-- tooltip -- "Adjusts the strength of the selected colorblind filter." --
	-- which is a control, not the paragraph being hunted. The remaining two
	-- are phrases that only appear in the description text itself.
	local NEEDLES = { "privacy policy", "see which looks the best" }

	local seen, hits = 0, 0
	for _, layout in pairs(SettingsPanel.categoryLayouts) do
		local inits = type(layout) == "table" and rawget(layout, "initializers")
		if type(inits) == "table" then
			for _, init in ipairs(inits) do
				seen = seen + 1
				local data = type(init) == "table" and rawget(init, "data")
				-- Any string field, not just `name`: the field this text
				-- lives in is exactly what is unknown.
				local text
				if type(data) == "table" then
					for k, v in pairs(data) do
						if type(v) == "string" and #v > 20 then
							local low = v:lower()
							for _, needle in ipairs(NEEDLES) do
								if low:find(needle, 1, true) then
									text = k .. " = " .. v:sub(1, 70)
								end
							end
						end
					end
				end
				if text then
					hits = hits + 1
					add("   HIT: " .. text)
					add("      frameTemplate -> " .. tostring(rawget(init, "frameTemplate")))
					if type(init.GetTemplate) == "function" then
						local okt, tmpl = pcall(init.GetTemplate, init)
						add("      GetTemplate()  -> " .. (okt and tostring(tmpl) or "error"))
					end
					if type(data) == "table" then dumpTable(data, "      .data", 20) end
					dumpMethods(init, "      initializer", { "text", "name", "tooltip", "template" })
				end
			end
		end
	end

	add("   walked " .. seen .. " initializers, " .. hits .. " hit(s).")
	if hits == 0 then
		add("   So the paragraphs are not in any initializer's data. They are")
		add("   either drawn by the template itself, or those panels are canvas")
		add("   layouts rather than vertical ones. The census below is the lead.")
	end

	-- The template census, ALWAYS. v0.26 gated this behind `hits == 0` and
	-- the run scored exactly one hit -- a slider's tooltip that happened to
	-- mention the colorblind filter, not the description text at all -- so the
	-- gate suppressed the only genuinely useful half of the section. A
	-- near-miss is not an answer, and a cheap dump should not be conditional
	-- on a match that might be a false positive.
	do
		local templates = {}
		for _, layout in pairs(SettingsPanel.categoryLayouts) do
			local inits = type(layout) == "table" and rawget(layout, "initializers")
			if type(inits) == "table" then
				for _, init in ipairs(inits) do
					local t = type(init) == "table" and rawget(init, "frameTemplate")
					if type(t) == "string" then templates[t] = (templates[t] or 0) + 1 end
				end
			end
		end
		local names = {}
		for k in pairs(templates) do names[#names + 1] = k end
		table.sort(names)
		add("   every frameTemplate Blizzard uses:")
		for i = 1, #names do
			add("      " .. names[i] .. "  x" .. templates[names[i]])
		end
	end
end

-- [G26] [G25] left an inference, not a result.
--
-- The census named all 22 frameTemplates Blizzard uses, and every one of them
-- reads as a control, a section header, or a purpose-built widget. So the
-- paragraphs seen in game are almost certainly baked into
-- ColorblindSelectorTemplate and the RTTS/STT templates rather than drawn by
-- anything reusable. "Almost certainly" is not an answer, and this project has
-- been wrong twice already by reasoning from a list instead of looking.
--
-- So: build a real category with a real layout, put one row in it per
-- candidate template through Settings.CreateElementInitializer, and hand each
-- a name and a tooltip. Then OPEN THE PANEL AND LOOK. A row that shows
-- "PROBE <template>" as a line of body text is the answer; a row that shows a
-- heading, a control, or nothing at all is a no.
--
-- This is the cheapest possible definitive test, and it costs one glance.
local function sectionDescriptionRender()
	head("[G26] Render each candidate template and look at it")

	if type(Settings) ~= "table"
		or type(Settings.RegisterVerticalLayoutCategory) ~= "function"
		or type(Settings.CreateElementInitializer) ~= "function"
		or type(Settings.RegisterAddOnCategory) ~= "function" then
		add("   Settings API incomplete; cannot build a panel to look at.")
		return
	end

	-- Every non-control template from the v0.27 census, plus one derived from
	-- the SettingsListElementMixin name that [G23] found. The derived one is
	-- marked as such: if it does not exist, that is worth knowing too.
	local CANDIDATES = {
		{ "SettingsListSectionHeaderTemplate",   "baseline -- known to render its name as a heading" },
		{ "SettingsLanguageRestartNeededTemplate", "a one-line notice; the closest thing to a paragraph" },
		{ "SettingsAdvancedQualitySectionTemplate", "a section wrapper" },
		{ "SettingsKeybindingSectionTemplate",   "a section wrapper" },
		{ "SettingsListElementTemplate",         "DERIVED from SettingsListElementMixin, may not exist" },
	}

	local ok, category, layout = pcall(Settings.RegisterVerticalLayoutCategory, "Unmarked Recon G26")
	if not ok or type(layout) ~= "table" or type(layout.AddInitializer) ~= "function" then
		add("   could not build a category to render into.")
		return
	end

	for i = 1, #CANDIDATES do
		local template, note = CANDIDATES[i][1], CANDIDATES[i][2]
		local oki, init = pcall(Settings.CreateElementInitializer, template, {
			name    = "PROBE " .. template,
			tooltip = "PROBE tooltip for " .. template,
		})
		if not oki or type(init) ~= "table" then
			add("   " .. template .. ": initializer REFUSED -- " ..
				tostring(init):sub(1, 60))
		else
			local oka = pcall(layout.AddInitializer, layout, init)
			add("   " .. template .. ": built" .. (oka and " and added" or ", ADD FAILED"))
			add("      (" .. note .. ")")
		end
	end

	pcall(Settings.RegisterAddOnCategory, category)
	add("")
	add("   NOW LOOK: Options -> AddOns -> \"Unmarked Recon G26\".")
	add("   Report, for each row, whether it shows PROBE <template> as body")
	add("   text, as a heading, as a control, or not at all.")
end

-- [G27] Does a template the ADDON ships render in Blizzard's settings list?
--
-- [G26] proved no Blizzard element takes a paragraph. But
-- Settings.CreateElementInitializer takes ANY template name, not just
-- Blizzard's -- so the remaining question is whether the settings list will
-- render a template that came out of an AddOn's own XML.
--
-- Templates.xml defines UnmarkedReconDescriptionTemplate: a plain Frame, a
-- FontString with a fixed width and no height so it WRAPS rather than
-- ellipsising, and an OnLoad that hangs an Init method on by hand. The
-- ellipsis is what ruled out SettingsLanguageRestartNeededTemplate, so a long
-- string is rendered here on purpose.
--
-- The row's text says which stage it reached, so a glance distinguishes three
-- outcomes rather than two:
--
--   the real text          -> Init was called with our data. Solved.
--   "Init CALLED, no data" -> the list renders it but the data does not arrive.
--   "OnLoad ran, Init NOT" -> the frame renders; the list never initialises it.
--   nothing at all         -> an AddOn template is not rendered. Closed.
local function sectionOwnTemplate()
	head("[G27] Does an AddOn's own template render in the settings list?")

	if type(Settings) ~= "table"
		or type(Settings.RegisterVerticalLayoutCategory) ~= "function"
		or type(Settings.CreateElementInitializer) ~= "function"
		or type(Settings.RegisterAddOnCategory) ~= "function" then
		add("   Settings API incomplete; cannot build a panel.")
		return
	end

	-- Does the template exist at all? A virtual XML frame is not a global, so
	-- this is the only way to ask before using it.
	local okTest, testFrame = pcall(CreateFrame, "Frame", nil, UIParent,
		"UnmarkedReconDescriptionTemplate")
	if not okTest or type(testFrame) ~= "table" then
		add("   Templates.xml did NOT load -- the template does not exist.")
		add("   (" .. tostring(testFrame):sub(1, 80) .. ")")
		return
	end
	add("   template exists; CreateFrame against it works.")
	add("   its OnLoad " .. (type(testFrame.Init) == "function" and "ran and hung Init on"
		or "did NOT hang Init on") .. " the frame.")
	pcall(testFrame.Hide, testFrame)

	local ok, category, layout = pcall(Settings.RegisterVerticalLayoutCategory, "Unmarked Recon G27")
	if not ok or type(layout) ~= "table" or type(layout.AddInitializer) ~= "function" then
		add("   could not build a category to render into.")
		return
	end

	-- A heading first, so the panel is identifiable even if every row below
	-- it draws nothing.
	if type(CreateSettingsListSectionHeaderInitializer) == "function" then
		local okh, h = pcall(CreateSettingsListSectionHeaderInitializer, "G27 -- own template")
		if okh and type(h) == "table" then pcall(layout.AddInitializer, layout, h) end
	end

	local ROWS = {
		{ "SHORT: own template works.", nil },
		{ "LONG: these are not turned on by the Vanilla preset, and this "
			.. "sentence is deliberately long enough that it must wrap onto a "
			.. "second line rather than being cut off with an ellipsis.", nil },
		{ "WITH EXTENT: same as the long one, but the initializer is handed "
			.. "an explicit extent in case the list needs telling how tall the "
			.. "row is before it will draw it.", 48 },
	}

	for i = 1, #ROWS do
		local text, extent = ROWS[i][1], ROWS[i][2]
		local data = { name = text }
		if extent then data.extent = extent end
		local oki, init = pcall(Settings.CreateElementInitializer,
			"UnmarkedReconDescriptionTemplate", data)
		if not oki or type(init) ~= "table" then
			add("   row " .. i .. ": initializer REFUSED -- " .. tostring(init):sub(1, 60))
		else
			if type(init.GetExtent) == "function" then
				local oke, e = pcall(init.GetExtent, init)
				add("   row " .. i .. ": GetExtent() -> " .. (oke and tostring(e) or "error"))
			end
			local oka = pcall(layout.AddInitializer, layout, init)
			add("   row " .. i .. ": built" .. (oka and " and added" or ", ADD FAILED"))
		end
	end

	pcall(Settings.RegisterAddOnCategory, category)
	add("")
	add("   NOW LOOK: Options -> AddOns -> \"Unmarked Recon G27\".")
	add("   Three rows under the heading. For each, which is it:")
	add("     the sentence itself, wrapped        -> SOLVED")
	add("     \"INIT CALLED, but no data.name\"    -> renders, data missing")
	add("     \"OnLoad ran, Init did NOT\"         -> renders, never initialised")
	add("     nothing at all                      -> AddOn templates do not render")

end

local function sectionQuestFrameAndTooltip()
	head("[G22] Questgiver portrait, and a switch for quest tooltips")

	add("   The portrait frame -- which name is real here:")
	for _, n in ipairs({
		"QuestNPCModel", "QuestModelScene", "QuestFrameNPCModel",
		"QuestFrame_ShowQuestPortrait", "QuestFrame_HideQuestPortrait",
		"QuestLogPopupDetailFrame_ShowQuestPortrait",
		"QuestFrameDetailPanel", "QuestLogPopupDetailFrame",
	}) do probe(n) end
	add("")
	listGlobals("Globals containing 'npcmodel'", "npcmodel", 30)
	add("")
	listGlobals("Globals containing 'questportrait'", "questportrait", 30)
	add("")
	listGlobals("Globals containing 'modelscene'", "modelscene", 30)
	add("")

	-- If one of them exists, describe it: what it is parented to decides
	-- whether hiding it disturbs the layout of the frame around it.
	local portrait
	for _, n in ipairs({ "QuestNPCModel", "QuestModelScene", "QuestFrameNPCModel" }) do
		if _G[n] then portrait = _G[n]; add("   Found: " .. n); break end
	end
	if portrait then
		local parent, shown, otype = "?", "?", "?"
		pcall(function() local p = portrait:GetParent() parent = (p and p:GetName()) or "<unnamed>" end)
		pcall(function() shown = portrait:IsShown() and "shown" or "hidden" end)
		pcall(function() otype = portrait:GetObjectType() end)
		add("      parent=" .. parent .. "  " .. shown .. "  [" .. otype .. "]")
		add("")
		dumpChildren(portrait, "   portrait")
		add("")
		dumpRegions(portrait, "   portrait")
	else
		add("   None of the three exist. Open a quest window and run this again --")
		add("   the frame may be created on first use.")
	end
	add("")

	-- Now the switch hunt. Same walk that found instantQuestText: Blizzard's
	-- registered settings, read off its own controls.
	add("   Every registered setting mentioning tooltip, quest or objective:")
	local seen, found = {}, 0

	local function inspect(setting, where)
		if type(setting) ~= "table" or seen[setting] then return end
		seen[setting] = true
		local name, var, vtype
		pcall(function() name = setting.GetName and setting:GetName() end)
		pcall(function() var = setting.GetVariable and setting:GetVariable() end)
		pcall(function() vtype = setting.GetVariableType and setting:GetVariableType() end)
		if tostring(var):find("VanillaQuesting", 1, true) then return end
		local hay = (tostring(name) .. " " .. tostring(var)):lower()
		if hay:find("tooltip") or hay:find("quest") or hay:find("objective") then
			found = found + 1
			local value = "?"
			pcall(function() value = tostring(setting:GetValue()) end)
			add(string.format("      %-40s variable=%-30s [%s] = %s",
				tostring(name), tostring(var), tostring(vtype), value))
		end
	end

	if type(SettingsPanel) == "table" then
		local layouts = rawget(SettingsPanel, "categoryLayouts")
		if type(layouts) == "table" then
			for _, layout in pairs(layouts) do
				local inits = type(layout) == "table" and rawget(layout, "initializers")
				if type(inits) == "table" then
					for i = 1, #inits do
						local init = inits[i]
						if type(init) == "table" and type(init.GetSetting) == "function" then
							local ok, st = pcall(init.GetSetting, init)
							if ok then inspect(st, "") end
						end
					end
				end
			end
		end
	end
	if found == 0 then
		add("      none. Open Blizzard's options once, then run this again.")
	end
	add("")

	-- And the colour-code globals the AddOn now takes its palette from, so a
	-- fallback that never fires can be confirmed as never firing.
	add("   Blizzard's own colour codes, which the palette prefers:")
	for _, n in ipairs({
		"NORMAL_FONT_COLOR_CODE", "HIGHLIGHT_FONT_COLOR_CODE",
		"GRAY_FONT_COLOR_CODE", "GREEN_FONT_COLOR_CODE",
		"RED_FONT_COLOR_CODE", "FONT_COLOR_CODE_CLOSE",
	}) do
		local v = _G[n]
		if v == nil then
			add("   --   " .. n)
		else
			-- Printed with the bar escaped, or the report shows a colour
			-- instead of the value being reported.
			add("   OK   " .. n .. " = " .. tostring(v):gsub("|", "||"))
		end
	end
	add("")

	-- The quest log API the tooltip matcher reads titles from.
	add("   Quest log API the tooltip matcher depends on:")
	for _, n in ipairs({
		"GetNumQuestLogEntries", "GetQuestLogTitle", "GetQuestLogIndexByID",
		"C_QuestLog",
	}) do probe(n) end
end

local function collect()
	wipe(lines)

	local version, build, _, tocnum = GetBuildInfo()
	add("Unmarked Recon v" .. RECON_VERSION .. " - " .. date("%Y-%m-%d %H:%M"))
	add("Client " .. tostring(version) .. " build " .. tostring(build) .. ", interface number " .. tostring(tocnum))

	-- ---- v0.2 sections, kept so each run is a self-contained record ----
	if ACTIVE.baseline then

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
	end

	-- ---- v0.3 gap sections ----

	if ACTIVE.g1  then sectionMinimapSurface()  end
	if ACTIVE.g2  then sectionTracking()        end
	if ACTIVE.g3  then sectionDataProviders()   end
	if ACTIVE.g4  then sectionSettings()        end
	if ACTIVE.g5  then sectionCVarDetail()      end
	if ACTIVE.g6  then sectionCVarDiscovery()   end
	if ACTIVE.g6  then sectionTrackingDetail()  end
	if ACTIVE.g7  then sectionMapClutter()      end
	if ACTIVE.g8  then sectionSettingsRegistry() end
	if ACTIVE.g9  then sectionBlips()           end
	if ACTIVE.g10 then sectionBlipAtlas()       end
	if ACTIVE.g11 then sectionOutline()         end
	if ACTIVE.g12 then sectionQuestTooltip()    end
	if ACTIVE.g13 then sectionSelector()        end
	if ACTIVE.g13 then sectionSettingSignature() end

	if ACTIVE.g13c then sectionSettingReadback() end
	if ACTIVE.g14  then sectionTracker()         end
	if ACTIVE.g15  then sectionTrackerInternals() end
	if ACTIVE.g16  then sectionNativePanel()     end
	if ACTIVE.g17  then sectionHeaderTooltip()   end
	if ACTIVE.g18  then sectionBagQuestBorder()  end
	if ACTIVE.g19  then sectionInstantQuestText() end
	if ACTIVE.g20  then sectionDefaultsAndApply() end
	if ACTIVE.g21  then sectionBlizzardTooltips() end
	if ACTIVE.g22  then sectionQuestFrameAndTooltip() end
	if ACTIVE.g23  then sectionListDescription()   end
	if ACTIVE.g24  then sectionDescriptionLabel()  end
	if ACTIVE.g25  then sectionDescriptionText()   end
	if ACTIVE.g26  then sectionDescriptionRender() end
	if ACTIVE.g27  then sectionOwnTemplate()      end

	-- Any full method dumps collected via "/unrecon methods <global>" get
	-- folded in here so they travel inside the readable report rather than
	-- sitting in a separate SavedVariables key that is easy to miss.
	if UnmarkedReconDB.methodDumps and next(UnmarkedReconDB.methodDumps) then
		local names = {}
		for k in pairs(UnmarkedReconDB.methodDumps) do names[#names + 1] = k end
		table.sort(names)
		for i = 1, #names do
			head("Full method dump: " .. names[i])
			for line in tostring(UnmarkedReconDB.methodDumps[names[i]]):gmatch("[^\n]+") do
				add("   " .. names[i] .. ":" .. line)
			end
		end
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
-- Blip atlas viewer (G10)
---------------------------------------------------------------------

local gridFrame

-- v0.9 drew each cell into a fixed square, which stretched them and made the
-- icons unreadable. Draw the WHOLE sheet instead and label each POI index in
-- place on top of it, positioned from the same UV coords. That needs no
-- assumption about the texture's real pixel size and cannot distort anything.
local function showBlipGrid(w, h)
	-- Rebuild on request so the display aspect can be changed until the art
	-- looks natural; labels stay correct at any size because they are placed
	-- from UV fractions rather than pixels.
	if gridFrame then gridFrame:Hide() gridFrame = nil end

	local SHEET_W = tonumber(w) or 512
	local SHEET_H = tonumber(h) or 1024

	local f = CreateFrame("Frame", "UnmarkedReconAtlas", UIParent)
	f:SetSize(math.min(SHEET_W, 900) + 60, 700)
	f:SetPoint("CENTER")
	f:SetFrameStrata("DIALOG")
	f:EnableMouse(true)
	f:SetMovable(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)

	local bg = f:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0, 0, 0, 0.95)

	local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOP", 0, -8)
	title:SetText("Blip atlas " .. SHEET_W .. "x" .. SHEET_H .. "  -  each red box is one index")
	local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	hint:SetPoint("TOP", 0, -24)
	hint:SetText("Wrong shape? Try /unrecon atlas 512 512  or  /unrecon atlas 256 512")

	local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -4, -4)

	local scroll = CreateFrame("ScrollFrame", "UnmarkedReconAtlasScroll", f, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 14, -44)
	scroll:SetPoint("BOTTOMRIGHT", -34, 14)

	local canvas = CreateFrame("Frame", nil, scroll)
	canvas:SetSize(SHEET_W, SHEET_H)
	scroll:SetScrollChild(canvas)

	local sheet = canvas:CreateTexture(nil, "ARTWORK")
	sheet:SetAllPoints()
	sheet:SetTexture("Interface\\MINIMAP\\ObjectIconsAtlas")

	local getCoords = C_Minimap and C_Minimap.GetPOITextureCoords
	if type(getCoords) ~= "function" then
		local err = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		err:SetPoint("CENTER")
		err:SetText("C_Minimap.GetPOITextureCoords missing")
		gridFrame = f
		return
	end

	-- v1.0 labelled cell centres, but with most cells empty there was nothing
	-- for a number to visually attach to. Outline each cell instead: the box
	-- IS the index, so the mapping is unambiguous however the sheet is scaled.
	local labelled = 0
	for i = 1, 400 do
		local ok, l, r, t, b = pcall(getCoords, i)
		if not ok or type(l) ~= "number" then break end

		local x, y = l * SHEET_W, t * SHEET_H
		local cw, ch = (r - l) * SHEET_W, (b - t) * SHEET_H

		local top = canvas:CreateTexture(nil, "OVERLAY")
		top:SetColorTexture(1, 0, 0, 0.45)
		top:SetSize(cw, 1)
		top:SetPoint("TOPLEFT", canvas, "TOPLEFT", x, -y)

		local left = canvas:CreateTexture(nil, "OVERLAY")
		left:SetColorTexture(1, 0, 0, 0.45)
		left:SetSize(1, ch)
		left:SetPoint("TOPLEFT", canvas, "TOPLEFT", x, -y)

		local num = canvas:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		num:SetPoint("CENTER", canvas, "TOPLEFT", x + cw / 2, -(y + ch / 2))
		num:SetText(tostring(i))
		num:SetTextColor(1, 0.25, 0.25)
		labelled = labelled + 1
	end

	local foot = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	foot:SetPoint("BOTTOM", 0, 2)
	foot:SetText(labelled .. " cells outlined. The number sits inside its own box.")

	gridFrame = f
end

---------------------------------------------------------------------
-- Single atlas cell (G10)
---------------------------------------------------------------------

local cellFrame

-- The whole-sheet view's red boxes did not line up with the art, so the UV
-- coords and this texture disagree about the grid. Rather than keep arguing
-- with a screenshot, render ONE index on its own, big, at three different
-- aspects. Whichever looks like a real icon tells us the true cell shape --
-- and if none do, the coords simply do not index this sheet.
local function showCell(index)
	index = tonumber(index)
	if not index then
		DEFAULT_CHAT_FRAME:AddMessage("|cffff5555[Recon]|r usage: /unrecon cell 124")
		return
	end
	local getCoords = C_Minimap and C_Minimap.GetPOITextureCoords
	if type(getCoords) ~= "function" then
		DEFAULT_CHAT_FRAME:AddMessage("|cffff5555[Recon]|r GetPOITextureCoords missing.")
		return
	end
	local ok, l, r, t, b = pcall(getCoords, index)
	if not ok or type(l) ~= "number" then
		DEFAULT_CHAT_FRAME:AddMessage("|cffff5555[Recon]|r no coords for index " .. index)
		return
	end

	if cellFrame then cellFrame:Hide() cellFrame = nil end

	local f = CreateFrame("Frame", "UnmarkedReconCell", UIParent)
	f:SetSize(420, 220)
	f:SetPoint("CENTER")
	f:SetFrameStrata("DIALOG")
	f:EnableMouse(true)
	f:SetMovable(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)

	local bg = f:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0, 0, 0, 0.95)

	local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOP", 0, -8)
	title:SetText("Index " .. index .. " drawn at three aspects")

	local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -4, -4)

	local shapes = {
		{ w = 128, h = 64,  label = "2:1 wide" },
		{ w = 96,  h = 96,  label = "square" },
		{ w = 64,  h = 128, label = "1:2 tall" },
	}
	local x = 30
	for i = 1, #shapes do
		local sh = shapes[i]
		local tex = f:CreateTexture(nil, "ARTWORK")
		tex:SetSize(sh.w, sh.h)
		tex:SetPoint("TOPLEFT", x, -50)
		tex:SetTexture("Interface\\MINIMAP\\ObjectIconsAtlas")
		pcall(tex.SetTexCoord, tex, l, r, t, b)

		local cap = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		cap:SetPoint("TOP", tex, "BOTTOM", 0, -4)
		cap:SetText(sh.label)
		x = x + sh.w + 24
	end

	local coords = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	coords:SetPoint("BOTTOM", 0, 8)
	coords:SetText(string.format("uv %.5f %.5f %.5f %.5f", l, r, t, b))

	cellFrame = f
	DEFAULT_CHAT_FRAME:AddMessage("|cff66ccff[Recon]|r showing index " .. index ..
		". Try neighbours too: /unrecon cell " .. (index + 1))
end

---------------------------------------------------------------------
-- Tooltip capture (G12)
---------------------------------------------------------------------

-- The quest lines are not at a fixed line number, so a matcher has to key off
-- text and colour instead. This snapshots whatever GameTooltip is showing so
-- those can be read exactly rather than guessed.
local tipWatcher

local function captureTooltip()
	if not (GameTooltip and GameTooltip.IsShown and GameTooltip:IsShown()) then return end
	local n = 0
	pcall(function() n = GameTooltip:NumLines() or 0 end)
	if n == 0 then return end

	local snap = {}
	for i = 1, n do
		local fs = _G["GameTooltipTextLeft" .. i]
		if fs then
			local text, cr, cg, cb = nil, nil, nil, nil
            pcall(function() text = fs:GetText() end)
			pcall(function() cr, cg, cb = fs:GetTextColor() end)
			snap[#snap + 1] = string.format("%2d  [%s,%s,%s]  %s", i,
				cr and string.format("%.2f", cr) or "?",
				cg and string.format("%.2f", cg) or "?",
				cb and string.format("%.2f", cb) or "?",
				tostring(text))
		end
	end
	UnmarkedReconDB.tooltip = table.concat(snap, "\n")
	UnmarkedReconDB.tooltipAt = date("%Y-%m-%d %H:%M:%S")
end

local function toggleTipWatch()
	if tipWatcher then
		tipWatcher:SetScript("OnUpdate", nil)
		tipWatcher = nil
		DEFAULT_CHAT_FRAME:AddMessage("|cff66ccff[Recon]|r tooltip watch OFF.")
		return
	end
	tipWatcher = CreateFrame("Frame")
	local elapsed = 0
	tipWatcher:SetScript("OnUpdate", function(_, dt)
		elapsed = elapsed + (dt or 0)
		if elapsed < 0.1 then return end
		elapsed = 0
		captureTooltip()
	end)
	DEFAULT_CHAT_FRAME:AddMessage("|cff66ccff[Recon]|r tooltip watch ON. Mouse over a quest NPC or object,")
	DEFAULT_CHAT_FRAME:AddMessage("|cff66ccff[Recon]|r then move away and type |cffffd100/unrecon tipdump|r.")
end

---------------------------------------------------------------------
-- CVar effect test (G5)---------------------------------------------------------------------
-- CVar effect test (G5)
---------------------------------------------------------------------

-- Whitelisted so a typo can't wander off into unrelated console variables.
local SETTABLE = {
	questpoi = "questPOI",
	questhelper = "questHelper",
	autoquestwatch = "autoQuestWatch",
	trackquestsorting = "trackQuestSorting",
	showbosses = "showBosses",
	digsites = "digSites",
	outline = "Outline",
	graphicsoutlinemode = "graphicsOutlineMode",
	particledensity = "particleDensity",
	ffxglow = "ffxGlow",
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
	if not okOld or old == nil then
		DEFAULT_CHAT_FRAME:AddMessage("|cffff5555[Recon]|r " .. real .. " does not exist on this client.")
		return
	end
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
	-- Rebuild the report now so the dump is inside it; otherwise the user has
	-- to remember to re-run /unrecon before reloading.
	UnmarkedReconDB.report = collect()
	UnmarkedReconDB.generated = date("%Y-%m-%d %H:%M:%S")
	DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Folded into the report. Type /reload now to write it to disk.|r")
end

SLASH_UNRECON1 = "/unrecon"
SlashCmdList["UNRECON"] = function(msg)
	msg = msg or ""
	local cmd, a, b = msg:lower():match("^%s*(%a*)%s*(%S*)%s*(%S*)")
	-- Escape hatch for a CVar the G6 dump turned up that is not whitelisted.
	-- Echoes the old value and the exact command to put it back.
	if cmd == "trycvar" then
		local _, name, value = msg:match("^%s*(%a*)%s+(%S+)%s+(%S+)")
		if not name or not value then
			DEFAULT_CHAT_FRAME:AddMessage("|cffff5555[Recon]|r usage: /unrecon trycvar <name> <value>")
			return
		end
		local okOld, old = pcall(GetCVar, name)
		if not okOld or old == nil then
			DEFAULT_CHAT_FRAME:AddMessage("|cffff5555[Recon]|r no such CVar: " .. name)
			return
		end
		pcall(SetCVar, name, value)
		local _, new = pcall(GetCVar, name)
		DEFAULT_CHAT_FRAME:AddMessage(string.format(
			"|cff66ccff[Recon]|r %s: %s -> %s   restore with: /unrecon trycvar %s %s",
			name, tostring(old), tostring(new), name, tostring(old)))
		return
	end

	if cmd == "blip" then
		local _, value = msg:match("^%s*(%a*)%s+(%S+)")
		if not value then
			DEFAULT_CHAT_FRAME:AddMessage("|cffff5555[Recon]|r usage: /unrecon blip <fileID or texture path>")
			return
		end
		if not (Minimap and type(Minimap.SetBlipTexture) == "function") then
			DEFAULT_CHAT_FRAME:AddMessage("|cffff5555[Recon]|r Minimap:SetBlipTexture missing.")
			return
		end
		local asNumber = tonumber(value)
		local ok, err = pcall(Minimap.SetBlipTexture, Minimap, asNumber or value)
		if not ok then
			DEFAULT_CHAT_FRAME:AddMessage("|cffff5555[Recon]|r SetBlipTexture failed: " .. tostring(err))
			return
		end
		pcall(Minimap.UpdateBlips, Minimap)
		DEFAULT_CHAT_FRAME:AddMessage("|cff66ccff[Recon]|r blip texture set to " .. tostring(value) ..
			". There is no getter, so |cffffd100/reload|r to put it back.")
		return
	end

	if cmd == "blipreset" then
		-- Minimap:SetToDefaults() removed the whole minimap frame when tried in
		-- game. It is deliberately NOT called here. Restoring means naming the
		-- Blizzard sheet explicitly, since there is no getter.
		if not (Minimap and type(Minimap.SetBlipTexture) == "function") then
			DEFAULT_CHAT_FRAME:AddMessage("|cffff5555[Recon]|r Minimap:SetBlipTexture missing.")
			return
		end
		local path = msg:match("^%s*%a+%s+(%S+)") or "Interface\\MINIMAP\\ObjectIconsAtlas"
		local ok, err = pcall(Minimap.SetBlipTexture, Minimap, path)
		pcall(Minimap.UpdateBlips, Minimap)
		DEFAULT_CHAT_FRAME:AddMessage("|cff66ccff[Recon]|r set blip texture to " .. path ..
			": " .. tostring(ok) .. (ok and "" or (" " .. tostring(err))))
		DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Look at the minimap. Did the real icons come back?|r")
		return
	end

	if cmd == "blipgrid" or cmd == "atlas" then
		local w, h = msg:match("^%s*%a+%s+(%d+)%s+(%d+)")
		showBlipGrid(w, h)
		return
	end

	if cmd == "cell" then
		showCell(msg:match("^%s*%a+%s+(%-?%d+)"))
		return
	end

	if cmd == "tipwatch" then
		toggleTipWatch()
		return
	end

	if cmd == "tipdump" then
		local t = UnmarkedReconDB.tooltip
		if not t then
			DEFAULT_CHAT_FRAME:AddMessage("|cffff5555[Recon]|r nothing captured. Run /unrecon tipwatch first.")
			return
		end
		DEFAULT_CHAT_FRAME:AddMessage("|cff66ccff[Recon]|r last tooltip (" .. tostring(UnmarkedReconDB.tooltipAt) .. "):")
		for line in t:gmatch("[^\n]+") do DEFAULT_CHAT_FRAME:AddMessage("   " .. line) end
		DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Saved to SavedVariables too - /reload writes it out.|r")
		return
	end

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
