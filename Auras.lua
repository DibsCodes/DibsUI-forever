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
-- Moves a buff's time or name text from where it normally sits. Positive Y is up.
ns.AuraTextOffsetRange = { min = -50, max = 50, step = 1 }

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
	-- Moves up above the pet bar and its name while there's a pet.
	{ key = "player", label = "DibsUI player bar" },
}

-- The five groups the settings list. Only the ones marked built exist so far. Anchored groups sit on a
-- DibsUI frame and take their place and width from it, so they have no position or growth settings.
ns.AuraGroups = {
	{ key = "playerLongBuffs", label = "Player long buffs", built = true, hasListMode = true },
	{ key = "playerShortBuffs", label = "Player short buffs", built = true, anchored = true,
		anchorNote = "Sits above the player bar, as wide as it and clear of your name, and fills right, then up." },
	{ key = "playerDebuffs", label = "Player debuffs", built = true, hasListMode = true },
	{ key = "targetBuffs", label = "Target buffs", built = true },
	{ key = "targetDebuffs", label = "Target debuffs", built = true, anchored = true, hasOwnSize = true,
		anchorNote = "Sits above the target bar, as wide as it and clear of its name and level, and fills right, then up. Your own debuffs come first, at their own size. Shows while you have a target." },
}

local function ByKey(list)
	local index = {}
	for _, item in ipairs(list) do
		index[item.key] = item
	end
	return index
end

-- Player long buffs and debuffs can also show as a list, with its own settings.
ns.AuraModes = {
	{ key = "standard", label = "Standard", description = "A grid of icons with the time under each." },
	{ key = "list", label = "List", description = "One per line, longest at the top, with the name and time beside each icon." },
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
		textX = 0,
		textY = 0,
		mode = "standard",
	},
	playerShortBuffs = {
		enabled = true,
		iconSize = 26,
		spacing = 4,
		textSize = 10,
		textColor = { 1, 0.82, 0 },
		textX = 0,
		textY = 0,
	},
	-- Beside the player bar's outer end, filling up. List mode is the default and has its own place.
	playerDebuffs = {
		enabled = true,
		iconSize = 28,
		spacing = 4,
		growth = "LEFT_UP",
		frameSize = 200,
		point = "BOTTOMRIGHT",
		anchorTo = "player",
		anchorPoint = "BOTTOMLEFT",
		x = -4,
		y = 0,
		textSize = 11,
		textColor = { 1, 0.82, 0 },
		textX = 0,
		textY = 0,
		mode = "list",
	},
	-- Under the target bar, past the orb's ring, filling right towards the end of the bar.
	targetBuffs = {
		enabled = true,
		iconSize = 26,
		spacing = 4,
		growth = "RIGHT_DOWN",
		frameSize = 200,
		point = "TOPLEFT",
		anchorTo = "orb",
		anchorPoint = "CENTER",
		x = 70,
		y = -20,
		textSize = 10,
		textColor = { 1, 0.82, 0 },
		textX = 0,
		textY = 0,
	},
	-- The player's own debuffs on the target are larger, so they stand out.
	targetDebuffs = {
		enabled = true,
		iconSize = 24,
		ownIconSize = 32,
		spacing = 4,
		textSize = 10,
		textColor = { 1, 0.82, 0 },
		textX = 0,
		textY = 0,
	},
}

-- List mode's own settings, kept in a group's list table. The name is white and the time a
-- little smaller and off-white. List mode has its own position, at the top left of the screen, and
-- grows down unless growUp is set.
local LIST_DEFAULTS = {
	iconSide = "LEFT",
	growUp = false,
	iconSize = 28,
	spacing = 4,
	nameSize = 13,
	nameColor = { 1, 1, 1 },
	timeSize = 11,
	timeColor = { 0.88, 0.87, 0.82 },
	nameX = 0,
	nameY = 0,
	timeX = 0,
	timeY = 0,
	point = "TOPLEFT",
	anchorTo = "screen",
	anchorPoint = "TOPLEFT",
	x = 0,
	y = 0,
}

-- Where a group's list mode differs: the player's debuffs rise from beside the player bar, with the
-- icons on the side nearest it.
local LIST_OVERRIDES = {
	playerDebuffs = {
		iconSide = "RIGHT",
		growUp = true,
		point = "BOTTOMRIGHT",
		anchorTo = "player",
		anchorPoint = "BOTTOMLEFT",
		x = -4,
	},
}

