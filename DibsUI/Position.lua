local _, ns = ...

local Layout = ns.Layout

ns.ScaleRange = { min = 0.5, max = 2, step = 0.05 }

local DEFAULTS = {
	locked = true,
	scale = 1,
	-- Orb centre relative to the bottom centre of the screen, in UIParent units so it holds still when scaling.
	x = 0,
	y = Layout.originY,
}

local root, mover

local function ClampScale(scale)
	return math.min(math.max(scale, ns.ScaleRange.min), ns.ScaleRange.max)
end

function ns.LoadSettings()
	DibsUIDB = DibsUIDB or {}
	for key, value in pairs(DEFAULTS) do
		if DibsUIDB[key] == nil then
			DibsUIDB[key] = value
		end
	end
	DibsUIDB.scale = ClampScale(DibsUIDB.scale)
	ns.db = DibsUIDB
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
	root:SetSize(Layout.rootWidth, Layout.rootHeight)
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
end

-- Left click on the bars targets, so dragging needs its own handle above them while unlocked.
function ns.CreateMover()
	mover = CreateFrame("Frame", nil, root)
	mover:SetAllPoints()
	mover:SetFrameStrata("MEDIUM")
	mover:EnableMouse(true)
	mover:RegisterForDrag("LeftButton")

	local tint = ns.CreateArt(mover, "BACKGROUND", "Flat")
	tint:SetAllPoints()
	tint:SetVertexColor(0.15, 0.45, 1, 0.3)

	local labelSpec = ns.Text.moverLabel
	local label = ns.CreateText(mover, labelSpec)
	label:SetPoint("TOP", mover, "TOP", labelSpec.x, labelSpec.y)
	label:SetText("DibsUI: drag to move")

	mover:SetScript("OnDragStart", function(self)
		self.isMoving = true
		root:StartMoving()
	end)
	mover:SetScript("OnDragStop", FinishMoving)

	UpdateMover()

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
		ns.db.scale = ClampScale(math.floor(scale * 100 + 0.5) / 100)
		ApplyPlacement()
	end
	return ns.db.scale
end
