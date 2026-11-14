local _, ns = ...

local Layout = ns.Layout

ns.ScaleRange = { min = 0.5, max = 2, step = 0.05 }
ns.WidthRange = { min = 0.5, max = 2, step = 0.05 }
ns.TextSizeRange = { min = 6, max = 40, step = 1 }
ns.TextOffsetRange = { min = -100, max = 100, step = 1 }
ns.OpacityRange = { min = 0, max = 1, step = 0.05 }

ns.DEFAULT_PROFILE = "Default"

-- Settings kept in each profile.
local PROFILE_DEFAULTS = {
	locked = true,
	scale = 1,
	-- Each bar's width as a multiple of its default. The player and target bars are linked to share one
	-- width, and so are the pet and target of target bars, until one is changed on its own.
	playerWidth = 1,
	targetWidth = 1,
	widthsLinked = true,
	petWidth = 1,
	totWidth = 1,
	outerWidthsLinked = true,
	showTargetOfTarget = true,
	showSurnames = false,
	showHealPrediction = true,
	showPvPIcon = true,
	castTextPlacement = "below", -- or "above" the orb
	showPet = true,
	orbStyle = "animated", -- or "plain"
	showManaSpark = true, -- the five second rule
	showSwingTimer = true,
	showCastIcon = true,
	opacityMode = "smart",
	manualOpacity = 0.6,
	-- Orb centre relative to the bottom centre of the screen, in UIParent units so it holds still when scaling.
	x = 0,
	y = Layout.originY,
}

-- Settings shared by the whole account, whichever profile a character uses.
local ACCOUNT_DEFAULTS = {
	showMinimapButton = true,
	minimapAngle = 225, -- degrees anticlockwise from 3 o'clock, so the lower left of the minimap
}

local root, mover

local function Clamp(value, range)
	return math.min(math.max(value, range.min), range.max)
end

-- Text spots that were named after what they showed, before they were named after where they sit.
local RENAMED_TEXT = {
	playerDeficit = "playerLeft",
	playerHealth = "playerRight",
	petHealth = "petCenter",
	targetHealth = "targetRight",
	targetPower = "targetPowerRight",
	orbPower = "orbCenter",
}

-- Custom text styles by field key. Anything unknown or malformed is dropped rather than applied.
local function CleanTextStyles(styles)
	if type(styles) ~= "table" then
		return {}
	end
	for oldKey, newKey in pairs(RENAMED_TEXT) do
		if styles[newKey] == nil then
			styles[newKey] = styles[oldKey]
		end
		styles[oldKey] = nil
	end
	for key, style in pairs(styles) do
		if not ns.TextFields[key] or type(style) ~= "table" then
			styles[key] = nil
		else
			if type(style.font) ~= "string" then
				style.font = nil
			end
			style.size = type(style.size) == "number" and Clamp(math.floor(style.size + 0.5), ns.TextSizeRange) or nil
			for _, part in ipairs({ "offsetX", "offsetY" }) do
				local offset = style[part]
				style[part] = type(offset) == "number" and Clamp(math.floor(offset + 0.5), ns.TextOffsetRange) or nil
			end
			local color = style.color
			if type(color) ~= "table" or type(color[1]) ~= "number" or type(color[2]) ~= "number" or type(color[3]) ~= "number" then
				style.color = nil
			end
			for _, part in ipairs({ "enabled", "mouseover" }) do
				if type(style[part]) ~= "boolean" then
					style[part] = nil
				end
			end
			if not (ns.TextFields[key].values and ns.ValueFormatsByKey[style.format]) then
				style.format = nil
			end
			if not ns.OutlinesByKey[style.outline] then
				style.outline = nil
			end
			if not next(style) then
				styles[key] = nil
			end
		end
	end
	return styles
end

local function FillDefaults(settings, defaults)
	for key, value in pairs(defaults) do
		if settings[key] == nil then
			settings[key] = value
		end
	end
end

-- Before 0.2.0 the player and target bars shared one "width", and the pet and target of target bars
-- shared "petWidth". Each pair keeps its width, linked, so nothing moves.
local function MigrateWidths(profile)
	if profile.playerWidth == nil and type(profile.width) == "number" then
		profile.playerWidth, profile.targetWidth = profile.width, profile.width
	end
	profile.width = nil
	if profile.totWidth == nil and type(profile.petWidth) == "number" then
		profile.totWidth = profile.petWidth
	end
end

local WIDTH_KEYS = { "playerWidth", "targetWidth", "petWidth", "totWidth" }

