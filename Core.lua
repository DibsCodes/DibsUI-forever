local addonName, ns = ...

local MEDIA = "Interface\\AddOns\\" .. addonName .. "\\Media\\"

function ns.Media(name)
	return MEDIA .. name
end

-- Border art themes, picked on the General page. A theme lists only the textures it replaces, from
-- Media\Themes\<folder>; everything else is shared. rimScale: how big the orb rim is drawn, as a
-- multiple of the orb, for themes whose rim has ornament reaching past the shipped one.
-- The themed art is made with devResources/DibsUI/art/theme_art.py.
ns.Themes = {
	{ key = "default", label = "Default", description = "Brushed silver and gold." },
	{ key = "bronze", label = "Bronze", description = "Rough cast bronze with a carved eagle.", folder = "Bronze",
		textures = { OrbFrame = true, BarHealthFrame = true, BarPowerFrame = true, BarPetFrame = true }, rimScale = 1.25 },
}
ns.ThemesByKey = {}
local themeable = {} -- every texture name some theme replaces
for _, theme in ipairs(ns.Themes) do
	ns.ThemesByKey[theme.key] = theme
	for name in pairs(theme.textures or {}) do
		themeable[name] = true
	end
end

function ns.GetTheme()
	return ns.db and ns.ThemesByKey[ns.db.theme] or ns.Themes[1]
end

-- The file for a texture in the current theme.
function ns.ThemedMedia(name)
	local theme = ns.GetTheme()
	if theme.textures and theme.textures[name] then
		return MEDIA .. "Themes\\" .. theme.folder .. "\\" .. name
	end
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
	comboQuad = 108, -- size of the combo point textures, which sit on the orb's inner edge
	manaSparkQuad = 128, -- size of the spark's texture, with margin for rotating it

	barQuadHeight = 40,
	glowQuadHeight = 64, -- the low health glow's bar textures, taller to leave room for the glow
	orbGlowQuad = 200, -- the low health glow round the orb, bigger than the orb for the same reason

	-- The target wing slides from under the ring, so it's clipped where the bar first clears it.
	-- Left of this it would show through the orb, which is see-through at rest.
	wingClipInner = 51,
	-- The clip reaches this far above the frame, so target debuffs stacked above the bar aren't cut off.
	wingClipHeadroom = 400,

	-- yCenter/height/tip: the visible bar outline. hitInner: where the click area starts.
	-- fillInner/fillOuter: StatusBar span, measured from the orb centre.
	-- fillHeight: inside of the double border. capWidth: how far the slanted cap reaches past the fill.
	-- wedgeWidth/wedgeArt: the piece joining the fill's straight inner edge to the shape of the bar's inner end.
	-- widthSettings: the saved settings that stretch the bar, on the left wing then the right.
	health = {
		yCenter = 31, height = 34, tip = 245, hitInner = 52,
		fillInner = 68, fillOuter = 224.59, fillHeight = 26, capWidth = 13.76, wedgeWidth = 14, wedgeArt = "BarFillInner",
		back = "BarHealthBack", frame = "BarHealthFrame", glow = "BarHealthGlow", art = BAR_ART, widthSettings = { "playerWidth", "targetWidth" },
	},
	power = {
		yCenter = 2, height = 18, tip = 188, hitInner = 66,
		fillInner = 70, fillOuter = 176.66, fillHeight = 12, capWidth = 6.35,
		back = "BarPowerBack", frame = "BarPowerFrame", art = BAR_ART, widthSettings = { "playerWidth", "targetWidth" },
	},
	-- Used by the pet bar and, mirrored, the target of target bar.
	-- Distances assume the health bar beside it at its default width; followsHealth moves this bar along with the tip of
	-- the health bar on its own side.
	-- hitInset: the click area stops short of the slanted inner end, which reaches under the player bar's tip.
	pet = {
		yCenter = 31, height = 34, tip = 369, hitInner = 231, hitInset = 18,
		fillInner = 251.41, fillOuter = 348.59, fillHeight = 26, capWidth = 13.76, wedgeWidth = 13.76, wedgeArt = "BarFillSlant",
		back = "BarPetBack", frame = "BarPetFrame", glow = "BarPetGlow", art = PET_ART, widthSettings = { "petWidth", "totWidth" }, followsHealth = true,
	},
}

