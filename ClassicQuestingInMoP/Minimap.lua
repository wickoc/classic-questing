-- Classic Questing in MoP -- Minimap
--
-- Tier 1 minimap. One lever does both jobs: the "Track Quest POIs" entry in
-- the minimap tracking list controls the numbered quest pins AND the blue
-- quest objective area. Confirmed in game; see SPEC.md conclusions G1/G2.
--
-- The Minimap:SetQuestBlob* widget methods the original spec assumed do not
-- exist on this client -- the full 205-method dump has no blob methods at
-- all. The blob is engine-drawn and switched through tracking instead.

local ADDON_NAME, ns = ...

local M = ns:RegisterModule("minimapMarkers", {})
M.setting = "minimapQuestPOI"

ns:RegisterDefaults({
	minimapQuestPOI = true,
})

local applying = false
local refused = false

local function api()
	local C = C_Minimap
	if type(C) ~= "table"
		or type(C.GetNumTrackingTypes) ~= "function"
		or type(C.GetTrackingInfo) ~= "function"
		or type(C.SetTracking) ~= "function" then
		return nil
	end
	return C
end

-- Resolve the entry by NAME, never by a hardcoded index.
--
-- The indices are not stable: they shift with class and profession. On the
-- recon character "Track Quest POIs" sat at 17, but index 1 was "Find Herbs",
-- which only exists because that character is a herbalist. Hardcoding 17
-- would appear to work there and silently toggle some unrelated tracking
-- type on the next character.
local function findEntry()
	local C = api()
	if not C then
		ns:Warn("mm:api", "C_Minimap tracking API missing; skipping minimap markers.")
		return nil
	end

	local wanted = MINIMAP_TRACKING_QUEST_POIS
	if type(wanted) ~= "string" then
		ns:Warn("mm:name", "MINIMAP_TRACKING_QUEST_POIS missing; skipping minimap markers.")
		return nil
	end

	local ok, count = pcall(C.GetNumTrackingTypes)
	if not ok or type(count) ~= "number" then
		ns:Warn("mm:count", "could not read the tracking list; skipping minimap markers.")
		return nil
	end

	for i = 1, count do
		local gotInfo, info = pcall(C.GetTrackingInfo, i)
		if gotInfo and type(info) == "table" and info.name == wanted then
			return i, info
		end
	end

	ns:Warn("mm:notfound",
		"no '" .. wanted .. "' entry in the tracking list; skipping minimap markers.")
	return nil
end

local function setTracking(index, enabled)
	local C = api()
	if not C then return false end
	applying = true
	local ok = pcall(C.SetTracking, index, enabled)
	applying = false
	return ok
end

local function enforce()
	if applying or refused then return end
	if not ns.db or not ns.db.settings[M.setting] then return end

	local index, info = findEntry()
	if not index then return end
	if not info.active then return end   -- already off, nothing to do and no event to cause

	if not setTracking(index, false) then
		refused = true
		ns:Warn("mm:set", "could not change quest POI tracking; skipping minimap markers.")
		return
	end

	-- Verify rather than assume the call took effect.
	local _, after = findEntry()
	if after and after.active then
		refused = true
		ns:Warn("mm:refused",
			"quest POI tracking would not turn off; skipping minimap markers.")
	end
end

function M:Enable()
	local index, info = findEntry()
	if not index then return end

	-- Remember the pre-addon state once, so Disable restores what the player
	-- actually had rather than assuming it was on.
	if ns.db.state.minimapQuestPOITracking == nil then
		ns.db.state.minimapQuestPOITracking = info.active and true or false
	end

	enforce()
end

function M:Disable()
	local original = ns.db and ns.db.state.minimapQuestPOITracking
	if original == nil then return end
	local index, info = findEntry()
	if not index then return end
	if info.active ~= original then
		setTracking(index, original)
	end
end

function M:Status()
	local index, info = findEntry()
	if not index then return "tracking entry not found" end
	if refused then return "tracking entry #" .. index .. " (write refused)" end
	return "tracking entry #" .. index .. ", quest POIs " ..
		(info.active and "|cffff5555showing|r" or "hidden")
end

-- The tracking dropdown stays fully functional; we simply put it back. Flipping
-- "Track Quest POIs" on from Blizzard's menu fires this and it turns off again,
-- which makes the menu entry effectively inert while this module is on without
-- reaching into Blizzard's menu code and risking taint.
ns:RegisterEvent("MINIMAP_UPDATE_TRACKING", enforce)
