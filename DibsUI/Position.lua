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
	width = 1,
	petWidth = 1,
	showTargetOfTarget = true,
	showSurnames = false,
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

-- Fills in what's missing and corrects what's out of range. Returns the profile.
function ns.CleanProfile(profile)
	FillDefaults(profile, PROFILE_DEFAULTS)
	profile.scale = Clamp(profile.scale, ns.ScaleRange)
	profile.width = Clamp(profile.width, ns.WidthRange)
	profile.petWidth = Clamp(profile.petWidth, ns.WidthRange)
	if not ns.OpacityModesByKey[profile.opacityMode] then
		profile.opacityMode = PROFILE_DEFAULTS.opacityMode
	end
	if type(profile.manualOpacity) ~= "number" then
		profile.manualOpacity = PROFILE_DEFAULTS.manualOpacity
	end
	profile.manualOpacity = Clamp(profile.manualOpacity, ns.OpacityRange)
	profile.text = CleanTextStyles(profile.text)
	profile.auras = ns.CleanAuraSettings(profile.auras)
	return profile
end

-- DibsUIDB holds the account's settings, every profile, and which profile each character uses.
-- ns.db is the profile this character uses, and ns.account the shared settings.
function ns.LoadSettings()
	local saved = type(DibsUIDB) == "table" and DibsUIDB or {}
	DibsUIDB = saved

	-- Before profiles, one set of settings sat at the top level. It becomes the Default profile.
	if type(saved.profiles) ~= "table" then
		local profile = { text = saved.text }
		saved.text = nil
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

-- How much longer the width setting makes a bar, in UI units. A negative value means shorter.
function ns.GetBarGrowth(spec)
	return (ns.db[spec.widthSetting] - 1) * (spec.fillOuter - spec.fillInner)
end

-- How far a bar moves away from the orb to stay attached to the bar it follows.
function ns.GetBarShift(spec)
	return spec.followsHealth and ns.GetBarGrowth(Layout.health) or 0
end

function ns.GetRootWidth()
	return 2 * (Layout.health.tip + ns.GetBarGrowth(Layout.health) + Layout.rootMargin)
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
end

-- The root stays symmetrical around the orb and only covers the health bars, so the pet and target
-- of target bars hang out past its edges by this much.
function ns.GetOuterBarOverhang()
	return Layout.pet.tip + ns.GetBarGrowth(Layout.pet) - Layout.health.tip
end

local function LayoutMover()
	local overhang = ns.GetOuterBarOverhang()
	mover:ClearAllPoints()
	mover:SetPoint("TOPLEFT", root, "TOPLEFT", -overhang, 0)
	mover:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", ns.db.showTargetOfTarget and overhang or 0, 0)
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

-- Returns the width in effect, which is unchanged during combat.
function ns.SetWidth(width)
	if not InCombatLockdown() then
		ns.db.width = Clamp(math.floor(width * 100 + 0.5) / 100, ns.WidthRange)
		root:SetSize(ns.GetRootWidth(), Layout.rootHeight)
		ns.UpdateBarWidths()
	end
	return ns.db.width
end

-- Returns the width of the pet and target of target bars in effect, which is unchanged during combat.
function ns.SetPetWidth(width)
	if not InCombatLockdown() then
		ns.db.petWidth = Clamp(math.floor(width * 100 + 0.5) / 100, ns.WidthRange)
		ns.UpdateBarWidths()
		LayoutMover()
	end
	return ns.db.petWidth
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
	ns.UpdateBarWidths()
	LayoutMover()
	UpdateMover()
	ns.RefreshAllText()
	ns.RefreshAuraFrames()
end

-- Last names are only text, so this works in combat too.
function ns.SetSurnamesShown(shown)
	ns.db.showSurnames = shown
	ns.RefreshAllText()
end