-- Fills in what's missing and corrects what's out of range. Returns the profile.
function ns.CleanProfile(profile)
	MigrateWidths(profile)
	FillDefaults(profile, PROFILE_DEFAULTS)
	profile.scale = Clamp(profile.scale, ns.ScaleRange)
	for _, key in ipairs(WIDTH_KEYS) do
		if type(profile[key]) ~= "number" then
			profile[key] = PROFILE_DEFAULTS[key]
		end
		profile[key] = Clamp(profile[key], ns.WidthRange)
	end
	for _, key in ipairs({ "widthsLinked", "outerWidthsLinked" }) do
		if type(profile[key]) ~= "boolean" then
			profile[key] = PROFILE_DEFAULTS[key]
		end
	end
	if not ns.OpacityModesByKey[profile.opacityMode] then
		profile.opacityMode = PROFILE_DEFAULTS.opacityMode
	end
	if type(profile.manualOpacity) ~= "number" then
		profile.manualOpacity = PROFILE_DEFAULTS.manualOpacity
	end
	profile.manualOpacity = Clamp(profile.manualOpacity, ns.OpacityRange)
	if type(profile.masterFont) ~= "string" then
		profile.masterFont = nil
	end
	for _, key in ipairs({ "showPet", "showManaSpark", "showSwingTimer", "showCastIcon" }) do
		if type(profile[key]) ~= "boolean" then
			profile[key] = PROFILE_DEFAULTS[key]
		end
	end
	if profile.orbStyle ~= "animated" and profile.orbStyle ~= "plain" then
		profile.orbStyle = PROFILE_DEFAULTS.orbStyle
	end
	if profile.castTextPlacement ~= "below" and profile.castTextPlacement ~= "above" then
		profile.castTextPlacement = PROFILE_DEFAULTS.castTextPlacement
	end
	profile.text = CleanTextStyles(profile.text)
	profile.auras = ns.CleanAuraSettings(profile.auras)
	profile.combatText = ns.CleanCombatTextSettings(profile.combatText, profile)
	return profile
end

-- DibsUIDB holds the account's settings, every profile, and which profile each character uses.
-- ns.db is the profile this character uses, and ns.account the shared settings.
function ns.LoadSettings()
	local saved = type(DibsUIDB) == "table" and DibsUIDB or {}
	DibsUIDB = saved

	-- Before profiles, one set of settings sat at the top level. It becomes the Default profile.
	if type(saved.profiles) ~= "table" then
		local profile = { text = saved.text, width = saved.width }
		saved.text, saved.width = nil, nil
		for key in pairs(PROFILE_DEFAULTS) do
			profile[key], saved[key] = saved[key], nil
		end
		saved.profiles = { [ns.DEFAULT_PROFILE] = profile }
	end
	for name, profile in pairs(saved.profiles) do
		if type(name) ~= "string" or type(profile) ~= "table" then
			saved.profiles[name] = nil
		else
			ns.CleanProfile(profile)
		end
	end
	saved.profiles[ns.DEFAULT_PROFILE] = saved.profiles[ns.DEFAULT_PROFILE] or ns.CleanProfile({})
	if type(saved.characters) ~= "table" then
		saved.characters = {}
	end
	FillDefaults(saved, ACCOUNT_DEFAULTS)
	-- The buffs DibsUI has learned the durations of, shared by every character.
	saved.learnedBuffs = ns.CleanLearnedBuffs(saved.learnedBuffs)
	ns.account = saved

	-- A character whose profile has been deleted goes back to Default.
	ns.characterKey = UnitName("player") .. " - " .. GetRealmName()
	local name = saved.characters[ns.characterKey]
	if not saved.profiles[name] then
		name = ns.DEFAULT_PROFILE
		saved.characters[ns.characterKey] = nil
	end
	ns.profileName = name
	ns.db = saved.profiles[name]
end

-- side is -1 for the left wing (player) and 1 for the right (target).
local function WidthSetting(spec, side)
	return spec.widthSettings[side < 0 and 1 or 2]
end

-- How much longer the width setting makes a bar, in UI units. A negative value means shorter.
function ns.GetBarGrowth(spec, side)
	return (ns.db[WidthSetting(spec, side)] - 1) * (spec.fillOuter - spec.fillInner)
end

-- How far a bar moves away from the orb to stay attached to the bar it follows, on the same side.
function ns.GetBarShift(spec, side)
	return spec.followsHealth and ns.GetBarGrowth(Layout.health, side) or 0
end

-- How far from the orb's centre a bar's outer tip reaches, with its width and shift.
function ns.GetBarReach(spec, side)
	return spec.tip + ns.GetBarGrowth(spec, side) + ns.GetBarShift(spec, side)
end

-- How far the frames reach on one side: the pet bar on the left, and on the right the target of target
-- bar while it's shown, or else the target bar.
function ns.GetWingReach(side)
	if side < 0 or ns.db.showTargetOfTarget then
		return ns.GetBarReach(Layout.pet, side)
	end
	return ns.GetBarReach(Layout.health, side)
