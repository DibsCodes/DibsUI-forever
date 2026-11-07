local _, ns = ...

local Layout = ns.Layout

local SMOOTH = Enum.StatusBarInterpolation.ExponentialEaseOut
local IMMEDIATE = Enum.StatusBarInterpolation.Immediate

local function CreateLayer(parent, level)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetAllPoints()
	frame:SetFrameLevel(level)
	return frame
end

local function CreatePowerOrb(orb)
	local fill = CreateFrame("StatusBar", nil, orb)
	fill:SetSize(Layout.orbRadius * 2, Layout.orbRadius * 2)
	fill:SetPoint("CENTER")
	fill:SetFrameLevel(orb:GetFrameLevel() + 1)
	fill:SetOrientation("VERTICAL")
	fill:SetFillStyle(Enum.StatusBarFillStyle.StandardNoRangeFill)
	fill:SetStatusBarTexture(ns.Media("Flat"))

	-- A flat fill clipped by Blizzard's round mask, so the level rises inside the circle.
	-- The sphere shading lives on the glass layer above.
	local mask = fill:CreateMaskTexture()
	mask:SetAtlas("CircleMask")
	mask:SetAllPoints()
	fill:GetStatusBarTexture():AddMaskTexture(mask)

	local glass = CreateLayer(orb, orb:GetFrameLevel() + 2)
	ns.CreateArt(glass, "ARTWORK", "OrbGlass"):SetAllPoints()

	local valueSpec = ns.Text.orbPower
	local value = ns.CreateText(glass, valueSpec)
	value:SetPoint("CENTER", glass, "CENTER", valueSpec.x, valueSpec.y)

	-- Power can be secret. It only goes into the widgets, as with the bars.
	local function Update(interpolation)
		local powerType, powerToken = UnitPowerType("player")
		if not powerType then
			return
		end
		fill:SetStatusBarColor(ns.GetPowerColor(powerToken))
		fill:SetMinMaxValues(0, UnitPowerMax("player", powerType))
		fill:SetValue(UnitPower("player", powerType), interpolation)
		value:SetText(ns.Shorten(UnitPower("player", powerType)))
	end

	fill:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
	fill:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
	fill:RegisterUnitEvent("UNIT_MAXPOWER", "player")
	fill:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
	fill:RegisterEvent("PLAYER_ENTERING_WORLD")
	fill:SetScript("OnEvent", function(_, event)
		local isPowerTick = event == "UNIT_POWER_UPDATE" or event == "UNIT_POWER_FREQUENT"
		Update(isPowerTick and SMOOTH or IMMEDIATE)
	end)
end

local MAX_COMBO_POINTS = 5

-- Rogues always, and druids while they're on energy, which is cat form.
local function UsesComboPoints()
	local _, classFile = UnitClass("player")
	if classFile == "ROGUE" then
		return true
	end
	local _, powerToken = UnitPowerType("player")
	return classFile == "DRUID" and powerToken == "ENERGY"
end

-- Combo points are held on the target and can be secret, so addon code can't compare them. Each
-- segment is a status bar covering one point of the range, which leaves it either empty or full.
local function CreateComboRing(orb)
	local ring = CreateFrame("Frame", "DibsUIComboRing", orb)
	ring:SetSize(Layout.comboQuad, Layout.comboQuad)
	ring:SetPoint("CENTER")
	ring:SetFrameLevel(orb:GetFrameLevel() + 3)
	ns.CreateArt(ring, "ARTWORK", "ComboTrack"):SetAllPoints()

	local segments = {}
	for i = 1, MAX_COMBO_POINTS do
		local segment = CreateFrame("StatusBar", nil, ring)
		segment:SetAllPoints()
		segment:SetFrameLevel(ring:GetFrameLevel() + 1)
		segment:SetStatusBarTexture(ns.Media("ComboSegment" .. i))
		local color = ns.Colors.combo[i]
		segment:SetStatusBarColor(color[1], color[2], color[3])
		segment:SetMinMaxValues(i - 1, i)
		segments[i] = segment
	end

	ring:RegisterEvent("PLAYER_ENTERING_WORLD")
	ring:RegisterEvent("PLAYER_TARGET_CHANGED")
	-- Moving points to a new target keeps the same count, so no power event fires.
	ring:RegisterEvent("COMBO_TARGET_CHANGED")
	ring:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
	ring:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
	ring:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
	ring:RegisterUnitEvent("UNIT_POWER_POINT_CHARGE", "player")
	ring:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
	ring:SetScript("OnEvent", function(self)
		local isUsed = UsesComboPoints()
		self:SetShown(isUsed)
		if isUsed then
			local points = GetComboPoints("player", "target")
			for _, segment in ipairs(segments) do
				segment:SetValue(points)
			end
		end
	end)
	ring:Hide()
