local _, ns = ...

-- Buffs whose full duration is longer than this are long buffs, along with buffs that never expire.
local LONG_BUFF_SECONDS = 120
local TIME_GAP = 1 -- between an icon and its time text
local BORDER = 1
local LIST_TEXT_GAP = 4 -- between an icon and its name and time in list mode
-- Room the frame leaves beside the icons for names in list mode. It sets the frame's size while
-- unlocked and where a right side icon sits. Longer names run past it.
local LIST_TEXT_WIDTH = 150
local NAME_CLEARANCE = 2 -- between the short buffs' time text and the player's name above the bar

ns.AuraIconSizeRange = { min = 16, max = 64, step = 1 }
ns.AuraSpacingRange = { min = 0, max = 20, step = 1 }
ns.AuraFrameSizeRange = { min = 40, max = 1200, step = 1 }
ns.AuraTextSizeRange = { min = 6, max = 24, step = 1 }
ns.AuraOffsetRange = { min = -2000, max = 2000, step = 1 }

ns.AuraPoints = {
	{ key = "TOPLEFT", label = "Top left" },
	{ key = "TOP", label = "Top" },
	{ key = "TOPRIGHT", label = "Top right" },
	{ key = "LEFT", label = "Left" },
	{ key = "CENTER", label = "Center" },
	{ key = "RIGHT", label = "Right" },
	{ key = "BOTTOMLEFT", label = "Bottom left" },
	{ key = "BOTTOM", label = "Bottom" },
	{ key = "BOTTOMRIGHT", label = "Bottom right" },
}

-- Which way icons fill a line, then which way new lines go. The first icon sits in the corner both
-- directions start from, so right then down starts at the top left.
ns.AuraGrowths = {
	{ key = "RIGHT_DOWN", label = "Right, then down", line = "RIGHT", wrap = "DOWN" },
	{ key = "RIGHT_UP", label = "Right, then up", line = "RIGHT", wrap = "UP" },
	{ key = "LEFT_DOWN", label = "Left, then down", line = "LEFT", wrap = "DOWN" },
	{ key = "LEFT_UP", label = "Left, then up", line = "LEFT", wrap = "UP" },
	{ key = "DOWN_RIGHT", label = "Down, then right", line = "DOWN", wrap = "RIGHT" },
	{ key = "DOWN_LEFT", label = "Down, then left", line = "DOWN", wrap = "LEFT" },
	{ key = "UP_RIGHT", label = "Up, then right", line = "UP", wrap = "RIGHT" },
	{ key = "UP_LEFT", label = "Up, then left", line = "UP", wrap = "LEFT" },
}

ns.AuraAnchorTargets = {
	{ key = "screen", label = "Screen" },
	{ key = "root", label = "DibsUI frames" },
	{ key = "orb", label = "DibsUI orb" },
	{ key = "minimap", label = "Minimap" },
}

-- The five groups the settings list. Only the ones marked built exist so far. Anchored groups sit on a
-- DibsUI frame and take their place and width from it, so they have no position or growth settings.
ns.AuraGroups = {
	{ key = "playerLongBuffs", label = "Player long buffs", built = true, hasListMode = true },
	{ key = "playerShortBuffs", label = "Player short buffs", built = true, anchored = true,
		anchorNote = "Sits above the player bar, as wide as it and clear of your name, and fills right, then up." },
	{ key = "playerDebuffs", label = "Player debuffs" },
	{ key = "targetBuffs", label = "Target buffs" },
	{ key = "targetDebuffs", label = "Target debuffs" },
}

local function ByKey(list)
	local index = {}
	for _, item in ipairs(list) do
		index[item.key] = item
	end
	return index
end

-- Player long buffs can also show as a list, with its own settings.
ns.AuraModes = {
	{ key = "standard", label = "Standard", description = "A grid of icons with the time under each." },
	{ key = "list", label = "List", description = "One buff per line, longest at the top, with its name and time beside the icon." },
}

ns.AuraModesByKey = ByKey(ns.AuraModes)
ns.AuraPointsByKey = ByKey(ns.AuraPoints)
ns.AuraGrowthsByKey = ByKey(ns.AuraGrowths)
ns.AuraAnchorTargetsByKey = ByKey(ns.AuraAnchorTargets)
ns.AuraGroupsByKey = ByKey(ns.AuraGroups)

-- Sizes, spacing and offsets are in UI units, so they follow the UI scale like Blizzard's buffs. The
-- short buffs live on the player bar, so they follow DibsUI's scale as well. The time text's color is
-- Blizzard's gold, which its own buff timers use.
local GROUP_DEFAULTS = {
	playerLongBuffs = {
		enabled = true,
		iconSize = 32,
		spacing = 6,
		growth = "LEFT_DOWN",
		frameSize = 360,
		point = "TOPRIGHT",
		anchorTo = "minimap",
		anchorPoint = "TOPLEFT",
		x = -24,
		y = 0,
		textSize = 11,
		textColor = { 1, 0.82, 0 },
		mode = "standard",
	},
	playerShortBuffs = {
		enabled = true,
		iconSize = 26,
		spacing = 4,
		textSize = 10,
		textColor = { 1, 0.82, 0 },
	},
}

-- The short buffs always fill from the bar's outer end, towards the orb, then up.
local SHORT_BUFF_GROWTH = "RIGHT_UP"

-- List mode's own settings, kept in a group's list table. The name is white and the time a
-- little smaller and off-white. List mode has its own position, at the top left of the screen.
local LIST_DEFAULTS = {
	iconSide = "LEFT",
	iconSize = 28,
	spacing = 4,
	nameSize = 13,
	nameColor = { 1, 1, 1 },
	timeSize = 11,
	timeColor = { 0.88, 0.87, 0.82 },
	point = "TOPLEFT",
	anchorTo = "screen",
	anchorPoint = "TOPLEFT",
	x = 0,
	y = 0,
}

local LIST_RANGES = {
	iconSize = ns.AuraIconSizeRange,
	spacing = ns.AuraSpacingRange,
	nameSize = ns.AuraTextSizeRange,
	timeSize = ns.AuraTextSizeRange,
	x = ns.AuraOffsetRange,
	y = ns.AuraOffsetRange,
}

