-- Classic Questing (MoP) -- Quest progress in tooltips
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

local M = ns:RegisterModule("questProgressTooltips", {})
M.title = "Hide quest progress in tooltips"
M.desc  = "Mousing over a creature or object stops telling you which quest it belongs to and how many you still need. Classic expected you to remember what you were looking for."
M.onText  = "quest progress no longer appended to tooltips"
M.offText = "quest progress shown in tooltips again"
M.group = "Quest text"
M.order = 26

ns:RegisterDefaults({ questProgressTooltips = true })

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

local function scrub(tooltip)
	if scanning then return end
	if not ns.db or not ns.db.settings.questProgressTooltips then return end
	if type(tooltip) ~= "table" or type(tooltip.NumLines) ~= "function" then return end

	local name = tooltip:GetName()
	if not name then return end

	local okn, lines = pcall(tooltip.NumLines, tooltip)
	if not okn or type(lines) ~= "number" or lines < 2 then return end

	local titles
	local removed, inQuestBlock = 0, false

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

				if isGold(r, g, b) then
					titles = titles or activeQuestTitles()
					if titles[text] then
						-- A quest header. Everything under it, while it keeps
						-- looking like an objective, belongs to it.
						inQuestBlock = true
						fs:SetText("")
						removed = removed + 1
					else
						-- Gold, but not a quest -- a gathering node's name.
						inQuestBlock = false
					end
				elseif inQuestBlock and text:match(OBJECTIVE_PATTERN) then
					fs:SetText("")
					removed = removed + 1
				else
					inQuestBlock = false
				end
			end
		end
	end
	scanning = false

	-- Blanked lines still take up their height, so the tooltip would keep a
	-- gap where the quest block was. Shrinking by one line height each is
	-- cosmetic; if it ever misjudges, the text is still gone, which is the
	-- part that matters.
	if removed > 0 and type(tooltip.GetHeight) == "function" and type(tooltip.SetHeight) == "function" then
		pcall(function()
			local perLine = _G[name .. "TextLeft2"]
			local h = perLine and perLine.GetHeight and perLine:GetHeight() or 0
			if h > 0 then
				tooltip:SetHeight(math.max(1, tooltip:GetHeight() - (h * removed)))
			end
		end)
	end
end

local hooked = false

local function ensureHook()
	if hooked then return end
	if type(GameTooltip) ~= "table" or type(GameTooltip.HookScript) ~= "function" then
		ns:Warn("tooltip:missing", "GameTooltip is not hookable here; skipping quest progress tooltips.")
		return
	end
	hooked = true
	-- OnShow rather than OnTooltipSetUnit: the quest block is appended to
	-- object tooltips too, and those are not units.
	pcall(GameTooltip.HookScript, GameTooltip, "OnShow", scrub)
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
