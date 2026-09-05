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

-- One source of truth: read it from the .toc rather than repeating it here.
-- v0.4 shipped announcing 0.4 in chat while the .toc still said 0.3.
local RECON_VERSION = (function()
	local getter = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
	if type(getter) ~= "function" then return "?" end
	local ok, v = pcall(getter, "UnmarkedRecon", "Version")
	return (ok and v) or "?"
end)()

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
	add("   2 and 3 also work. Never on by default, never part of /cq on.")
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
	sectionCVarDiscovery()
	sectionTrackingDetail()
	sectionMapClutter()
	sectionSettingsRegistry()
	sectionBlips()
	sectionBlipAtlas()
	sectionOutline()
	sectionQuestTooltip()

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
