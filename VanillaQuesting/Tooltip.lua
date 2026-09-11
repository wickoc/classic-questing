-- Vanilla Questing -- Quest progress in tooltips
--
-- Mousing over a mob or an object that counts towards a quest appends the
-- quest's name and your progress to its tooltip: "Pie for Billy" and then
-- " - Tender Boar Meat: 0/4". Classic did not do this. You knew what you were
-- collecting because you had read the quest.
--
-- The matching rule below is not a guess. It comes from six tooltips captured
-- live with per-line colours (SPEC.md, G12), and it is the only rule that
-- survives all six:
--
--   1  [0.90,0.70,0.00]  Stonetusk Boar          <- unit name
--   2  [1.00,1.00,1.00]  Level 6 Beast
--   3  [1.00,0.82,0.00]  Pie for Billy           <- quest title
--   4  [1.00,1.00,1.00]   - Tender Boar Meat: 0/4  <- objective
--
--   1  [1.00,0.82,0.00]  Silverleaf              <- an OBJECT's name, in the
--   2  [1.00,1.00,0.00]  Herbalism                  same gold as a quest title
--
-- So neither colour nor line number is enough on its own: gold is also a
-- gathering node's name, and the quest title moved from line 3 to line 4
-- between two tooltips on the same mob. What makes it safe is requiring the
-- text to MATCH AN ACTIVE QUEST IN THE LOG. That is what stops "Silverleaf"
-- being eaten.

local ADDON_NAME, ns = ...

local M = ns:RegisterModule("hideTooltipsQuestProgress", {})
M.title = "Hide Quest Progress In Tooltips"
M.desc  = "Hovering a creature or object no longer tells you which quest it belongs to or your progress."
M.onText  = "Quest progress removed from tooltips."
M.offText = "Quest progress in tooltips restored."
M.group = "UI"
M.order = 90

ns:RegisterDefaults({ hideTooltipsQuestProgress = true })

-- Blizzard's gold, as the captured tooltips report it. Compared with a
-- tolerance because these come back as floats.
local GOLD = { r = 1.00, g = 0.82, b = 0.00 }
local EPSILON = 0.02

local function isGold(r, g, b)
	if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then return false end
	return math.abs(r - GOLD.r) < EPSILON
		and math.abs(g - GOLD.g) < EPSILON
		and math.abs(b - GOLD.b) < EPSILON
end

-- " - Tender Boar Meat: 0/4". Leading dash, a name, a colon, a count.
local OBJECTIVE_PATTERN = "^%s*%-%s.+:%s*%d+/%d+%s*$"

-- The titles of every quest in the log, rebuilt on demand. Cheap enough at
-- tooltip rate, and always current -- caching it would go stale the moment a
-- quest was accepted or handed in.
local function activeQuestTitles()
	local titles = {}
	if type(GetNumQuestLogEntries) ~= "function" or type(GetQuestLogTitle) ~= "function" then
		return titles
	end
	local okn, n = pcall(GetNumQuestLogEntries)
	if not okn or type(n) ~= "number" then return titles end

	for i = 1, n do
		local ok, title, _, _, isHeader = pcall(GetQuestLogTitle, i)
		-- Headers are zone names, not quests, and must not be matched against.
		if ok and type(title) == "string" and title ~= "" and not isHeader then
			titles[title] = true
		end
	end
	return titles
end

local scanning = false

-- Run something on the NEXT frame.
--
-- This exists because of the one difference between a tooltip that works and
-- one that does not. A tooltip shown from hidden calls Show(), and the hook on
-- Show re-applies the height AFTER Blizzard has laid the frame out. A tooltip
-- built into a frame that is ALREADY visible never calls Show() again -- so
-- the only pass is the content-set script, which runs BEFORE Blizzard resizes
-- the frame for the new content, and the resize then throws the fit away.
--
-- Three earlier attempts all corrected the height at a moment the client
-- reserved the right to overrule. Next frame is after every moment the client
-- has, whatever order it used them in.
--
-- A one-shot OnUpdate rather than C_Timer: CreateFrame and SetScript are
-- certain on this client, and C_Timer has never been probed here.
local deferFrame
local function nextFrame(fn)
	if type(CreateFrame) ~= "function" then return end
	if not deferFrame then
		deferFrame = CreateFrame("Frame")
		if not deferFrame then return end
		deferFrame:Hide()
	end
	deferFrame.pending = fn
	deferFrame:SetScript("OnUpdate", function(self)
		self:SetScript("OnUpdate", nil)
		self:Hide()
		local f = self.pending
		self.pending = nil
		if f then pcall(f) end
	end)
	deferFrame:Show()
