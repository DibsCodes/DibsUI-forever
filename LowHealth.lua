local _, ns = ...

-- A faint red glow round the orb and the player's bars while health is low. Bars.lua and Orb.lua hand
-- their glow textures over here as they're made.
--
-- Health can be secret in combat, and then addon code can't compare it to the threshold. Instead the
-- client turns the health percentage into the glow's alpha through a step curve: the glow below the
-- threshold, nothing at or above it.

local GLOW_COLOR = { 1.00, 0.12, 0.10 }
local GLOW_ALPHA = 0.9 -- the frame's own opacity applies on top

local textures = {}
local curve, curveThreshold

function ns.AddLowHealthGlow(texture)
	-- Added to what's behind rather than painted over it, so it reads as light.
	texture:SetBlendMode("ADD")
	texture:SetVertexColor(GLOW_COLOR[1], GLOW_COLOR[2], GLOW_COLOR[3])
	texture:SetAlpha(0)
	textures[#textures + 1] = texture
end

local function GetCurve()
	local threshold = ns.db.lowHealthThreshold
	if threshold ~= curveThreshold then
		curve = C_CurveUtil.CreateCurve()
		curve:SetType(Enum.LuaCurveType.Step)
		curve:AddPoint(0, GLOW_ALPHA)
		curve:AddPoint(threshold / 100, 0)
		curveThreshold = threshold
	end
	return curve
end

local function IsDead()
	local dead = UnitIsDeadOrGhost("player")
	return not issecretvalue(dead) and dead
end

function ns.UpdateLowHealthGlow()
	local alpha = 0
	if ns.db and ns.db.lowHealthGlow and not IsDead() then
		alpha = UnitHealthPercent("player", false, GetCurve())
	end
	for _, texture in ipairs(textures) do
		texture:SetAlpha(alpha)
	end
end

local watcher = CreateFrame("Frame")
watcher:RegisterUnitEvent("UNIT_HEALTH", "player")
watcher:RegisterUnitEvent("UNIT_MAXHEALTH", "player")
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
watcher:RegisterEvent("PLAYER_DEAD")
watcher:RegisterEvent("PLAYER_ALIVE")
watcher:RegisterEvent("PLAYER_UNGHOST")
watcher:SetScript("OnEvent", function()
	ns.UpdateLowHealthGlow()
end)
