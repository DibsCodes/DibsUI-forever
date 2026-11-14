local _, ns = ...

-- Blizzard's scrolling combat text: damage, heals, procs and so on happening to you. DibsUI can move
-- it, change its font, outline and scale, and recolor kinds of hits, all without tainting it.
--
-- Blizzard's code places every line from the bottom middle of the screen, and works out where the next
-- line goes from its own numbers, so those are left alone. Writing into its frame or its tables would
-- taint it, and it handles amounts that are secret to addon code. Instead:
-- - Each time it places its lines, they're all moved by the same distance, onto DibsUI's anchor.
-- - The font is set on the font object every line uses, and the scale on its frame. Both are changes
--   inside the client, not Lua values Blizzard's code reads.
-- - A line's color is set straight after Blizzard adds it, from the kind of hit its event names.

ns.CombatTextScaleRange = { min = 0.5, max = 2, step = 0.05 }
ns.CombatTextOffsetRange = { min = -300, max = 300, step = 1 }

ns.CombatTextOutlines = {
	{ key = "NONE", label = "None", flags = "" },
	{ key = "OUTLINE", label = "Outline", flags = "OUTLINE" },
	{ key = "THICKOUTLINE", label = "Thick outline", flags = "THICKOUTLINE" },
}
local OUTLINE_FLAGS = {}
for _, outline in ipairs(ns.CombatTextOutlines) do
	OUTLINE_FLAGS[outline.key] = outline.flags
end

-- Kinds of combat text that can be recolored, by the type Blizzard's event names. default is
-- Blizzard's own color, which they keep until a custom one is chosen.
ns.CombatTextColorGroups = {
	{ key = "melee", label = "Melee hits", default = { 1, 0.1, 0.1 },
		types = { "DAMAGE", "DAMAGE_CRIT", "SPLIT_DAMAGE" } },
	{ key = "spell", label = "Spell hits", default = { 0.79, 0.3, 0.85 },
		types = { "SPELL_DAMAGE", "SPELL_DAMAGE_CRIT", "DAMAGE_SHIELD" } },
	{ key = "heal", label = "Heals", default = { 0.1, 1, 0.1 },
		types = { "HEAL", "HEAL_CRIT", "PERIODIC_HEAL", "PERIODIC_HEAL_CRIT", "HEAL_ABSORB", "PERIODIC_HEAL_ABSORB",
			"HEAL_CRIT_ABSORB", "ABSORB_ADDED" } },
	{ key = "avoided", label = "Misses, blocks and resists", default = { 1, 1, 1 },
		types = { "MISS", "DODGE", "PARRY", "EVADE", "IMMUNE", "DEFLECT", "REFLECT", "RESIST", "BLOCK", "ABSORB",
			"SPELL_MISS", "SPELL_DODGE", "SPELL_PARRY", "SPELL_EVADE", "SPELL_IMMUNE", "SPELL_DEFLECT",
			"SPELL_REFLECT", "SPELL_RESIST", "SPELL_BLOCK", "SPELL_ABSORB" } },
}
local COLOR_GROUP_OF_TYPE = {}
for _, group in ipairs(ns.CombatTextColorGroups) do
	for _, combatTextType in ipairs(group.types) do
		COLOR_GROUP_OF_TYPE[combatTextType] = group.key
	end
end

local DEFAULTS = {
	enabled = true, -- moved onto DibsUI's anchor
	attach = "player", -- above the player bar, or "free" where it was dragged
	x = 0, -- the free anchor's bottom, from the bottom middle of the screen, in UIParent units
	y = 400,
	offsetX = 0, -- added to wherever it's attached
	offsetY = 0,
	outline = "NONE",
	scale = 1,
}

local function Clamp(value, range)
	return math.min(math.max(value, range.min), range.max)
end

local function IsColor(color)
	return type(color) == "table" and type(color[1]) == "number" and type(color[2]) == "number" and type(color[3]) == "number"
end

