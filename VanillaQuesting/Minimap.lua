-- Vanilla Questing -- Minimap
--
-- Tier 1 minimap. One lever does both jobs: the "Track Quest POIs" entry in
-- the minimap tracking list controls the numbered quest pins AND the blue
-- quest objective area. Confirmed in game; see SPEC.md conclusions G1/G2.
--
-- The Minimap:SetQuestBlob* widget methods the original spec assumed do not
-- exist on this client -- the full 205-method dump has no blob methods at
-- all. The blob is engine-drawn and switched through tracking instead.

local ADDON_NAME, ns = ...

local C = ns.color

local M = ns:RegisterModule("hideMinimapQuestHelper", {})
M.onText = "Minimap quest markers and the blue quest areas removed."
M.offText = "Minimap quest helper restored."
M.group = "Map and minimap"
M.title = "Hide Minimap Quest Helper"
M.order = 20
M.desc = "Keeps the " .. C.title .. "Track Quest POIs" .. C.close .. " tracking switched off, removing both the quest markers and the blue objective areas from the minimap."

-- One name: module key, saved-settings key and typed handle are all the same.
ns:RegisterDefaults({
	hideMinimapQuestHelper = true,
})

local applying = false
local refused = false

-- Enforcement only explains itself once the AddOn has settled. The very
-- first turn-off at login is ours and needs no announcement; a later one
-- means the player just clicked the entry and deserves to know why it
-- bounced back.
local settled = false
local tooltipHooked = false
-- Far enough in the past that the first notice is never swallowed by the
-- throttle window, whatever GetTime() happens to return.
local lastNotice = -math.huge

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
		ns:Warn("mm:api", "C_Minimap tracking API missing; minimap markers are untouched.")
		return nil
	end

	local wanted = MINIMAP_TRACKING_QUEST_POIS
	if type(wanted) ~= "string" then
		ns:Warn("mm:name", "MINIMAP_TRACKING_QUEST_POIS missing; minimap markers are untouched.")
		return nil
	end

	local ok, count = pcall(C.GetNumTrackingTypes)
	if not ok or type(count) ~= "number" then
		ns:Warn("mm:count", "could not read the tracking list; minimap markers are untouched.")
		return nil
	end

	for i = 1, count do
		local gotInfo, info = pcall(C.GetTrackingInfo, i)
		if gotInfo and type(info) == "table" and info.name == wanted then
			return i, info
		end
	end

	ns:Warn("mm:notfound",
		"no '" .. wanted .. "' entry in the tracking list; minimap markers are untouched.")
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

-- TODO(Options): when the Tier 3 options panel ships, this line and the
-- tooltip below should point at the panel instead of a slash command.
local function notice()
	-- Throttled: a burst of tracking events must not turn into a wall of text.
	local now = (type(GetTime) == "function" and GetTime()) or 0
	if now - lastNotice < 10 then return end
	lastNotice = now
	-- Name the tracking entry explicitly so the line can be scanned at a
	-- glance, and say "automatically" so it reads as the AddOn acting rather
	-- than the click failing.
	ns:Print(C.highlight .. "Track Quest POIs" .. C.close ..
		" was disabled automatically. To allow it, use " ..
		C.highlight .. "/vq off hideMinimapQuestHelper" .. C.close .. ".")
end

local function enforce()
	if applying or refused then return end
	if not ns.db or not ns.db.settings[M.key] then return end

	local index, info = findEntry()
	if not index then return end
	if not info.active then return end   -- already off, nothing to do and no event to cause

	-- The player just turned it on themselves; say why it is about to bounce.
	if settled then notice() end

	if not setTracking(index, false) then
		refused = true
		ns:Warn("mm:set", "could not change quest POI tracking; minimap markers are untouched.")
		return
	end

	-- Verify rather than assume the call took effect.
	local _, after = findEntry()
	if after and after.active then
		refused = true
		ns:Warn("mm:refused",
			"quest POI tracking would not turn off; minimap markers are untouched.")
	end
end

-- Adding a line to the tracking button's tooltip is the polite way to
-- explain the behaviour: it is a script hook on an ordinary UI button, it
-- adds no quest data, and it touches none of Blizzard's menu logic, so it
-- stays clear of the taint risk in safety rule 2. If the button is not
-- where we expect, we simply do without it -- the chat notice below is the
-- guaranteed path.
local function attachTooltip()
	if tooltipHooked then return end
	local btn = MiniMapTrackingButton or MiniMapTracking
	if not btn or type(btn.HookScript) ~= "function" then
		ns:Warn("mm:tooltip", "tracking button not found; using chat notices instead of a tooltip.")
		return
	end

	local ok = pcall(function()
		btn:HookScript("OnEnter", function(self)
			if not ns.db or not ns.db.settings[M.key] then return end
			if not GameTooltip or type(GameTooltip.AddLine) ~= "function" then return end
			if GameTooltip.GetOwner and GameTooltip:GetOwner() ~= self then return end
			-- Blank spacer, then the AddOn name as its own header line so the
			-- block reads as ours rather than as part of Blizzard's tooltip.
			-- A tooltip header cannot be made larger: AddLine has no per-line
			-- font, and the big header font applies only to the tooltip's own
			-- first line. So separate the block by colour instead, using the
			-- AddOn's chat blue, which stands clear of Blizzard's white body
			-- text and yellow highlights.
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine(C.title .. "Track Quest POIs" .. C.close .. " " ..
				C.brand .. "is managed by " .. ns.title .. "." .. C.close)
			GameTooltip:Show()
		end)
	end)
	tooltipHooked = ok
end

function M:Enable()
	local index, info = findEntry()
	if not index then return end

	-- Remember the pre-AddOn state once, so Disable restores what the player
	-- actually had rather than assuming it was on.
	if ns.db.state.minimapMarkersTracking == nil then
		ns.db.state.minimapMarkersTracking = info.active and true or false
	end

	enforce()
	attachTooltip()
	settled = true
end

-- Switching this option OFF turns Track Quest POIs back ON.
--
-- Not "back to what the player had", which is what it used to do. Track Quest
-- POIs is on by default in the game, so a player who turns this option off is
-- asking for the minimap quest helper -- and handing them back an entry that
-- happened to be off when they installed the AddOn would look like the option
-- had failed.
--
-- This is the one place the AddOn restores a Blizzard DEFAULT rather than the
-- exact value it found. The remembered value is still kept, and is what a full
-- Disable() at logout or on unload would want if that ever becomes a thing.
function M:Disable()
	settled = false
	local index, info = findEntry()
	if not index then return end
	if not info.active then
		setTracking(index, true)
	end
end

function M:Status()
	local index, info = findEntry()
	if not index then return "tracking entry not found" end
	if refused then return "tracking entry #" .. index .. " (write refused)" end
	return "tracking entry #" .. index .. ", quest POIs " ..
		(info.active and (C.off .. "showing" .. C.close) or "hidden")
end

-- The tracking dropdown stays fully functional; we simply put it back. Flipping
-- "Track Quest POIs" on from Blizzard's menu fires this and it turns off again,
-- which makes the menu entry effectively inert while this module is on without
-- reaching into Blizzard's menu code and risking taint.
ns:RegisterEvent("MINIMAP_UPDATE_TRACKING", enforce)
