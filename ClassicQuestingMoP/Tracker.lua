-- Classic Questing (MoP) -- Objective tracker
--
-- Tier 2. Classic HAS a tracker: you shift-click a quest in the log and it
-- appears. So nothing here hides it -- that would remove a Classic feature
-- rather than a MoP one. What Classic did not have is everything MoP bolted
-- onto the lines: clickable quest titles with a context menu behind them, and
-- a use button for quest items. Those are what this file removes.
--
-- Everything below is named in the v0.15 probe log ([G15]); nothing is
-- reached for on the strength of what a later client calls it. In particular
-- this client has WatchFrame, NOT ObjectiveTrackerFrame, and
-- WatchFrame:IsProtected() came back explicitly false -- so hooking and
-- hiding here is safe, in combat included.
--
-- One thing that looked like work turned out not to be: "no auto-sort by
-- distance" has nothing to remove. The only sort constants this client
-- defines are WATCHFRAME_SORT_MANUAL (0), _DIFFICULTY_HIGH (1) and
-- _DIFFICULTY_LOW (2). There is no proximity sort, and WATCHFRAME_SORT_TYPE
-- already reads 0.

local ADDON_NAME, ns = ...

-- Re-applied after every tracker rebuild rather than once at login: the
-- tracker recycles its buttons, so a line that is a quest title now may be
-- something else after the next update.
local hooked = false
local function ensureHook()
	if hooked then return end
	if type(hooksecurefunc) ~= "function" or type(WatchFrame_Update) ~= "function" then
		return
	end
	hooked = true
	hooksecurefunc("WatchFrame_Update", function()
		if not ns.db then return end
		for i = 1, #ns.modules do
			local m = ns.modules[i]
			if m.trackerPass and ns.db.settings[m.key] then
				pcall(m.trackerPass, m)
			end
		end
	end)
end

---------------------------------------------------------------------
-- Click-to-track
---------------------------------------------------------------------
--
-- WATCHFRAME_LINKBUTTONS holds one Button per tracked quest title, each with
-- an OnClick -- left-click opens the map to the quest, right-click opens a
-- context menu with Abandon and Share on it. Classic's tracker was text and
-- nothing else.
--
-- The buttons are disabled rather than hidden: hiding them would leave the
-- title text unclickable but also disturb the layout the tracker built around
-- them. EnableMouse(false) takes the click without moving anything.

do
	local M = ns:RegisterModule("trackerClickToTrack", {})
	M.title = "Make tracker quests plain text"
	M.desc  = "Quest titles in the tracker stop being clickable, so there is no click-to-open-map and no right-click menu. Classic's tracker was text you read."
	M.onText  = "tracker quest titles are plain text"
	M.offText = "tracker quest titles are clickable again"
	M.group = "Quest tracking"
	M.order = 50

	ns:RegisterDefaults({ trackerClickToTrack = true })

	-- Remembered so Disable can hand the clicks back rather than guessing
	-- that they were on. A subtractive AddOn leaves no trace when off.
	local touched = {}

	function M:trackerPass()
		local buttons = WATCHFRAME_LINKBUTTONS
		if type(buttons) ~= "table" then return end
		for i = 1, #buttons do
			local b = buttons[i]
			if type(b) == "table" and type(b.EnableMouse) == "function" then
				if touched[b] == nil and type(b.IsMouseEnabled) == "function" then
					local ok, was = pcall(b.IsMouseEnabled, b)
					touched[b] = ok and was or false
				end
				pcall(b.EnableMouse, b, false)
			end
		end
	end

	function M:Enable()
		ensureHook()
		if type(WatchFrame_Update) == "function" then pcall(WatchFrame_Update) end
	end

	function M:Disable()
		for b, was in pairs(touched) do
			if type(b) == "table" and type(b.EnableMouse) == "function" then
				pcall(b.EnableMouse, b, was and true or false)
			end
		end
		wipe(touched)
		if type(WatchFrame_Update) == "function" then pcall(WatchFrame_Update) end
	end

	function M:Status()
		local buttons = WATCHFRAME_LINKBUTTONS
		if type(buttons) ~= "table" then return "no tracker link buttons" end
		return #buttons .. " tracker link button(s)"
	end
end

---------------------------------------------------------------------
-- Quest item buttons
---------------------------------------------------------------------
--
-- WatchFrameItem1..N, parented to WatchFrameLines, with WATCHFRAME_NUM_ITEMS
-- counting the live ones. Classic had no such thing: a quest item was used
-- from your bags.