-- The focus frame is drawn like a DibsUI-Party member, in the same units as the orb above, and the whole
-- frame is scaled down by baseScale (times the Focus scale setting). Distances are from its orb's centre.
-- The health bar is the target health bar stretched to 1.5 times its height, art, outline and fill
-- together, so its slanted caps still match the art; the power bar is the target's, 3 units under it.
ns.FocusLayout = {
	baseScale = 0.63,
	-- The Width setting's 1 is this many times the target bar's length, so names fit at the frame's size.
	widthBase = 1.3,
	margin = 100, -- from the frame's left edge to the orb centre: room for a theme's larger rim
	rightMargin = 8, -- past the health bar's tip
	height = 200,

	orbQuad = 160,
	orbRadius = 53.5, -- the well inside the ring, where the portrait goes

	barArt = { width = 320, sliceInner = 75, sliceTip = 165 }, -- BAR_ART
	health = {
		yCenter = 12, height = 51, quadHeight = 60, tip = 245, hitInner = 52,
		fillInner = 68, fillOuter = 224.59, fillHeight = 39, capWidth = 13.76, wedgeWidth = 14, wedgeArt = "BarFillInner",
		back = "BarHealthBack", frame = "BarHealthFrame",
	},
	power = {
		yCenter = -25.5, height = 18, quadHeight = 40, tip = 188, hitInner = 66,
		fillInner = 70, fillOuter = 176.66, fillHeight = 12, capWidth = 6.35,
		back = "BarPowerBack", frame = "BarPowerFrame",
	},
	nameReserved = 24, -- the name's box is the bar's width less this, so it stays off the slanted tip
}

-- Every text field's default size and offset. The comment says what each offset is measured from.
ns.Text = {
	font = "Fonts\\FRIZQT__.TTF",
	outline = "OUTLINE",

	-- The larger first piece of a two part value such as "70% - 13k": its size as a multiple of the
	-- text's, and its BOTTOMRIGHT to the BOTTOMLEFT of the rest.
	lead = { scale = 1.4, x = -3, y = -1 },

	orbCenter = { size = 28, x = 0, y = 0 }, -- CENTER of the orb
	orbMana = { size = 14, x = 0, y = -1 }, -- TOP of the text to the BOTTOM of orbCenter; druids in bear and cat form

	playerLeft = { size = 14, x = 22, y = 0 }, -- LEFT of the left bar
	playerRight = { size = 14, x = -17, y = 0 }, -- RIGHT of the left bar
	playerName = { size = 15, x = 0, y = 3 }, -- BOTTOM of the text to the TOP of the left bar
	pvpTimer = { size = 12, x = 3, y = 0 }, -- LEFT of the text to the RIGHT of the PvP icon under the left bar

	targetRight = { size = 10, x = -22, y = 0 }, -- RIGHT of the right bar
	targetPowerRight = { size = 10, x = -13, y = 0 }, -- RIGHT of the power bar
	targetName = { size = 15, x = 0, y = 3 }, -- BOTTOM of the text to the TOP of the right bar
	targetLevel = { size = 12, x = -1, y = 3 }, -- BOTTOMRIGHT to the TOPRIGHT of the right bar

	petName = { size = 15, x = -9, y = 3 }, -- BOTTOM of the text to the TOP of the pet bar; x centres it on the slanted top edge
	petCenter = { size = 12, x = 0, y = 0 }, -- CENTER of the pet bar
	petHappiness = { size = 20, x = 16, y = 3 }, -- BOTTOMLEFT of the icon to the BOTTOMLEFT of the pet bar

	totName = { size = 15, x = 18, y = 3 }, -- BOTTOMLEFT of the text to the TOPLEFT of the bar; runs up to totLevel, centred between
	totLevel = { size = 12, x = -1, y = 3 }, -- BOTTOMRIGHT to the TOPRIGHT of the target of target bar

	-- The cast shows below the orb, or above it if the settings say so. Either way the spell name sits
	-- over the time, so above the orb the two swap distances.
	castIcon = { size = 20, x = 0, y = -86, yAbove = 105 }, -- centre of the icon and name row, from the orb CENTER
	castName = { size = 13, x = 5, y = 0 }, -- LEFT of the text to the RIGHT of the icon
	castTime = { size = 12, x = 0, y = -105, yAbove = 86 }, -- CENTER of the text, from the orb CENTER

	moverLabel = { size = 14, x = 0, y = -6 }, -- TOP of the text to the TOP of the drag handle

	-- The focus frame's, in its own units (ns.FocusLayout), so they're scaled with it: 24 is about 15 px.
	focusName = { size = 24, x = 0, y = 4 }, -- BOTTOM of the text to the TOP of the health bar
	focusLevel = { size = 20, x = 54, y = 54 }, -- CENTER of the text, from the orb CENTER: the top right of the rim
	focusRight = { size = 20, x = -22, y = 0 }, -- RIGHT of the health bar
	focusPowerRight = { size = 16, x = -13, y = 0 }, -- RIGHT of the power bar
	focusCastName = { size = 20, x = 0, y = -82 }, -- TOP of the text, from the orb CENTER
	focusCastTime = { size = 17, x = 0, y = -2 }, -- TOP of the text to the BOTTOM of the spell name
	focusMoverLabel = { size = 22, x = 0, y = 4 }, -- BOTTOM of the text to the TOP of the drag handle
}

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
	gcd = { 0.30, 0.90, 0.35 }, -- the global cooldown after an instant ability
	manaRule = { 1.00, 0.72, 0.20 }, -- the spark during the five second rule
	druidMana = { 0.40, 0.70, 1.00 }, -- a druid's mana under the orb's power, lighter than the liquid so it reads over it
	-- One per combo point, in the order they're earned.
	combo = {
		{ 1.00, 0.88, 0.10 },
		{ 1.00, 0.88, 0.10 },
		{ 1.00, 0.50, 0.05 },
		{ 1.00, 0.50, 0.05 },
		{ 0.95, 0.12, 0.08 },
	},
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

