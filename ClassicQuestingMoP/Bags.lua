-- Classic Questing (MoP) -- Bags
--
-- MoP puts a yellow highlight on quest items sitting in your bags. Classic did
-- not: a quest item looked like any other item, and knowing which was which
-- was part of reading the quest.
--
-- Probe v0.19 [G18] settled how to reach it. There is NO console variable --
-- every plausible name came back absent -- but every bag slot carries a
-- texture named ContainerFrame<N>Item<M>IconQuestTexture, 468 of them on this
-- client, and hiding it takes the highlight with it.
--
-- One coupling worth knowing: that single texture draws both the yellow border
-- on a quest item and the "!" on an item that STARTS a quest. Blizzard swaps
-- the texture on the same object rather than using two, so they cannot be
-- separated. Both go, which is the Classic result anyway.

local ADDON_NAME, ns = ...

local M = ns:RegisterModule("bagQuestHighlight", {})
M.title = "Hide quest item highlight in bags"
M.desc  = "Quest items in your bags stop being outlined in yellow, and items that start a quest lose their exclamation mark. Both are drawn by the same texture, and neither was in Classic: a quest item looked like any other item."
M.onText  = "bag quest item highlight hidden"
M.offText = "bag quest item highlight shown again"
M.group = "Bags"
M.order = 80

ns:RegisterDefaults({ bagQuestHighlight = true })

-- Bags redraw constantly, and each redraw puts the highlight back, so this
-- runs off a post-hook rather than once at login.
local hooked = false

-- The frame is passed in, so its own slots can be walked rather than sweeping
-- all 468 textures on every bag update.
local function scrub(frame)
	if not ns.db or not ns.db.settings.bagQuestHighlight then return end

	local name
	if type(frame) == "table" and type(frame.GetName) == "function" then
		local ok, n = pcall(frame.GetName, frame)
		name = ok and n or nil
	end
	if not name then return end

	-- 36 is the largest bag this client draws; stopping at the first missing
	-- slot would cut short on a frame whose buttons are not contiguous.
	for i = 1, 36 do
		local tex = _G[name .. "Item" .. i .. "IconQuestTexture"]
		if tex and type(tex.Hide) == "function" then
			pcall(tex.Hide, tex)
		end
	end
end

local function ensureHook()
	if hooked then return end
	if type(hooksecurefunc) ~= "function" or type(ContainerFrame_Update) ~= "function" then
		ns:Warn("bags:missing",
			"ContainerFrame_Update is not present on this client; skipping the bag quest highlight.")
		return
	end
	hooked = true
	hooksecurefunc("ContainerFrame_Update", scrub)
end

-- Every container frame currently on screen, so a change takes effect on bags
-- that are already open rather than waiting for the next redraw.
local function eachOpenContainer(fn)
	for i = 1, 13 do
		local f = _G["ContainerFrame" .. i]
		if f and type(f.IsShown) == "function" then
			local ok, shown = pcall(f.IsShown, f)
			if ok and shown then fn(f) end
		end
	end
end

function M:Enable()
	ensureHook()
	eachOpenContainer(scrub)
end

function M:Disable()
	-- Which slots SHOULD show a highlight is the game's business, not ours, so
	-- the restore is to let it redraw and decide.
	if type(ContainerFrame_Update) ~= "function" then return end
	eachOpenContainer(function(f) pcall(ContainerFrame_Update, f) end)
end

function M:Status()
	if type(ContainerFrame_Update) ~= "function" then return "ContainerFrame_Update missing" end
	local n = 0
	eachOpenContainer(function() n = n + 1 end)
	return n .. " bag frame(s) open"
end