local NUMBER_RANGES = {
	iconSize = ns.AuraIconSizeRange,
	spacing = ns.AuraSpacingRange,
	frameSize = ns.AuraFrameSizeRange,
	textSize = ns.AuraTextSizeRange,
	x = ns.AuraOffsetRange,
	y = ns.AuraOffsetRange,
}

local function IsColor(color)
	return type(color) == "table" and type(color[1]) == "number" and type(color[2]) == "number" and type(color[3]) == "number"
end

-- Puts back defaults for anything missing or of the wrong kind, rounds and clamps the numbers, and
-- drops a font that isn't a path. Colors are the only tables in the defaults. Ranges for settings a
-- group doesn't have are skipped.
local function CleanFields(settings, defaults, ranges, fontFields)
	for field, default in pairs(defaults) do
		local value = settings[field]
		if type(value) ~= type(default) or (type(default) == "table" and not IsColor(value)) then
			settings[field] = type(default) == "table" and { unpack(default) } or default
		end
	end
	for field, range in pairs(ranges) do
		if defaults[field] ~= nil then
			settings[field] = math.min(math.max(math.floor(settings[field] + 0.5), range.min), range.max)
		end
	end
	for _, field in ipairs(fontFields) do
		if settings[field] ~= nil and type(settings[field]) ~= "string" then
			settings[field] = nil
		end
	end
end

local function CleanPosition(position, defaults)
	if not ns.AuraPointsByKey[position.point] then
		position.point = defaults.point
	end
	if not ns.AuraPointsByKey[position.anchorPoint] then
		position.anchorPoint = defaults.anchorPoint
	end
	if not ns.AuraAnchorTargetsByKey[position.anchorTo] then
		position.anchorTo = defaults.anchorTo
	end
end

local function CleanGroup(settings, defaults)
	CleanFields(settings, defaults, NUMBER_RANGES, { "font" })
	if defaults.growth and not ns.AuraGrowthsByKey[settings.growth] then
		settings.growth = defaults.growth
	end
	if defaults.point then
		CleanPosition(settings, defaults)
	end
	if defaults.mode then
		if not ns.AuraModesByKey[settings.mode] then
			settings.mode = defaults.mode
		end
		if type(settings.list) ~= "table" then
			settings.list = {}
		end
		CleanFields(settings.list, LIST_DEFAULTS, LIST_RANGES, { "nameFont", "timeFont" })
		if settings.list.iconSide ~= "LEFT" and settings.list.iconSide ~= "RIGHT" then
			settings.list.iconSide = LIST_DEFAULTS.iconSide
		end
		CleanPosition(settings.list, LIST_DEFAULTS)
	end
end

-- Fills in what's missing and corrects what's out of range. Returns the table.
function ns.CleanAuraSettings(auras)
	if type(auras) ~= "table" then
		auras = {}
	end
	for key, settings in pairs(auras) do
		if not GROUP_DEFAULTS[key] or type(settings) ~= "table" then
			auras[key] = nil
		end
	end
	for key, defaults in pairs(GROUP_DEFAULTS) do
		auras[key] = auras[key] or {}
		CleanGroup(auras[key], defaults)
	end
	return auras
end

-- Spell IDs to full durations, 0 for buffs that never expire. Only whole numbers above 0 are spell IDs.
function ns.CleanLearnedBuffs(learned)
	if type(learned) ~= "table" then
		return {}
	end
	for spellID, duration in pairs(learned) do
		if type(spellID) ~= "number" or spellID <= 0 or spellID ~= math.floor(spellID)
			or type(duration) ~= "number" or duration < 0 then
			learned[spellID] = nil
		end
	end
	return learned
end

local function GetAnchorTarget(key)
	if key == "root" then
		return ns.root
	elseif key == "orb" then
		return DibsUIOrb
	elseif key == "minimap" then
		return Minimap
	end
	return UIParent
end

-- Blizzard's own buff timer style: one unit, abbreviated, seconds only under a minute and a half.
-- Blizzard's aura container uses the same style for real buffs, so test buffs match them.
local timeFormatter
local function GetTimeFormatter()
	if not timeFormatter then
		local bands = C_CurveUtil.CreateCurve()
		bands:SetType(Enum.LuaCurveType.Step)
		bands:AddPoint(0, Enum.SecondsFormatterInterval.Seconds)
		bands:AddPoint(1 + 1.5 * 60, Enum.SecondsFormatterInterval.Minutes)
		bands:AddPoint(1 + 1.5 * 3600, Enum.SecondsFormatterInterval.Hours)
		bands:AddPoint(1 + 1.5 * 86400, Enum.SecondsFormatterInterval.Days)
		timeFormatter = C_StringUtil.CreateSecondsFormatter()
		timeFormatter:SetDefaultAbbreviation(Enum.SecondsFormatterAbbreviation.OneLetter)
		timeFormatter:SetRounding(Enum.SecondsFormatterRounding.Truncate)
		timeFormatter:SetCanRoundUpLastUnit(true)
		timeFormatter:SetMinInterval(Enum.SecondsFormatterInterval.Seconds)
		timeFormatter:SetMaxIntervalCurve(bands)
		timeFormatter:SetDesiredUnitCount(1)
	end
	return timeFormatter
end

-- Sample buffs for test mode, in the order they'd be applied. Durations are in seconds, and
-- remaining is how much is left when test mode starts.
local TEST_LONG_BUFFS = {
	{ name = "Power Word: Fortitude", icon = "Interface\\Icons\\Spell_Holy_WordFortitude", duration = 3600, remaining = 3312 },
	{ name = "Mark of the Wild", icon = "Interface\\Icons\\Spell_Nature_Regeneration", duration = 3600, remaining = 2710 },
	{ name = "Arcane Intellect", icon = "Interface\\Icons\\Spell_Holy_MagicalSentry", duration = 3600, remaining = 1905 },
	{ name = "Blessing of Kings", icon = "Interface\\Icons\\Spell_Magic_GreaterBlessingofKings", duration = 1800, remaining = 1260 },
	{ name = "Flask of Endless Rage", icon = "Interface\\Icons\\INV_Alchemy_Endlessflask_06", duration = 7200, remaining = 6480 },
	{ name = "Well Fed", icon = "Interface\\Icons\\Spell_Misc_Food", duration = 3600, remaining = 845 },
	{ name = "Shadow Protection", icon = "Interface\\Icons\\Spell_Shadow_AntiShadow", duration = 600, remaining = 412 },
	{ name = "Battle Shout", icon = "Interface\\Icons\\Ability_Warrior_BattleShout", duration = 180, remaining = 150 },
	{ name = "Thorns", icon = "Interface\\Icons\\Spell_Nature_Thorns", duration = 600, remaining = 95 },
	{ name = "Water Walking", icon = "Interface\\Icons\\Spell_Frost_WindWalkOn", duration = 600, remaining = 38 },
	{ name = "Devotion Aura", icon = "Interface\\Icons\\Spell_Holy_DevotionAura" },
	{ name = "Trueshot Aura", icon = "Interface\\Icons\\Ability_TrueShot" },
}