-- Fills in what's missing and drops what's malformed. profile.combatTextAtPlayer was this feature's
-- first switch, before it had its own settings.
function ns.CleanCombatTextSettings(settings, profile)
	if type(settings) ~= "table" then
		settings = {}
	end
	if profile and type(profile.combatTextAtPlayer) == "boolean" and settings.enabled == nil then
		settings.enabled = profile.combatTextAtPlayer
	end
	if profile then
		profile.combatTextAtPlayer = nil
	end
	for key, value in pairs(DEFAULTS) do
		if type(settings[key]) ~= type(value) then
			settings[key] = value
		end
	end
	if settings.attach ~= "player" and settings.attach ~= "free" then
		settings.attach = DEFAULTS.attach
	end
	if not OUTLINE_FLAGS[settings.outline] then
		settings.outline = DEFAULTS.outline
	end
	if type(settings.font) ~= "string" then
		settings.font = nil
	end
	settings.scale = Clamp(settings.scale, ns.CombatTextScaleRange)
	settings.offsetX = Clamp(settings.offsetX, ns.CombatTextOffsetRange)
	settings.offsetY = Clamp(settings.offsetY, ns.CombatTextOffsetRange)
	if type(settings.colors) ~= "table" then
		settings.colors = {}
	end
	for key, color in pairs(settings.colors) do
		if not IsColor(color) then
			settings.colors[key] = nil
		end
	end
	return settings
end

local function Settings()
	return ns.db.combatText
end

function ns.GetCombatTextColor(groupKey)
	return Settings().colors[groupKey]
end

-- Anchor ----------------------------------------------------------------------------------------------

-- Lines rise from the anchor's bottom edge: Blizzard's lowest line sits on it. Above the player bar it
-- also clears the player's name, and above short buffs it leaves a small gap. In the units of the bar
-- or the buffs.
local ABOVE_BAR = 23
local ABOVE_SHORT_BUFFS = 3
local ANCHOR_WIDTH = 160
local LINE_HEIGHT = 25 -- Blizzard's MessageHeight, if it can't be read

local anchor

local function GetLineHeight()
	local constants = CombatTextConstants
	return type(constants) == "table" and tonumber(constants.MessageHeight) or LINE_HEIGHT
end

-- Where the anchor's bottom middle goes above the player bar, in screen pixels.
local function GetPlayerFloor()
	local bar = DibsUIPlayerHealth
	if not (bar and bar:GetTop()) then
		return
	end
	local barScale = bar:GetEffectiveScale()
	local x = bar:GetCenter() * barScale
	local buffsTop, buffsScale = ns.GetShortBuffsTop()
	if buffsTop then
		return x, (buffsTop + ABOVE_SHORT_BUFFS) * buffsScale
	end
	return x, (bar:GetTop() + ABOVE_BAR) * barScale
end

local placedX, placedY, placedHeight

-- Puts the anchor where the settings say. Above the player bar it follows the bar and the short buffs,
-- so this runs every frame, but only moves the anchor when that changes something.
local function PlaceAnchor()
	local settings = Settings()
	local uiScale = UIParent:GetEffectiveScale()
	local x, y
	if settings.attach == "free" then
		x, y = UIParent:GetWidth() / 2 + settings.x, settings.y
	else
		local floorX, floorY = GetPlayerFloor()
		if not floorX then
			return
		end
		x, y = floorX / uiScale, floorY / uiScale
	end
	x, y = x + settings.offsetX, y + settings.offsetY
	local height = GetLineHeight() * settings.scale
	if anchor.isMoving or (x == placedX and y == placedY and height == placedHeight) then
		return
	end
	placedX, placedY, placedHeight = x, y, height
	anchor:SetSize(ANCHOR_WIDTH * settings.scale, height)
	anchor:ClearAllPoints()
	anchor:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", x, y)
end

-- Moving Blizzard's lines -----------------------------------------------------------------------------

