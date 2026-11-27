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

local TURN = 2 * math.pi
local SURFACE_HEIGHT = 6.7 -- the surface texture's height, from generate_art.py

-- How each kind of power looks in the orb. Flows are layers over the liquid that turn at their own
-- speed, in turns per second. Negative speeds turn clockwise, the way the swirls curl.
local LIQUIDS = {
	MANA = {
		texture = "OrbLiquidMana",
		surface = { 0.60, 0.85, 1.00 },
		flows = {
			{ texture = "OrbFlow1", blend = "ADD", color = { 0.35, 0.65, 1.00 }, alpha = 0.55, speed = -1 / 14 },
			{ texture = "OrbFlow2", blend = "ADD", color = { 0.55, 0.85, 1.00 }, alpha = 0.30, speed = -1 / 23 },
		},
	},
	RAGE = {
		texture = "OrbLiquidBlood",
		surface = { 0.90, 0.30, 0.25 },
		flows = {
			{ texture = "OrbClots", blend = "BLEND", color = { 0.10, 0.00, 0.01 }, alpha = 0.45, speed = -1 / 60 },
			{ texture = "OrbFlow2", blend = "ADD", color = { 0.75, 0.10, 0.08 }, alpha = 0.14, speed = -1 / 40 },
		},
	},
}

-- How the liquid looks, picked in the settings. Plain keeps the liquid and its surface line but drops
-- the turning flows. Flat is a single color, the power's own, under the glass.
ns.OrbStyles = {
	{ key = "animated", label = "Animated", description = "Swirling liquid, in the power's own style." },
	{ key = "plain", label = "Plain", description = "A still liquid with no swirls." },
	{ key = "flat", label = "Flat", description = "A flat fill in the power's color." },
}

-- Every other power: grey liquid and a single flow, in the power's colour.
local TINTED_LIQUID = {
	texture = "OrbLiquid",
	flows = {
		{ texture = "OrbFlow1", blend = "ADD", alpha = 0.30, speed = -1 / 18 },
	},
}

-- The flat style: no painted liquid and no flows, only the power's color.
local FLAT_LIQUID = {
	texture = "Flat",
	flows = {},
}

local function Lighten(r, g, b)
	return r + (1 - r) * 0.5, g + (1 - g) * 0.5, b + (1 - b) * 0.5
end