end


-- Shrink the tooltip to end just under its last surviving line.
--
-- Two earlier attempts at this both failed, and for the same underlying
-- reason. Subtracting a line height per removed line ignored the spacing
-- between lines and left a pad. Measuring the removed block was correct
-- arithmetic, but it was applied once and then thrown away: Blizzard re-lays
-- the tooltip out on Show(), which puts the height back.
--
-- So this measures the FINISHED tooltip and corrects it, on every pass,
-- including the one that runs after Show(). Once the height is right the
-- correction computes as zero, so repeating it costs nothing.
--
-- Nothing here assumes a line height or a padding value. The padding above
-- line 1 is measured and reused as the padding below the last line, because a
-- tooltip is symmetrical -- which is a fact about the frame in front of us
-- rather than a number to be guessed.
-- Setting a height fires OnSizeChanged, which is hooked below and fits the
-- height -- so a fit can re-enter itself. It would terminate on its own (the
-- second pass measures zero to correct and sets nothing), but a guard says so
-- outright rather than relying on the arithmetic to stop it.
local fitting = false

local function fitHeight(tooltip, name, lines)
	if fitting then return end
	if type(tooltip.GetHeight) ~= "function" or type(tooltip.SetHeight) ~= "function" then
		return
	end

	-- The last line with anything in it. Anything after it is dead space.
	local lastKept
	for i = lines, 1, -1 do
		local fs = _G[name .. "TextLeft" .. i]
		local text = fs and fs.GetText and fs:GetText()
		if type(text) == "string" and text ~= "" then lastKept = fs break end
	end
	if not lastKept then return end

	local first = _G[name .. "TextLeft1"]
	if not first or type(first.GetTop) ~= "function" then return end

	-- Raised only around the part that can set a height. Every return above
	-- this point leaves it down, which is the whole reason it is not raised
	-- at the top of the function: a guard stuck on is a feature switched off.
	fitting = true
	local ok = pcall(function()
		local frameTop, frameBottom = tooltip:GetTop(), tooltip:GetBottom()
		local firstTop, keptBottom = first:GetTop(), lastKept:GetBottom()
		if not (frameTop and frameBottom and firstTop and keptBottom) then return end

		local padding = frameTop - firstTop
		local wantBottom = keptBottom - padding
		local excess = wantBottom - frameBottom
		-- Corrects in BOTH directions. Shrinking only was enough while every
		-- tooltip was freshly laid out, but a re-used one can arrive already
		-- too short -- the previous tooltip's fit is still on the frame, and
		-- Blizzard does not always resize it back up. A fit that can only
		-- shrink leaves that one cramped forever.
		--
		-- Half a pixel either way is rounding, not a resize.
		if excess > 0.5 or excess < -0.5 then
			tooltip:SetHeight(math.max(1, tooltip:GetHeight() - excess))
			-- Setting a height PINS the frame: it stops sizing itself from
			-- its lines, and the value stays on it when the next tooltip is
			-- built into the same frame. Once that has happened, this AddOn
			-- owns the height and has to keep setting it -- including for
			-- tooltips it has nothing to remove from, which would otherwise
			-- be left at whatever size the last scrubbed one needed.
			tooltip.__vqPinned = true
		end
	end)
	fitting = false
	if not ok then return end
end


