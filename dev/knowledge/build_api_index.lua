-- Builds an offline index of the client's OWN generated API documentation.
--
-- Blizzard ships Interface/AddOns/Blizzard_APIDocumentationGenerated in the UI
-- source drop: one Lua file per system, each a plain table describing that
-- system's namespace, functions, arguments, returns and events. It is generated
-- from the build, so for a given drop it is exact rather than remembered.
--
-- This does not parse the files with patterns. It LOADS them, with a stub
-- standing in for APIDocumentation, and reads the tables the client itself
-- would have read. A regex over Lua is a guess; running the Lua is not.
--
-- Usage:
--   lua5.1 build_api_index.lua <path to Blizzard_APIDocumentationGenerated> <outdir>
--
-- Writes:
--   api-index.txt      every system, every function and event name. Small
--                      enough to keep in the repository, which is the point:
--                      "does this exist on 5.5.4" must be answerable with no
--                      network and no client.
--   api-signatures.txt full argument and return signatures, but only for the
--                      systems this AddOn actually touches (see SYSTEMS).
--                      Everything else -- pet battles, garrisons, transmog --
--                      is noise this project will never read.

local docsDir, outDir = ...
if not docsDir or not outDir then
	io.stderr:write("usage: lua5.1 build_api_index.lua <docs dir> <out dir>\n")
	os.exit(2)
end

-- The systems worth keeping full signatures for. Names are matched against
-- both the Namespace ("C_Minimap") and the system Name ("Minimap"), so a
-- system that has no namespace still lands.
local SYSTEMS = {
	"C_Minimap", "Minimap",
	"C_Map", "Map",
	"C_QuestLog", "QuestLog", "C_QuestOffer", "C_QuestSession",
	"C_TaskQuest", "C_QuestItemUse", "C_QuestInfoSystem",
	"C_SuperTrack", "C_ContentTracking",
	"C_TooltipInfo", "TooltipInfo", "C_TooltipComparison",
	"C_CVar", "CVar", "C_Console", "Console",
	"C_Container", "Container",
	"C_AreaPoiInfo", "AreaPoiInfo",
	"C_VignetteInfo", "VignetteInfo",
	"C_Item", "C_Spell",
	"C_AddOns", "AddOns",
	"C_Timer",
	"C_UIWidgetManager",
	"C_EventUtils",
}
local keep = {}
for _, n in ipairs(SYSTEMS) do keep[n] = true end

---------------------------------------------------------------------
-- A sandbox permissive enough to load documentation written for the
-- live client. The files reference globals (Enum, Constants) that do
-- not exist out here; anything unknown resolves to a stand-in whose
-- only job is to not raise.
---------------------------------------------------------------------

local collected = {}

-- Arithmetic is not decoration here: three of the documentation files do
-- sums on constants (MAX_STABLE_SLOTS + 1 and friends). A stand-in that
-- only answers __index loads 530 files and dies on those three.
local stub
stub = setmetatable({}, {
	__index = function(t, k) return t end,
	__call = function() return stub end,
	__tostring = function() return "<stub>" end,
	__len = function() return 0 end,
	__concat = function() return "" end,
	__add = function() return 0 end,
	__sub = function() return 0 end,
	__mul = function() return 0 end,
	__div = function() return 0 end,
	__mod = function() return 0 end,
	__pow = function() return 0 end,
	__unm = function() return 0 end,
	__eq = function() return false end,
	__lt = function() return false end,
	__le = function() return false end,
})