end

local FIVE_SECOND_RULE = 5
local DEFAULT_TICK_INTERVAL = 2
local MIN_TICK_INTERVAL, MAX_TICK_INTERVAL = 0.5, 3

-- A spark circling the orb's inner edge, reaching 12 o'clock when the next mana tick is due. Spending
-- mana sends it on one slower lap in gold, lasting until the first tick after the five second rule.
-- The tick interval is learned from the gaps between mana gains. All this compares mana, so the
-- spark has to hide while mana is secret.
local function CreateManaSpark(orb)
	local frame = CreateFrame("Frame", "DibsUIManaSpark", orb)
	frame:SetSize(Layout.comboQuad, Layout.comboQuad)
	frame:SetPoint("CENTER")
	frame:SetFrameLevel(orb:GetFrameLevel() + 3)
	frame:Hide()

	local spark = ns.CreateArt(frame, "ARTWORK", "ManaSpark")
	spark:SetAllPoints()

	local lastMana, lastTick
	local tickInterval = DEFAULT_TICK_INTERVAL
	local ruleEnd = 0
	local lapStart, lapEnd = 0, 0

	local function StartLap(start, finish, color)
		lapStart, lapEnd = start, finish
		spark:SetVertexColor(color[1], color[2], color[3])
	end

	-- The first expected tick at or after this time, or the time itself until a tick has been seen.
	local function NextTickAfter(time)
		if not lastTick then
			return time
		end
		return lastTick + math.ceil((time - lastTick) / tickInterval) * tickInterval
	end

	local function OnManaSpent(now)
		ruleEnd = now + FIVE_SECOND_RULE
		StartLap(now, NextTickAfter(ruleEnd), ns.Colors.manaRule)
	end

	local function OnManaGained(now)
		if lastTick then
			local gap = now - lastTick
			if gap >= MIN_TICK_INTERVAL and gap <= MAX_TICK_INTERVAL then
				tickInterval = gap
			end
		end
		lastTick = now
		if now >= ruleEnd then
			StartLap(now, now + tickInterval, ns.Colors.manaTick)
		end
	end

	local function UpdateMana()
		local _, powerToken = UnitPowerType("player")
		local mana, maxMana = UnitPower("player", Enum.PowerType.Mana), UnitPowerMax("player", Enum.PowerType.Mana)
		if powerToken ~= "MANA" or issecretvalue(mana) or issecretvalue(maxMana) then
			lastMana = nil
			frame:Hide()
			return
		end

		local now = GetTime()
		if lastMana then
			if mana < lastMana then
				OnManaSpent(now)
			elseif mana > lastMana then
				OnManaGained(now)
			end
		end
		lastMana = mana
		frame:SetShown(mana < maxMana)
	end

	frame:SetScript("OnUpdate", function()
		local now = GetTime()
		-- No gain arrived on time, so go round again until one does.
		if now >= lapEnd then
			StartLap(now, now + tickInterval, ns.Colors.manaTick)
		end
		-- Rotation runs anticlockwise, so clockwise travel is negative.
		spark:SetRotation(-2 * math.pi * (now - lapStart) / (lapEnd - lapStart))
	end)

	-- Events still arrive while the frame is hidden, which is how it comes back.
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	frame:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
	frame:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
	frame:RegisterUnitEvent("UNIT_MAXPOWER", "player")
	frame:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
	frame:SetScript("OnEvent", UpdateMana)
end