-- The stamp identifying a tooltip's current contents. Line count alone was not
-- enough: hover a two-line herb node, then a creature whose tooltip comes to
-- the same count, and the marker from one carried into the other. Two tooltips
-- are only "the same" if the first line matches as well.
local function stampFor(name, lines)
	local first = _G[name .. "TextLeft1"]
	return lines .. "\1" .. tostring(first and first:GetText() or "")
end

local function scrub(tooltip)
	if scanning then return end
	if not ns.db or not ns.db.settings.hideTooltipsQuestProgress then return end
	if type(tooltip) ~= "table" or type(tooltip.NumLines) ~= "function" then return end

	local name = tooltip:GetName()
	if not name then return end

	local okn, lines = pcall(tooltip.NumLines, tooltip)
	if not okn or type(lines) ~= "number" or lines < 2 then return end

	local titles
	local inQuestBlock = false
	local blankedHere = 0

	scanning = true
	-- Line 1 is always the name; never touch it.
	for i = 2, lines do
		local fs = _G[name .. "TextLeft" .. i]
		if fs and type(fs.GetText) == "function" then
			local text = fs:GetText()
			if type(text) == "string" and text ~= "" then
				local r, g, b
				if type(fs.GetTextColor) == "function" then
					local okc, cr, cg, cb = pcall(fs.GetTextColor, fs)
					if okc then r, g, b = cr, cg, cb end
				end

				local blank = false
				if isGold(r, g, b) then
					titles = titles or activeQuestTitles()
					if titles[text] then
						-- A quest header. Everything under it, while it keeps
						-- looking like an objective, belongs to it.
						inQuestBlock = true
						blank = true
					else
						-- Gold, but not a quest -- a gathering node's name.
						inQuestBlock = false
					end
				elseif inQuestBlock and text:match(OBJECTIVE_PATTERN) then
					blank = true
				else
					inQuestBlock = false
				end

				if blank then
					fs:SetText("")
					blankedHere = blankedHere + 1
				end
			end
		end
	end

	-- Remember that THIS tooltip, at this line count, has had lines taken out
	-- of it. A later pass over the same tooltip finds only empty strings and
	-- would otherwise have no way to know they were ever anything.
	local stamp = stampFor(name, lines)
	if blankedHere > 0 then
		tooltip.__vqBlankedAt = stamp
	elseif tooltip.__vqBlankedAt ~= stamp then
		-- Different tooltip entirely: whatever was blanked was not this.
		tooltip.__vqBlankedAt = nil
	end

	-- Fit when there is something to fit, and also whenever this frame is
	-- already carrying a height of ours -- see __vqPinned above.
	--
	-- This is the earliest opportunity, not the decisive one. Whether it
	-- sticks depends on whether the client has already sized the frame for
	-- this content, which nothing here can know. The OnSizeChanged hook below
	-- is what makes that not matter.
	if tooltip.__vqBlankedAt == stamp or tooltip.__vqPinned then
		fitHeight(tooltip, name, lines)
		-- And once more next frame, after every moment the client has. By
		-- then the height is normally already right and this measures zero to
		-- correct; it exists for a client that resizes without telling us.
		nextFrame(function()
			-- IsShown is checked for existence first. A tooltip implementation
			-- without it is not a reason to skip the fit -- and inside a pcall
			-- a missing method would have skipped it silently.
			local shown = true
			if type(tooltip.IsShown) == "function" then
				local ok, v = pcall(tooltip.IsShown, tooltip)
				shown = (not ok) or v
			end
			if shown then
				scanning = true
				fitHeight(tooltip, name, tooltip:NumLines())
				scanning = false
			end
		end)
	end
	scanning = false
end

