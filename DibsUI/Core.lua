local addonName, ns = ...

local MEDIA = "Interface\\AddOns\\" .. addonName .. "\\Media\\"

function ns.Media(name)
	return MEDIA .. name
end

-- Where a bar's art sits, and where to cut it into three so the width setting only stretches the
-- straight middle, keeping the slanted ends and double border in shape. Distances from the texture's start.
local BAR_ART = { start = 0, width = 320, sliceInner = 75, sliceTip = 165 } -- starts at the orb centre
local PET_ART = { start = 226, width = 160, sliceInner = 30, sliceTip = 114 }

-- Geometry in UI units, with the orb centre as the origin and y pointing up.
-- The artwork is drawn from the same numbers in devResources/DibsUI/art/generate_art.py.
ns.Layout = {
	originY = 240, -- default orb centre above the bottom of the screen

	-- The frame that moves and scales everything, centred on the orb. Big enough to hold the names and cast info.
	-- Its width follows the bars, plus this margin each side.
	rootMargin = 5,
	rootHeight = 230,

	orbQuad = 160, -- size of every orb texture
	orbRadius = 53.5, -- power orb, inside the cast ring

	barQuadHeight = 40,

	-- The target wing slides from under the ring, so it's clipped where the bar first clears it.
	-- Left of this it would show through the orb, which is see-through at rest.
	wingClipInner = 51,

	-- yCenter/height/tip: the visible bar outline. hitInner: where the click area starts.
	-- fillInner/fillOuter: StatusBar span, measured from the orb centre.
	-- fillHeight: inside of the double border. capWidth: how far the slanted cap reaches past the fill.
	-- wedgeWidth/wedgeArt: the piece joining the fill's straight inner edge to the shape of the bar's inner end.
	-- widthSetting: the saved setting that stretches the bar.
	health = {
		yCenter = 31, height = 34, tip = 245, hitInner = 52,
		fillInner = 68, fillOuter = 224.59, fillHeight = 26, capWidth = 13.76, wedgeWidth = 14, wedgeArt = "BarFillInner",
		back = "BarHealthBack", frame = "BarHealthFrame", art = BAR_ART, widthSetting = "width",
	},
	power = {
		yCenter = 2, height = 18, tip = 188, hitInner = 66,
		fillInner = 70, fillOuter = 176.66, fillHeight = 12, capWidth = 6.35,
		back = "BarPowerBack", frame = "BarPowerFrame", art = BAR_ART, widthSetting = "width",
	},
	-- Distances assume the player bar at its default width; followsHealth moves this bar along with its tip.
	-- hitInset: the click area stops short of the slanted inner end, which reaches under the player bar's tip.
	pet = {
		yCenter = 31, height = 34, tip = 369, hitInner = 231, hitInset = 18,
		fillInner = 251.41, fillOuter = 348.59, fillHeight = 26, capWidth = 13.76, wedgeWidth = 13.76, wedgeArt = "BarFillSlant",
		back = "BarPetBack", frame = "BarPetFrame", art = PET_ART, widthSetting = "petWidth", followsHealth = true,
	},
}

-- Every text field's size and offset. The comment says what each offset is measured from.
ns.Text = {
	font = "Fonts\\FRIZQT__.ttf",
	outline = "OUTLINE",

	orbPower = { size = 28, x = 0, y = 0 }, -- CENTER of the orb

	playerDeficit = { size = 14, x = 22, y = 0 }, -- LEFT of the left bar
	playerHealth = { size = 14, x = -17, y = 0 }, -- RIGHT of the left bar
	playerName = { size = 15, x = 0, y = 3 }, -- BOTTOM of the text to the TOP of the left bar

	targetHealth = { size = 10, x = -22, y = 0 }, -- RIGHT of the right bar
	targetPercent = { size = 14, x = -3, y = -1 }, -- BOTTOMRIGHT to the BOTTOMLEFT of targetHealth
	targetPower = { size = 10, x = -13, y = 0 }, -- RIGHT of the power bar
	targetName = { size = 15, x = 0, y = 3 }, -- BOTTOM of the text to the TOP of the right bar
	targetLevel = { size = 12, x = -1, y = 3 }, -- BOTTOMRIGHT to the TOPRIGHT of the right bar

	petName = { size = 15, x = -9, y = 3 }, -- BOTTOM of the text to the TOP of the pet bar; x centres it on the slanted top edge
	petHealth = { size = 12, x = 0, y = 0 }, -- CENTER of the pet bar, on mouseover
	petHappiness = { size = 20, x = 16, y = 3 }, -- BOTTOMLEFT of the icon to the BOTTOMLEFT of the pet bar

	castIcon = { size = 20, x = 0, y = -86 }, -- centre of the icon and name row, from the orb CENTER
	castName = { size = 13, x = 5, y = 0 }, -- LEFT of the text to the RIGHT of the icon
	castTime = { size = 12, x = 0, y = -105 }, -- CENTER of the text, from the orb CENTER

	moverLabel = { size = 14, x = 0, y = -6 }, -- TOP of the text to the TOP of the drag handle

	configTitle = { size = 13 },
	configLabel = { size = 13 },
	configValue = { size = 12 },
	configRange = { size = 10 },
}