local CAST_EVENTS = {
	"UNIT_SPELLCAST_START",
	"UNIT_SPELLCAST_STOP",
	"UNIT_SPELLCAST_FAILED",
	"UNIT_SPELLCAST_INTERRUPTED",
	"UNIT_SPELLCAST_DELAYED",
	"UNIT_SPELLCAST_CHANNEL_START",
	"UNIT_SPELLCAST_CHANNEL_UPDATE",
	"UNIT_SPELLCAST_CHANNEL_STOP",
	"UNIT_SPELLCAST_EMPOWER_START",
	"UNIT_SPELLCAST_EMPOWER_UPDATE",
	"UNIT_SPELLCAST_EMPOWER_STOP",
}

-- These can arrive for an older or rejected cast while a newer one is running, so they carry a cast ID to check.
local CAST_END_EVENTS = {
	UNIT_SPELLCAST_STOP = true,
	UNIT_SPELLCAST_FAILED = true,
	UNIT_SPELLCAST_INTERRUPTED = true,
}

local CHANNEL_END_EVENTS = {
	UNIT_SPELLCAST_CHANNEL_STOP = true,
	UNIT_SPELLCAST_EMPOWER_STOP = true,
}

-- Below the orb: a round spell icon beside the name, then "current / total" under them.
local function CreateCastInfo(orb)
	local info = CreateFrame("Frame", nil, orb)
	info:SetAllPoints()
	info:SetFrameLevel(orb:GetFrameLevel() + 5)
	info:SetIgnoreParentAlpha(true)
	info:Hide()

	local iconSpec, nameSpec, timeSpec = ns.Text.castIcon, ns.Text.castName, ns.Text.castTime

	local icon = info:CreateTexture(nil, "ARTWORK")
	icon:SetSize(iconSpec.size, iconSpec.size)
	-- Spell icons have a baked-in border, which the crop removes.
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

	local mask = info:CreateMaskTexture()
	mask:SetAtlas("CircleMask")
	mask:SetAllPoints(icon)
	icon:AddMaskTexture(mask)

	local name = ns.CreateText(info, nameSpec)
	name:SetPoint("LEFT", icon, "RIGHT", nameSpec.x, nameSpec.y)

	local timeText = ns.CreateText(info, timeSpec)
	timeText:SetPoint("CENTER", orb, "CENTER", timeSpec.x, timeSpec.y)

	local startMS, endMS, countsDown
	local sinceUpdate = 0

	local function UpdateTime()
		local total = (endMS - startMS) / 1000
		local current = math.min(math.max(GetTime() - startMS / 1000, 0), total)
		timeText:SetFormattedText("%.1f / %.1f", countsDown and total - current or current, total)
	end

	info:SetScript("OnUpdate", function(_, elapsed)
		sinceUpdate = sinceUpdate + elapsed
		if sinceUpdate >= 0.05 then
			sinceUpdate = 0
			UpdateTime()
		end
	end)

	-- These are only called for casts whose details are readable, so measuring the name is safe.
	function info:Start(spellName, texture, castStartMS, castEndMS, isDraining)
		startMS, endMS, countsDown = castStartMS, castEndMS, isDraining
		icon:SetTexture(texture)
		name:SetText(spellName)

		-- Centres the icon and name as one group under the orb.
		local rowWidth = iconSpec.size + nameSpec.x + name:GetStringWidth()
		icon:ClearAllPoints()
		icon:SetPoint("CENTER", orb, "CENTER", iconSpec.x + (iconSpec.size - rowWidth) / 2, iconSpec.y)

		UpdateTime()
		self:Show()
	end

	return info
end