local TEST_SHORT_BUFFS = {
	{ name = "Bloodlust", icon = "Interface\\Icons\\Spell_Nature_BloodLust", duration = 40, remaining = 31 },
	{ name = "Clearcasting", icon = "Interface\\Icons\\Spell_Shadow_ManaBurn", duration = 15, remaining = 11 },
	{ name = "Power Infusion", icon = "Interface\\Icons\\Spell_Holy_PowerInfusion", duration = 20, remaining = 17 },
	{ name = "Bloodrage", icon = "Interface\\Icons\\Ability_Racial_BloodRage", duration = 10, remaining = 7 },
	{ name = "Sprint", icon = "Interface\\Icons\\Ability_Rogue_Sprint", duration = 15, remaining = 9 },
}

-- Weapon enchants show at the start of the long buffs, main hand first, as on Blizzard's buff frame.
local TEST_ENCHANTS = {
	{ name = "Instant Poison", icon = "Interface\\Icons\\Ability_Poisons", duration = 1800, remaining = 1420 },
	{ name = "Brilliant Wizard Oil", icon = "Interface\\Icons\\INV_Potion_105", duration = 1800, remaining = 655 },
}

ns.auraTestMode = false

-- Masque, when it's installed, can skin the icons. Each group is its own group in Masque's settings.
-- It's looked up at login, once every addon has loaded, whatever order they loaded in.
ns.hasMasque = false

local groups = {}

local function IsMasqueSkinned(group)
	return group.masque ~= nil and not group.masque.db.Disabled
end

-- Groups that aren't built yet count as off.
local function IsGroupEnabled(groupKey)
	local settings = ns.db.auras[groupKey]
	return settings ~= nil and settings.enabled == true
end

local function IsListMode(settings)
	return settings.mode == "list"
end

local function GetMode(group)
	return IsListMode(group.settings) and "list" or "standard"
end

-- While aura details are secret, in combat and in some instances, addon code can't read the player's
-- buffs at all, or touch the buttons in Blizzard's aura containers. Blizzard's containers keep
-- showing and sorting buffs by themselves, so DibsUI only waits.
local function AreAurasSecret()
	return C_Secrets ~= nil and C_Secrets.ShouldAurasBeSecret ~= nil and C_Secrets.ShouldAurasBeSecret() == true
end

-- Learning ------------------------------------------------------------------------------------

-- Spell IDs of the buffs long enough to be long buffs. Blizzard's containers sort buffs by this list
-- themselves, even while buffs are secret. It starts from every long aura in the game client
-- (SpellDurations.lua) and takes in the durations DibsUI sees, which win, so talents and hotfixes
-- count. A buff on neither shows with the short buffs until it can be read.
local longSpells = {}
-- How many buffs each group showed when they could last be read, which sizes the frames' drag handles.
local readableCounts = { long = 0, all = 0 }

local function IsLongDuration(duration)
	return duration == 0 or duration > LONG_BUFF_SECONDS
end

local function RebuildLongSpells()
	wipe(longSpells)
	for _, spellID in ipairs(ns.LongBuffSpells or {}) do
		longSpells[spellID] = true
	end
	for spellID, duration in pairs(ns.account.learnedBuffs) do
		longSpells[spellID] = IsLongDuration(duration) or nil
	end
end

local function IsReadable(aura)
	return aura ~= nil and not issecretvalue(aura) and not issecretvalue(aura.spellId)
		and not issecretvalue(aura.duration) and not issecretvalue(aura.expirationTime)
end

-- Records every current buff's full duration. Returns whether the long buff list or the counts changed.
local function LearnBuffs()
	if AreAurasSecret() then
		return false
	end
	local ok, auraInstanceIDs = pcall(C_UnitAuras.GetUnitAuraInstanceIDs, "player", "HELPFUL")
	if not ok or issecretvalue(auraInstanceIDs) or type(auraInstanceIDs) ~= "table" then
		return false
	end
	local learned = ns.account.learnedBuffs
	local listChanged = false
	local counts = { long = 0, all = 0 }
	for _, auraInstanceID in ipairs(auraInstanceIDs) do
		local aura = not issecretvalue(auraInstanceID) and C_UnitAuras.GetAuraDataByAuraInstanceID("player", auraInstanceID)
		if IsReadable(aura) and aura.spellId then
			local duration = (aura.duration == 0 or aura.expirationTime == 0) and 0 or aura.duration
			if learned[aura.spellId] ~= duration then
				learned[aura.spellId] = duration
				local isLong = IsLongDuration(duration)
				if (longSpells[aura.spellId] == true) ~= isLong then
					longSpells[aura.spellId] = isLong or nil
					listChanged = true
				end
			end
		end
		counts.all = counts.all + 1
		if aura and not issecretvalue(aura) and not issecretvalue(aura.spellId) and longSpells[aura.spellId] then
			counts.long = counts.long + 1
		end
	end
	local countsChanged = counts.long ~= readableCounts.long or counts.all ~= readableCounts.all
	readableCounts = counts
	return listChanged or countsChanged
end

-- What a group's container lets through: long buffs take the list's spells and short buffs the rest,
-- and either takes every buff while the other is off.
local function GetCandidateFilters(groupKey)
	if groupKey == "playerLongBuffs" then
		return IsGroupEnabled("playerShortBuffs") and { includeSpellIDs = longSpells } or nil
	end
	return IsGroupEnabled("playerLongBuffs") and { excludeSpellIDs = longSpells } or nil