function ns.CreateText(parent, spec)
	local text = parent:CreateFontString(nil, "OVERLAY")
	text:SetFont(ns.Text.font, spec.size, ns.Text.outline)
	text:SetTextColor(1, 1, 1)
	text:SetWordWrap(false)
	return text
end

-- 999, 1.2k, 12k, 1.2m, 12m: Blizzard's documented rule for abbreviation breakpoints. The numbers
-- can be secret, so the client has to do the shortening; addon code can't divide them.
local ABBREVIATE_OPTIONS = {
	breakpointData = {
		{ breakpoint = 10000000, abbreviation = "m", significandDivisor = 1000000, fractionDivisor = 1, abbreviationIsGlobal = false },
		{ breakpoint = 1000000, abbreviation = "m", significandDivisor = 100000, fractionDivisor = 10, abbreviationIsGlobal = false },
		{ breakpoint = 10000, abbreviation = "k", significandDivisor = 1000, fractionDivisor = 1, abbreviationIsGlobal = false },
		{ breakpoint = 1000, abbreviation = "k", significandDivisor = 100, fractionDivisor = 10, abbreviationIsGlobal = false },
	},
}

function ns.Shorten(value)
	return AbbreviateNumbers(value, ABBREVIATE_OPTIONS)
end

-- nil if the class can't be read. UnitClass is secret for units that aren't player-controlled.
function ns.GetUnitClassColor(unit)
	local _, classFile = UnitClass(unit)
	if issecretvalue(classFile) or classFile == nil then
		return nil
	end
	return RAID_CLASS_COLORS[classFile]
end

-- Frame levels, all in the LOW strata. Bars sit under the orb so their inner ends disappear beneath the ring.
ns.Level = {
	bar = 10,
	orb = 30,
}

ns.Colors = {
	playerHealth = { 0.20, 0.80, 0.28 },
	disabled = { 0.50, 0.50, 0.50 },
	cast = { 1.00, 0.76, 0.25 },
	channel = { 0.35, 0.85, 0.75 },
	swing = { 0.60, 0.60, 0.60 },
	unknownPower = { 0.70, 0.70, 0.70 },
	-- PowerBarColor's mana and energy are pure primaries, which turn muddy under the glass shading.
	power = {
		MANA = { 0.15, 0.45, 1.00 },
		RAGE = { 0.90, 0.15, 0.10 },
		ENERGY = { 1.00, 0.85, 0.20 },
	},
}

function ns.GetPowerColor(powerToken)
	local color = ns.Colors.power[powerToken]
	if color then
		return color[1], color[2], color[3]
	end
	local info = PowerBarColor and powerToken and PowerBarColor[powerToken]
	if info then
		return info.r, info.g, info.b
	end
	color = ns.Colors.unknownPower
	return color[1], color[2], color[3]
end

-- A texture that stays crisp at any UI scale instead of snapping to the pixel grid.
function ns.CreateArt(parent, layer, fileName)
	local texture = parent:CreateTexture(nil, layer)
	texture:SetTexture(ns.Media(fileName))
	texture:SetSnapToPixelGrid(false)
	texture:SetTexelSnappingBias(0)
	return texture
end

local hiddenParent = CreateFrame("Frame", nil, UIParent)
hiddenParent:Hide()

-- PlayerFrame itself stays alive: TotemFrame, RuneFrame and the class resource bars are its children.
-- PetFrame is laid out by a managed container that takes it back when it's shown, but under a hidden
-- parent it never fires OnShow, and the OnHide from reparenting takes it out of that layout.
local function HideBlizzardFrames()
	PlayerFrame.PlayerFrameContainer:Hide()
	PlayerFrame.PlayerFrameContent:Hide()
	PlayerFrame:EnableMouse(false)

	PetFrame:SetParent(hiddenParent)

	TargetFrame:SetParent(hiddenParent)

	PlayerCastingBarFrame:SetAndUpdateShowCastbar(false)
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 == addonName then
			self:UnregisterEvent("ADDON_LOADED")
			ns.LoadSettings()
			ns.CreateRoot()
			ns.CreateBars()
			ns.CreateOrb()
			ns.CreateMover()
			ns.CreateOpacity()
		end
	elseif event == "PLAYER_LOGIN" then
		-- These are protected frames, so a /reload during combat has to wait for combat to end.
		if InCombatLockdown() then
			self:RegisterEvent("PLAYER_REGEN_ENABLED")
		else
			HideBlizzardFrames()
		end
	elseif event == "PLAYER_REGEN_ENABLED" then
		self:UnregisterEvent("PLAYER_REGEN_ENABLED")
		HideBlizzardFrames()
	end
end)
