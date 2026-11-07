local _, ns = ...

local Layout = ns.Layout

-- Health and power can be secret values, so they only ever go straight into the widgets.
-- Never compare, test or do arithmetic on them here.
local SMOOTH = Enum.StatusBarInterpolation.ExponentialEaseOut
local IMMEDIATE = Enum.StatusBarInterpolation.Immediate

local CAP_OVERLAP = 0.5

local function SetBarColor(bar, r, g, b)
	bar:SetStatusBarColor(r, g, b)
	bar.cap:SetVertexColor(r, g, b)
end

-- side is -1 for the left wing and 1 for the right. The button is a secure unit button:
-- left click targets the unit, right click opens its menu.
local function CreateBar(name, unit, spec, side)
	local width = spec.tip - spec.hitInner
	local centerDistance = (spec.tip + spec.hitInner) / 2

	local button = CreateFrame("Button", name, ns.root, "SecureUnitButtonTemplate")
	button:SetFrameStrata("LOW")
	button:SetFrameLevel(ns.Level.bar)
	button:SetSize(width, spec.height)
	button:SetPoint("CENTER", ns.root, "CENTER", side * centerDistance, spec.yCenter)
	button:RegisterForClicks("AnyUp")
	button:SetAttribute("unit", unit)
	button:SetAttribute("*type1", "target")
	button:SetAttribute("*type2", "togglemenu")

	local function PlaceArt(texture)
		texture:SetSize(Layout.barQuadWidth, Layout.barQuadHeight)
		texture:SetPoint("CENTER", button, "CENTER", side * (Layout.barQuadWidth / 2 - centerDistance), 0)
		if side < 0 then
			texture:SetTexCoord(1, 0, 0, 1)
		end
	end

	PlaceArt(ns.CreateArt(button, "BACKGROUND", spec.back))

	local fillWidth = spec.fillOuter - spec.fillInner
	local bar = CreateFrame("StatusBar", nil, button)
	bar:SetSize(fillWidth, spec.fillHeight)
	bar:SetPoint("CENTER", button, "CENTER", side * ((spec.fillOuter + spec.fillInner) / 2 - centerDistance), 0)
	bar:SetStatusBarTexture(ns.Media("BarFill"))
	-- Fill grows away from the orb, so the left wing runs right to left.
	bar:SetFillStyle(Enum.StatusBarFillStyle.StandardNoRangeFill)
	bar:SetReverseFill(side < 0)

	-- A triangle riding on the fill's moving edge gives it the same slant as the bar's outline.
	-- It overlaps the fill slightly so no seam shows between them.
	local fill = bar:GetStatusBarTexture()
	local cap = ns.CreateArt(bar, "ARTWORK", "BarFillCap")
	cap:SetWidth(spec.capWidth + CAP_OVERLAP)
	if side < 0 then
		cap:SetPoint("TOPRIGHT", fill, "TOPLEFT", CAP_OVERLAP, 0)
		cap:SetPoint("BOTTOMRIGHT", fill, "BOTTOMLEFT", CAP_OVERLAP, 0)
		cap:SetTexCoord(1, 0, 0, 1)
	else
		cap:SetPoint("TOPLEFT", fill, "TOPRIGHT", -CAP_OVERLAP, 0)
		cap:SetPoint("BOTTOMLEFT", fill, "BOTTOMRIGHT", -CAP_OVERLAP, 0)
	end
	bar.cap = cap

	-- The double border sits above the fill.
	local overlay = CreateFrame("Frame", nil, button)
	overlay:SetAllPoints()
	overlay:SetFrameLevel(bar:GetFrameLevel() + 1)
	PlaceArt(ns.CreateArt(overlay, "ARTWORK", spec.frame))

	button.bar = bar
	button.overlay = overlay
	return button
end