end

local function GetReadableCount(groupKey)
	local otherKey = groupKey == "playerLongBuffs" and "playerShortBuffs" or "playerLongBuffs"
	if not IsGroupEnabled(otherKey) then
		return readableCounts.all
	end
	if groupKey == "playerLongBuffs" then
		return readableCounts.long
	end
	return readableCounts.all - readableCounts.long
end

-- Test buffs ----------------------------------------------------------------------------------

-- Test buffs start over when they run out, so test mode can be left on. Each group shows its own
-- samples, plus the other group's while that one is off.
local testStart
local function AddTestBuffs(list, buffs)
	local now = GetTime()
	for _, buff in ipairs(buffs) do
		local expiration = math.huge
		if buff.duration then
			expiration = testStart + buff.remaining
			while expiration <= now do
				expiration = expiration + buff.duration
			end
		end
		list[#list + 1] = { name = buff.name, icon = buff.icon, duration = buff.duration, expiration = expiration, order = #list + 1 }
	end
end

local function ReadTestBuffs(groupKey)
	local list = {}
	local function Add(buffs)
		AddTestBuffs(list, buffs)
	end
	local isLong = groupKey == "playerLongBuffs"
	local otherKey = isLong and "playerShortBuffs" or "playerLongBuffs"
	if isLong or not IsGroupEnabled(otherKey) then
		Add(TEST_LONG_BUFFS)
	end
	if not isLong or not IsGroupEnabled(otherKey) then
		Add(TEST_SHORT_BUFFS)
	end
	return list
end

-- Soonest to expire first, or the longest first in list mode. Buffs that never expire count as the
-- longest. Ties keep the order they were applied in. Blizzard's containers sort real buffs the same way.
local function SortBuffs(list, longestFirst)
	table.sort(list, function(a, b)
		if a.expiration ~= b.expiration then
			if longestFirst then
				return a.expiration > b.expiration
			end
			return a.expiration < b.expiration
		end
		return a.order < b.order
	end)
end

-- Icons -----------------------------------------------------------------------------------------

-- The textures and texts DibsUI puts on a button, whether it's a test icon or one of Blizzard's.
local function CreateParts(button)
	local parts = { button = button }
	parts.border = button:CreateTexture(nil, "BACKGROUND", nil, -8)
	parts.border:SetAllPoints()
	parts.border:SetColorTexture(0, 0, 0, 1)
	parts.icon = button:CreateTexture(nil, "ARTWORK")
	-- Every text gets a font straight away, since Blizzard fills them in as soon as they're handed over.
	parts.count = button:CreateFontString(nil, "OVERLAY")
	parts.count:SetFont(ns.Text.font, 12, "OUTLINE")
	parts.time = button:CreateFontString(nil, "OVERLAY")
	parts.time:SetFont(ns.Text.font, 11, "OUTLINE")
	parts.name = button:CreateFontString(nil, "OVERLAY")
	parts.name:SetFont(ns.Text.font, LIST_DEFAULTS.nameSize, "OUTLINE")
	return parts
end

-- DibsUI's own look: a thin black border, with the icon's baked-in border cropped off. Under a
-- Masque skin, Masque draws the icon, border and stack count instead.
local function ApplyOwnSkin(parts)
	parts.border:Show()
	-- Masque moves the icon down a layer when its skin is turned off, which would put it under the border.
	parts.icon:SetDrawLayer("ARTWORK", 0)
	parts.icon:ClearAllPoints()
	parts.icon:SetPoint("TOPLEFT", BORDER, -BORDER)
	parts.icon:SetPoint("BOTTOMRIGHT", -BORDER, BORDER)
	parts.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	parts.count:ClearAllPoints()
	parts.count:SetPoint("BOTTOMRIGHT", -1, 2)
end

-- A font that can't be loaded any more falls back to the default.
local function SetFontStyle(fontString, font, size)
	if not fontString:SetFont(font or ns.Text.font, size, "OUTLINE") then
		fontString:SetFont(ns.Text.font, size, "OUTLINE")
	end
end

local function SetTextStyle(fontString, font, size, color)
	SetFontStyle(fontString, font, size)
	fontString:SetTextColor(color[1], color[2], color[3])
end

-- Blizzard's time text keeps its color secret, so its color is handed to Blizzard as a curve that's
-- the same color at every remaining time. Test icons are DibsUI's own and set it directly.
local function SetTimeStyle(parts, font, size, color)
	SetFontStyle(parts.time, font, size)
	if not parts.isContainer then
		parts.time:SetTextColor(color[1], color[2], color[3])
		return
	end
	local curve = C_CurveUtil.CreateColorCurve()
	curve:AddPoint(0, CreateColor(color[1], color[2], color[3], 1))
	parts.button:SetDurationText(parts.time, {
		textColor = { curve = curve, property = Enum.DurationTextBindingProperty.RemainingDuration },
	})
end

-- Masque fits its skin to a button's size, but Blizzard's aura buttons can keep their size secret, which
-- would leave Masque using the size it first saw. DibsUI tells Masque the size it set instead. Masque
-- only takes it for a button already in the group; otherwise it would apply it to every button.
local function TellMasqueSize(group, parts, reskin)
	local masque = group.masque
	if masque and masque.SetFrameSize and masque.Buttons and masque.Buttons[parts.button] and parts.size then
		masque:SetFrameSize(parts.size, parts.size, parts.button, true, not reskin)
	end
end

-- Standard mode puts the time under the icon. List mode puts the name level with the icon's top
-- and the time level with its bottom, on whichever side the icon isn't.
local function StyleParts(group, mode, parts)
	local settings = group.settings
	local isList = mode == "list"
	local style = isList and settings.list or settings
	local button = parts.button
	button:SetSize(style.iconSize, style.iconSize)
	parts.size = style.iconSize
	-- The reskin comes with the next refresh of every group.
	TellMasqueSize(group, parts, false)
	if IsMasqueSkinned(group) then
		parts.border:Hide()
	else
		ApplyOwnSkin(parts)
	end
	parts.count:SetFont(ns.Text.font, math.max(math.floor(style.iconSize * 0.4), 8), "OUTLINE")
	parts.time:ClearAllPoints()
	parts.name:ClearAllPoints()
	if isList then
		local list = settings.list
		local justify = list.iconSide == "LEFT" and "LEFT" or "RIGHT"
		SetTextStyle(parts.name, list.nameFont, list.nameSize, list.nameColor)
		SetTimeStyle(parts, list.timeFont, list.timeSize, list.timeColor)
		if list.iconSide == "LEFT" then
			parts.name:SetPoint("TOPLEFT", button, "TOPRIGHT", LIST_TEXT_GAP, 0)
			parts.time:SetPoint("BOTTOMLEFT", button, "BOTTOMRIGHT", LIST_TEXT_GAP, 0)
		else
			parts.name:SetPoint("TOPRIGHT", button, "TOPLEFT", -LIST_TEXT_GAP, 0)
			parts.time:SetPoint("BOTTOMRIGHT", button, "BOTTOMLEFT", -LIST_TEXT_GAP, 0)
		end
		parts.name:SetJustifyH(justify)
		parts.time:SetJustifyH(justify)
	else
		SetTimeStyle(parts, settings.font, settings.textSize, settings.textColor)
		parts.time:SetPoint("TOP", button, "BOTTOM", 0, -TIME_GAP)
		parts.time:SetJustifyH("CENTER")
	end
	-- Test icons show the name only in list mode. Blizzard's buttons only fill it in list mode.
	if parts.isTest then
		parts.name:SetShown(isList)
	end
end

-- The time text stays out of Masque, which would size it to the skin and could cut it off.
local function AddToMasque(group, parts)
	if group.masque then
		group.masque:AddButton(parts.button, { Icon = parts.icon, Count = parts.count, Duration = false }, "Buff")
		TellMasqueSize(group, parts, true)
	end
end

local function OnTestIconEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
	GameTooltip:SetText(self.testName)
	GameTooltip:AddLine("Test buff", 0.6, 0.6, 0.6)
	GameTooltip:Show()
end

local function OnTestIconLeave()
	GameTooltip:Hide()
end

local function CreateTestIcon(group)
	local button = CreateFrame("Button", nil, group.holder)
	button:SetScript("OnEnter", OnTestIconEnter)
	button:SetScript("OnLeave", OnTestIconLeave)
	local parts = CreateParts(button)
	parts.isTest = true
	parts.binding = C_DurationUtil.CreateDurationTextBinding()
	parts.binding:SetFontString(parts.time)
	parts.binding:SetFormatter(GetTimeFormatter())
	parts.binding:SetZeroDurationText("")
	parts.binding:SetExpiredText("")
	parts.duration = C_DurationUtil.CreateDuration()
	return parts
end

local function ShowTestAura(parts, data)
	parts.button.testName = data.name
	parts.icon:SetTexture(data.icon)
	parts.name:SetText(data.name)
	parts.count:SetText("")
	if data.duration then
		parts.duration:SetTimeFromEnd(data.expiration, data.duration, 1)
	else
		parts.duration:SetTimeSpan(0, 0)
	end
	parts.binding:SetDuration(parts.duration)
	parts.binding:SetEnabled(true)
end

-- Layout ------------------------------------------------------------------------------------------

local FLOW_AXIS = { horizontal = 0, vertical = 1 }
local FLOW_DIRECTION = { LEFT = -1, RIGHT = 1, UP = 1, DOWN = -1 }

-- The short buffs are as wide as the player bar.
local function GetPlayerBody()
	return DibsUIPlayerHealth and DibsUIPlayerHealth.body
end

-- How a group's icons are laid out. The same numbers drive Blizzard's container and the test icons,
-- so test mode shows exactly where real buffs go. Elements are the space each buff takes: in standard
-- mode that's the icon plus its time text, and in list mode the icon plus room for its name.
local function GetLayout(group, mode)
	local settings = group.settings
	local layout = {}
	if mode == "list" then
		local list = settings.list
		local left = list.iconSide == "LEFT"
		layout.vertical = true
		layout.anchor = left and "TOPLEFT" or "TOPRIGHT"
		layout.signX, layout.signY = left and 1 or -1, -1
		layout.width = list.iconSize + LIST_TEXT_GAP + LIST_TEXT_WIDTH
		layout.height = list.iconSize
		layout.spacing = list.spacing
		layout.lineSize = math.huge
		layout.padY = 0
	else
		local growthKey = group.key == "playerShortBuffs" and SHORT_BUFF_GROWTH or settings.growth
		local growth = ns.AuraGrowthsByKey[growthKey]
		local function Has(direction)
			return growth.line == direction or growth.wrap == direction
		end
		local textHeight = TIME_GAP + settings.textSize + 1
		layout.vertical = growth.line == "UP" or growth.line == "DOWN"
		layout.anchor = (Has("UP") and "BOTTOM" or "TOP") .. (Has("LEFT") and "RIGHT" or "LEFT")
		layout.signX, layout.signY = Has("LEFT") and -1 or 1, Has("UP") and 1 or -1
		layout.width = settings.iconSize
		layout.height = settings.iconSize + textHeight
		layout.spacing = settings.spacing
		if group.key == "playerShortBuffs" then
			local body = GetPlayerBody()
			layout.lineSize = body and body:GetWidth() or 200
		else
			layout.lineSize = settings.frameSize
		end
		-- Icons placed from the bottom leave room under them for their time text.
		layout.padY = Has("UP") and textHeight or 0
	end
	layout.lineSize = math.max(layout.lineSize, 1)
	return layout
end

local function GetPerLine(layout, count)
	if layout.lineSize == math.huge then
		return math.max(count, 1)
	end
	local primary = layout.vertical and layout.height or layout.width
	return math.max(math.floor((layout.lineSize + layout.spacing) / (primary + layout.spacing)), 1)
end

-- Where the nth buff goes from the group's starting corner, the way Blizzard's flow layout places it.
local function GetElementOffset(layout, index, perLine)
	local along, across = (index - 1) % perLine, math.floor((index - 1) / perLine)
	local primaryStep = (layout.vertical and layout.height or layout.width) + layout.spacing
	local crossStep = (layout.vertical and layout.width or layout.height) + layout.spacing
	local x, y
	if layout.vertical then
		x, y = across * crossStep, along * primaryStep
	else
		x, y = along * primaryStep, across * crossStep
	end
	return layout.signX * x, layout.signY * (layout.padY + y)
end

-- The holder is the frame's own outline: as long as its size setting along the way lines fill, and as
-- deep as the lines its buffs need, at least one. Blizzard's containers keep their own size secret.
local function SizeHolder(group, layout, count)
	local perLine = GetPerLine(layout, count)
	local lines = math.max(math.ceil(count / perLine), 1)
	local primaryCount = math.min(math.max(count, 1), perLine)
	local function Span(size, n)
		return n * (size + layout.spacing) - layout.spacing
	end
	local width, height
	if layout.vertical then
		width = Span(layout.width, lines)
		height = layout.lineSize == math.huge and Span(layout.height, primaryCount) or layout.lineSize
	else
		width = layout.lineSize == math.huge and Span(layout.width, primaryCount) or layout.lineSize
		height = Span(layout.height, lines) + layout.padY
	end
	group.holder:SetSize(math.max(width, 1), math.max(height, 1))
end

local function LayoutTestIcons(group, layout, count)
	local perLine = GetPerLine(layout, count)
	for i = 1, count do
		local button = group.testIcons[i].button
		local x, y = GetElementOffset(layout, i, perLine)
		button:ClearAllPoints()
		button:SetPoint(layout.anchor, group.holder, layout.anchor, x, y)
	end
end

local ENCHANTS_BEFORE_BUFFS = 0

-- Weapon enchants are their own group in the layout, ahead of the buffs, and the buffs carry on from
-- them along the same line. The flow layout already leaves the spacing after each icon, so the
-- groups need no gap of their own.
local function ConfigureContainer(container, layout, hasEnchants)
	container:SetFlowLayoutAxis(layout.vertical and FLOW_AXIS.vertical or FLOW_AXIS.horizontal)
	container:SetFlowLayoutGrowthDirection(layout.signX > 0 and FLOW_DIRECTION.RIGHT or FLOW_DIRECTION.LEFT,
		layout.signY > 0 and FLOW_DIRECTION.UP or FLOW_DIRECTION.DOWN)
	container:SetFlowLayoutAnchorPoint(layout.anchor)
	container:SetFlowLayoutPadding(0, 0, 0, layout.padY)
	container:SetFlowLayoutMaximumLineSize(layout.lineSize)
	local groupLayout = {
		elementSpacing = layout.spacing,
		lineSpacing = layout.spacing,
		groupSpacing = 0,
		groupLineSpacing = layout.spacing,
		elementWidth = layout.width,
		elementHeight = layout.height,
	}
	container:SetAuraGroupLayout("buffs", groupLayout)
	if hasEnchants then
		local placement = CustomAuraContainerItemEnchantmentPlacement
		groupLayout.placement = placement and placement.BeforeAuraGroups or ENCHANTS_BEFORE_BUFFS
		container:SetItemEnchantmentLayout(groupLayout)
	end
end

-- How many weapons have a temporary enchant, such as a poison or an oil. Only sizes the drag handle.
local function CountWeaponEnchants()
	if not GetWeaponEnchantInfo then
		return 0
	end
	local info = { pcall(GetWeaponEnchantInfo) }
	if not info[1] then
		return 0
	end
	local count = 0
	-- After pcall's own result: main hand, off hand and ranged each start a group of four.
	for _, position in ipairs({ 2, 6, 10 }) do
		if not issecretvalue(info[position]) and info[position] == true then
			count = count + 1
		end
	end
	return count
end

-- Placement -----------------------------------------------------------------------------------------

-- The table holding the frame's point, target and offsets: list mode keeps its own.
local function GetPosition(settings)
	return IsListMode(settings) and settings.list or settings
end

-- How far above the player bar the short buffs sit: clear of the name's line while the name is on.
-- The name's height is taken from its font size, since a name's own measurements can be secret.
local function GetNameClearance()
	if not ns.GetTextOption("playerName", "enabled") then
		return NAME_CLEARANCE
	end
	local spec = ns.Text.playerName
	return spec.y + ns.GetTextOption("playerName", "offsetY") + ns.GetTextOption("playerName", "size") + 2 + NAME_CLEARANCE
end

local function PlaceHolder(group)
	local holder = group.holder
	holder:ClearAllPoints()
	if group.key == "playerShortBuffs" then
		local body = GetPlayerBody()
		if body then
			holder:SetPoint("BOTTOMRIGHT", body, "TOPRIGHT", 0, GetNameClearance())
		end
		return
	end
	local position = GetPosition(group.settings)
	holder:SetPoint(position.point, GetAnchorTarget(position.anchorTo), position.anchorPoint, position.x, position.y)
end

-- Updates --------------------------------------------------------------------------------------------

-- Restyles Blizzard's buttons, which addon code can only do while buffs can be read. A change made
-- in combat waits until it ends.
local function StyleContainerButtons(group)
	if AreAurasSecret() then
		group.styleWaiting = true
		return
	end
	group.styleWaiting = false
	for mode, records in pairs(group.records) do
		for _, parts in ipairs(records) do
			StyleParts(group, mode, parts)
		end
	end
end

local function ShowTestIcons(group, mode, layout)
	local list = ReadTestBuffs(group.key)
	SortBuffs(list, mode == "list")
	if group.key == "playerLongBuffs" then
		local enchants = {}
		AddTestBuffs(enchants, TEST_ENCHANTS)
		for i = #enchants, 1, -1 do
			table.insert(list, 1, enchants[i])
		end
	end
	for i, data in ipairs(list) do
		local parts = group.testIcons[i]
		if not parts then
			parts = CreateTestIcon(group)
			group.testIcons[i] = parts
			AddToMasque(group, parts)
		end
		StyleParts(group, mode, parts)
		ShowTestAura(parts, data)
		parts.button:Show()
	end
	for i = #list + 1, #group.testIcons do
		local parts = group.testIcons[i]
		parts.button:Hide()
		parts.binding:SetEnabled(false)
	end
	LayoutTestIcons(group, layout, #list)

	-- The buffs are read again each time one runs out and starts over.
	local nextExpiry = math.huge
	for _, data in ipairs(list) do
		nextExpiry = math.min(nextExpiry, data.expiration)
	end
	group.nextTestExpiry = nextExpiry
	return #list
end

local function HideTestIcons(group)
	for _, parts in ipairs(group.testIcons) do
		parts.button:Hide()
		parts.binding:SetEnabled(false)
	end
	group.nextTestExpiry = math.huge
end

local function UpdateGroup(group)
	local settings = group.settings
	local mode = GetMode(group)
	group.holder:SetShown(settings.enabled)
	-- Only the container for the mode in use runs. Test mode shows DibsUI's own icons instead.
	for containerMode, container in pairs(group.containers) do
		container:SetShown(settings.enabled and not ns.auraTestMode and containerMode == mode)
	end
	if not settings.enabled then
		HideTestIcons(group)
		return
	end

	local layout = GetLayout(group, mode)
	PlaceHolder(group)

	local count
	if ns.auraTestMode then
		count = ShowTestIcons(group, mode, layout)
	else
		HideTestIcons(group)
		local container = group.containers[mode]
		local hasEnchants = group.key == "playerLongBuffs"
		if container then
			ConfigureContainer(container, layout, hasEnchants)
			container:SetAuraGroupCandidateFilters("buffs", GetCandidateFilters(group.key))
			container:ClearAllPoints()
			container:SetPoint(layout.anchor, group.holder, layout.anchor)
		end
		count = GetReadableCount(group.key)
		if hasEnchants and not AreAurasSecret() then
			count = count + CountWeaponEnchants()
		end
	end
	StyleContainerButtons(group)
	SizeHolder(group, layout, count)
end

-- Moving -----------------------------------------------------------------------------------------------

-- Where a point of a region is, in the base UI units every region shares.
local function GetPointPosition(region, point)
	local left, right, top, bottom = region:GetLeft(), region:GetRight(), region:GetTop(), region:GetBottom()
	local x = point:find("LEFT") and left or point:find("RIGHT") and right or (left + right) / 2
	local y = point:find("TOP") and top or point:find("BOTTOM") and bottom or (top + bottom) / 2
	local scale = region:GetEffectiveScale()
	return x * scale, y * scale
end

-- After a drag, works out the offsets that keep the frame where it was dropped, from the point and
-- target the settings name.
local function FinishMoving(group)
	if not group.isMoving then
		return
	end
	local holder = group.holder
	group.isMoving = false
	holder:StopMovingOrSizing()
	holder:SetUserPlaced(false)
	local settings = group.settings
	local position = GetPosition(settings)
	local frameX, frameY = GetPointPosition(holder, position.point)
	local targetX, targetY = GetPointPosition(GetAnchorTarget(position.anchorTo), position.anchorPoint)
	local scale = holder:GetEffectiveScale()
	position.x = (frameX - targetX) / scale
	position.y = (frameY - targetY) / scale
	CleanGroup(settings, GROUP_DEFAULTS[group.key])
	PlaceHolder(group)
	if ns.OnAuraSettingsMoved then
		ns.OnAuraSettingsMoved(group.key)
	end
end

-- A tinted handle over the frame while the frames are unlocked.
local function CreateMover(group)
	local mover = CreateFrame("Frame", nil, UIParent)
	mover:SetAllPoints(group.holder)
	mover:SetFrameStrata("MEDIUM")
	mover:EnableMouse(true)
	mover:RegisterForDrag("LeftButton")
	mover:Hide()

	local tint = ns.CreateArt(mover, "BACKGROUND", "Flat")
	tint:SetAllPoints()
	tint:SetVertexColor(0.15, 0.45, 1, 0.3)

	local text = mover:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	text:SetPoint("CENTER")
	text:SetText(group.label)

	mover:SetScript("OnDragStart", function()
		group.isMoving = true
		group.holder:StartMoving()
	end)
	mover:SetScript("OnDragStop", function()
		FinishMoving(group)
	end)
	return mover
end

function ns.UpdateAuraMovers()
	local unlocked = not ns.db.locked and not InCombatLockdown()
	for _, group in pairs(groups) do
		if group.mover then
			if not unlocked then
				FinishMoving(group)
			end
			group.mover:SetShown(unlocked and group.settings.enabled)
		end
	end
end

-- Blizzard's buff frame goes while either buff group is on. Its debuffs are a separate frame and stay.
local function UpdateBlizzardBuffFrame()
	if not BuffFrame or (InCombatLockdown() and BuffFrame:IsProtected()) then
		return
	end
	local replaced = IsGroupEnabled("playerLongBuffs") or IsGroupEnabled("playerShortBuffs")
	BuffFrame:SetParent(replaced and ns.hiddenParent or UIParent)
end

-- Puts every group where the current profile says, with what it should show.
function ns.RefreshAuraFrames()
	for key, group in pairs(groups) do
		group.settings = ns.db.auras[key]
		UpdateGroup(group)
		-- Masque fits a skin to the icon's size when it applies it, so a new size needs a reskin.
		if IsMasqueSkinned(group) and not AreAurasSecret() then
			group.masque:ReSkin()
		end
	end
	ns.UpdateAuraMovers()
	UpdateBlizzardBuffFrame()
end

function ns.GetAuraSettings(groupKey)
	return ns.db.auras[groupKey]
end

-- Changes one setting and shows the result. Returns the value in effect, which may be corrected.
function ns.SetAuraOption(groupKey, field, value)
	local settings = ns.db.auras[groupKey]
	settings[field] = value
	CleanGroup(settings, GROUP_DEFAULTS[groupKey])
	ns.RefreshAuraFrames()
	return settings[field]
end

-- The same for one of list mode's settings.
function ns.SetAuraListOption(groupKey, field, value)
	local settings = ns.db.auras[groupKey]
	settings.list[field] = value
	CleanGroup(settings, GROUP_DEFAULTS[groupKey])
	ns.RefreshAuraFrames()
	return settings.list[field]
end

function ns.SetAuraTestMode(enabled)
	ns.auraTestMode = enabled
	testStart = GetTime()
	ns.RefreshAuraFrames()
end

-- Blizzard's containers ------------------------------------------------------------------------------

-- Sets up one of Blizzard's buttons the moment the container makes it. Blizzard keeps it filled in
-- from then on: icon, stack count, time, and the name in list mode. Its tooltip and right-click to
-- cancel are Blizzard's own.
local function InitContainerButton(group, mode, button)
	local ok, err = pcall(function()
		local parts = CreateParts(button)
		parts.isContainer = true
		button:SetIcon(parts.icon)
		button:SetApplicationCount(parts.count)
		if mode == "list" then
			button:SetSpellName(parts.name)
		else
			parts.name:Hide()
		end
		button:SetCancelAuraButtons("RightButtonUp")
		local records = group.records[mode]
		records[#records + 1] = parts
		StyleParts(group, mode, parts)
		AddToMasque(group, parts)
	end)
	if not ok then
		geterrorhandler()(err)
	end
end

local SORT_EXPIRATION_ONLY = 5
local SORT_NORMAL, SORT_REVERSE = 0, 1

-- Standard mode shows the soonest to expire first and list mode the longest first, with buffs that
-- never expire counted as the longest either way.
local function CreateContainer(group, mode)
	local ok, container = pcall(CreateFrame, "AuraContainer", nil, group.holder, "CustomAuraContainerTemplate")
	if not ok then
		geterrorhandler()(container)
		return
	end
	group.records[mode] = {}
	container:Hide()
	container:SetUnit("player")
	local sortMethod = AuraContainerSortMethod and AuraContainerSortMethod.ExpirationOnly or SORT_EXPIRATION_ONLY
	local directions = AuraContainerSortDirection or { Normal = SORT_NORMAL, Reverse = SORT_REVERSE }
	container:AddAuraGroup("buffs", "HELPFUL", {
		sortMethod = sortMethod,
		sortDirection = mode == "list" and directions.Reverse or directions.Normal,
		candidateFilters = GetCandidateFilters(group.key),
		initializeFrame = function(button)
			InitContainerButton(group, mode, button)
		end,
	})
	-- The long buffs also show weapon enchants: main hand, off hand and ranged. Blizzard fills them in
	-- and cancels them on right-click, as with buffs. In list mode the name is the weapon's.
	if group.key == "playerLongBuffs" then
		local slots = AuraContainerItemEnchantmentSlot or { MainHand = 0, OffHand = 1, Ranged = 2 }
		for _, slot in ipairs({ slots.MainHand, slots.OffHand, slots.Ranged }) do
			local added, err = pcall(container.AddItemEnchantment, container, slot, {
				initializeFrame = function(button)
					InitContainerButton(group, mode, button)
				end,
			})
			if not added then
				geterrorhandler()(err)
			end
		end
	end
	group.containers[mode] = container
end

local function CreateContainers()
	if C_AddOns and C_AddOns.IsAddOnLoaded and not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
		pcall(C_AddOns.LoadAddOn, "Blizzard_AuraContainer")
	end
	CreateContainer(groups.playerLongBuffs, "standard")
	CreateContainer(groups.playerLongBuffs, "list")
	CreateContainer(groups.playerShortBuffs, "standard")
end

local function SetUpMasque()
	local Masque = LibStub and LibStub("Masque", true)
	if not Masque then
		return
	end
	ns.hasMasque = true
	for key, group in pairs(groups) do
		group.masque = Masque:Group("DibsUI", group.label, key)
		-- Turning the skin off in Masque puts DibsUI's own look back.
		group.masque:RegisterCallback(function()
			ns.RefreshAuraFrames()
		end)
		for _, parts in ipairs(group.testIcons) do
			AddToMasque(group, parts)
		end
		for _, records in pairs(group.records) do
			for _, parts in ipairs(records) do
				AddToMasque(group, parts)
			end
		end
	end
end

local function CreateGroup(key, label, parent)
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetSize(1, 1)
	local group = {
		key = key,
		label = label,
		holder = holder,
		settings = ns.db.auras[key],
		containers = {},
		records = {},
		testIcons = {},
		nextTestExpiry = math.huge,
	}
	holder:SetScript("OnUpdate", function()
		if GetTime() >= group.nextTestExpiry then
			UpdateGroup(group)
		end
	end)
	groups[key] = group
	return group
end

function ns.CreateAuraFrames()
	RebuildLongSpells()

	local long = CreateGroup("playerLongBuffs", "Player long buffs", UIParent)
	long.holder:SetFrameStrata("LOW")
	long.holder:SetMovable(true)
	long.holder:SetClampedToScreen(true)
	long.holder:SetDontSavePosition(true)
	long.mover = CreateMover(long)

	-- The short buffs ride on the player bar, so they scale with DibsUI, but they keep full opacity
	-- while the bars fade, like the long buffs.
	local short = CreateGroup("playerShortBuffs", "Player short buffs", ns.root)
	short.holder:SetIgnoreParentAlpha(true)

	-- The short buffs follow the player bar's width and the name above it.
	local function RefreshShortBuffs()
		if groups.playerShortBuffs.settings then
			UpdateGroup(groups.playerShortBuffs)
		end
	end
	hooksecurefunc(ns, "UpdateBarWidths", RefreshShortBuffs)
	hooksecurefunc(ns, "SetTextStyle", RefreshShortBuffs)
	hooksecurefunc(ns, "RefreshAllText", RefreshShortBuffs)

	local events = CreateFrame("Frame")
	events:RegisterEvent("PLAYER_LOGIN")
	events:RegisterUnitEvent("UNIT_AURA", "player")
	events:RegisterEvent("PLAYER_ENTERING_WORLD")
	events:RegisterEvent("PLAYER_REGEN_DISABLED")
	events:RegisterEvent("PLAYER_REGEN_ENABLED")
	events:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_LOGIN" then
			CreateContainers()
			SetUpMasque()
			LearnBuffs()
			ns.RefreshAuraFrames()
		elseif event == "UNIT_AURA" then
			-- Blizzard's containers show the change by themselves. DibsUI only learns from it.
			if LearnBuffs() and not ns.auraTestMode then
				for _, group in pairs(groups) do
					UpdateGroup(group)
				end
			end
		elseif event == "PLAYER_REGEN_DISABLED" then
			-- This fires just before combat begins, so the movers go now rather than waiting for the lockdown.
			for _, group in pairs(groups) do
				FinishMoving(group)
				if group.mover then
					group.mover:Hide()
				end
			end
		else
			-- Buffs can be read again, so anything learned or restyled during combat catches up.
			LearnBuffs()
			ns.RefreshAuraFrames()
		end
	end)

	ns.RefreshAuraFrames()
end
