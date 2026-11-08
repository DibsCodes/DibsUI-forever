local _, ns = ...

local Layout = ns.Layout

-- Health and power can be secret values, so they only ever go straight into the widgets.
-- Never compare, test or do arithmetic on them here.
local SMOOTH = Enum.StatusBarInterpolation.ExponentialEaseOut
local IMMEDIATE = Enum.StatusBarInterpolation.Immediate

local SLIDE_DURATION = 0.25

-- Alpha 0 at empty and 1 above it, so an empty bar shows no sliver of its slanted cap.
local VISIBLE_ABOVE_ZERO = C_CurveUtil.CreateCurve()
VISIBLE_ABOVE_ZERO:SetType(Enum.LuaCurveType.Step)
VISIBLE_ABOVE_ZERO:AddPoint(0, 0)
VISIBLE_ABOVE_ZERO:AddPoint(0.001, 1)

local function SetBarColor(bar, r, g, b)
	bar:SetStatusBarColor(r, g, b)
	bar.cap:SetVertexColor(r, g, b)
	if bar.wedge then
		bar.wedge:SetVertexColor(r, g, b)
	end
end

local bars = {}

local function CreateArtSlices(parent, layer, fileName, side, art)
	local quad = art.width
	-- The middle reads a narrow band and only ever stretches. Squeezing a wider strip into a short
	-- bar would blur the border into dark notches.
	local ranges = {
		{ 0, art.sliceInner },
		{ art.sliceInner, art.sliceInner + 4 },
		{ art.sliceTip, quad },
	}
	local slices = {}
	for i, range in ipairs(ranges) do
		local slice = ns.CreateArt(parent, layer, fileName)
		local left, right = range[1] / quad, range[2] / quad
		if side < 0 then
			slice:SetTexCoord(right, left, 0, 1)
		else
			slice:SetTexCoord(left, right, 0, 1)
		end
		slices[i] = slice
	end
	return slices
end

local function LayoutArtSlices(slices, button, growth, centerDistance)
	local art = button.spec.art
	local edges = { art.start, art.start + art.sliceInner, art.start + art.sliceTip + growth, art.start + art.width + growth }
	for i, slice in ipairs(slices) do
		slice:SetSize(edges[i + 1] - edges[i], Layout.barQuadHeight)
		slice:ClearAllPoints()
		slice:SetPoint("CENTER", button.body, "CENTER", button.side * ((edges[i] + edges[i + 1]) / 2 - centerDistance), 0)
	end
end

-- Applies the width setting: the click area, the visible body, the art and the fill.
local function LayoutBar(button)
	local spec, side = button.spec, button.side
	local growth = ns.GetBarGrowth(spec)
	local tip = spec.tip + growth
	local width = tip - spec.hitInner
	local centerDistance = (tip + spec.hitInner) / 2
	local shift = ns.GetBarShift(spec)

	button:SetSize(width, spec.height)
	button:ClearAllPoints()
	button:SetPoint("CENTER", ns.root, "CENTER", side * (centerDistance + shift), spec.yCenter)

	local body = button.body
	body:SetSize(width, spec.height)
	body:ClearAllPoints()
	body:SetPoint("CENTER", button.visualParent, "CENTER", side * (centerDistance + shift), spec.yCenter)

	LayoutArtSlices(button.backSlices, button, growth, centerDistance)
	LayoutArtSlices(button.frameSlices, button, growth, centerDistance)

	local fillOuter = spec.fillOuter + growth
	button.bar:SetSize(fillOuter - spec.fillInner, spec.fillHeight)
	button.bar:ClearAllPoints()
	button.bar:SetPoint("CENTER", body, "CENTER", side * ((fillOuter + spec.fillInner) / 2 - centerDistance), 0)

	if button.nameText then
		button.nameText:SetWidth(width - button.nameReserved)
	end
end