-- The mana a cast will spend, shown on the liquid while the cast runs: a band from the liquid's top down
-- to where the mana will be once the cast goes off, with a surface line at that level. Mana can be
-- secret, so nothing here does sums with it. The band is its own status bar, as tall as the orb and
-- hung from the liquid's top, filling downward by cost / max mana; the game works out its height. A
-- cost bigger than the mana left runs past the bottom and is cut off by the round mask.
local function CreateManaPrediction(orb, fill, liquid)
	local bar = CreateFrame("StatusBar", "DibsUIManaPrediction", orb)
	bar:SetFrameLevel(orb:GetFrameLevel() + 2)
	bar:SetSize(Layout.orbRadius * 2, Layout.orbRadius * 2)
	bar:SetPoint("TOP", liquid, "TOP")
	bar:SetOrientation("VERTICAL")
	bar:SetFillStyle(Enum.StatusBarFillStyle.StandardNoRangeFill)
	-- After the fill style, which resets it.
	bar:SetReverseFill(true)
	bar:SetStatusBarTexture(ns.Media("Flat"))
	local band = bar:GetStatusBarTexture()
	band:SetBlendMode("BLEND")
	local color = ns.Colors.manaPrediction
	bar:SetStatusBarColor(color[1], color[2], color[3], color[4])
	bar:Hide()

	local circle = bar:CreateMaskTexture()
	circle:SetAtlas("CircleMask")
	circle:SetAllPoints(fill)
	band:AddMaskTexture(circle)
	-- The round mask's edge pixels repeat outside its square, so a cost bigger than the mana left would
	-- show the line under the orb. This one is black outside the orb's square.
	local square = bar:CreateMaskTexture()
	square:SetTexture(ns.Media("Flat"), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	square:SetAllPoints(fill)
	band:AddMaskTexture(square)

	local line = ns.CreateArt(bar, "OVERLAY", "OrbSurface")
	line:SetBlendMode("ADD")
	line:SetSize(Layout.orbRadius * 2, SURFACE_HEIGHT)
	line:SetPoint("CENTER", band, "BOTTOM")
	line:AddMaskTexture(circle)
	line:AddMaskTexture(square)
	local lineColor = ns.Colors.manaPredictionLine
	line:SetVertexColor(lineColor[1], lineColor[2], lineColor[3])

	-- The mana cost of the cast running now, or nil. The cost type has to be readable to tell it's mana;
	-- the amount itself only goes into the bar, so it can be secret.
	local function CastManaCost()
		local _, _, _, startMS, _, _, _, _, spellID = UnitCastingInfo("player")
		if not issecretvalue(startMS) and startMS == nil then
			return nil
		end
		if not issecretvalue(spellID) and spellID == nil then
			return nil
		end
		local costs = C_Spell.GetSpellPowerCost(spellID)
		if issecretvalue(costs) or not costs then
			return nil
		end
		for _, info in ipairs(costs) do
			if not issecretvalue(info.type) and info.type == Enum.PowerType.Mana then
				local cost = info.cost
				if issecretvalue(cost) or cost > 0 then
					return cost
				end
			end
		end
		return nil
	end

	local function Update()
		local _, powerToken = UnitPowerType("player")
		local cost = ns.db.showManaPrediction and powerToken == "MANA" and CastManaCost() or nil
		if cost == nil then
			bar:Hide()
			return
		end
		bar:SetMinMaxValues(0, UnitPowerMax("player", Enum.PowerType.Mana))
		bar:SetValue(cost)
		bar:Show()
	end
	ns.UpdateManaPrediction = Update

	-- Mana comes off when the cast completes, so the band shows from the cast's start until it ends.
	-- Channels pay up front, so they have nothing to predict.
	for _, event in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
		"UNIT_SPELLCAST_INTERRUPTED", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER" }) do
		bar:RegisterUnitEvent(event, "player")
	end
	bar:RegisterEvent("PLAYER_ENTERING_WORLD")
	bar:SetScript("OnEvent", Update)
end

local function CreatePowerOrb(orb)
	local fill = CreateFrame("StatusBar", nil, orb)
	fill:SetSize(Layout.orbRadius * 2, Layout.orbRadius * 2)
	fill:SetPoint("CENTER")
	fill:SetFrameLevel(orb:GetFrameLevel() + 1)
	fill:SetOrientation("VERTICAL")
	fill:SetFillStyle(Enum.StatusBarFillStyle.StandardNoRangeFill)
	fill:SetStatusBarTexture(ns.Media("OrbLiquid"))
	local liquid = fill:GetStatusBarTexture()

	-- Everything is clipped by Blizzard's round mask, so the level rises inside the circle.
	-- The sphere shading lives on the glass layer above.
	local circle = fill:CreateMaskTexture()
	circle:SetAtlas("CircleMask")
	circle:SetAllPoints()
	liquid:AddMaskTexture(circle)

	-- The flows cover the whole orb and turn, so this second mask cuts them off at the liquid's top
	-- edge. It's anchored to the fill rather than sized from the power, which can be secret.
	local level = fill:CreateMaskTexture()
	level:SetTexture(ns.Media("Flat"), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	level:SetPoint("TOPLEFT", liquid, "TOPLEFT")
	level:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT")

	local flows = {}
	for i = 1, 2 do
		local flow = ns.CreateArt(fill, "OVERLAY", "OrbFlow1")
		flow:SetDrawLayer("OVERLAY", i)
		flow:SetAllPoints()
		flow:AddMaskTexture(circle)
		flow:AddMaskTexture(level)
		flow.angle = 0
		flows[i] = flow
	end

	local surface = ns.CreateArt(fill, "OVERLAY", "OrbSurface")
	surface:SetDrawLayer("OVERLAY", 3)
	surface:SetBlendMode("ADD")
	surface:SetSize(Layout.orbRadius * 2, SURFACE_HEIGHT)
	surface:SetPoint("CENTER", liquid, "TOP")
	surface:AddMaskTexture(circle)

	CreateManaPrediction(orb, fill, liquid)

	fill:SetScript("OnUpdate", function(_, elapsed)
		for _, flow in ipairs(flows) do
			if flow.speed then
				flow.angle = (flow.angle + flow.speed * TURN * elapsed) % TURN
				flow:SetRotation(flow.angle)
			end
		end
	end)

	local shownToken, shownStyle
	local function ShowLiquid(powerToken)
		local orbStyle = ns.db.orbStyle
		if powerToken == shownToken and orbStyle == shownStyle then
			return
		end
		shownToken, shownStyle = powerToken, orbStyle
		local animated = orbStyle == "animated"
		local style = LIQUIDS[powerToken]
		local r, g, b = 1, 1, 1
		if orbStyle == "flat" then
			style = FLAT_LIQUID
			r, g, b = ns.GetPowerColor(powerToken)
		elseif not style then
			style = TINTED_LIQUID
			r, g, b = ns.GetPowerColor(powerToken)
		end
		liquid:SetTexture(ns.Media(style.texture))
		fill:SetStatusBarColor(r, g, b)
		if style.surface then
			surface:SetVertexColor(style.surface[1], style.surface[2], style.surface[3])
		else
			surface:SetVertexColor(Lighten(r, g, b))
		end
		for i, flow in ipairs(flows) do
			local spec = animated and style.flows[i] or nil
			flow:SetShown(spec ~= nil)
			flow.speed = spec and spec.speed
			if spec then
				flow:SetTexture(ns.Media(spec.texture))
				flow:SetBlendMode(spec.blend)
				if spec.color then
					flow:SetVertexColor(spec.color[1], spec.color[2], spec.color[3], spec.alpha)
				else
					local fr, fg, fb = Lighten(r, g, b)
					flow:SetVertexColor(fr, fg, fb, spec.alpha)
				end
			end
		end
	end

	local glass = CreateLayer(orb, orb:GetFrameLevel() + 3)
	ns.CreateArt(glass, "ARTWORK", "OrbGlass"):SetAllPoints()

	local value = ns.CreateValueText(glass, "orbCenter", glass, "CENTER", orb)

	-- A druid in bear or cat form still has mana underneath, shown small below the power. The text's own
	-- settings decide whether it shows at all; this holder hides it outside those forms. It hangs from the
	-- bottom of the power text, so it follows that text when it's moved or resized.
	local manaHolder = CreateFrame("Frame", "DibsUIOrbManaHolder", glass)
	manaHolder:SetAllPoints()
	manaHolder:Hide()
	local manaAnchor = CreateFrame("Frame", nil, manaHolder)
	manaAnchor:SetSize(1, 1)
	manaAnchor:SetPoint("TOP", value, "BOTTOM")
	local mana = ns.CreateValueText(manaHolder, "orbMana", manaAnchor, "TOP", orb)
	local manaColor = ns.Colors.druidMana
	ns.SetTextColor(mana, manaColor[1], manaColor[2], manaColor[3])

	-- The class is checked each time, since it isn't always known yet when the orb is made.
	local function ShowDruidMana(powerToken)
		local _, classFile = UnitClass("player")
		local isShown = classFile == "DRUID" and (powerToken == "RAGE" or powerToken == "ENERGY")
		manaHolder:SetShown(isShown)
		if isShown then
			ns.ShowValue(mana, "player", Enum.PowerType.Mana)
		end
	end

	-- Power can be secret. It only goes into the widgets, as with the bars.
	local function Update(interpolation)
		local powerType, powerToken = UnitPowerType("player")
		if not powerType then
			return
		end
		ShowLiquid(powerToken)
		fill:SetMinMaxValues(0, UnitPowerMax("player", powerType))
		fill:SetValue(UnitPower("player", powerType), interpolation)
		ns.ShowValue(value, "player", powerType)
		ShowDruidMana(powerToken)
	end

	fill:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
	fill:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
	fill:RegisterUnitEvent("UNIT_MAXPOWER", "player")
	fill:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
	fill:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
	fill:RegisterEvent("PLAYER_ENTERING_WORLD")
	fill:SetScript("OnEvent", function(_, event)
		local isPowerTick = event == "UNIT_POWER_UPDATE" or event == "UNIT_POWER_FREQUENT"
		Update(isPowerTick and SMOOTH or IMMEDIATE)
	end)

	ns.UpdateOrbLiquid = function()
		Update(IMMEDIATE)
	end
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
	ring:SetFrameLevel(orb:GetFrameLevel() + 4)
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

-- Item uses, wands and free spells cost no mana, so they don't trigger the rule.
local function CostsMana(spellID)
	local costs = C_Spell.GetSpellPowerCost(spellID)
	if issecretvalue(costs) or not costs then
		return false
	end
	for _, info in ipairs(costs) do
		if not issecretvalue(info.type) and info.type == Enum.PowerType.Mana then
			local cost, perSecond, percent = info.cost, info.costPerSec, info.costPercent
			if not (issecretvalue(cost) or issecretvalue(perSecond) or issecretvalue(percent))
				and (cost > 0 or perSecond > 0 or percent > 0) then
				return true
			end
		end
	end
	return false
end

-- A spark that circles the orb's inner edge once after a mana spell succeeds, for the five seconds
-- of the rule, then goes away. It works from the cast rather than from mana, which can be secret.
local function CreateManaSpark(orb)
	local frame = CreateFrame("Frame", "DibsUIManaSpark", orb)
	frame:SetSize(Layout.manaSparkQuad, Layout.manaSparkQuad)
	frame:SetPoint("CENTER")
	frame:SetFrameLevel(orb:GetFrameLevel() + 4)
	frame:Hide()

	local color = ns.Colors.manaRule
	local spark = ns.CreateArt(frame, "ARTWORK", "ManaSpark")
	spark:SetAllPoints()
	spark:SetVertexColor(color[1], color[2], color[3])

	local ruleEnd = 0

	local function UpdateShown()
		local _, powerToken = UnitPowerType("player")
		frame:SetShown(ns.db.showManaSpark and powerToken == "MANA" and GetTime() < ruleEnd)
	end
	ns.UpdateManaSpark = UpdateShown

	frame:SetScript("OnUpdate", function(self)
		local remaining = ruleEnd - GetTime()
		if remaining <= 0 then
			self:Hide()
			return
		end
		-- Rotation runs anticlockwise, so clockwise travel is negative.
		spark:SetRotation(-2 * math.pi * (1 - remaining / FIVE_SECOND_RULE))
	end)

	frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
	frame:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
	frame:SetScript("OnEvent", function(_, event, _, _, spellID)
		if event == "UNIT_SPELLCAST_SUCCEEDED" then
			if not CostsMana(spellID) then
				return
			end
			ruleEnd = GetTime() + FIVE_SECOND_RULE
			spark:SetRotation(0)
		end
		UpdateShown()
	end)
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

-- Below the orb, or above it: a round spell icon beside the name, then "current / total" under them.
local function CreateCastInfo(orb)
	local info = CreateFrame("Frame", nil, orb)
	info:SetAllPoints()
	info:SetFrameLevel(orb:GetFrameLevel() + 7)
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

	local name = ns.CreateText(info, "castName", orb)
	ns.PlaceText(name, "LEFT", icon, "RIGHT", nameSpec.x, nameSpec.y)

	local timeText = ns.CreateText(info, "castTime", orb)

	-- How wide the name is, measured when a cast starts. nil when the name is secret, which can be
	-- shown but not measured.
	local nameWidth = 0

	local function GetY(spec)
		return ns.db.castTextPlacement == "above" and spec.yAbove or spec.y
	end

	-- Centres the icon and name as one group over or under the orb, and puts the time beside them.
	-- Without the icon the name starts where the icon would, so it's centred on its own.
	local function Place()
		local showIcon = ns.db.showCastIcon
		icon:SetShown(showIcon)
		icon:ClearAllPoints()
		if nameWidth then
			local rowWidth = showIcon and (iconSpec.size + nameSpec.x + nameWidth) or nameWidth
			icon:SetPoint("LEFT", orb, "CENTER", iconSpec.x - rowWidth / 2, GetY(iconSpec))
			if showIcon then
				ns.MoveText(name, "LEFT", icon, "RIGHT", nameSpec.x, nameSpec.y)
			else
				ns.MoveText(name, "LEFT", icon, "LEFT", 0, nameSpec.y)
			end
		else
			-- Unmeasured: the name's centre sits half the icon and gap right of the orb's, with the icon
			-- against its left, which centres the row whatever the name's width.
			local shift = showIcon and (iconSpec.size + nameSpec.x) / 2 or 0
			ns.MoveText(name, "CENTER", orb, "CENTER", iconSpec.x + shift, GetY(iconSpec) + nameSpec.y)
			icon:SetPoint("RIGHT", name, "LEFT", -nameSpec.x, -nameSpec.y)
		end
		ns.MoveText(timeText, "CENTER", orb, "CENTER", timeSpec.x, GetY(timeSpec))
	end
	Place()
	ns.UpdateCastTextPlacement = Place

	local startMS, endMS, countsDown
	local sinceUpdate = 0

	local function UpdateTime()
		if not startMS then
			return
		end
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

	-- A secret name or icon can still be shown, but the name can't be measured.
	local function ShowSpell(spellName, texture)
		icon:SetTexture(texture)
		name:SetText(spellName)
		nameWidth = not issecretvalue(spellName) and name:GetStringWidth() or nil
		Place()
		info:Show()
	end

	function info:Start(spellName, texture, castStartMS, castEndMS, isDraining)
		startMS, endMS, countsDown = castStartMS, castEndMS, isDraining
		ShowSpell(spellName, texture)
		UpdateTime()
	end

	-- An instant ability on the global cooldown: its icon and name, with no time.
	function info:ShowInstant(spellName, texture)
		startMS = nil
		timeText:SetText("")
		ShowSpell(spellName, texture)
	end

	return info
end

-- The animated ring is a flipbook of ring textures with light flowing round them (generate_art.py's
-- CastFlow frames), swapped into the swipe in turn. The swipe itself can't be masked or turned.
local FLOW_FRAMES = 24
local FLOW_FPS = 24
local FLOW_TEXTURES = {}
for i = 1, FLOW_FRAMES do
	FLOW_TEXTURES[i] = ns.Media(("CastFlow%02d"):format(i))
end

-- Pushback moves a cast's end later, so the ring would jump back. Instead it slides back over this long,
-- easing out, while the cast carries on filling underneath.
local PUSHBACK_SLIDE = 0.3

-- A send more than this long before a cast starts belongs to something else (an instant, or a spell the
-- server refused), so the cast uses the game's world latency instead.
local LATENCY_WINDOW = 1.5
-- The longest the latency swipe's held cooldown runs, in seconds (a day).
local LATENCY_HOLD_MAX = 86400


-- The global cooldown's own spell. A spell on the global cooldown reports it too (isOnGCD).
--
-- In combat a cooldown's start and length are secret, so addon code can't time it. The ring gets it
-- as a duration object instead, which the client draws without the addon reading it, and whether it
-- is still running comes from isActive and isOnGCD, which are never secret.
local GCD_SPELL = 61304

local TIMING_CHANGE_EVENTS = {
	UNIT_SPELLCAST_DELAYED = true,
	UNIT_SPELLCAST_CHANNEL_UPDATE = true,
	UNIT_SPELLCAST_EMPOWER_UPDATE = true,
}

local function CreateCastRing(orb)
	local info = CreateCastInfo(orb)

	-- A Cooldown swipe starts at 12 o'clock and travels clockwise. Reversed, the swipe is
	-- the elapsed part, so it grows as a cast fills. Unreversed it is the remaining part,
	-- so a channel drains in the same direction.
	local ring = CreateFrame("Cooldown", nil, orb)
	ring:SetAllPoints()
	ring:SetFrameLevel(orb:GetFrameLevel() + 5)
	ring:SetHideCountdownNumbers(true)
	ring:SetDrawBling(false)
	ring:SetDrawSwipe(true)
	ring:SetSwipeTexture(ns.Media("CastRing"), 1, 1, 1, 1)
	ring:SetEdgeTexture(ns.Media("CastEdge"), 1, 1, 1, 1)
	ring:SetDrawEdge(true)
	ring:SetUseCircularEdge(true)

	-- Latency: the last part of a cast, as long as the delay between sending the spell and the server
	-- saying it started. The server finishes the cast that much before the ring does, so the next spell
	-- can be pressed once the fill reaches it. It's a second swipe under the cast's, held still: unreversed,
	-- a swipe is the remaining part, which ends at 12 o'clock. Its start must never be negative: the client
	-- takes a negative start as zero, so a long cooldown shows a full ring (0.3.11's bug, seen in game).
	-- GetTime counts from the PC's boot, so the cooldown is as long as it can be with its start still
	-- above zero (capped at LATENCY_HOLD_MAX), then paused. Paused, it holds still; if a client ever drew a
	-- paused cooldown running, as UIForever does, the long duration still keeps it from moving visibly.
	local latencyRing = CreateFrame("Cooldown", "DibsUICastLatency", orb)
	latencyRing:SetAllPoints()
	latencyRing:SetFrameLevel(orb:GetFrameLevel() + 4)
	latencyRing:SetHideCountdownNumbers(true)
	latencyRing:SetDrawBling(false)
	latencyRing:SetDrawEdge(false)
	latencyRing:SetDrawSwipe(true)
	latencyRing:SetSwipeTexture(ns.Media("CastRing"), 1, 1, 1, 1)
	local latencyColor = ns.Colors.latency
	latencyRing:SetSwipeColor(latencyColor[1], latencyColor[2], latencyColor[3], latencyColor[4])
	latencyRing:SetReverse(false)
	-- Casts show at full opacity, so their latency does too.
	latencyRing:SetIgnoreParentAlpha(true)
	latencyRing:Hide()
	-- When the spell was sent, and the latency measured for the cast showing, in seconds.
	local sentTime, castLatency

	local activeCastID
	local isChanneling = false
	local isCasting = false
	local swingStart, swingDuration
	-- The swing timer is on the ring: no cast is showing and the swing hasn't finished.
	local isSwinging = false
	-- The spell whose cooldown is the global cooldown an instant ability started (GCD_SPELL, or the
	-- ability itself), and whether the ring is showing it.
	local gcdSource
	local isGCD = false
	-- The instant ability that started it. In combat its name and icon can be secret, which is fine:
	-- they're only shown, never compared, so whether there is one is kept separately.
	local gcdSpellName, gcdSpellIcon, hasGCDSpell
	local ShowIdle, IsGCDRunning

	-- The cast being shown: when it started and how long it lasts, in seconds, and its color.
	local castStart, castDuration
	local castR, castG, castB = 1, 1, 1
	-- While sliding back from pushback: how far ahead of the real progress the ring still is, as a
	-- fraction of the cast, and when the slide began.
	local slideFrom, slideStart
	local flowFrame

	local animator = CreateFrame("Frame", nil, orb)
	animator:Hide()

	-- Only for casts: channels drain from the start, and empowered spells end when the key comes up.
	local isPlainCast = false
	local function ShowLatency()
		if not (ns.db.castLatency and isCasting and isPlainCast and castLatency and castDuration and castDuration > 0) then
			latencyRing:Hide()
			return
		end
		local fraction = math.min(castLatency / castDuration, 1)
		local now = GetTime()
		local hold = math.min(LATENCY_HOLD_MAX, now * 0.99 / math.max(1 - fraction, 0.01))
		latencyRing:Resume()
		latencyRing:SetCooldown(now - (1 - fraction) * hold, hold)
		latencyRing:Pause()
	end

	local function ShowStaticRing()
		if flowFrame then
			flowFrame = nil
			ring:SetSwipeTexture(ns.Media("CastRing"))
			ring:SetSwipeColor(castR, castG, castB, 1)
		end
	end

	-- Flows while a cast, the global cooldown or the swing timer shows, when the animation is on.
	local function IsFlowing()
		return ns.db.castAnimated and (isCasting or isGCD or isSwinging)
	end

	local function UpdateAnimator()
		local flowing = IsFlowing()
		if not flowing then
			ShowStaticRing()
		end
		-- The global cooldown has no end event either, so it's watched to hand back to the swing timer.
		animator:SetShown(flowing or slideFrom ~= nil or isGCD)
	end

	animator:SetScript("OnUpdate", function()
		local now = GetTime()
		if isGCD and not IsGCDRunning() then
			ShowIdle()
		end
		-- The swing timer has no end event, so its flow stops when the swing runs out.
		if isSwinging and now >= swingStart + swingDuration then
			isSwinging = false
			UpdateAnimator()
		end
		if IsFlowing() then
			local frame = math.floor(now * FLOW_FPS) % FLOW_FRAMES + 1
			if frame ~= flowFrame then
				flowFrame = frame
				ring:SetSwipeTexture(FLOW_TEXTURES[frame])
				ring:SetSwipeColor(castR, castG, castB, 1)
			end
		end
		if slideFrom then
			local t = (now - slideStart) / PUSHBACK_SLIDE
			if t >= 1 or not isCasting then
				slideFrom = nil
				if isCasting then
					ring:SetCooldown(castStart, castDuration)
				end
				UpdateAnimator()
			else
				local ease = 1 - (1 - t) ^ 3
				local shown = (now - castStart) / castDuration + slideFrom * (1 - ease)
				shown = math.min(math.max(shown, 0), 1)
				ring:SetCooldown(now - shown * castDuration, castDuration)
			end
		end
	end)

	-- An instant ability was just used: if it started the global cooldown, the ring shows it, with the
	-- ability's name and icon when they're readable. An ability off the global cooldown doesn't.
	local function StartGCD(spellID)
		if issecretvalue(spellID) then
			return false
		end
		local own = C_Spell.GetSpellCooldown(spellID)
		local gcd = C_Spell.GetSpellCooldown(GCD_SPELL)
		local source
		if own and (own.isOnGCD or own.isActive) and gcd and gcd.isActive then
			source = GCD_SPELL
		elseif own and own.isOnGCD then
			source = spellID
		end
		if not source then
			return false
		end
		gcdSource = source
		local spell = C_Spell.GetSpellInfo(spellID)
		hasGCDSpell = spell ~= nil
		gcdSpellName, gcdSpellIcon = spell and spell.name, spell and spell.iconID
		return true
	end

	-- Puts the global cooldown on the ring. The duration object works even when the numbers are secret.
	-- In case the client refuses it from addon code, readable numbers are the fallback.
	local function ShowGCDCooldown()
		local duration = C_Spell.GetSpellCooldownDuration(gcdSource)
		if duration and pcall(ring.SetCooldownFromDurationObject, ring, duration) then
			return true
		end
		local info = C_Spell.GetSpellCooldown(gcdSource)
		if info and not issecretvalue(info.startTime) and not issecretvalue(info.duration) then
			ring:SetCooldown(info.startTime, info.duration)
			return true
		end
		return false
	end

	function IsGCDRunning()
		local info = gcdSource and C_Spell.GetSpellCooldown(gcdSource)
		if not info then
			return false
		end
		if gcdSource == GCD_SPELL then
			return info.isActive
		end
		return info.isOnGCD
	end

	-- With no cast running, the ring shows the global cooldown in green, the main hand or ranged swing in grey,
	-- or nothing.
	function ShowIdle()
		activeCastID = nil
		isChanneling = false
		isCasting = false
		latencyRing:Hide()
		slideFrom = nil
		ring:SetIgnoreParentAlpha(false)
		local now = GetTime()
		isGCD = ns.db.castGCD and IsGCDRunning() and ShowGCDCooldown() or false
		isSwinging = not isGCD and ns.db.showSwingTimer and swingStart ~= nil and now < swingStart + swingDuration
		if isGCD and hasGCDSpell then
			info:ShowInstant(gcdSpellName, gcdSpellIcon)
		else
			info:Hide()
		end
		if isGCD then
			-- Like a cast, at full opacity whatever the rest of the frame is doing.
			ring:SetIgnoreParentAlpha(true)
			local color = ns.Colors.gcd
			castR, castG, castB = color[1], color[2], color[3]
			ring:SetReverse(true)
			ring:SetSwipeColor(color[1], color[2], color[3], 1)
		elseif isSwinging then
			local color = ns.Colors.swing
			castR, castG, castB = color[1], color[2], color[3]
			ring:SetReverse(true)
			ring:SetSwipeColor(color[1], color[2], color[3], 1)
			ring:SetCooldown(swingStart, swingDuration)
		else
			ring:Clear()
		end
		UpdateAnimator()
	end

	-- The player's casts are readable, except spells Blizzard individually flags as secret.
	-- Those can't be timed from addon code, so the ring stays empty for them. Check for
	-- secrecy first, because even comparing a secret value to nil is an error.
	local function Update(event)
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

		local newCastID = not issecretvalue(castID) and castID or nil
		local start, duration = startMS / 1000, (endMS - startMS) / 1000
		local now = GetTime()

		-- A new cast's latency: from the send to the start, or the game's world latency when the send
		-- wasn't seen (or was too long ago to belong to this cast).
		if event == "UNIT_SPELLCAST_START" then
			if sentTime and now - sentTime < LATENCY_WINDOW then
				castLatency = now - sentTime
			else
				local _, _, _, world = GetNetStats()
				castLatency = world and world / 1000 or nil
			end
			sentTime = nil
		end

		-- The same cast with new timing: slide from where the ring is now rather than jumping.
		local isSameCast = isCasting and isChanneling == not isCast and newCastID == activeCastID
		if TIMING_CHANGE_EVENTS[event] and isSameCast and castDuration and castDuration > 0 and duration > 0 then
			local shownBefore = (now - castStart) / castDuration
			if slideFrom then
				local t = math.min((now - slideStart) / PUSHBACK_SLIDE, 1)
				shownBefore = shownBefore + slideFrom * (1 - (1 - (1 - t) ^ 3))
			end
			local shownAfter = (now - start) / duration
			slideFrom = shownBefore - shownAfter
			slideStart = now
		elseif not isSameCast then
			slideFrom = nil
		end

		activeCastID = newCastID
		isChanneling = not isCast
		isCasting = true
		isSwinging = false
		-- A cast's own global cooldown isn't shown after it ends: only an instant ability's is.
		isGCD = false
		gcdSource = nil
		castStart, castDuration = start, duration
		-- Casts always show at full opacity, whatever the rest of the frame is doing.
		ring:SetIgnoreParentAlpha(true)

		local color = isCast and ns.Colors.cast or ns.Colors.channel
		castR, castG, castB = color[1], color[2], color[3]
		local isFilling = isCast or isEmpowered
		ring:SetReverse(isFilling)
		ring:SetSwipeColor(castR, castG, castB, 1)
		if not slideFrom then
			ring:SetCooldown(start, duration)
		end
		isPlainCast = isCast and not isEmpowered
		ShowLatency()
		UpdateAnimator()
		info:Start(spellName, texture, startMS, endMS, not isFilling)
	end

	-- Switching the animation on or off shows straight away, even mid-cast.
	ns.UpdateCastRingStyle = UpdateAnimator
	ns.UpdateCastLatency = ShowLatency

	-- Switching the swing timer shows or clears it straight away, unless a cast is showing.
	ns.UpdateSwingTimer = function()
		if not isCasting then
			ShowIdle()
		end
	end

	for _, event in ipairs(CAST_EVENTS) do
		ring:RegisterUnitEvent(event, "player")
	end
	ring:RegisterEvent("PLAYER_ENTERING_WORLD")
	ring:RegisterEvent("PLAYER_SWING")
	ring:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
	ring:RegisterUnitEvent("UNIT_SPELLCAST_SENT", "player")
	ring:SetScript("OnEvent", function(_, event, arg1, arg2, arg3)
		if event == "UNIT_SPELLCAST_SENT" then
			sentTime = GetTime()
			return
		elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
			-- arg3 is the spell. A cast-time spell also succeeds, but its cast is still showing then.
			if not isCasting and StartGCD(arg3) then
				ShowIdle()
			end
			return
		elseif event == "PLAYER_SWING" then
			-- Main hand and ranged (bows, guns, crossbows, thrown and wands) share the ring: you can't
			-- melee and shoot at once, so the latest swing wins. The off hand is left out, since it
			-- runs alongside the main hand.
			if arg2 == Enum.PlayerSwingType.MainHand or arg2 == Enum.PlayerSwingType.Ranged then
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
		Update(event)
	end)
end

function ns.CreateOrb()
	local orb = CreateFrame("Frame", "DibsUIOrb", ns.root)
	orb:SetFrameStrata("LOW")
	orb:SetFrameLevel(ns.Level.orb)
	orb:SetSize(Layout.orbQuad, Layout.orbQuad)
	orb:SetPoint("CENTER", ns.root, "CENTER")

	ns.CreateArt(orb, "BACKGROUND", "OrbBack"):SetAllPoints()

	-- The low health glow round the ring, under the bars so it only shows outside them.
	local glowFrame = CreateFrame("Frame", nil, ns.root)
	glowFrame:SetFrameStrata("LOW")
	glowFrame:SetFrameLevel(ns.Level.bar - 1)
	glowFrame:SetSize(Layout.orbGlowQuad, Layout.orbGlowQuad)
	glowFrame:SetPoint("CENTER", orb)
	local glow = ns.CreateArt(glowFrame, "BACKGROUND", "OrbGlow")
	glow:SetAllPoints()
	ns.AddLowHealthGlow(glow)

	CreatePowerOrb(orb)
	CreateComboRing(orb)
	CreateManaSpark(orb)
	CreateCastRing(orb)

	-- Rims and the 12 o'clock tick, above the cast swipe.
	local rim = CreateLayer(orb, orb:GetFrameLevel() + 6)
	local rimArt = ns.CreateArt(rim, "ARTWORK", "OrbFrame")
	rimArt:SetPoint("CENTER", orb)
	-- Some themes' rims reach past the orb's quad, so their art is drawn bigger.
	ns.UpdateRimSize = function()
		local size = Layout.orbQuad * (ns.GetTheme().rimScale or 1)
		rimArt:SetSize(size, size)
	end
	ns.UpdateRimSize()
end
