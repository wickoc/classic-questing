-- Classic Questing (MoP) -- Quest frame
--
-- MoP shows a portrait of the questgiver beside the quest text: a framed
-- character box on the quest offer window, and again on the quest log's detail
-- panel. It is the same widget in both places. Classic had no such thing --
-- you read the text and looked at the NPC.
--
-- HONEST NOTE ON THE NAMES USED HERE. Unlike the rest of this AddOn, the
-- globals below have NOT been confirmed by a probe run on this client; the
-- feature was asked for and the probe goes out in the same build. Everything
-- is therefore existence-checked before use and the module reports what it
-- actually found through Status(), so a wrong guess disables the option
-- loudly rather than erroring. Probe [G22] settles it.

local ADDON_NAME, ns = ...

local M = ns:RegisterModule("questGiverPortrait", {})
M.title = "Hide the questgiver portrait"
M.desc  = "Removes the framed character box MoP puts beside quest text, both when a quest is offered and in the quest log. Classic showed the text and nothing else."
M.onText  = "questgiver portrait hidden"
M.offText = "questgiver portrait shown again"
M.group = "Quest text"
M.order = 25

ns:RegisterDefaults({ questGiverPortrait = true })

-- Every frame this might be, in the order worth trying. The first that exists
-- is used; the rest cost nothing.
local CANDIDATE_FRAMES = {
	"QuestNPCModel",          -- the 5.x name
	"QuestModelScene",        -- what later clients renamed it to
	"QuestFrameNPCModel",
}

-- And the functions that put it on screen, so it can be re-hidden after
-- Blizzard shows it rather than only once at login.
local CANDIDATE_SHOWERS = {
	"QuestFrame_ShowQuestPortrait",
	"QuestLogPopupDetailFrame_ShowQuestPortrait",
}

local frame, frameName
local hooked = false

local function findFrame()
	if frame then return frame end
	for i = 1, #CANDIDATE_FRAMES do
		local f = _G[CANDIDATE_FRAMES[i]]
		if type(f) == "table" and type(f.Hide) == "function" then
			frame, frameName = f, CANDIDATE_FRAMES[i]
			return frame
		end
	end
	return nil
end

local function hidePortrait()
	if not ns.db or not ns.db.settings.questGiverPortrait then return end
	local f = findFrame()
	if f then pcall(f.Hide, f) end
end

local function ensureHooks()
	if hooked then return end
	if type(hooksecurefunc) ~= "function" then return end
	hooked = true

	-- Post-hook whichever show functions exist. Blizzard calls one of these
	-- every time a quest is offered or opened in the log, which is exactly
	-- when the box comes back.
	local any = false
	for i = 1, #CANDIDATE_SHOWERS do
		if type(_G[CANDIDATE_SHOWERS[i]]) == "function" then
			pcall(hooksecurefunc, CANDIDATE_SHOWERS[i], hidePortrait)
			any = true
		end
	end

	-- Belt and braces: the frame's own OnShow catches any route that does not
	-- go through a named function.
	local f = findFrame()
	if f and type(f.HookScript) == "function" then
		pcall(f.HookScript, f, "OnShow", hidePortrait)
		any = true
	end

	if not any then
		ns:Warn("questframe:missing",
			"could not find the questgiver portrait on this client; skipping that option.")
	end
end

function M:Enable()
	ensureHooks()
	hidePortrait()
end

function M:Disable()
	-- Not shown again by hand: which quests have a portrait is the game's
	-- business, and the next quest opened will show it correctly.
	local f = findFrame()
	if f and type(f.Show) == "function" and type(f.IsShown) == "function" then
		-- Only if a quest frame is actually up; otherwise leave it hidden,
		-- which is where Blizzard would have it anyway.
		local okp, parent = pcall(f.GetParent, f)
		if okp and type(parent) == "table" and type(parent.IsShown) == "function" then
			local oks, shown = pcall(parent.IsShown, parent)
			if oks and shown then pcall(f.Show, f) end
		end
	end
end

function M:Status()
	if not findFrame() then return "portrait frame not found" end
	return frameName .. " found"
end
