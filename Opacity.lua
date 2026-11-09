local _, ns = ...

-- How the frames fade, picked in the settings. Smart and Minimalist go by what's happening: rest
-- when nothing needs attention, active with an enemy targeted or health or power away from where it
-- rests, and combat. Full and Manual hold one opacity. Casts show at full whatever the mode.
ns.OpacityModes = {
	{ key = "smart", label = "Smart", description = "30% at rest, 60% when something needs attention, 100% in combat" },
	{ key = "minimalist", label = "Minimalist", description = "Hidden at rest, 60% when something needs attention, 100% in combat" },
	{ key = "full", label = "Full", description = "Always 100%" },
	{ key = "manual", label = "Manual", description = "Always the opacity set below" },
}

ns.OpacityModesByKey = {}
for _, mode in ipairs(ns.OpacityModes) do
	ns.OpacityModesByKey[mode.key] = mode
end

-- These sit at 0 when idle. Every other power type, including energy, sits at full.
local RESTS_AT_ZERO = {
	RAGE = true,
}

-- Health and power can be secret, and then addon code can't compare them. The client evaluates
-- these instead, turning a percentage straight into an alpha.
local function CreateStepCurve(...)
	local curve = C_CurveUtil.CreateCurve()
	curve:SetType(Enum.LuaCurveType.Step)
	for i = 1, select("#", ...), 2 do
		curve:AddPoint(select(i, ...), (select(i + 1, ...)))
	end
	return curve
end

local function CreatePreset(rest, active, combat)
	return {
		rest = rest,
		active = active,
		combat = combat,
		restAtFullCurve = CreateStepCurve(0, active, 1, rest),
		restAtZeroCurve = CreateStepCurve(0, rest, 0.001, active),
	}
end

local PRESETS = {
	smart = CreatePreset(0.3, 0.6, 1),
	minimalist = CreatePreset(0, 0.6, 1),
}

local inCombat = false

local function IsTargetAttackable()
	return UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsDead("target")
end

-- With readable values this is a plain comparison. A secret value decides the alpha through a
-- curve, and one curve can only read one value: if health and power are both secret, power is
-- left out and only health decides.
local function ApplyRestingAlpha(root, preset)
	local missing = UnitHealthMissing("player")
	local healthIsSecret = issecretvalue(missing)
	if not healthIsSecret and missing > 0 then
		root:SetAlpha(preset.active)
		return
	end

	local powerType, powerToken = UnitPowerType("player")
	local powerIsSecret = false
	local restsAtZero = RESTS_AT_ZERO[powerToken]
	if powerType then
		local power, maxPower = UnitPower("player", powerType), UnitPowerMax("player", powerType)
		powerIsSecret = issecretvalue(power) or issecretvalue(maxPower)
		if not powerIsSecret then
			local isActive
			if restsAtZero then
				isActive = power > 0
			else
				isActive = power < maxPower
			end
			if isActive then
				root:SetAlpha(preset.active)
				return
			end
		end
	end

	if healthIsSecret then
		root:SetAlpha(UnitHealthPercent("player", true, preset.restAtFullCurve))
	elseif powerIsSecret then
		local curve = restsAtZero and preset.restAtZeroCurve or preset.restAtFullCurve
		root:SetAlpha(UnitPowerPercent("player", powerType, false, curve))
	else
		root:SetAlpha(preset.rest)
	end
end

function ns.UpdateOpacity()
	local root = ns.root
	local mode = ns.db.opacityMode
	local preset = PRESETS[mode]
	if not ns.db.locked then
		-- The drag handle and layout need to be clearly visible while moving them.
		root:SetAlpha(1)
	elseif mode == "full" then
		root:SetAlpha(1)
	elseif mode == "manual" then
		root:SetAlpha(ns.db.manualOpacity)
	elseif inCombat then
		root:SetAlpha(preset.combat)
	elseif IsTargetAttackable() then
		root:SetAlpha(preset.active)
	else
		ApplyRestingAlpha(root, preset)
	end
end

-- Opacity isn't protected, so these work in combat too.
function ns.SetOpacityMode(mode)
	if ns.OpacityModesByKey[mode] then
		ns.db.opacityMode = mode
		ns.UpdateOpacity()
	end
end

-- 0 to 1.
function ns.SetManualOpacity(opacity)
	ns.db.manualOpacity = math.min(math.max(opacity, 0), 1)
	ns.UpdateOpacity()
	return ns.db.manualOpacity
end

function ns.CreateOpacity()
	local events = CreateFrame("Frame")
	events:RegisterEvent("PLAYER_ENTERING_WORLD")
	events:RegisterEvent("PLAYER_REGEN_DISABLED")
	events:RegisterEvent("PLAYER_REGEN_ENABLED")
	events:RegisterEvent("PLAYER_TARGET_CHANGED")
	events:RegisterUnitEvent("UNIT_FACTION", "target")
	events:RegisterUnitEvent("UNIT_FLAGS", "target")
	events:RegisterUnitEvent("UNIT_HEALTH", "player")
	events:RegisterUnitEvent("UNIT_MAXHEALTH", "player")
	events:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
	events:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
	events:RegisterUnitEvent("UNIT_MAXPOWER", "player")
	events:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
	events:SetScript("OnEvent", function(_, event)
		-- InCombatLockdown is still false as PLAYER_REGEN_DISABLED fires, so follow the events.
		if event == "PLAYER_REGEN_DISABLED" then
			inCombat = true
		elseif event == "PLAYER_REGEN_ENABLED" then
			inCombat = false
		elseif event == "PLAYER_ENTERING_WORLD" then
			inCombat = InCombatLockdown()
		end
		ns.UpdateOpacity()
	end)

	inCombat = InCombatLockdown()
	ns.UpdateOpacity()
end