-- Textures a theme can replace, kept so a theme switch can swap their files.
local themedTextures = {}

-- A texture that stays crisp at any UI scale instead of snapping to the pixel grid.
function ns.CreateArt(parent, layer, fileName)
	local texture = parent:CreateTexture(nil, layer)
	texture:SetTexture(ns.ThemedMedia(fileName))
	texture:SetSnapToPixelGrid(false)
	texture:SetTexelSnappingBias(0)
	if themeable[fileName] then
		themedTextures[#themedTextures + 1] = { texture = texture, name = fileName }
	end
	return texture
end

-- After a theme switch or a profile change. Textures aren't protected, so this works in combat.
function ns.UpdateTheme()
	for _, entry in ipairs(themedTextures) do
		entry.texture:SetTexture(ns.ThemedMedia(entry.name))
	end
	if ns.UpdateRimSize then
		ns.UpdateRimSize()
	end
end

local hiddenParent = CreateFrame("Frame", nil, UIParent)
hiddenParent:Hide()
ns.hiddenParent = hiddenParent

-- PlayerFrame itself stays alive: TotemFrame, RuneFrame and the class resource bars are its children.
-- PetFrame is laid out by a managed container that takes it back when it's shown, but under a hidden
-- parent it never fires OnShow, and the OnHide from reparenting takes it out of that layout.
local function HideBlizzardFrames()
	PlayerFrame.PlayerFrameContainer:Hide()
	PlayerFrame.PlayerFrameContent:Hide()
	PlayerFrame:EnableMouse(false)

	PetFrame:SetParent(hiddenParent)

	TargetFrame:SetParent(hiddenParent)

	-- DibsUI has its own focus frame, unless it's switched off. FocusFrame's cast bar is its child, so it
	-- goes too.
	ns.TakeOverFocusFrame()
end

-- The orb shows casts, so Blizzard's cast bar stays off. Blizzard turns it back on whenever one of its
-- own cast bars finishes, such as the one over the talent or crafting window or a vehicle's action bar,
-- so it goes straight back off. It isn't a protected frame, so this doesn't have to wait for combat.
local function HideCastBar()
	PlayerCastingBarFrame:SetAndUpdateShowCastbar(false)
	hooksecurefunc(PlayerCastingBarFrame, "SetAndUpdateShowCastbar", function(castBar, showCastbar)
		if showCastbar then
			castBar:SetAndUpdateShowCastbar(false)
		end
	end)
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
			ns.CreateIndicators()
			ns.CreateOrb()
			ns.CreateMover()
			ns.CreateFocus()
			ns.CreateAuraFrames()
			ns.CreateCombatText()
			ns.CreateOpacity()
		end
	elseif event == "PLAYER_LOGIN" then
		-- Said at login rather than on load, once the chat frame is ready to show it.
		print("|cffffd100DibsUI|r is loaded! Use /dibsui or /dui to configure.")
		HideCastBar()
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