-- How far to move the lines, in the combat text's own units, or nil if they stay where Blizzard puts them.
-- Blizzard starts a burst of lines below its usual start, down to textOffsetMax under it, and lines
-- scrolling down end at endY. The lowest of those is what sits on the anchor.
local function GetOffset(combatText)
	if not Settings().enabled then
		return
	end
	local locations = combatText.textLocations
	if type(locations) ~= "table" or not (locations.startX and locations.startY and locations.endY and anchor:GetBottom()) then
		return
	end
	local scale, anchorScale, worldScale = combatText:GetEffectiveScale(), anchor:GetEffectiveScale(), WorldFrame:GetEffectiveScale()
	local anchorX = anchor:GetCenter() * anchorScale / scale
	local floor = anchor:GetBottom() * anchorScale / scale
	local worldX = WorldFrame:GetCenter() * worldScale / scale
	local worldBottom = WorldFrame:GetBottom() * worldScale / scale
	local lowestTop = math.min(locations.startY - (tonumber(combatText.textOffsetMax) or 0), locations.endY)
	return anchorX - worldX - locations.startX, floor + GetLineHeight() - worldBottom - lowestTop
end

-- In combat a line's amount is secret, and Blizzard places it from the text's own height, so its
-- position is secret too: addon code can't read it, add to it or pass it back to SetPoint. The client
-- adds the distance to whatever offsets the line has instead, and the distance itself isn't secret.
local function MoveLine(line, dx, dy)
	line:AdjustPointsOffset(dx, dy)
end

-- Blizzard places every line again each frame, so each line is moved once from where it was just put.
local function MoveLines(combatText)
	local lines = combatText.activeFontStrings
	if type(lines) ~= "table" or #lines == 0 then
		return
	end
	local dx, dy = GetOffset(combatText)
	if dx then
		for _, line in ipairs(lines) do
			MoveLine(line, dx, dy)
		end
	end
end

-- The line Blizzard added last, until its event has been seen, so it can be recolored.
local newLine