local env = {
	APIDocumentation = {
		AddDocumentationTable = function(_, tbl) collected[#collected + 1] = tbl end,
	},
	string = string, table = table, math = math, type = type,
	pairs = pairs, ipairs = ipairs, tostring = tostring, tonumber = tonumber,
	select = select, print = function() end,
}
setmetatable(env, { __index = function() return stub end })

---------------------------------------------------------------------
-- Load every documentation file
---------------------------------------------------------------------

local function listLuaFiles(dir)
	local names = {}
	local p = io.popen('ls -1 "' .. dir .. '" 2>/dev/null')
	if not p then return names end
	for line in p:lines() do
		if line:match("%.lua$") then names[#names + 1] = line end
	end
	p:close()
	table.sort(names)
	return names
end

local files = listLuaFiles(docsDir)
if #files == 0 then
	io.stderr:write("no .lua files in " .. docsDir .. "\n")
	os.exit(1)
end

local failed = {}
for _, name in ipairs(files) do
	local chunk, err = loadfile(docsDir .. "/" .. name)
	if not chunk then
		failed[#failed + 1] = name .. ": " .. tostring(err)
	else
		setfenv(chunk, env)
		local ok, rerr = pcall(chunk)
		if not ok then failed[#failed + 1] = name .. ": " .. tostring(rerr) end
	end
end

---------------------------------------------------------------------
-- Render
---------------------------------------------------------------------

local function fieldList(list)
	if type(list) ~= "table" or #list == 0 then return "" end
	local parts = {}
	for _, f in ipairs(list) do
		local s = tostring(f.Name or "?")
		if f.Type then s = s .. ":" .. tostring(f.Type) end
		if f.Nilable then s = s .. "?" end
		if f.Default ~= nil then s = s .. "=" .. tostring(f.Default) end
		parts[#parts + 1] = s
	end
	return table.concat(parts, ", ")
end

local function systemKey(sys)
	return sys.Namespace or sys.Name or "?"
end

table.sort(collected, function(a, b) return systemKey(a) < systemKey(b) end)

local index, signatures = {}, {}
local nFun, nEv, nSys = 0, 0, 0

for _, sys in ipairs(collected) do
	local key = systemKey(sys)
	local label = key
	if sys.Namespace and sys.Name and sys.Namespace ~= sys.Name then
		label = sys.Namespace .. " (" .. sys.Name .. ")"
	end
	nSys = nSys + 1

	local funNames, evNames = {}, {}
	for _, f in ipairs(sys.Functions or {}) do
		if f.Name then funNames[#funNames + 1] = f.Name end
	end
	for _, e in ipairs(sys.Events or {}) do
		evNames[#evNames + 1] = e.LiteralName or e.Name or "?"
	end
	table.sort(funNames); table.sort(evNames)
	nFun = nFun + #funNames
	nEv = nEv + #evNames

	index[#index + 1] = "## " .. label
	if sys.Environment and sys.Environment ~= "All" then
		index[#index + 1] = "   environment: " .. tostring(sys.Environment)
	end
	if #funNames > 0 then
		index[#index + 1] = "   functions: " .. table.concat(funNames, ", ")
	end
	if #evNames > 0 then
		index[#index + 1] = "   events: " .. table.concat(evNames, ", ")
	end

	if keep[key] or keep[sys.Name or ""] then
		signatures[#signatures + 1] = "## " .. label
		if sys.Environment then
			signatures[#signatures + 1] = "   environment: " .. tostring(sys.Environment)
		end
		for _, f in ipairs(sys.Functions or {}) do
			local prefix = sys.Namespace and (sys.Namespace .. ".") or ""
			local line = "   " .. prefix .. tostring(f.Name or "?") ..
				"(" .. fieldList(f.Arguments) .. ")"
			local rets = fieldList(f.Returns)
			if rets ~= "" then line = line .. " -> " .. rets end
			signatures[#signatures + 1] = line
		end
		for _, e in ipairs(sys.Events or {}) do
			signatures[#signatures + 1] = "   event " .. tostring(e.LiteralName or e.Name) ..
				"(" .. fieldList(e.Payload) .. ")"
		end
		-- A return type you cannot resolve is half an answer. GetTrackingInfo
		-- returning "MinimapScriptTrackingInfo?" says nothing on its own, so
		-- the structures and enums each kept system declares come too.
		for _, t in ipairs(sys.Tables or {}) do
			local kind = tostring(t.Type or "Table"):lower()
			if t.Fields then
				signatures[#signatures + 1] = "   " .. kind .. " " .. tostring(t.Name) ..
					" { " .. fieldList(t.Fields) .. " }"
			elseif t.Values then
				local vals = {}
				for _, v in ipairs(t.Values) do
					vals[#vals + 1] = tostring(v.Name) .. "=" .. tostring(v.EnumValue)
				end
				signatures[#signatures + 1] = "   " .. kind .. " " .. tostring(t.Name) ..
					" { " .. table.concat(vals, ", ") .. " }"
			else
				signatures[#signatures + 1] = "   " .. kind .. " " .. tostring(t.Name)
			end
		end
		signatures[#signatures + 1] = ""
	end
end

local function write(path, header, lines)
	local fh = assert(io.open(path, "w"))
	fh:write(header)
	fh:write(table.concat(lines, "\n"))
	fh:write("\n")
	fh:close()
end

local stamp = "-- Generated by dev/knowledge/build_api_index.lua. Do not hand-edit.\n" ..
	"-- Source: Blizzard_APIDocumentationGenerated, from the WoW UI source drop.\n" ..
	"-- Systems: " .. nSys .. "  functions: " .. nFun .. "  events: " .. nEv .. "\n\n"

write(outDir .. "/api-index.txt", stamp, index)
write(outDir .. "/api-signatures.txt", stamp, signatures)

io.write("systems " .. nSys .. ", functions " .. nFun .. ", events " .. nEv .. "\n")
if #failed > 0 then
	io.write("failed to load " .. #failed .. " file(s):\n")
	for _, f in ipairs(failed) do io.write("  " .. f .. "\n") end
	os.exit(1)
end