-- Name and level sit above the bar, so they're capped to its width rather than running under the orb.
local function PlaceName(text, button, spec, reserved)
	text:SetPoint("BOTTOM", button, "TOP", spec.x, spec.y)
	text:SetWidth(button:GetWidth() - reserved)
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
	local name = ns.CreateText(overlay, ns.Text.playerName)
	PlaceName(name, button, ns.Text.playerName, 0)

	local function Update()
		local classColor = ns.GetUnitClassColor("player")
		if classColor then
			name:SetTextColor(classColor.r, classColor.g, classColor.b)
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
	local button = CreateBar("DibsUIPlayerHealth", "player", Layout.health, -1)
	local bar = button.bar
	local color = ns.Colors.playerHealth
	SetBarColor(bar, color[1], color[2], color[3])

	local deficit = ns.CreateText(button.overlay, ns.Text.playerDeficit)
	deficit:SetPoint("LEFT", button, "LEFT", ns.Text.playerDeficit.x, ns.Text.playerDeficit.y)

	local health = ns.CreateText(button.overlay, ns.Text.playerHealth)
	health:SetPoint("RIGHT", button, "RIGHT", ns.Text.playerHealth.x, ns.Text.playerHealth.y)

	bar:RegisterUnitEvent("UNIT_HEALTH", "player")
	bar:RegisterUnitEvent("UNIT_MAXHEALTH", "player")
	bar:RegisterEvent("PLAYER_ENTERING_WORLD")
	bar:RegisterEvent("PLAYER_DEAD")
	bar:RegisterEvent("PLAYER_ALIVE")
	bar:RegisterEvent("PLAYER_UNGHOST")
	bar:SetScript("OnEvent", function(self, event)
		local interpolation = event == "UNIT_HEALTH" and SMOOTH or IMMEDIATE
		UpdateHealth(self, "player", interpolation)
		deficit:SetText(ns.Shorten(UnitHealthMissing("player")))
		health:SetText(ns.Shorten(UnitHealth("player")))
	end)

	CreatePlayerName(button)
end

-- Class color for friendly players, reaction color for friendly NPCs, otherwise the default white.
local function UpdateTargetNameColor(name)
	local classColor = GetFriendlyClassColor("target")
	if classColor then
		name:SetTextColor(classColor.r, classColor.g, classColor.b)
	elseif UnitIsFriend("player", "target") then
		local r, g, b = UnitSelectionColor("target")
		name:SetTextColor(r, g, b)
	else
		name:SetTextColor(1, 1, 1)
	end
end

local function UpdateTargetLevel(level)
	local effectiveLevel = UnitEffectiveLevel("target")
	level:SetText(effectiveLevel > 0 and effectiveLevel or "??")
	-- Grey, green, yellow, orange or red.
	local color = GetDifficultyColor(C_PlayerInfo.GetContentDifficultyCreatureForPlayer("target"))
	level:SetTextColor(color.r, color.g, color.b)
end

local function CreateTargetName(button)
	local overlay = button.overlay

	local level = ns.CreateText(overlay, ns.Text.targetLevel)
	level:SetPoint("BOTTOMRIGHT", button, "TOPRIGHT", ns.Text.targetLevel.x, ns.Text.targetLevel.y)

	-- Leaves room each side so a long name stays centred and clear of the level.
	local name = ns.CreateText(overlay, ns.Text.targetName)
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
		UpdateTargetNameColor(name)
		UpdateTargetLevel(level)
	end)
end

-- Only visible while a target exists. RegisterUnitWatch does the showing and hiding,
-- since a secure frame can't be toggled from addon code in combat.
local function CreateTargetBars()
	local healthButton = CreateBar("DibsUITargetHealth", "target", Layout.health, 1)
	local powerButton = CreateBar("DibsUITargetPower", "target", Layout.power, 1)
	RegisterUnitWatch(healthButton)
	RegisterUnitWatch(powerButton)

	-- "70% - 1.3k": the amount sits at the bar's right edge and the percent rides on its left side.
	local amountSpec = ns.Text.targetHealth
	local amount = ns.CreateText(healthButton.overlay, amountSpec)
	amount:SetPoint("RIGHT", healthButton, "RIGHT", amountSpec.x, amountSpec.y)

	local percentSpec = ns.Text.targetPercent
	local percent = ns.CreateText(healthButton.overlay, percentSpec)
	percent:SetPoint("BOTTOMRIGHT", amount, "BOTTOMLEFT", percentSpec.x, percentSpec.y)

	local powerSpec = ns.Text.targetPower
	local powerAmount = ns.CreateText(powerButton.overlay, powerSpec)
	powerAmount:SetPoint("RIGHT", powerButton, "RIGHT", powerSpec.x, powerSpec.y)

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
		percent:SetFormattedText("%.0f%%", UnitHealthPercent("target", true, CurveConstants.ScaleTo100))
		amount:SetFormattedText("- %s", ns.Shorten(UnitHealth("target")))
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
		powerAmount:SetText(ns.Shorten(UnitPower("target")))
	end)
end

function ns.CreateBars()
	CreatePlayerHealth()
	CreateTargetBars()
end