-- side is -1 for the left wing and 1 for the right. The bar is two separate things. The secure
-- button is an invisible click area: left click targets the unit, right click opens its menu.
-- Secure frames can't move in combat, so everything visible lives on a plain "body" frame beside it,
-- under visualParent, which is free to slide.
local function CreateBar(name, unit, spec, side, visualParent)
	local button = CreateFrame("Button", name, ns.root, "SecureUnitButtonTemplate")
	button:SetFrameStrata("LOW")
	button:SetFrameLevel(ns.Level.bar)
	button:RegisterForClicks("AnyUp")
	button:SetAttribute("unit", unit)
	button:SetAttribute("*type1", "target")
	button:SetAttribute("*type2", "togglemenu")

	local body = CreateFrame("Frame", nil, visualParent)
	body:SetFrameLevel(ns.Level.bar)

	local bar = CreateFrame("StatusBar", nil, body)
	bar:SetStatusBarTexture(ns.Media("BarFill"))
	-- Fill grows away from the orb, so the left wing runs right to left.
	bar:SetFillStyle(Enum.StatusBarFillStyle.StandardNoRangeFill)
	bar:SetReverseFill(side < 0)

	-- A triangle riding on the fill's moving edge gives it the same slant as the bar's outline.
	-- The pieces meet edge to edge: an overlap would show as a line at the resting opacity.
	local fill = bar:GetStatusBarTexture()
	local cap = ns.CreateArt(bar, "ARTWORK", "BarFillCap")
	cap:SetWidth(spec.capWidth)
	if side < 0 then
		cap:SetPoint("TOPRIGHT", fill, "TOPLEFT")
		cap:SetPoint("BOTTOMRIGHT", fill, "BOTTOMLEFT")
		cap:SetTexCoord(1, 0, 0, 1)
	else
		cap:SetPoint("TOPLEFT", fill, "TOPRIGHT")
		cap:SetPoint("BOTTOMLEFT", fill, "BOTTOMRIGHT")
	end
	bar.cap = cap

	if spec.wedgeWidth then
		local wedge = ns.CreateArt(bar, "ARTWORK", spec.wedgeArt)
		wedge:SetWidth(spec.wedgeWidth)
		if side < 0 then
			wedge:SetPoint("TOPLEFT", bar, "TOPRIGHT")
			wedge:SetPoint("BOTTOMLEFT", bar, "BOTTOMRIGHT")
			wedge:SetTexCoord(1, 0, 0, 1)
		else
			wedge:SetPoint("TOPRIGHT", bar, "TOPLEFT")
			wedge:SetPoint("BOTTOMRIGHT", bar, "BOTTOMLEFT")
		end
		bar.wedge = wedge
	end

	-- The double border sits above the fill.
	local overlay = CreateFrame("Frame", nil, body)
	overlay:SetAllPoints()
	overlay:SetFrameLevel(bar:GetFrameLevel() + 1)

	button.spec = spec
	button.side = side
	button.visualParent = visualParent
	button.body = body
	button.bar = bar
	button.overlay = overlay
	button.backSlices = CreateArtSlices(body, "BACKGROUND", spec.back, side, spec.art)
	button.frameSlices = CreateArtSlices(overlay, "ARTWORK", spec.frame, side, spec.art)
	bars[#bars + 1] = button
	return button
end

-- Name and level sit above the bar, so they're capped to its width rather than running under the orb.
local function PlaceName(text, button, spec, reserved)
	ns.PlaceText(text, "BOTTOM", button.body, "TOP", spec.x, spec.y)
	button.nameText = text
	button.nameReserved = reserved
end

local function UpdateHealth(bar, unit, interpolation)
	bar:SetMinMaxValues(0, UnitHealthMax(unit))
	bar:SetValue(UnitHealth(unit), interpolation)
	-- A slanted fill would still show a sliver of the corner at zero or ghost health.
	bar:SetShown(not UnitIsDeadOrGhost(unit))
end

local function UpdatePower(bar, unit, interpolation)
	local powerType, powerToken = UnitPowerType(unit)
	if not powerType then
		return
	end
	SetBarColor(bar, ns.GetPowerColor(powerToken))
	bar:SetMinMaxValues(0, UnitPowerMax(unit, powerType))
	bar:SetValue(UnitPower(unit, powerType), interpolation)
	bar.cap:SetAlpha(UnitPowerPercent(unit, powerType, false, VISIBLE_ABOVE_ZERO))
end

-- nil unless the unit is a friendly player whose class can be read.
local function GetFriendlyClassColor(unit)
	if UnitIsFriend("player", unit) and UnitIsPlayer(unit) then
		return ns.GetUnitClassColor(unit)
	end
end

local function UpdateTargetColor(bar, unit)
	if not UnitIsConnected(unit) or UnitIsTapDenied(unit) then
		local color = ns.Colors.disabled
		SetBarColor(bar, color[1], color[2], color[3])
		return
	end
	local classColor = GetFriendlyClassColor(unit)
	if classColor then
		SetBarColor(bar, classColor.r, classColor.g, classColor.b)
	else
		local r, g, b = UnitSelectionColor(unit)
		SetBarColor(bar, r, g, b)
	end
end

local function CreatePlayerName(button)
	local overlay = button.overlay
	local name = ns.CreateText(overlay, "playerName", button)
	PlaceName(name, button, ns.Text.playerName, 0)

	local function Update()
		local classColor = ns.GetUnitClassColor("player")
		if classColor then
			ns.SetTextColor(name, classColor.r, classColor.g, classColor.b)
		end
		name:SetFormattedText("%s |cffffff00%d|r", UnitName("player"), UnitEffectiveLevel("player"))
	end

	overlay:RegisterUnitEvent("UNIT_NAME_UPDATE", "player")
	overlay:RegisterUnitEvent("UNIT_LEVEL", "player")
	overlay:RegisterEvent("PLAYER_LEVEL_UP")
	overlay:RegisterEvent("PLAYER_ENTERING_WORLD")
	overlay:SetScript("OnEvent", Update)
end

local function CreatePlayerHealth()
	local button = CreateBar("DibsUIPlayerHealth", "player", Layout.health, -1, ns.root)
	local bar = button.bar
	local color = ns.Colors.playerHealth
	SetBarColor(bar, color[1], color[2], color[3])

	local left = ns.CreateValueText(button.overlay, "playerLeft", button.body, "LEFT", button)
	local right = ns.CreateValueText(button.overlay, "playerRight", button.body, "RIGHT", button)

	bar:RegisterUnitEvent("UNIT_HEALTH", "player")
	bar:RegisterUnitEvent("UNIT_MAXHEALTH", "player")
	bar:RegisterEvent("PLAYER_ENTERING_WORLD")
	bar:RegisterEvent("PLAYER_DEAD")
	bar:RegisterEvent("PLAYER_ALIVE")
	bar:RegisterEvent("PLAYER_UNGHOST")
	bar:SetScript("OnEvent", function(self, event)
		local interpolation = event == "UNIT_HEALTH" and SMOOTH or IMMEDIATE
		UpdateHealth(self, "player", interpolation)
		ns.ShowValue(left, "player")
		ns.ShowValue(right, "player")
	end)

	CreatePlayerName(button)
end

-- Name and level above the bar, and Blizzard's happiness icon, which keeps itself up to date and
-- hides for pets that aren't a hunter's. It only needs telling when there's a new pet to show.
local function CreatePetName(button)
	local overlay = button.overlay
	local nameSpec = ns.Text.petName
	local name = ns.CreateText(overlay, "petName", button)
	ns.PlaceText(name, "BOTTOM", button.body, "TOP", nameSpec.x, nameSpec.y)

	local iconSpec = ns.Text.petHappiness
	local happiness = CreateFrame("Frame", nil, overlay, "PetFrameHappinessTemplate")
	happiness:SetSize(iconSpec.size, iconSpec.size)
	happiness:SetPoint("BOTTOMLEFT", button.body, "BOTTOMLEFT", iconSpec.x, iconSpec.y)

	overlay:RegisterUnitEvent("UNIT_NAME_UPDATE", "pet")
	overlay:RegisterUnitEvent("UNIT_LEVEL", "pet")
	overlay:RegisterUnitEvent("UNIT_PET", "player")
	overlay:RegisterEvent("PET_UI_UPDATE")
	overlay:RegisterEvent("PLAYER_ENTERING_WORLD")
	overlay:SetScript("OnEvent", function()
		if UnitExists("pet") then
			name:SetFormattedText("%s |cffffff00%d|r", UnitName("pet"), UnitEffectiveLevel("pet"))
			happiness:UpdateHappiness()
		end
	end)
end

local function CreatePetHealth()
	local spec = Layout.pet
	local button = CreateBar("DibsUIPetHealth", "pet", spec, -1, ns.root)
	button:SetHitRectInsets(0, spec.hitInset, 0, 0)
	RegisterUnitWatch(button)
	local bar = button.bar
	local color = ns.Colors.playerHealth
	SetBarColor(bar, color[1], color[2], color[3])

	local health = ns.CreateValueText(button.overlay, "petCenter", button.body, "CENTER", button)

	bar:RegisterUnitEvent("UNIT_HEALTH", "pet")
	bar:RegisterUnitEvent("UNIT_MAXHEALTH", "pet")
	bar:RegisterUnitEvent("UNIT_PET", "player")
	bar:RegisterEvent("PET_UI_UPDATE")
	bar:RegisterEvent("PLAYER_ENTERING_WORLD")
	bar:SetScript("OnEvent", function(self, event)
		local hasPet = UnitExists("pet")
		button.body:SetShown(hasPet)
		if not hasPet then
			return
		end
		local interpolation = event == "UNIT_HEALTH" and SMOOTH or IMMEDIATE
		UpdateHealth(self, "pet", interpolation)
		ns.ShowValue(health, "pet")
	end)

	CreatePetName(button)
end

-- Class color for friendly players, reaction color for friendly NPCs, otherwise the default white.
local function UpdateTargetNameColor(name, unit)
	local classColor = GetFriendlyClassColor(unit)
	if classColor then
		ns.SetTextColor(name, classColor.r, classColor.g, classColor.b)
	elseif UnitIsFriend("player", unit) then
		local r, g, b = UnitSelectionColor(unit)
		ns.SetTextColor(name, r, g, b)
	else
		ns.SetTextColor(name, 1, 1, 1)
	end
end

local function UpdateTargetLevel(level, unit)
	local effectiveLevel = UnitEffectiveLevel(unit)
	level:SetText(effectiveLevel > 0 and effectiveLevel or "??")
	-- Grey, green, yellow, orange or red.
	local color = GetDifficultyColor(C_PlayerInfo.GetContentDifficultyCreatureForPlayer(unit))
	ns.SetTextColor(level, color.r, color.g, color.b)
end

local function CreateTargetName(button)
	local overlay = button.overlay

	local level = ns.CreateText(overlay, "targetLevel", button)
	ns.PlaceText(level, "BOTTOMRIGHT", button.body, "TOPRIGHT", ns.Text.targetLevel.x, ns.Text.targetLevel.y)

	-- Leaves room each side so a long name stays centred and clear of the level.
	local name = ns.CreateText(overlay, "targetName", button)
	PlaceName(name, button, ns.Text.targetName, 60)

	overlay:RegisterUnitEvent("UNIT_NAME_UPDATE", "target")
	overlay:RegisterUnitEvent("UNIT_FACTION", "target")
	overlay:RegisterUnitEvent("UNIT_LEVEL", "target")
	overlay:RegisterEvent("PLAYER_LEVEL_UP")
	overlay:RegisterEvent("PLAYER_TARGET_CHANGED")
	overlay:RegisterEvent("PLAYER_ENTERING_WORLD")
	overlay:SetScript("OnEvent", function()
		if not UnitExists("target") then
			return
		end
		name:SetText(UnitName("target"))
		UpdateTargetNameColor(name, "target")
		UpdateTargetLevel(level, "target")
	end)
end

-- The visible target bars sit on this plain frame, which slides out from under the ring when a
-- target is selected and back in when it's cleared.
local function CreateTargetWing()
	local clip = CreateFrame("Frame", nil, ns.root)
	clip:SetFrameLevel(ns.Level.bar)
	clip:SetClipsChildren(true)
	local wing = CreateFrame("Frame", nil, clip)
	wing:SetFrameLevel(ns.Level.bar)

	local offset, startOffset, endOffset, elapsed = 0, 0, 0, 0

	local function SetOffset(value)
		offset = value
		wing:ClearAllPoints()
		wing:SetPoint("CENTER", ns.root, "CENTER", value, 0)
	end

	-- Far enough for everything on the wing to end up past the clip edge.
	local function GetTuckedOffset()
		local outerSpec = ns.db.showTargetOfTarget and Layout.pet or Layout.health
		return Layout.wingClipInner - (outerSpec.tip + ns.GetBarGrowth(outerSpec) + ns.GetBarShift(outerSpec))
	end

	local function OnUpdate(_, delta)
		elapsed = elapsed + delta
		local progress = math.min(elapsed / SLIDE_DURATION, 1)
		local eased = 1 - (1 - progress) ^ 3
		SetOffset(startOffset + (endOffset - startOffset) * eased)
		if progress >= 1 then
			clip:SetScript("OnUpdate", nil)
			wing:SetShown(endOffset == 0)
		end
	end

	local function SlideTo(value)
		startOffset, endOffset, elapsed = offset, value, 0
		wing:Show()
		clip:SetScript("OnUpdate", OnUpdate)
	end

	local function Snap()
		clip:SetScript("OnUpdate", nil)
		local hasTarget = UnitExists("target")
		SetOffset(hasTarget and 0 or GetTuckedOffset())
		wing:SetShown(hasTarget)
	end

	local hasTarget = false

	clip:RegisterEvent("PLAYER_ENTERING_WORLD")
	clip:RegisterEvent("PLAYER_TARGET_CHANGED")
	clip:SetScript("OnEvent", function(_, event)
		local exists = UnitExists("target")
		if event == "PLAYER_ENTERING_WORLD" then
			hasTarget = exists
			Snap()
		-- Swapping from one target straight to another stays put.
		elseif exists ~= hasTarget then
			hasTarget = exists
			SlideTo(exists and 0 or GetTuckedOffset())
		end
	end)

	function wing:UpdateWidth()
		-- The target of target bar reaches past the root, and the clip has to leave room for it.
		clip:ClearAllPoints()
		clip:SetPoint("TOPLEFT", ns.root, "TOP", Layout.wingClipInner, 0)
		clip:SetPoint("BOTTOMRIGHT", ns.root, "BOTTOMRIGHT", ns.GetOuterBarOverhang(), 0)
		self:SetSize(ns.GetRootWidth(), Layout.rootHeight)
		if not hasTarget then
			Snap()
		end
	end

	return wing
end

-- The secure buttons only take clicks now, and RegisterUnitWatch shows and hides them,
-- since a secure frame can't be toggled from addon code in combat.
local function CreateTargetBars(wing)
	local healthButton = CreateBar("DibsUITargetHealth", "target", Layout.health, 1, wing)
	local powerButton = CreateBar("DibsUITargetPower", "target", Layout.power, 1, wing)
	RegisterUnitWatch(healthButton)
	RegisterUnitWatch(powerButton)

	local healthText = ns.CreateValueText(healthButton.overlay, "targetRight", healthButton.body, "RIGHT", healthButton)
	local powerText = ns.CreateValueText(powerButton.overlay, "targetPowerRight", powerButton.body, "RIGHT", powerButton)

	CreateTargetName(healthButton)

	local health = healthButton.bar
	health:RegisterUnitEvent("UNIT_HEALTH", "target")
	health:RegisterUnitEvent("UNIT_MAXHEALTH", "target")
	health:RegisterUnitEvent("UNIT_FACTION", "target")
	health:RegisterUnitEvent("UNIT_FLAGS", "target")
	health:RegisterUnitEvent("UNIT_CONNECTION", "target")
	health:RegisterEvent("PLAYER_TARGET_CHANGED")
	health:RegisterEvent("PLAYER_ENTERING_WORLD")
	health:SetScript("OnEvent", function(self, event)
		if not UnitExists("target") then
			return
		end
		local interpolation = event == "UNIT_HEALTH" and SMOOTH or IMMEDIATE
		UpdateHealth(self, "target", interpolation)
		UpdateTargetColor(self, "target")
		ns.ShowValue(healthText, "target")
	end)

	local power = powerButton.bar
	power:RegisterUnitEvent("UNIT_POWER_UPDATE", "target")
	power:RegisterUnitEvent("UNIT_POWER_FREQUENT", "target")
	power:RegisterUnitEvent("UNIT_MAXPOWER", "target")
	power:RegisterUnitEvent("UNIT_DISPLAYPOWER", "target")
	power:RegisterEvent("PLAYER_TARGET_CHANGED")
	power:RegisterEvent("PLAYER_ENTERING_WORLD")
	power:SetScript("OnEvent", function(self, event)
		if not UnitExists("target") then
			return
		end
		local isPowerTick = event == "UNIT_POWER_UPDATE" or event == "UNIT_POWER_FREQUENT"
		UpdatePower(self, "target", isPowerTick and SMOOTH or IMMEDIATE)
		ns.ShowValue(powerText, "target", (UnitPowerType("target")))
	end)
end

-- The pet bar mirrored, beyond the target's health bar, on the wing so it slides out with it.
local function CreateTargetOfTarget(wing)
	local unit = "targettarget"
	local spec = Layout.pet
	local button = CreateBar("DibsUITargetOfTarget", unit, spec, 1, wing)
	button:SetHitRectInsets(spec.hitInset, 0, 0, 0)
	local bar, body, overlay = button.bar, button.body, button.overlay

	local levelSpec, nameSpec = ns.Text.totLevel, ns.Text.totName
	local level = ns.CreateText(overlay, "totLevel", button)
	ns.PlaceText(level, "BOTTOMRIGHT", body, "TOPRIGHT", levelSpec.x, levelSpec.y)

	-- Target names can be long. This keeps them over the bar and clear of the level at any width.
	local name = ns.CreateText(overlay, "totName", button)
	ns.PlaceText(name, "BOTTOMLEFT", body, "TOPLEFT", nameSpec.x, nameSpec.y)
	ns.PlaceText(name, "BOTTOMRIGHT", level, "BOTTOMLEFT", -3, 0)

	local function Update(interpolation)
		local exists = UnitExists(unit)
		body:SetShown(exists)
		if exists then
			UpdateHealth(bar, unit, interpolation)
			UpdateTargetColor(bar, unit)
			name:SetText(UnitName(unit))
			UpdateTargetNameColor(name, unit)
			UpdateTargetLevel(level, unit)
		end
	end

	-- This unit has no events of its own, so nothing says when its health or identity changes.
	-- Blizzard's frame polls as well. This sits apart from the bar, which is hidden with no unit.
	local poller = CreateFrame("Frame", nil, ns.root)
	local sinceUpdate = 0
	poller:SetScript("OnUpdate", function(_, elapsed)
		sinceUpdate = sinceUpdate + elapsed
		if sinceUpdate >= 0.1 then
			sinceUpdate = 0
			Update(SMOOTH)
		end
	end)
	poller:RegisterEvent("PLAYER_ENTERING_WORLD")
	poller:RegisterEvent("PLAYER_TARGET_CHANGED")
	poller:RegisterUnitEvent("UNIT_TARGET", "target")
	-- Hiding the poller stops OnUpdate, but its events still arrive.
	poller:SetScript("OnEvent", function()
		if ns.db.showTargetOfTarget then
			Update(IMMEDIATE)
		end
	end)

	function ns.UpdateTargetOfTargetShown()
		local shown = ns.db.showTargetOfTarget
		poller:SetShown(shown)
		if shown then
			RegisterUnitWatch(button)
			Update(IMMEDIATE)
		else
			UnregisterUnitWatch(button)
			button:Hide()
			body:Hide()
		end
	end

	ns.UpdateTargetOfTargetShown()
end

function ns.CreateBars()
	CreatePlayerHealth()
	CreatePetHealth()
	local wing = CreateTargetWing()
	CreateTargetBars(wing)
	CreateTargetOfTarget(wing)

	function ns.UpdateBarWidths()
		wing:UpdateWidth()
		for _, button in ipairs(bars) do
			LayoutBar(button)
		end
	end

	ns.UpdateBarWidths()
end
