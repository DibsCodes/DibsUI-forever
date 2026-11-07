local _, ns = ...

local BASE_ALPHA = 0.3
local ACTIVE_ALPHA = 0.6
local COMBAT_ALPHA = 1

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

local REST_AT_FULL_CURVE = CreateStepCurve(0, ACTIVE_ALPHA, 1, BASE_ALPHA)
local REST_AT_ZERO_CURVE = CreateStepCurve(0, BASE_ALPHA, 0.001, ACTIVE_ALPHA)

local inCombat = false

local function IsTargetAttackable()
	return UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsDead("target")
end

-- With readable values this is a plain comparison. A secret value decides the alpha through a
-- curve, and one curve can only read one value: if health and power are both secret, power is
-- left out and only health decides.
local function ApplyRestingAlpha(root)
	local missing = UnitHealthMissing("player")
	local healthIsSecret = issecretvalue(missing)
	if not healthIsSecret and missing > 0 then
		root:SetAlpha(ACTIVE_ALPHA)
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
				root:SetAlpha(ACTIVE_ALPHA)
				return
			end
		end
	end

	if healthIsSecret then
		root:SetAlpha(UnitHealthPercent("player", true, REST_AT_FULL_CURVE))
	elseif powerIsSecret then
		local curve = restsAtZero and REST_AT_ZERO_CURVE or REST_AT_FULL_CURVE
		root:SetAlpha(UnitPowerPercent("player", powerType, false, curve))
	else
		root:SetAlpha(BASE_ALPHA)
	end
end

function ns.UpdateOpacity()
	local root = ns.root
	if inCombat then
		root:SetAlpha(COMBAT_ALPHA)
	elseif not ns.db.locked then
		-- The drag handle and layout need to be clearly visible while moving them.
		root:SetAlpha(1)
	elseif IsTargetAttackable() then
		root:SetAlpha(ACTIVE_ALPHA)
	else
		ApplyRestingAlpha(root)
	end
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