do
	local M = ns:RegisterModule("trackerItemButtons", {})
	M.title = "Hide tracker quest item buttons"
	M.desc  = "Removes the use buttons MoP puts beside tracked quests. Quest items are used from your bags, as they were in Classic."
	M.onText  = "tracker quest item buttons hidden"
	M.offText = "tracker quest item buttons shown again"
	M.group = "Quest tracking"
	M.order = 60

	ns:RegisterDefaults({ trackerItemButtons = true })

	local hiddenOnes = {}

	-- WATCHFRAME_MAXQUESTS is the ceiling on tracked quests and so on item
	-- buttons; reading it beats a number written in by hand.
	local function maxItems()
		local n = WATCHFRAME_MAXQUESTS
		if type(n) ~= "number" or n < 1 then return 10 end
		return n
	end

	function M:trackerPass()
		for i = 1, maxItems() do
			local b = _G["WatchFrameItem" .. i]
			if b and type(b.Hide) == "function" then
				local shown = false
				if type(b.IsShown) == "function" then
					local ok, s = pcall(b.IsShown, b)
					shown = ok and s or false
				end
				if shown then
					hiddenOnes[b] = true
					pcall(b.Hide, b)
				end
			end
		end
	end

	function M:Enable()
		ensureHook()
		if type(WatchFrame_Update) == "function" then pcall(WatchFrame_Update) end
	end

	function M:Disable()
		wipe(hiddenOnes)
		-- The tracker decides for itself which buttons belong on screen, so
		-- rebuilding is both the correct restore and the simplest one.
		if type(WatchFrame_Update) == "function" then pcall(WatchFrame_Update) end
	end

	function M:Status()
		local n = 0
		for i = 1, maxItems() do
			if _G["WatchFrameItem" .. i] then n = n + 1 end
		end
		return n .. " item button(s) exist"
	end
end

---------------------------------------------------------------------
-- Turn-in pop-ups  (experimental)
---------------------------------------------------------------------
--
-- The bubble that slides out of the tracker saying a quest is ready to hand
-- in. EXPERIMENTAL, and honestly so: [G15] named the whole mechanism --
-- GetNumAutoQuestPopUps, GetAutoQuestPopUp, RemoveAutoQuestPopUp and the
-- WatchFrameAutoQuest_* display family -- but could not read the DATA, because
-- GetNumAutoQuestPopUps() returns 0 unless a pop-up is on screen at that
-- moment, and one cannot be summoned on demand.
--
-- So the first return of GetAutoQuestPopUp is TAKEN to be the questID that
-- RemoveAutoQuestPopUp wants. That is the one unverified assumption in this
-- file, it is why the option is experimental, and if it is wrong the pcall
-- swallows it and the pop-ups simply keep appearing.

do
	local M = ns:RegisterModule("trackerTurnInPopups", {})
	M.title = "Suppress turn-in pop-ups"
	M.desc  = "Stops the bubble that slides out of the tracker to tell you a quest can be handed in."
	M.onText  = "turn-in pop-ups suppressed"
	M.offText = "turn-in pop-ups shown again"
	M.group = "Quest tracking"
	M.order = 70
	M.experimental = true

	ns:RegisterDefaults({ trackerTurnInPopups = false })

	local removed = 0

	function M:trackerPass()
		if type(GetNumAutoQuestPopUps) ~= "function"
			or type(GetAutoQuestPopUp) ~= "function"
			or type(RemoveAutoQuestPopUp) ~= "function" then
			return
		end
		local okn, n = pcall(GetNumAutoQuestPopUps)
		if not okn or type(n) ~= "number" then return end
		-- Backwards: removing an entry renumbers the ones after it.
		for i = n, 1, -1 do
			local okg, id = pcall(GetAutoQuestPopUp, i)
			if okg and id ~= nil then
				if pcall(RemoveAutoQuestPopUp, id) then removed = removed + 1 end
			end
		end
		if removed > 0 and type(WatchFrameAutoQuest_ClearPopUp) == "function" then
			pcall(WatchFrameAutoQuest_ClearPopUp)
		end
	end

	function M:Enable()
		ensureHook()
	end

	function M:Disable()
		-- Nothing to put back: the pop-ups are queued by the game as quests
		-- complete, so leaving it alone is the restore.
	end

	function M:Status()
		if type(GetNumAutoQuestPopUps) ~= "function" then return "pop-up API missing" end
		if removed == 0 then return "no pop-up seen yet" end
		return removed .. " pop-up(s) removed"
	end
end