-- The moment that actually matters.
--
-- Everything before this corrected the height at some point in the frame and
-- hoped the client was finished. It never reliably was: the client sizes the
-- tooltip for its new content AFTER the content-set script, and on this client
-- after the Show hook too. So the player saw the untrimmed height first and
-- the trimmed one a frame later -- the box growing, then shrinking into place.
-- That is the stutter, and it was there on a fresh tooltip and a re-used one
-- alike, because both end the frame the same way.
--
-- OnSizeChanged fires DURING the client's own resize, in the same frame,
-- before anything is drawn. Correcting here means the oversized height never
-- reaches the screen: it is set and replaced between two draws. Nothing else
-- in the frame has that property, which is why four attempts at picking a
-- better hook could not have worked.
--
-- Cheap: it does nothing at all unless this frame is one we have taken lines
-- out of, or one still carrying a height of ours.
local function onSizeChanged(tooltip)
	if fitting or scanning then return end
	if not ns.db or not ns.db.settings.hideTooltipsQuestProgress then return end
	if type(tooltip) ~= "table" or type(tooltip.NumLines) ~= "function" then return end

	local name = tooltip:GetName()
	if not name then return end

	local okn, lines = pcall(tooltip.NumLines, tooltip)
	if not okn or type(lines) ~= "number" or lines < 1 then return end

	if tooltip.__vqBlankedAt ~= stampFor(name, lines) and not tooltip.__vqPinned then
		return
	end
	fitHeight(tooltip, name, lines)
end

local hooked = false

-- WHEN to run, which is the whole difficulty.
--
-- v0.16.0 hooked OnShow alone and removed nothing at all. OnShow fires when
-- the tooltip becomes VISIBLE, which is before its lines have been filled in
-- -- NumLines() is still zero or still showing the last tooltip -- and it does
-- not fire again when the mouse moves from one creature to the next without
-- the tooltip hiding in between. So the scrub ran, found nothing, and left.
--
-- The lines exist by the time the content-set scripts fire, so those are the
-- real moment. Several are hooked because the quest block is appended to
-- creature tooltips AND to world object tooltips, and those arrive by
-- different routes. A script name this client does not have makes HookScript
-- throw, which the pcall absorbs -- so listing one that turns out not to exist
-- costs nothing. Running twice on one tooltip costs nothing either: the second
-- pass finds the lines already blank.
local SCRIPTS = { "OnTooltipSetUnit", "OnTooltipSetItem", "OnTooltipSetDefaultAnchor", "OnShow" }

local function ensureHook()
	if hooked then return end
	if type(GameTooltip) ~= "table" or type(GameTooltip.HookScript) ~= "function" then
		ns:Warn("tooltip:missing", "GameTooltip is not hookable here; skipping quest progress tooltips.")
		return
	end
	hooked = true

	local any = false
	for i = 1, #SCRIPTS do
		if pcall(GameTooltip.HookScript, GameTooltip, SCRIPTS[i], scrub) then
			any = true
		end
	end

	-- The height, as opposed to the text. This is the hook the feature turns
	-- on: it runs inside the client's own resize, so the untrimmed height is
	-- corrected before the frame is drawn rather than a frame afterwards.
	-- Failing to get it is not fatal -- the deferred pass still lands, one
	-- frame late and visibly -- so it does not count towards `any`.
	pcall(GameTooltip.HookScript, GameTooltip, "OnSizeChanged", onSizeChanged)

	-- Catch-all. Blizzard calls Show() after building a tooltip, whatever
	-- built it, so this covers any route the scripts above miss. scrub never
	-- calls Show itself, so there is nothing to recurse into.
	if type(hooksecurefunc) == "function" and type(GameTooltip.Show) == "function" then
		if pcall(hooksecurefunc, GameTooltip, "Show", scrub) then any = true end
	end

	if not any then
		ns:Warn("tooltip:nohook", "could not hook GameTooltip; skipping quest progress tooltips.")
	end
end

function M:Enable()
	ensureHook()
end

function M:Disable()
	-- Nothing to restore. The lines are rebuilt from scratch every time a
	-- tooltip is shown, so the next one is Blizzard's again.
end

function M:Status()
	if not hooked then return "not hooked" end
	if type(GetNumQuestLogEntries) ~= "function" then return "quest log API missing" end
	local n = 0
	for _ in pairs(activeQuestTitles()) do n = n + 1 end
	return n .. " quest title(s) being matched"
end