end

-- The root stays centred on the orb, so it's as wide as the longer health bar on both sides.
function ns.GetRootWidth()
	return 2 * (math.max(ns.GetBarReach(Layout.health, -1), ns.GetBarReach(Layout.health, 1)) + Layout.rootMargin)
end

local function ApplyPlacement()
	local db = ns.db
	root:SetScale(db.scale)
	root:ClearAllPoints()
	-- SetPoint offsets are multiplied by the frame's own scale.
	root:SetPoint("CENTER", UIParent, "BOTTOM", db.x / db.scale, db.y / db.scale)
end

-- Everything hangs off this frame, so it's the one thing that moves and scales. The secure unit
-- buttons are anchored to it, which means it can't be moved or scaled during combat.
function ns.CreateRoot()
	root = CreateFrame("Frame", nil, UIParent)
	root:SetFrameStrata("LOW")
	root:SetSize(ns.GetRootWidth(), Layout.rootHeight)
	root:SetMovable(true)
	root:SetClampedToScreen(true)
	root:SetDontSavePosition(true)
	ApplyPlacement()
	ns.root = root
end

local function SavePosition()
	local db = ns.db
	local x, y = root:GetCenter()
	db.x = x * db.scale - UIParent:GetWidth() / 2
	db.y = y * db.scale
end

local function FinishMoving()
	if mover.isMoving then
		mover.isMoving = false
		root:StopMovingOrSizing()
		root:SetUserPlaced(false)
		SavePosition()
		ApplyPlacement()
	end
end

local function UpdateMover()
	mover:SetShown(not ns.db.locked and not InCombatLockdown())
	ns.UpdateOpacity()
	ns.UpdateAuraMovers()
	ns.UpdateCombatTextMover()
end

-- The handle covers everything from the pet bar's tip to the far tip on the right, which can differ
-- now each side has its own widths.
local function LayoutMover()
	mover:ClearAllPoints()
	mover:SetPoint("TOPLEFT", root, "TOP", -(ns.GetWingReach(-1) + Layout.rootMargin), 0)
	mover:SetPoint("BOTTOMRIGHT", root, "BOTTOM", ns.GetWingReach(1) + Layout.rootMargin, 0)
end

-- Left click on the bars targets, so dragging needs its own handle above them while unlocked.
function ns.CreateMover()
	mover = CreateFrame("Frame", nil, root)
	LayoutMover()
	mover:SetFrameStrata("MEDIUM")
	mover:EnableMouse(true)
	mover:RegisterForDrag("LeftButton")

	local tint = ns.CreateArt(mover, "BACKGROUND", "Flat")
	tint:SetAllPoints()
	tint:SetVertexColor(0.15, 0.45, 1, 0.3)

	local labelSpec = ns.Text.moverLabel
	local label = ns.CreateText(mover, "moverLabel")
	label:SetPoint("TOP", mover, "TOP", labelSpec.x, labelSpec.y)
	label:SetText("DibsUI: drag to move")

	mover:SetScript("OnDragStart", function(self)
		self.isMoving = true
		root:StartMoving()
	end)
	mover:SetScript("OnDragStop", FinishMoving)

	mover:SetShown(not ns.db.locked and not InCombatLockdown())

	-- Protected frames can't move in combat, so drop any drag in progress the moment it starts.
	-- This event fires just before the lockdown begins.
	local events = CreateFrame("Frame")
	events:RegisterEvent("PLAYER_REGEN_DISABLED")
	events:RegisterEvent("PLAYER_REGEN_ENABLED")
	events:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_REGEN_DISABLED" then
			FinishMoving()
			mover:Hide()
		else
			UpdateMover()
		end
	end)
end

function ns.SetLocked(locked)
	ns.db.locked = locked
	FinishMoving()
	UpdateMover()
end

-- Returns the scale in effect, which is unchanged during combat.
function ns.SetScale(scale)
	if not InCombatLockdown() then
		ns.db.scale = Clamp(math.floor(scale * 100 + 0.5) / 100, ns.ScaleRange)
		ApplyPlacement()
	end
	return ns.db.scale
end

-- Widths ---------------------------------------------------------------------------------------------

-- The frames with a width of their own, by the name the settings use, and the pair each belongs to.
-- The first of a pair is the one the other takes its width from when they're linked again.
local FRAME_WIDTHS = { player = "playerWidth", target = "targetWidth", pet = "petWidth", tot = "totWidth" }
local WIDTH_PAIRS = {
	main = { "player", "target", linked = "widthsLinked" },
	outer = { "pet", "tot", linked = "outerWidthsLinked" },
}
local PAIR_OF = { player = "main", target = "main", pet = "outer", tot = "outer" }

