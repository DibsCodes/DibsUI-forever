local _, ns = ...

local Layout = ns.Layout

ns.ScaleRange = { min = 0.5, max = 2, step = 0.05 }
ns.WidthRange = { min = 0.5, max = 2, step = 0.05 }
ns.TextSizeRange = { min = 6, max = 40, step = 1 }

local DEFAULTS = {
	locked = true,
	scale = 1,
	width = 1,
	petWidth = 1,
	showTargetOfTarget = true,
	showMinimapButton = true,
	minimapAngle = 225, -- degrees anticlockwise from 3 o'clock, so the lower left of the minimap
	-- Orb centre relative to the bottom centre of the screen, in UIParent units so it holds still when scaling.
	x = 0,
	y = Layout.originY,
}

local root, mover

local function Clamp(value, range)
	return math.min(math.max(value, range.min), range.max)
end

-- Custom text styles by field key. Anything unknown or malformed is dropped rather than applied.
local function CleanTextStyles(styles)
	if type(styles) ~= "table" then
		return {}
	end
	for key, style in pairs(styles) do
		if not ns.TextFields[key] or type(style) ~= "table" then
			styles[key] = nil
		else
			if type(style.font) ~= "string" then
				style.font = nil
			end
			style.size = type(style.size) == "number" and Clamp(math.floor(style.size + 0.5), ns.TextSizeRange) or nil
			local color = style.color
			if type(color) ~= "table" or type(color[1]) ~= "number" or type(color[2]) ~= "number" or type(color[3]) ~= "number" then
				style.color = nil
			end
			if not next(style) then
				styles[key] = nil
			end
		end
	end
	return styles
end

function ns.LoadSettings()
	DibsUIDB = DibsUIDB or {}
	for key, value in pairs(DEFAULTS) do
		if DibsUIDB[key] == nil then
			DibsUIDB[key] = value
		end
	end
	DibsUIDB.scale = Clamp(DibsUIDB.scale, ns.ScaleRange)
	DibsUIDB.width = Clamp(DibsUIDB.width, ns.WidthRange)
	DibsUIDB.petWidth = Clamp(DibsUIDB.petWidth, ns.WidthRange)
	DibsUIDB.text = CleanTextStyles(DibsUIDB.text)
	ns.db = DibsUIDB
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