local function CreateCastRing(orb)
	local info = CreateCastInfo(orb)

	-- A Cooldown swipe starts at 12 o'clock and travels clockwise. Reversed, the swipe is
	-- the elapsed part, so it grows as a cast fills. Unreversed it is the remaining part,
	-- so a channel drains in the same direction.
	local ring = CreateFrame("Cooldown", nil, orb)
	ring:SetAllPoints()
	ring:SetFrameLevel(orb:GetFrameLevel() + 3)
	ring:SetHideCountdownNumbers(true)
	ring:SetDrawBling(false)
	ring:SetDrawSwipe(true)
	ring:SetSwipeTexture(ns.Media("CastRing"), 1, 1, 1, 1)
	ring:SetEdgeTexture(ns.Media("CastEdge"), 1, 1, 1, 1)
	ring:SetDrawEdge(true)
	ring:SetUseCircularEdge(true)

	local activeCastID
	local isChanneling = false
	local isCasting = false
	local swingStart, swingDuration

	-- With no cast running, the ring shows the main hand swing in grey, or nothing.
	local function ShowIdle()
		activeCastID = nil
		isChanneling = false
		isCasting = false
		info:Hide()
		ring:SetIgnoreParentAlpha(false)
		if swingStart and GetTime() < swingStart + swingDuration then
			local color = ns.Colors.swing
			ring:SetReverse(true)
			ring:SetSwipeColor(color[1], color[2], color[3], 1)
			ring:SetCooldown(swingStart, swingDuration)
		else
			ring:Clear()
		end
	end

	-- The player's casts are readable, except spells Blizzard individually flags as secret.
	-- Those can't be timed from addon code, so the ring stays empty for them. Check for
	-- secrecy first, because even comparing a secret value to nil is an error.
	local function Update()
		local _, spellName, texture, startMS, endMS, castID, isEmpowered
		_, spellName, texture, startMS, endMS, _, castID = UnitCastingInfo("player")
		local isCast = issecretvalue(startMS) or startMS ~= nil
		if not isCast then
			_, spellName, texture, startMS, endMS, _, _, _, isEmpowered = UnitChannelInfo("player")
			castID = nil
		end

		if issecretvalue(startMS) or issecretvalue(endMS) or startMS == nil then
			ShowIdle()
			return
		end

		activeCastID = not issecretvalue(castID) and castID or nil
		isChanneling = not isCast
		isCasting = true
		-- Casts always show at full opacity, whatever the rest of the frame is doing.
		ring:SetIgnoreParentAlpha(true)

		local color = isCast and ns.Colors.cast or ns.Colors.channel
		local isFilling = isCast or isEmpowered
		ring:SetReverse(isFilling)
		ring:SetSwipeColor(color[1], color[2], color[3], 1)
		ring:SetCooldown(startMS / 1000, (endMS - startMS) / 1000)
		info:Start(spellName, texture, startMS, endMS, not isFilling)
	end

	for _, event in ipairs(CAST_EVENTS) do
		ring:RegisterUnitEvent(event, "player")
	end
	ring:RegisterEvent("PLAYER_ENTERING_WORLD")
	ring:RegisterEvent("PLAYER_SWING")
	ring:SetScript("OnEvent", function(_, event, arg1, arg2)
		if event == "PLAYER_SWING" then
			if arg2 == Enum.PlayerSwingType.MainHand then
				swingStart, swingDuration = GetTime(), arg1
				if not isCasting then
					ShowIdle()
				end
			end
			return
		elseif CAST_END_EVENTS[event] then
			local castID = arg2
			if not issecretvalue(castID) and castID == activeCastID then
				ShowIdle()
				return
			end
		elseif CHANNEL_END_EVENTS[event] and isChanneling then
			ShowIdle()
			return
		end
		Update()
	end)
end

function ns.CreateOrb()
	local orb = CreateFrame("Frame", "DibsUIOrb", ns.root)
	orb:SetFrameStrata("LOW")
	orb:SetFrameLevel(ns.Level.orb)
	orb:SetSize(Layout.orbQuad, Layout.orbQuad)
	orb:SetPoint("CENTER", ns.root, "CENTER")

	ns.CreateArt(orb, "BACKGROUND", "OrbBack"):SetAllPoints()

	CreatePowerOrb(orb)
	CreateComboRing(orb)
	CreateManaSpark(orb)
	CreateCastRing(orb)

	-- Rims and the 12 o'clock tick, above the cast swipe.
	local rim = CreateLayer(orb, orb:GetFrameLevel() + 4)
	ns.CreateArt(rim, "ARTWORK", "OrbFrame"):SetAllPoints()
end