-- A new line can arrive after this frame's update, so it's moved straight away rather than showing for
-- a frame in the middle of the screen. It's the last one in the list.
local function OnLineAdded(combatText)
	local lines = combatText.activeFontStrings
	local line = type(lines) == "table" and lines[#lines]
	if not line then
		return
	end
	newLine = line
	local dx, dy = GetOffset(combatText)
	if dx then
		MoveLine(line, dx, dy)
	end
end

-- Runs after Blizzard has handled the event. If that added a line, its event names the kind of hit.
-- Blizzard only sets a line's color as it adds it, so a new one stays.
local function OnCombatTextEvent(_, event, combatTextType)
	local line = newLine
	newLine = nil
	if not line or event ~= "COMBAT_TEXT_UPDATE" or issecretvalue(combatTextType) then
		return
	end
	local groupKey = COLOR_GROUP_OF_TYPE[combatTextType]
	local color = groupKey and ns.GetCombatTextColor(groupKey)
	if color then
		line:SetTextColor(color[1], color[2], color[3])
	end
end

-- Font and scale ---------------------------------------------------------------------------------------

-- Blizzard's font, before any change. Every line sets its own height, so the font's size never shows.
local defaultFont, defaultSize, defaultFlags

local function ApplyFont()
	if not CombatTextFont then
		return
	end
	if not defaultFont then
		defaultFont, defaultSize, defaultFlags = CombatTextFont:GetFont()
	end
	local settings = Settings()
	local flags = settings.outline == "NONE" and defaultFlags or OUTLINE_FLAGS[settings.outline]
	if not (settings.font and CombatTextFont:SetFont(settings.font, defaultSize, flags)) then
		CombatTextFont:SetFont(defaultFont, defaultSize, flags)
	end
end

local function ApplyScale()
	if CombatText then
		CombatText:SetScale(Settings().scale)
	end
end

-- Dragging ---------------------------------------------------------------------------------------------

-- A dropped anchor stays where it was put, as a free one. The offsets still apply on top.
local function FinishMoving()
	if not anchor.isMoving then
		return
	end
	anchor.isMoving = false
	anchor:StopMovingOrSizing()
	anchor:SetUserPlaced(false)
	local settings = Settings()
	settings.attach = "free"
	settings.x = math.floor(anchor:GetCenter() - UIParent:GetWidth() / 2 - settings.offsetX + 0.5)
	settings.y = math.floor(anchor:GetBottom() - settings.offsetY + 0.5)
	placedX = nil
	PlaceAnchor()
	if ns.OnCombatTextMoved then
		ns.OnCombatTextMoved()
	end
end

function ns.UpdateCombatTextMover()
	if not anchor then
		return
	end
	local unlocked = not ns.db.locked and not InCombatLockdown() and Settings().enabled
	if not unlocked then
		FinishMoving()
	end
	anchor.handle:SetShown(unlocked)
	anchor:EnableMouse(unlocked)
end

local function CreateAnchor()
	anchor = CreateFrame("Frame", "DibsUICombatTextAnchor", UIParent)
	anchor:SetFrameStrata("MEDIUM")
	-- Above DibsUI's own drag handle, which it sits inside while it's over the player bar.
	anchor:SetFrameLevel(20)
	anchor:SetMovable(true)
	anchor:SetClampedToScreen(true)
	anchor:SetDontSavePosition(true)
	anchor:RegisterForDrag("LeftButton")
	anchor:SetScript("OnUpdate", PlaceAnchor)
	anchor:SetScript("OnDragStart", function(self)
		self.isMoving = true
		self:StartMoving()
	end)
	anchor:SetScript("OnDragStop", FinishMoving)

	-- Shown while the frames are unlocked: a tinted box where the lowest line sits, with lines rising from it.
	local handle = CreateFrame("Frame", nil, anchor)
	handle:SetAllPoints()
	handle:Hide()
	anchor.handle = handle
	local tint = ns.CreateArt(handle, "BACKGROUND", "Flat")
	tint:SetAllPoints()
	tint:SetVertexColor(0.15, 0.45, 1, 0.3)
	local label = handle:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	label:SetPoint("CENTER")
	label:SetText("Combat text")
	local arrow = handle:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	arrow:SetPoint("BOTTOM", handle, "TOP", 0, 2)
	arrow:SetText("rises from here")
end

-- Settings ---------------------------------------------------------------------------------------------

-- Changes one setting and applies it. All of it works in combat.
function ns.SetCombatTextOption(key, value)
	local settings = Settings()
	settings[key] = value
	ns.CleanCombatTextSettings(settings)
	placedX = nil
	ApplyFont()
	ApplyScale()
	ns.UpdateCombatTextMover()
	PlaceAnchor()
end

function ns.GetCombatTextOption(key)
	return Settings()[key]
end

-- nil goes back to Blizzard's color.
function ns.SetCombatTextColor(groupKey, color)
	Settings().colors[groupKey] = color
end

function ns.ResetCombatTextPosition()
	local settings = Settings()
	settings.attach = "player"
	settings.offsetX, settings.offsetY = 0, 0
	ns.SetCombatTextOption("x", DEFAULTS.x)
end

-- After switching profiles.
function ns.RefreshCombatText()
	ns.SetCombatTextOption("enabled", Settings().enabled)
end

-- Blizzard's combat text ------------------------------------------------------------------------------

local isAttached = false

local function Attach()
	if isAttached or not CombatText then
		return
	end
	isAttached = true
	CombatText:HookScript("OnUpdate", MoveLines)
	CombatText:HookScript("OnEvent", OnCombatTextEvent)
	hooksecurefunc(CombatText, "AddMessage", OnLineAdded)
	ApplyScale()
end

function ns.CreateCombatText()
	CreateAnchor()
	ApplyFont()
	ns.UpdateCombatTextMover()
	PlaceAnchor()
	-- Blizzard loads its combat text only once it's switched on in the game's options.
	if C_AddOns.IsAddOnLoaded("Blizzard_CombatText") then
		Attach()
	else
		local loader = CreateFrame("Frame")
		loader:RegisterEvent("ADDON_LOADED")
		loader:SetScript("OnEvent", function(self, _, name)
			if name == "Blizzard_CombatText" then
				self:UnregisterEvent("ADDON_LOADED")
				Attach()
			end
		end)
	end
end