-- Every bar, the root and the drag handle follow the widths. They move secure frames, so not in combat.
local function ApplyWidths()
	root:SetSize(ns.GetRootWidth(), Layout.rootHeight)
	ns.UpdateBarWidths()
	LayoutMover()
end

local function RoundWidth(width)
	return Clamp(math.floor(width * 100 + 0.5) / 100, ns.WidthRange)
end

function ns.GetFrameWidth(frame)
	return ns.db[FRAME_WIDTHS[frame]]
end

function ns.IsWidthLinked(pair)
	return ns.db[WIDTH_PAIRS[pair].linked]
end

-- One frame's own width, from its own tab. Changing one of a linked pair unlinks it, so the other
-- keeps its width. Returns the width in effect, which is unchanged during combat.
function ns.SetFrameWidth(frame, width)
	if not InCombatLockdown() then
		ns.db[FRAME_WIDTHS[frame]] = RoundWidth(width)
		ns.db[WIDTH_PAIRS[PAIR_OF[frame]].linked] = false
		ApplyWidths()
	end
	return ns.GetFrameWidth(frame)
end

-- Both frames of a linked pair at once, from the General tab. Returns the width in effect.
function ns.SetPairWidth(pair, width)
	local frames = WIDTH_PAIRS[pair]
	if not InCombatLockdown() then
		width = RoundWidth(width)
		ns.db[FRAME_WIDTHS[frames[1]]], ns.db[FRAME_WIDTHS[frames[2]]] = width, width
		ApplyWidths()
	end
	return ns.GetFrameWidth(frames[1])
end

-- Linking a pair again gives the second frame the first one's width.
function ns.SetWidthLinked(pair, linked)
	if InCombatLockdown() then
		return
	end
	local frames = WIDTH_PAIRS[pair]
	ns.db[frames.linked] = linked
	if linked then
		ns.db[FRAME_WIDTHS[frames[2]]] = ns.GetFrameWidth(frames[1])
		ApplyWidths()
	end
end

function ns.SetTargetOfTargetShown(shown)
	if not InCombatLockdown() then
		ns.db.showTargetOfTarget = shown
		ns.UpdateTargetOfTargetShown()
		ns.UpdateBarWidths()
		LayoutMover()
	end
end

function ns.CenterHorizontally()
	if not InCombatLockdown() then
		ns.db.x = 0
		ApplyPlacement()
	end
end

-- Moves by whole screen pixels. x and y are in pixels, whatever the UI scale.
function ns.Nudge(x, y)
	if not InCombatLockdown() then
		local pixel = PixelUtil.ConvertPixelsToUIForRegion(1, UIParent)
		ns.db.x = ns.db.x + x * pixel
		ns.db.y = ns.db.y + y * pixel
		ApplyPlacement()
	end
end

-- Puts every frame where the current profile says, after switching to another one. This moves and
-- resizes the secure buttons, so it can't happen in combat.
function ns.ApplyProfile()
	FinishMoving()
	root:SetSize(ns.GetRootWidth(), Layout.rootHeight)
	ApplyPlacement()
	ns.UpdateTargetOfTargetShown()
	ns.UpdatePetShown()
	ns.UpdateBarWidths()
	LayoutMover()
	UpdateMover()
	ns.RefreshAllText()
	ns.RefreshAuraFrames()
	ns.UpdateHealPredictionShown()
	ns.UpdatePvPIndicator()
	ns.UpdateCastTextPlacement()
	ns.UpdateOrb()
	ns.RefreshCombatText()
end

-- Not protected, so this works in combat, even mid-cast.
function ns.SetCastTextPlacement(placement)
	ns.db.castTextPlacement = placement
	ns.UpdateCastTextPlacement()
end

-- Last names are only text, so this works in combat too.
function ns.SetSurnamesShown(shown)
	ns.db.showSurnames = shown
	ns.RefreshAllText()
end

-- The pet bar's click area is a secure button, so this waits for combat to end like the other frames.
function ns.SetPetShown(shown)
	if not InCombatLockdown() then
		ns.db.showPet = shown
		ns.UpdatePetShown()
	end
end

-- The orb and cast ring settings aren't protected, so they all work in combat.

function ns.SetOrbStyle(style)
	ns.db.orbStyle = style
	ns.UpdateOrbLiquid()
end

function ns.SetManaSparkShown(shown)
	ns.db.showManaSpark = shown
	ns.UpdateManaSpark()
end

function ns.SetSwingTimerShown(shown)
	ns.db.showSwingTimer = shown
	ns.UpdateSwingTimer()
end

function ns.SetCastIconShown(shown)
	ns.db.showCastIcon = shown
	ns.UpdateCastTextPlacement()
end

-- After switching profiles.
function ns.UpdateOrb()
	ns.UpdateOrbLiquid()
	ns.UpdateManaSpark()
	ns.UpdateSwingTimer()
end