local function GetListDefaults(groupKey)
	local defaults = {}
	for field, value in pairs(LIST_DEFAULTS) do
		defaults[field] = value
	end
	for field, value in pairs(LIST_OVERRIDES[groupKey] or {}) do
		defaults[field] = value
	end
	return defaults
end

local LIST_RANGES = {
	iconSize = ns.AuraIconSizeRange,
	spacing = ns.AuraSpacingRange,
	nameSize = ns.AuraTextSizeRange,
	timeSize = ns.AuraTextSizeRange,
	nameX = ns.AuraTextOffsetRange,
	nameY = ns.AuraTextOffsetRange,
	timeX = ns.AuraTextOffsetRange,
	timeY = ns.AuraTextOffsetRange,
	x = ns.AuraOffsetRange,
	y = ns.AuraOffsetRange,
}

local NUMBER_RANGES = {
	iconSize = ns.AuraIconSizeRange,
	ownIconSize = ns.AuraIconSizeRange,
	spacing = ns.AuraSpacingRange,
	frameSize = ns.AuraFrameSizeRange,
	textSize = ns.AuraTextSizeRange,
	textX = ns.AuraTextOffsetRange,
	textY = ns.AuraTextOffsetRange,
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

local function CleanGroup(settings, groupKey)
	local defaults = GROUP_DEFAULTS[groupKey]
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
		local listDefaults = GetListDefaults(groupKey)
		CleanFields(settings.list, listDefaults, LIST_RANGES, { "nameFont", "timeFont" })
		if settings.list.iconSide ~= "LEFT" and settings.list.iconSide ~= "RIGHT" then
			settings.list.iconSide = listDefaults.iconSide
		end
		CleanPosition(settings.list, listDefaults)
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
	for key in pairs(GROUP_DEFAULTS) do
		auras[key] = auras[key] or {}
		CleanGroup(auras[key], key)
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
	elseif key == "player" then
		return ns.playerAuraAnchor or UIParent
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

-- Buffs on the target, long and short together. stealable marks the ones the player could steal or purge.
local TEST_TARGET_BUFFS = {
	{ name = "Power Word: Fortitude", icon = "Interface\\Icons\\Spell_Holy_WordFortitude", duration = 1800, remaining = 1514 },
	{ name = "Mark of the Wild", icon = "Interface\\Icons\\Spell_Nature_Regeneration", duration = 1800, remaining = 960, stealable = true },
	{ name = "Blessing of Might", icon = "Interface\\Icons\\Spell_Holy_FistOfJustice", duration = 300, remaining = 212 },
	{ name = "Renew", icon = "Interface\\Icons\\Spell_Holy_Renew", duration = 15, remaining = 11, stealable = true },
	{ name = "Rejuvenation", icon = "Interface\\Icons\\Spell_Nature_Rejuvenation", duration = 12, remaining = 5 },
	{ name = "Power Word: Shield", icon = "Interface\\Icons\\Spell_Holy_PowerWordShield", duration = 30, remaining = 24, stealable = true },
	{ name = "Demon Skin", icon = "Interface\\Icons\\Spell_Shadow_RagingScream" },
}

-- Debuffs on the player, one of each type and two with none.
local TEST_PLAYER_DEBUFFS = {
	{ name = "Curse of Weakness", icon = "Interface\\Icons\\Spell_Shadow_CurseOfMannoroth", duration = 120, remaining = 84, dispel = "Curse" },
	{ name = "Corruption", icon = "Interface\\Icons\\Spell_Shadow_AbominationExplosion", duration = 18, remaining = 13, dispel = "Magic" },
	{ name = "Deadly Poison", icon = "Interface\\Icons\\Ability_Rogue_DualWeild", duration = 12, remaining = 7, dispel = "Poison" },
	{ name = "Mortal Strike", icon = "Interface\\Icons\\Ability_Warrior_SavageBlow", duration = 10, remaining = 4 },
	{ name = "Plague", icon = "Interface\\Icons\\Spell_Shadow_CallofBone", duration = 180, remaining = 140, dispel = "Disease" },
	{ name = "Resurrection Sickness", icon = "Interface\\Icons\\Spell_Shadow_DeathScream", duration = 600, remaining = 410 },
}

-- Debuffs on the target: the player's own come first, at their own size. dispel names the border
-- color Blizzard gives a debuff of that type.
local TEST_TARGET_DEBUFFS = {
	{ name = "Corruption", icon = "Interface\\Icons\\Spell_Shadow_AbominationExplosion", duration = 18, remaining = 14, own = true, dispel = "Magic" },
	{ name = "Curse of Agony", icon = "Interface\\Icons\\Spell_Shadow_CurseOfSargeras", duration = 24, remaining = 20, own = true, dispel = "Curse" },
	{ name = "Immolate", icon = "Interface\\Icons\\Spell_Fire_Immolation", duration = 15, remaining = 6, own = true, dispel = "Magic" },
	{ name = "Sunder Armor", icon = "Interface\\Icons\\Ability_Warrior_Sunder", duration = 30, remaining = 22 },
	{ name = "Faerie Fire", icon = "Interface\\Icons\\Spell_Nature_FaerieFire", duration = 40, remaining = 31, dispel = "Magic" },
	{ name = "Rend", icon = "Interface\\Icons\\Ability_Gouge", duration = 21, remaining = 12 },
	{ name = "Deadly Poison", icon = "Interface\\Icons\\Ability_Rogue_DualWeild", duration = 12, remaining = 8, dispel = "Poison" },
	{ name = "Hamstring", icon = "Interface\\Icons\\Ability_ShockWave", duration = 15, remaining = 4 },
}

-- Blizzard's debuff type colors, for test debuffs. Real debuffs get theirs from Blizzard.
local TEST_DISPEL_COLORS = {
	Magic = { 0.2, 0.6, 1 },
	Curse = { 0.6, 0, 1 },
	Disease = { 0.6, 0.4, 0 },
	Poison = { 0, 0.6, 0 },
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

-- How each group is put together: the unit and auras it shows, and the bar an anchored group sits
-- on, clear of that bar's texts. A group's container holds one or more aura groups, each with its own
-- icon size setting; groups without a list show their filter's buffs in one.
local GROUP_SPECS = {
	playerLongBuffs = { unit = "player", filter = "HELPFUL", enchants = true },
	-- Short buffs fill from the bar's outer end, towards the orb, then up.
	playerShortBuffs = { unit = "player", filter = "HELPFUL", growth = "RIGHT_UP", bar = "DibsUIPlayerHealth", texts = { "playerName" } },
	-- Every debuff on the player, placed like the long buffs, with borders in the debuff type's color.
	playerDebuffs = { unit = "player", filter = "HARMFUL", dispel = true },
	-- Every buff on the target, long or short, placed like the long buffs. Buffs the player can steal or
	-- purge glow, as on Blizzard's target frame.
	targetBuffs = { unit = "target", filter = "HELPFUL", stealable = true },
	-- The player's own debuffs come first, at their own size, then everyone else's. Borders take the
	-- debuff type's color.
	targetDebuffs = {
		unit = "target", filter = "HARMFUL", growth = "RIGHT_UP", bar = "DibsUITargetHealth",
		texts = { "targetName", "targetLevel" }, dispel = true,
		auraGroups = {
			{ name = "own", sizeField = "ownIconSize", filters = { isFromPlayerOrPlayerPet = true } },
			{ name = "others", sizeField = "iconSize", filters = { isFromPlayerOrPlayerPet = false } },
		},
	},
}

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

-- A list shows the longest at the top, so one growing down starts with the longest and one growing up
-- with the soonest to expire. Elsewhere the soonest comes first. Auras that never expire count as the
-- longest either way.
local function IsLongestFirst(group, mode)
	return mode == "list" and not group.settings.list.growUp
end

local SORT_EXPIRATION_ONLY = 5
local SORT_NORMAL, SORT_REVERSE = 0, 1

local function GetSortOptions(group, mode)
	local sortMethod = AuraContainerSortMethod and AuraContainerSortMethod.ExpirationOnly or SORT_EXPIRATION_ONLY
	local directions = AuraContainerSortDirection or { Normal = SORT_NORMAL, Reverse = SORT_REVERSE }
	return sortMethod, IsLongestFirst(group, mode) and directions.Reverse or directions.Normal
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
-- and either takes every buff while the other is off. Target buffs take every buff.
local function GetCandidateFilters(groupKey)
	if groupKey == "playerLongBuffs" then
		return IsGroupEnabled("playerShortBuffs") and { includeSpellIDs = longSpells } or nil
	elseif groupKey == "playerShortBuffs" then
		return IsGroupEnabled("playerLongBuffs") and { excludeSpellIDs = longSpells } or nil
	end
	return nil
end

local function GetReadableCount(groupKey)
	if groupKey ~= "playerLongBuffs" and groupKey ~= "playerShortBuffs" then
		return 1
	end
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
		list[#list + 1] = { name = buff.name, icon = buff.icon, duration = buff.duration, expiration = expiration, order = #list + 1,
			own = buff.own, dispel = buff.dispel, stealable = buff.stealable }
	end
end

local function ReadTestBuffs(groupKey)
	local list = {}
	local function Add(buffs)
		AddTestBuffs(list, buffs)
	end
	if groupKey == "targetDebuffs" then
		Add(TEST_TARGET_DEBUFFS)
		return list
	elseif groupKey == "targetBuffs" then
		Add(TEST_TARGET_BUFFS)
		return list
	elseif groupKey == "playerDebuffs" then
		Add(TEST_PLAYER_DEBUFFS)
		return list
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
-- The player's own debuffs are their own group, ahead of the rest.
local function SortBuffs(list, longestFirst)
	table.sort(list, function(a, b)
		if (a.own == true) ~= (b.own == true) then
			return a.own == true
		end
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

-- Blizzard's own glow for buffs the player can steal or purge, a little larger than the icon.
local STEALABLE_TEXTURE = "Interface\\TargetingFrame\\UI-TargetingFrame-Stealable"
local STEALABLE_SCALE = 1.15

-- The textures and texts DibsUI puts on a button, whether it's a test icon or one of Blizzard's.
local function CreateParts(button, withDispel, withStealable)
	local parts = { button = button }
	if withStealable then
		parts.stealable = button:CreateTexture(nil, "OVERLAY", nil, -1)
		parts.stealable:SetTexture(STEALABLE_TEXTURE)
		parts.stealable:SetBlendMode("ADD")
		parts.stealable:SetPoint("CENTER")
		parts.stealable:Hide()
	end
	parts.border = button:CreateTexture(nil, "BACKGROUND", nil, -8)
	parts.border:SetAllPoints()
	parts.border:SetColorTexture(0, 0, 0, 1)
	-- Over the black border, colored by debuff type where a debuff has one.
	if withDispel then
		parts.dispel = button:CreateTexture(nil, "BACKGROUND", nil, -7)
		parts.dispel:SetColorTexture(1, 1, 1, 1)
		parts.dispel:Hide()
	end
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
	local size = style[parts.sizeField or "iconSize"]
	button:SetSize(size, size)
	parts.size = size
	-- The reskin comes with the next refresh of every group.
	TellMasqueSize(group, parts, false)
	local skinned = IsMasqueSkinned(group)
	if skinned then
		parts.border:Hide()
	else
		ApplyOwnSkin(parts)
	end
	-- Blizzard shows and colors the debuff type border itself. Under a skin it's tucked behind the icon,
	-- since its visibility belongs to Blizzard.
	if parts.dispel then
		parts.dispel:ClearAllPoints()
		parts.dispel:SetAllPoints(skinned and parts.icon or button)
	end
	if parts.stealable then
		parts.stealable:SetSize(size * STEALABLE_SCALE, size * STEALABLE_SCALE)
	end
	parts.count:SetFont(ns.Text.font, math.max(math.floor(size * 0.4), 8), "OUTLINE")
	parts.time:ClearAllPoints()
	parts.name:ClearAllPoints()
	if isList then
		local list = settings.list
		local justify = list.iconSide == "LEFT" and "LEFT" or "RIGHT"
		SetTextStyle(parts.name, list.nameFont, list.nameSize, list.nameColor)
		SetTimeStyle(parts, list.timeFont, list.timeSize, list.timeColor)
		if list.iconSide == "LEFT" then
			parts.name:SetPoint("TOPLEFT", button, "TOPRIGHT", LIST_TEXT_GAP + list.nameX, list.nameY)
			parts.time:SetPoint("BOTTOMLEFT", button, "BOTTOMRIGHT", LIST_TEXT_GAP + list.timeX, list.timeY)
		else
			parts.name:SetPoint("TOPRIGHT", button, "TOPLEFT", -LIST_TEXT_GAP + list.nameX, list.nameY)
			parts.time:SetPoint("BOTTOMRIGHT", button, "BOTTOMLEFT", -LIST_TEXT_GAP + list.timeX, list.timeY)
		end
		parts.name:SetJustifyH(justify)
		parts.time:SetJustifyH(justify)
	else
		SetTimeStyle(parts, settings.font, settings.textSize, settings.textColor)
		parts.time:SetPoint("TOP", button, "BOTTOM", settings.textX, settings.textY - TIME_GAP)
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
	local parts = CreateParts(button, group.spec.dispel, group.spec.stealable)
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
	if parts.dispel then
		local color = TEST_DISPEL_COLORS[data.dispel]
		parts.dispel:SetShown(color ~= nil)
		if color then
			parts.dispel:SetVertexColor(color[1], color[2], color[3])
		end
	end
	if parts.stealable then
		parts.stealable:SetShown(data.stealable == true)
	end
end

-- Layout ------------------------------------------------------------------------------------------

local FLOW_AXIS = { horizontal = 0, vertical = 1 }
local FLOW_DIRECTION = { LEFT = -1, RIGHT = 1, UP = 1, DOWN = -1 }

-- The visible body of the bar an anchored group sits on, which sets its width.
local function GetBarBody(group)
	local bar = group.spec.bar and _G[group.spec.bar]
	return bar and bar.body
end

-- The aura groups in a group's container, with what each lets through right now.
local function GetAuraGroups(group)
	return group.spec.auraGroups or { { name = "buffs", sizeField = "iconSize", filters = GetCandidateFilters(group.key) } }
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
		layout.anchor = (list.growUp and "BOTTOM" or "TOP") .. (left and "LEFT" or "RIGHT")
		layout.signX, layout.signY = left and 1 or -1, list.growUp and 1 or -1
		layout.isList = true
		layout.width = list.iconSize + LIST_TEXT_GAP + LIST_TEXT_WIDTH
		layout.height = list.iconSize
		layout.spacing = list.spacing
		layout.lineSize = math.huge
		layout.padY = 0
	else
		local growthKey = group.spec.growth or settings.growth
		local growth = ns.AuraGrowthsByKey[growthKey]
		local function Has(direction)
			return growth.line == direction or growth.wrap == direction
		end
		local textHeight = TIME_GAP + settings.textSize + 1
		layout.textHeight = textHeight
		layout.vertical = growth.line == "UP" or growth.line == "DOWN"
		layout.anchor = (Has("UP") and "BOTTOM" or "TOP") .. (Has("LEFT") and "RIGHT" or "LEFT")
		layout.signX, layout.signY = Has("LEFT") and -1 or 1, Has("UP") and 1 or -1
		layout.width = settings.iconSize
		layout.height = settings.iconSize + textHeight
		layout.spacing = settings.spacing
		if group.spec.bar then
			local body = GetBarBody(group)
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

-- The space a buff with an icon of this size takes.
local function GetElementSize(layout, size)
	if layout.isList then
		return size + LIST_TEXT_GAP + LIST_TEXT_WIDTH, size
	end
	return size, size + layout.textHeight
end

local function GetPerLine(layout, count)
	if layout.lineSize == math.huge then
		return math.max(count, 1)
	end
	local primary = layout.vertical and layout.height or layout.width
	return math.max(math.floor((layout.lineSize + layout.spacing) / (primary + layout.spacing)), 1)
end

-- Where each buff goes from the group's starting corner, given its icon size, step for step the way
-- Blizzard's flow layout places them: a line wraps when the next buff won't fit, and a new line starts
-- past the tallest buff on the last.
local function GetFlowOffsets(layout, sizes)
	local offsets = {}
	local cursor, cross, lineLength, lineDepth = 0, 0, 0, 0
	for i, size in ipairs(sizes) do
		local width, height = GetElementSize(layout, size)
		local along, across = layout.vertical and height or width, layout.vertical and width or height
		if lineLength > 0 and lineLength + along > layout.lineSize then
			cursor, cross = 0, cross + lineDepth + layout.spacing
			lineLength, lineDepth = 0, 0
		end
		local x, y = cursor, cross
		if layout.vertical then
			x, y = cross, cursor
		end
		offsets[i] = { layout.signX * x, layout.signY * (layout.padY + y) }
		cursor = cursor + along + layout.spacing
		lineLength = lineLength + along + layout.spacing
		lineDepth = math.max(lineDepth, across)
	end
	return offsets
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
	local sizes = {}
	for i = 1, count do
		sizes[i] = group.testIcons[i].size
	end
	for i, offset in ipairs(GetFlowOffsets(layout, sizes)) do
		local button = group.testIcons[i].button
		button:ClearAllPoints()
		button:SetPoint(layout.anchor, group.holder, layout.anchor, offset[1], offset[2])
	end
end

local ENCHANTS_BEFORE_BUFFS = 0

-- Each aura group takes buffs of its own icon size. Weapon enchants are their own group too, ahead of
-- the buffs, and each group carries on from the last along the same line. The flow layout already
-- leaves the spacing after each icon, so the groups need no gap of their own.
local function ConfigureContainer(container, layout, group)
	container:SetFlowLayoutAxis(layout.vertical and FLOW_AXIS.vertical or FLOW_AXIS.horizontal)
	container:SetFlowLayoutGrowthDirection(layout.signX > 0 and FLOW_DIRECTION.RIGHT or FLOW_DIRECTION.LEFT,
		layout.signY > 0 and FLOW_DIRECTION.UP or FLOW_DIRECTION.DOWN)
	container:SetFlowLayoutAnchorPoint(layout.anchor)
	container:SetFlowLayoutPadding(0, 0, 0, layout.padY)
	container:SetFlowLayoutMaximumLineSize(layout.lineSize)
	local style = layout.isList and group.settings.list or group.settings
	local function GroupLayout(size)
		local width, height = GetElementSize(layout, size)
		return {
			elementSpacing = layout.spacing,
			lineSpacing = layout.spacing,
			groupSpacing = 0,
			groupLineSpacing = layout.spacing,
			elementWidth = width,
			elementHeight = height,
		}
	end
	for _, auraGroup in ipairs(GetAuraGroups(group)) do
		container:SetAuraGroupLayout(auraGroup.name, GroupLayout(style[auraGroup.sizeField]))
	end
	if group.spec.enchants then
		local enchantLayout = GroupLayout(style.iconSize)
		local placement = CustomAuraContainerItemEnchantmentPlacement
		enchantLayout.placement = placement and placement.BeforeAuraGroups or ENCHANTS_BEFORE_BUFFS
		container:SetItemEnchantmentLayout(enchantLayout)
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

-- How far above its bar an anchored group sits: clear of the texts on top of the bar, such as a name
-- and level, while they're on. A text's height is taken from its font size, since a name's own
-- measurements can be secret.
local function GetTextClearance(keys)
	local clearance = 0
	for _, key in ipairs(keys) do
		if ns.GetTextOption(key, "enabled") then
			local top = ns.Text[key].y + ns.GetTextOption(key, "offsetY") + ns.GetTextOption(key, "size") + 2
			clearance = math.max(clearance, top)
		end
	end
	return clearance + NAME_CLEARANCE
end

local function PlaceHolder(group)
	local holder = group.holder
	holder:ClearAllPoints()
	if group.spec.bar then
		local body = GetBarBody(group)
		if body then
			holder:SetPoint("BOTTOMRIGHT", body, "TOPRIGHT", 0, GetTextClearance(group.spec.texts))
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
	SortBuffs(list, IsLongestFirst(group, mode))
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
		parts.sizeField = data.own and "ownIconSize" or "iconSize"
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
		if container then
			ConfigureContainer(container, layout, group)
			-- A list that changes direction is sorted the other way round.
			local sortMethod, sortDirection = GetSortOptions(group, mode)
			local resort = group.sortDirections[mode] ~= sortDirection
			group.sortDirections[mode] = sortDirection
			for _, auraGroup in ipairs(GetAuraGroups(group)) do
				container:SetAuraGroupCandidateFilters(auraGroup.name, auraGroup.filters)
				if resort then
					container:SetAuraGroupSortMethod(auraGroup.name, sortMethod, sortDirection)
				end
			end
			container:ClearAllPoints()
			container:SetPoint(layout.anchor, group.holder, layout.anchor)
		end
		count = GetReadableCount(group.key)
		if group.spec.enchants and not AreAurasSecret() then
			count = count + CountWeaponEnchants()
		end
	end
	StyleContainerButtons(group)
	SizeHolder(group, layout, count)
	group.count = count
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
	CleanGroup(settings, group.key)
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

-- Blizzard's buff frame goes while either buff group is on, and its debuff frame, a separate one,
-- while the player debuffs are. Each goes back to where it was when they're off.
local blizzardParents = {}
local function ReplaceBlizzardFrame(frame, replaced)
	if not frame or (InCombatLockdown() and frame:IsProtected()) then
		return
	end
	if blizzardParents[frame] == nil then
		blizzardParents[frame] = frame:GetParent() or UIParent
	end
	frame:SetParent(replaced and ns.hiddenParent or blizzardParents[frame])
end

local function UpdateBlizzardBuffFrame()
	ReplaceBlizzardFrame(BuffFrame, IsGroupEnabled("playerLongBuffs") or IsGroupEnabled("playerShortBuffs"))
	ReplaceBlizzardFrame(DebuffFrame, IsGroupEnabled("playerDebuffs"))
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
	CleanGroup(settings, groupKey)
	ns.RefreshAuraFrames()
	return settings[field]
end

-- The same for one of list mode's settings.
function ns.SetAuraListOption(groupKey, field, value)
	local settings = ns.db.auras[groupKey]
	settings.list[field] = value
	CleanGroup(settings, groupKey)
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
local DISPEL_PRESERVE_ASSET = 3
local DISPEL_CUSTOM_ASSET, ONLY_STEALABLE = 4, 0

-- Blizzard shows the stealable glow itself, on the buffs whose aura data says the player can steal or
-- purge them, which stays secret in combat. It's a dispel type texture limited to stealable buffs,
-- with the glow as its asset for every dispel type and none.
local function AddStealableTexture(button, texture)
	local styles = Enum.CustomAuraButtonDispelTypeTextureStyle
	local filters = Enum.CustomAuraButtonDispelTypeStealableFilter
	local glow = { asset = STEALABLE_TEXTURE }
	button:AddDispelTypeTexture(texture, {
		showWhenHelpful = true,
		showWhenHarmful = false,
		showWithoutDispelType = true,
		stealableFilter = filters and filters.Stealable or ONLY_STEALABLE,
		style = styles and styles.CustomAsset or DISPEL_CUSTOM_ASSET,
		customDispelAssetMap = { Magic = glow, Curse = glow, Disease = glow, Poison = glow, Enrage = glow, None = glow },
	})
end

local function InitContainerButton(group, mode, button, sizeField)
	local ok, err = pcall(function()
		local parts = CreateParts(button, group.spec.dispel, group.spec.stealable)
		parts.isContainer = true
		parts.sizeField = sizeField
		button:SetIcon(parts.icon)
		button:SetApplicationCount(parts.count)
		-- Blizzard colors the border texture by debuff type, as on its own target frame.
		if parts.dispel then
			local styles = Enum.CustomAuraButtonDispelTypeTextureStyle
			button:AddDispelTypeTexture(parts.dispel, { style = styles and styles.PreserveAsset or DISPEL_PRESERVE_ASSET })
		end
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
		-- Last, so the button is still set up if the client turns the glow's options down.
		if parts.stealable then
			AddStealableTexture(button, parts.stealable)
		end
	end)
	if not ok then
		geterrorhandler()(err)
	end
end

local function CreateContainer(group, mode)
	local ok, container = pcall(CreateFrame, "AuraContainer", nil, group.holder, "CustomAuraContainerTemplate")
	if not ok then
		geterrorhandler()(container)
		return
	end
	group.records[mode] = {}
	container:Hide()
	container:SetUnit(group.spec.unit)
	local sortMethod, sortDirection = GetSortOptions(group, mode)
	group.sortDirections[mode] = sortDirection
	for _, auraGroup in ipairs(GetAuraGroups(group)) do
		container:AddAuraGroup(auraGroup.name, group.spec.filter, {
			sortMethod = sortMethod,
			sortDirection = sortDirection,
			candidateFilters = auraGroup.filters,
			initializeFrame = function(button)
				InitContainerButton(group, mode, button, auraGroup.sizeField)
			end,
		})
	end
	-- The long buffs also show weapon enchants: main hand, off hand and ranged. Blizzard fills them in
	-- and cancels them on right-click, as with buffs. In list mode the name is the weapon's.
	if group.spec.enchants then
		local slots = AuraContainerItemEnchantmentSlot or { MainHand = 0, OffHand = 1, Ranged = 2 }
		for _, slot in ipairs({ slots.MainHand, slots.OffHand, slots.Ranged }) do
			local added, err = pcall(container.AddItemEnchantment, container, slot, {
				initializeFrame = function(button)
					InitContainerButton(group, mode, button, "iconSize")
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
	CreateContainer(groups.targetBuffs, "standard")
	CreateContainer(groups.targetDebuffs, "standard")
	CreateContainer(groups.playerDebuffs, "standard")
	CreateContainer(groups.playerDebuffs, "list")
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
		spec = GROUP_SPECS[key],
		containers = {},
		records = {},
		sortDirections = {},
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

-- The top of the player's short buffs, and the scale it's measured in, while any are showing; nil
-- otherwise. In combat the count is the last one that could be read, as for the frame's own size.
function ns.GetShortBuffsTop()
	local group = groups.playerShortBuffs
	if not (group and group.settings.enabled and group.holder:IsVisible() and (group.count or 0) > 0) then
		return
	end
	return group.holder:GetTop(), group.holder:GetEffectiveScale()
end

function ns.CreateAuraFrames()
	RebuildLongSpells()

	-- Groups placed by their settings, which can be dragged while the frames are unlocked.
	local function CreatePlacedGroup(key, label)
		local group = CreateGroup(key, label, UIParent)
		group.holder:SetFrameStrata("LOW")
		group.holder:SetMovable(true)
		group.holder:SetClampedToScreen(true)
		group.holder:SetDontSavePosition(true)
		group.mover = CreateMover(group)
	end
	-- What "DibsUI player bar" attaches to: the player bar itself, or the same span lifted clear of the
	-- pet bar and its name while there's a pet. The pet bar is as tall as the player bar and level with
	-- it, beyond its outer end, so the lift is its height plus the room for the name.
	local playerBody = DibsUIPlayerHealth.body
	local petBody = DibsUIPetHealth and DibsUIPetHealth.body
	local playerAnchor = CreateFrame("Frame", nil, ns.root)
	ns.playerAuraAnchor = playerAnchor
	local function PlacePlayerAnchor()
		local lift = 0
		if petBody and petBody:IsShown() then
			lift = ns.Layout.health.height + GetTextClearance({ "petName" })
		end
		playerAnchor:ClearAllPoints()
		playerAnchor:SetPoint("TOPLEFT", playerBody, "TOPLEFT", 0, lift)
		playerAnchor:SetPoint("BOTTOMRIGHT", playerBody, "BOTTOMRIGHT", 0, lift)
	end
	PlacePlayerAnchor()
	if petBody then
		petBody:HookScript("OnShow", PlacePlayerAnchor)
		petBody:HookScript("OnHide", PlacePlayerAnchor)
	end

	CreatePlacedGroup("playerLongBuffs", "Player long buffs")
	-- The player's debuffs sit beside the player bar by default.
	CreatePlacedGroup("playerDebuffs", "Player debuffs")
	-- The target's buffs stay put without a target, empty, so the frame can still be moved.
	CreatePlacedGroup("targetBuffs", "Target buffs")

	-- The short buffs ride on the player bar, so they scale with DibsUI, but they keep full opacity
	-- while the bars fade, like the long buffs.
	local short = CreateGroup("playerShortBuffs", "Player short buffs", ns.root)
	short.holder:SetIgnoreParentAlpha(true)

	-- Target debuffs ride on the target bar's sliding wing, so they slide in and out with it, are cut off
	-- at the orb the same way, and hide with it while there's no target.
	local targetDebuffs = CreateGroup("targetDebuffs", "Target debuffs", DibsUITargetHealth.body:GetParent())
	targetDebuffs.holder:SetIgnoreParentAlpha(true)

	-- Anchored groups follow their bar's width and the texts above it, and the player bar's anchor
	-- follows the pet's name.
	local function RefreshAnchoredGroups()
		PlacePlayerAnchor()
		for _, group in pairs(groups) do
			if group.spec.bar and group.settings then
				UpdateGroup(group)
			end
		end
	end
	hooksecurefunc(ns, "UpdateBarWidths", RefreshAnchoredGroups)
	hooksecurefunc(ns, "SetTextStyle", RefreshAnchoredGroups)
	hooksecurefunc(ns, "RefreshAllText", RefreshAnchoredGroups)

	local events = CreateFrame("Frame")
	events:RegisterEvent("PLAYER_LOGIN")
	events:RegisterUnitEvent("UNIT_AURA", "player")
	events:RegisterEvent("PLAYER_ENTERING_WORLD")
	events:RegisterEvent("PLAYER_REGEN_DISABLED")
	events:RegisterEvent("PLAYER_REGEN_ENABLED")
	events:RegisterEvent("PLAYER_TARGET_CHANGED")
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
		elseif event == "PLAYER_TARGET_CHANGED" then
			-- Blizzard's containers follow aura changes, but a new target is DibsUI's to announce.
			for _, group in pairs(groups) do
				if group.spec.unit == "target" then
					for _, container in pairs(group.containers) do
						container:UpdateAllAuras()
					end
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
