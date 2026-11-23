local _, ns = ...

-- The focus frame. It looks like a DibsUI-Party member: the orb with the unit's portrait in the well and a
-- tall health bar to its right, with the target frame's power bar under it. The ring round the portrait is
-- the focus's cast bar, and while it casts the portrait shows the spell's icon, with the spell's name and
-- time under the orb. An interrupt shows who did it. It has its own place and scale, set while DibsUI is
-- unlocked, and it fades while the focus is out of range.
--
-- DibsUI's rules hold here too: health, power, heal and absorb amounts, cast times and the interruptible
-- flag can be secret, so they only go straight into widgets, curves and FromBoolean calls.

local Layout = ns.FocusLayout
local UNIT = "focus"

local SMOOTH = Enum.StatusBarInterpolation.ExponentialEaseOut
local IMMEDIATE = Enum.StatusBarInterpolation.Immediate

-- Alpha 0 at empty and 1 above it, so an empty bar shows no sliver of its slanted cap.
local VISIBLE_ABOVE_ZERO = C_CurveUtil.CreateCurve()
VISIBLE_ABOVE_ZERO:SetType(Enum.LuaCurveType.Step)
VISIBLE_ABOVE_ZERO:AddPoint(0, 0)
VISIBLE_ABOVE_ZERO:AddPoint(0.001, 1)

-- The same prediction colors as the target bar.
local HEAL_SHADE = 0.4
local BACKING = { 0.075, 0.09, 0.125 }
local ABSORB_COLOR = { 0.35, 0.72, 1.00 }
local GLOW_COLOR = CreateColor(1, 1, 1, 1)
local CLEAR = CreateColor(0, 0, 0, 0)
local MASK_REACH = 32 -- generate_art.py's MASK_REACH

local PREDICTION_EVENTS = {
	UNIT_HEAL_PREDICTION = true,
	UNIT_ABSORB_AMOUNT_CHANGED = true,
	UNIT_HEAL_ABSORB_AMOUNT_CHANGED = true,
}

-- Casts the focus can't be interrupted out of show grey. Spell icons have a baked-in border, cropped off.
local LOCKED_CAST_COLOR = { 0.55, 0.55, 0.58 }
local INTERRUPTED_COLOR = { 1, 0.25, 0.2 }
local ICON_CROP = { 0.07, 0.93, 0.07, 0.93 }
local INTERRUPTED_SECONDS = 1.5 -- long enough to read who interrupted it

-- Out of range, the frame fades to this, as party members do.
local OUT_OF_RANGE_ALPHA = 0.35
local RANGE_INTERVAL = 0.2
-- Range is checked with the player's own longest-reaching spell up to this many yards, attack spells for
-- enemies and helpful ones for friends. Longer ones (Mind Vision and the like) say nothing about a fight.
local MAX_RANGE_SPELL_YARDS = 40

-- The animated ring's flipbook, as on the orb.
local FLOW_FRAMES, FLOW_FPS = 24, 24
local FLOW_TEXTURES = {}
for i = 1, FLOW_FRAMES do
	FLOW_TEXTURES[i] = ns.Media(("CastFlow%02d"):format(i))
end

-- While DibsUI is unlocked and there's no focus, the frame shows the player as a stand-in, casting
-- this, so it can be placed and its texts styled.
local PREVIEW_CAST = { name = "Frostbolt", icon = "Interface\\Icons\\Spell_Frost_FrostBolt02", fraction = 0.6, total = 2.5 }

local root, button, visual, mover
local health, power, orb
local nameText, levelText, healthText, powerText, castName, castTime

-- Geometry --------------------------------------------------------------------------------------------

local function GetScale()
	return Layout.baseScale * ns.db.focusScale
end

-- How much longer the Width setting makes a bar, in the frame's units. Negative means shorter.
function ns.GetFocusBarGrowth(spec)
	return (ns.db.focusWidth * Layout.widthBase - 1) * (spec.fillOuter - spec.fillInner)
end

local function GetFrameWidth()
	return Layout.margin + Layout.health.tip + ns.GetFocusBarGrowth(Layout.health) + Layout.rightMargin
end

-- Bars --------------------------------------------------------------------------------------------------

local function SetBarColor(bar, r, g, b)
	bar:SetStatusBarColor(r, g, b)
	bar.cap:SetVertexColor(r, g, b)
	if bar.wedge then
		bar.wedge:SetVertexColor(r, g, b)
	end
	local heal = bar.heal
	if heal then
		r = r + (BACKING[1] - r) * HEAL_SHADE
		g = g + (BACKING[2] - g) * HEAL_SHADE
		b = b + (BACKING[3] - b) * HEAL_SHADE
		heal:SetStatusBarColor(r, g, b)
		heal.cap:SetVertexColor(r, g, b)
	end
end

local function CreateFillCap(bar, spec)
	local fill = bar:GetStatusBarTexture()
	local cap = ns.CreateArt(bar, "ARTWORK", "BarFillCap")
	cap:SetWidth(spec.capWidth)
	cap:SetPoint("TOPLEFT", fill, "TOPRIGHT")
	cap:SetPoint("BOTTOMLEFT", fill, "BOTTOMRIGHT")
	bar.cap = cap
end

-- Cut in three like DibsUI's bars, so the Width setting only stretches the straight middle.
local function CreateArtSlices(parent, layer, fileName)
	local art = Layout.barArt
	local ranges = {
		{ 0, art.sliceInner },
		{ art.sliceInner, art.sliceInner + 4 }, -- a narrow band that only ever stretches
		{ art.sliceTip, art.width },
	}
	local slices = {}
	for i, range in ipairs(ranges) do
		local slice = ns.CreateArt(parent, layer, fileName)
		slice:SetTexCoord(range[1] / art.width, range[2] / art.width, 0, 1)
		slices[i] = slice
	end
	return slices
end

local function LayoutArtSlices(slices, origin, spec, growth)
	local art = Layout.barArt
	local edges = { 0, art.sliceInner, art.sliceTip + growth, art.width + growth }
	for i, slice in ipairs(slices) do
		slice:SetSize(edges[i + 1] - edges[i], spec.quadHeight)
		slice:ClearAllPoints()
		slice:SetPoint("LEFT", origin, "CENTER", edges[i], spec.yCenter)
	end
end

local function LayoutBar(barObject)
	local spec, origin = barObject.spec, barObject.origin
	local growth = ns.GetFocusBarGrowth(spec)
	barObject.body:SetSize(spec.tip + growth - spec.hitInner, spec.height)
	LayoutArtSlices(barObject.backSlices, origin, spec, growth)
	LayoutArtSlices(barObject.frameSlices, origin, spec, growth)
	local fillWidth = spec.fillOuter + growth - spec.fillInner
	barObject.bar:SetSize(fillWidth, spec.fillHeight)
	local prediction = barObject.prediction
	if prediction then
		prediction.heal:SetWidth(fillWidth)
		prediction.absorb:SetWidth(fillWidth)
	end
	if barObject.nameText then
		barObject.nameText.box:SetWidth(spec.tip + growth - spec.hitInner - barObject.nameReserved)
		ns.RefreshName(barObject.nameText)
	end
end

-- One bar drawn from the orb centre (origin). Its art and fill are on body, a plain frame at its outline.
local function CreateBar(parent, origin, spec, level)
	local body = CreateFrame("Frame", nil, parent)
	body:SetFrameLevel(level)
	body:SetPoint("LEFT", origin, "CENTER", spec.hitInner, spec.yCenter)

	local backSlices = CreateArtSlices(body, "BACKGROUND", spec.back)

	local bar = CreateFrame("StatusBar", nil, body)
	bar:SetFrameLevel(level + 3)
	bar:SetStatusBarTexture(ns.Media("BarFill"))
	bar:SetFillStyle(Enum.StatusBarFillStyle.StandardNoRangeFill)
	bar:SetPoint("LEFT", origin, "CENTER", spec.fillInner, spec.yCenter)
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(1)
	CreateFillCap(bar, spec)

	if spec.wedgeWidth then
		local wedge = ns.CreateArt(bar, "ARTWORK", spec.wedgeArt)
		wedge:SetWidth(spec.wedgeWidth)
		wedge:SetPoint("TOPRIGHT", bar, "TOPLEFT")
		wedge:SetPoint("BOTTOMRIGHT", bar, "BOTTOMLEFT")
		bar.wedge = wedge
	end

	-- The double border sits above the fill and the prediction.
	local overlay = CreateFrame("Frame", nil, body)
	overlay:SetAllPoints()
	overlay:SetFrameLevel(level + 5)
	local frameSlices = CreateArtSlices(overlay, "ARTWORK", spec.frame)

	return {
		body = body, bar = bar, overlay = overlay, spec = spec, origin = origin,
		backSlices = backSlices, frameSlices = frameSlices,
	}
end

-- Heal and absorb prediction, the same as the target bar's (see Bars.lua for why it's built this way).
local function MaskBehindCap(segment, spec)
	local mask = segment:CreateMaskTexture(nil, "ARTWORK")
	mask:SetTexture(ns.Media("BarFillMaskRight"), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetSize(spec.capWidth * MASK_REACH, spec.fillHeight)
	mask:SetPoint("TOPLEFT", segment, "TOPLEFT")
	segment:GetStatusBarTexture():AddMaskTexture(mask)
	segment.cap:AddMaskTexture(mask)
end

local function CreatePredictionSegment(parent, level, previous, spec)
	local segment = CreateFrame("StatusBar", nil, parent)
	segment:SetFrameLevel(level)
	segment:SetStatusBarTexture(ns.Media("BarFill"))
	segment:SetFillStyle(Enum.StatusBarFillStyle.StandardNoRangeFill)
	segment:SetHeight(spec.fillHeight)
	segment:SetPoint("LEFT", previous:GetStatusBarTexture(), "RIGHT")
	segment:SetMinMaxValues(0, 1)
	segment:SetValue(0)
	CreateFillCap(segment, spec)
	MaskBehindCap(segment, spec)
	return segment
end

local function CreateEndGlow(parent, barObject)
	local spec = barObject.spec
	local glow = ns.CreateArt(parent, "ARTWORK", "BarEndGlow")
	glow:SetBlendMode("ADD")
	glow:SetWidth(spec.capWidth * 2)
	glow:SetPoint("TOPRIGHT", barObject.bar, "TOPRIGHT", spec.capWidth, 0)
	glow:SetPoint("BOTTOMRIGHT", barObject.bar, "BOTTOMRIGHT", spec.capWidth, 0)
	glow:SetVertexColor(CLEAR:GetRGBA())
	return glow
end

local function CreatePrediction(barObject)
	if not CreateUnitHealPredictionCalculator then
		return
	end
	local spec, bar, body = barObject.spec, barObject.bar, barObject.body
	local level = body:GetFrameLevel()

	local clip = CreateFrame("Frame", nil, body)
	clip:SetFrameLevel(level + 1)
	clip:SetClipsChildren(true)
	clip:SetPoint("TOPLEFT", bar, "TOPLEFT")
	clip:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", spec.capWidth, 0)

	local heal = CreatePredictionSegment(clip, level + 2, bar, spec)
	local absorb = CreatePredictionSegment(clip, level + 1, heal, spec)
	absorb:SetStatusBarColor(ABSORB_COLOR[1], ABSORB_COLOR[2], ABSORB_COLOR[3])
	absorb.cap:SetVertexColor(ABSORB_COLOR[1], ABSORB_COLOR[2], ABSORB_COLOR[3])

	local glowFrame = CreateFrame("Frame", nil, clip)
	glowFrame:SetAllPoints()
	glowFrame:SetFrameLevel(level + 4)

	local calculator = CreateUnitHealPredictionCalculator()
	calculator:SetIncomingHealClampMode(Enum.UnitIncomingHealClampMode.MissingHealth)
	calculator:SetIncomingHealOverflowPercent(1)
	calculator:SetDamageAbsorbClampMode(Enum.UnitDamageAbsorbClampMode.MissingHealth)

	bar.heal = heal
	barObject.prediction = {
		frame = clip,
		heal = heal,
		absorb = absorb,
		healGlow = CreateEndGlow(glowFrame, barObject),
		absorbGlow = CreateEndGlow(glowFrame, barObject),
		calculator = calculator,
	}
end

-- The orb ------------------------------------------------------------------------------------------------

local function CreateLayer(parent, level)
	local layer = CreateFrame("Frame", nil, parent)
	layer:SetAllPoints()
	layer:SetFrameLevel(level)
	return layer
end

-- A swipe of the cast ring art. Reversed it grows as a cast fills; unreversed a channel drains.
local function CreateRingSwipe(parent, level)
	local ring = CreateFrame("Cooldown", nil, parent)
	ring:SetAllPoints()
	ring:SetFrameLevel(level)
	ring:SetHideCountdownNumbers(true)
	ring:SetDrawBling(false)
	ring:SetDrawSwipe(true)
	ring:SetSwipeTexture(ns.Media("CastRing"), 1, 1, 1, 1)
	ring:SetEdgeTexture(ns.Media("CastEdge"), 1, 1, 1, 1)
	ring:SetDrawEdge(true)
	ring:SetUseCircularEdge(true)
	return ring
end

local function CreateOrb(parent, origin, level)
	local frame = CreateFrame("Frame", "DibsUIFocusOrb", parent)
	frame:SetFrameLevel(level)
	frame:SetSize(Layout.orbQuad, Layout.orbQuad)
	frame:SetPoint("CENTER", origin, "CENTER")
	ns.CreateArt(frame, "BACKGROUND", "OrbBack"):SetAllPoints()

	local portrait = frame:CreateTexture(nil, "ARTWORK")
	portrait:SetSize(Layout.orbRadius * 2, Layout.orbRadius * 2)
	portrait:SetPoint("CENTER")
	local circle = frame:CreateMaskTexture()
	circle:SetAtlas("CircleMask")
	circle:SetAllPoints(portrait)
	portrait:AddMaskTexture(circle)

	local glass = CreateLayer(frame, level + 1)
	ns.CreateArt(glass, "ARTWORK", "OrbGlass"):SetAllPoints()

	-- Two copies of the cast ring, one in the cast's color and one grey. The interruptible flag can be
	-- secret, so the client picks which one shows (see ShowInterruptible).
	-- They're on their own layer, which ignores the frame's opacity fade (casts always show at full) but
	-- still takes the range fade, which is set on it directly.
	local castLayer = CreateLayer(frame, level + 2)
	castLayer:SetIgnoreParentAlpha(true)
	local ringOpen = CreateRingSwipe(castLayer, level + 2)
	local ringLocked = CreateRingSwipe(castLayer, level + 2)
	ringLocked:SetSwipeColor(LOCKED_CAST_COLOR[1], LOCKED_CAST_COLOR[2], LOCKED_CAST_COLOR[3], 1)

	local rim = CreateLayer(frame, level + 3)
	local rimArt = ns.CreateArt(rim, "ARTWORK", "OrbFrame")
	rimArt:SetPoint("CENTER", frame)

	local indicators = CreateLayer(frame, level + 4)
	local marker = indicators:CreateTexture(nil, "OVERLAY")
	marker:SetSize(52, 52)
	marker:SetPoint("CENTER", frame, "CENTER", 0, 66)
	marker:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
	marker:Hide()

	return {
		frame = frame, portrait = portrait, castLayer = castLayer,
		rimArt = rimArt, indicators = indicators, marker = marker,
		rings = { ringOpen, ringLocked }, ringOpen = ringOpen, ringLocked = ringLocked,
	}
end

-- Some themes' rims reach past the orb's quad, so their art is drawn bigger, as on the main orb.
local function SizeRim()
	local size = Layout.orbQuad * (ns.GetTheme().rimScale or 1)
	orb.rimArt:SetSize(size, size)
end

-- Showing a unit --------------------------------------------------------------------------------------

local previewing = false

-- The unit the frame shows: the focus, or the player as a stand-in while previewing.
local function GetShownUnit()
	if UnitExists(UNIT) then
		return UNIT
	elseif previewing then
		return "player"
	end
end

-- nil unless the unit is a friendly player whose class can be read.
local function GetFriendlyClassColor(unit)
	if UnitIsFriend("player", unit) and UnitIsPlayer(unit) then
		return ns.GetUnitClassColor(unit)
	end
end

-- As the target bar: class color for friendly players, reaction color otherwise, grey when tapped or offline.
local function UpdateHealthColor(unit)
	local bar = health.bar
	if not UnitIsConnected(unit) or UnitIsTapDenied(unit) then
		local color = ns.Colors.disabled
		SetBarColor(bar, color[1], color[2], color[3])
		return
	end
	local classColor = GetFriendlyClassColor(unit)
	if classColor then
		SetBarColor(bar, classColor.r, classColor.g, classColor.b)
	else
		SetBarColor(bar, UnitSelectionColor(unit))
	end
end

local function UpdateNameColor(unit)
	local classColor = GetFriendlyClassColor(unit)
	if classColor then
		ns.SetTextColor(nameText, classColor.r, classColor.g, classColor.b)
	elseif UnitIsFriend("player", unit) then
		ns.SetTextColor(nameText, UnitSelectionColor(unit))
	else
		ns.SetTextColor(nameText, 1, 1, 1)
	end
end

local function UpdateLevel(unit)
	local effectiveLevel = UnitEffectiveLevel(unit)
	if issecretvalue(effectiveLevel) then
		levelText:SetText(effectiveLevel)
		ns.SetTextColor(levelText, 1, 0.82, 0)
		return
	end
	levelText:SetText(effectiveLevel > 0 and effectiveLevel or "??")
	local color = GetDifficultyColor(C_PlayerInfo.GetContentDifficultyCreatureForPlayer(unit))
	ns.SetTextColor(levelText, color.r, color.g, color.b)
end

local function UpdateHealth(unit, interpolation)
	local bar = health.bar
	bar:SetMinMaxValues(0, UnitHealthMax(unit))
	bar:SetValue(UnitHealth(unit), interpolation)
	bar.cap:SetAlpha(UnitHealthPercent(unit, true, VISIBLE_ABOVE_ZERO))
	-- A slanted fill would still show a sliver of the corner at zero or ghost health.
	local dead = UnitIsDeadOrGhost(unit)
	bar:SetShown(not dead)
	orb.portrait:SetDesaturated(dead or not UnitIsConnected(unit))
	ns.ShowValue(healthText, unit)
end

local function UpdatePrediction(unit, interpolation)
	local prediction = health.prediction
	if not prediction then
		return
	end
	if not ns.db.showHealPrediction then
		prediction.frame:Hide()
		return
	end
	local calculator = prediction.calculator
	UnitGetDetailedHealPrediction(unit, nil, calculator)
	local heals, _, _, healsClamped = calculator:GetIncomingHeals()
	local absorbs, absorbsClamped = calculator:GetDamageAbsorbs()
	local maxHealth = UnitHealthMax(unit)
	prediction.heal:SetMinMaxValues(0, maxHealth)
	prediction.heal:SetValue(heals, interpolation)
	prediction.absorb:SetMinMaxValues(0, maxHealth)
	prediction.absorb:SetValue(absorbs, interpolation)
	prediction.healGlow:SetVertexColorFromBoolean(healsClamped, GLOW_COLOR, CLEAR)
	prediction.absorbGlow:SetVertexColorFromBoolean(healsClamped, CLEAR, GLOW_COLOR)
	prediction.absorbGlow:SetAlphaFromBoolean(absorbsClamped, 1, 0)
	prediction.frame:SetShown(not UnitIsDeadOrGhost(unit))
end

local function UpdatePower(unit, interpolation)
	local powerType, powerToken = UnitPowerType(unit)
	if not powerType then
		return
	end
	local bar = power.bar
	SetBarColor(bar, ns.GetPowerColor(powerToken))
	bar:SetMinMaxValues(0, UnitPowerMax(unit, powerType))
	bar:SetValue(UnitPower(unit, powerType), interpolation)
	bar.cap:SetAlpha(UnitPowerPercent(unit, powerType, false, VISIBLE_ABOVE_ZERO))
	ns.ShowValue(powerText, unit, powerType)
end

-- The raid marker sheet is a 4 by 4 grid; markers 1 to 8 are its top two rows.
local function UpdateMarker(unit)
	local index = GetRaidTargetIndex(unit)
	local marker = orb.marker
	if index and not issecretvalue(index) then
		local column, row = (index - 1) % 4, math.floor((index - 1) / 4)
		marker:SetTexCoord(column / 4, (column + 1) / 4, row / 4, (row + 1) / 4)
		marker:Show()
	else
		marker:Hide()
	end
end

-- Cast ring ---------------------------------------------------------------------------------------------

local cast = {
	active = false, -- a cast or channel is on the ring
	unit = nil,
	startMS = nil, endMS = nil, -- readable times, when they aren't secret
	duration = nil, -- the client's duration object, which works even when the times are secret
	countsDown = false, -- channels count down
	interruptedUntil = 0,
	flowFrame = 1, flowElapsed = 0,
}

local function ShowPortrait(unit)
	local portrait = orb.portrait
	portrait:SetTexCoord(0, 1, 0, 1)
	SetPortraitTexture(portrait, unit)
end

local function ShowInterruptible(notInterruptible)
	if issecretvalue(notInterruptible) then
		orb.ringOpen:SetAlphaFromBoolean(notInterruptible, 0, 1)
		orb.ringLocked:SetAlphaFromBoolean(notInterruptible, 1, 0)
	else
		orb.ringOpen:SetAlpha(notInterruptible and 0 or 1)
		orb.ringLocked:SetAlpha(notInterruptible and 1 or 0)
	end
end

local function UpdateCastTime()
	if cast.startMS then
		local total = (cast.endMS - cast.startMS) / 1000
		local current = math.min(math.max(GetTime() - cast.startMS / 1000, 0), total)
		castTime:SetFormattedText("%.1f / %.1f", cast.countsDown and total - current or current, total)
	elseif cast.duration then
		-- Secret times: the client still formats the duration object's own numbers.
		local ok = pcall(function()
			castTime:SetFormattedText("%.1f", cast.duration:GetRemainingDuration())
		end)
		if not ok then
			castTime:SetText("")
		end
	end
end

local function SetCastShown(shown)
	for _, ring in ipairs(orb.rings) do
		ring:SetShown(shown)
	end
	castName:SetShown(shown)
	castTime:SetShown(shown)
end

-- The spell icon is shown in the portrait itself, so ending a cast puts the unit's portrait back.
local function ShowSpellIcon(texture)
	orb.portrait:SetTexture(texture)
	orb.portrait:SetTexCoord(ICON_CROP[1], ICON_CROP[2], ICON_CROP[3], ICON_CROP[4])
end

local function EndCast(unit)
	cast.active = false
	cast.startMS, cast.endMS, cast.duration = nil, nil, nil
	SetCastShown(false)
	if unit then
		ShowPortrait(unit)
	end
end

-- Whether a value from the cast APIs holds something. Secret ones always count: they can't be looked at,
-- and the client still draws them. Secrecy is tested first, since even comparing a secret to nil errors.
local function Present(value)
	return issecretvalue(value) or (value ~= nil and value ~= "" and value ~= 0)
end

-- Reads the unit's cast or channel: label, icon, start and end in ms, the interruptible flag, and
-- whether it's a channel. Any of them can be secret. The label is the spell's display name, as on
-- Blizzard's cast bars and the orb, then its plain name, then whatever the spell ID gives.
local function ReadCast(unit)
	local isChannel = false
	local name, displayName, texture, startMS, endMS, _, _, notInterruptible, spellID = UnitCastingInfo(unit)
	if not Present(name) and not Present(startMS) then
		isChannel = true
		name, displayName, texture, startMS, endMS, _, notInterruptible, spellID = UnitChannelInfo(unit)
		if not Present(name) and not Present(startMS) then
			return
		end
	end
	local label = Present(displayName) and displayName or Present(name) and name or nil
	if not label and Present(spellID) then
		label = C_Spell.GetSpellName(spellID)
	end
	if not Present(texture) and Present(spellID) then
		texture = C_Spell.GetSpellTexture(spellID)
	end
	return label, texture, startMS, endMS, notInterruptible, isChannel
end

local function GetDuration(unit, isChannel)
	local getter = isChannel and UnitChannelDuration or UnitCastingDuration
	if getter then
		local ok, duration = pcall(getter, unit)
		if ok then
			return duration
		end
	end
end

local function StartSwipe(ring, isChannel, duration, startMS, endMS)
	ring:SetReverse(not isChannel)
	if duration and pcall(ring.SetCooldownFromDurationObject, ring, duration) then
		return
	end
	if startMS and endMS then
		ring:SetCooldown(startMS / 1000, (endMS - startMS) / 1000)
	end
end

local function UpdateCast(unit)
	if GetTime() < cast.interruptedUntil then
		return
	end
	local label, texture, startMS, endMS, notInterruptible, isChannel = ReadCast(unit)
	if not Present(startMS) then
		EndCast(unit)
		return
	end
	local readable = not issecretvalue(startMS) and not issecretvalue(endMS) and startMS ~= nil and endMS ~= nil
	cast.active, cast.unit = true, unit
	cast.startMS, cast.endMS = readable and startMS or nil, readable and endMS or nil
	cast.duration = GetDuration(unit, isChannel)
	cast.countsDown = isChannel

	local color = isChannel and ns.Colors.channel or ns.Colors.cast
	orb.ringOpen:SetSwipeColor(color[1], color[2], color[3], 1)
	for _, ring in ipairs(orb.rings) do
		StartSwipe(ring, isChannel, cast.duration, cast.startMS, cast.endMS)
	end
	ShowInterruptible(notInterruptible)

	-- A secret icon or name still draws.
	ShowSpellIcon(texture)
	castName:SetText(label)
	ns.SetTextColor(castName, 1, 1, 1)
	ns.SetTextColor(castTime, 1, 1, 1)
	SetCastShown(true)
	UpdateCastTime()
end

-- Who interrupted it, in the time's place, class-colored when the game says which class. The GUID and
-- the name can be secret; then the name still shows, in white.
local function ShowInterrupter(guid)
	castTime:Hide()
	if not Present(guid) then
		return
	end
	local ok, name = pcall(UnitNameFromGUID, guid)
	if not ok or not Present(name) then
		return
	end
	local r, g, b = 1, 1, 1
	local infoOK, _, classFile = pcall(GetPlayerInfoByGUID, guid)
	if infoOK and classFile and not issecretvalue(classFile) then
		local classColor = C_ClassColor.GetClassColor(classFile)
		if classColor then
			r, g, b = classColor.r, classColor.g, classColor.b
		end
	end
	castTime:SetText(name)
	ns.SetTextColor(castTime, r, g, b)
	castTime:Show()
end

-- Blizzard's cast bars say "Interrupted" for a moment, and so does this, in red, with the ring cleared
-- and the interrupter's name under it.
local function ShowInterrupted(unit, interruptedBy)
	for _, ring in ipairs(orb.rings) do
		ring:Hide()
	end
	ShowPortrait(unit)
	cast.active = false
	cast.startMS, cast.endMS, cast.duration = nil, nil, nil
	castName:SetText(INTERRUPTED or "Interrupted")
	ns.SetTextColor(castName, INTERRUPTED_COLOR[1], INTERRUPTED_COLOR[2], INTERRUPTED_COLOR[3])
	castName:Show()
	ShowInterrupter(interruptedBy)
	local token = {}
	cast.interruptToken = token
	cast.interruptedUntil = GetTime() + INTERRUPTED_SECONDS
	C_Timer.After(INTERRUPTED_SECONDS, function()
		if cast.interruptToken ~= token then
			return -- a newer interrupt, or a focus change, took over
		end
		cast.interruptedUntil = 0
		if GetShownUnit() == unit then
			UpdateCast(unit)
		end
	end)
end

-- A held sample cast for the preview: a swipe this long barely moves.
local function ShowPreviewCast()
	local held = 1e7
	cast.active = false
	local color = ns.Colors.cast
	orb.ringOpen:SetSwipeColor(color[1], color[2], color[3], 1)
	for _, ring in ipairs(orb.rings) do
		ring:SetReverse(true)
		ring:SetCooldown(GetTime() - PREVIEW_CAST.fraction * held, held)
	end
	ShowInterruptible(false)
	ShowSpellIcon(PREVIEW_CAST.icon)
	castName:SetText(PREVIEW_CAST.name)
	ns.SetTextColor(castName, 1, 1, 1)
	ns.SetTextColor(castTime, 1, 1, 1)
	castTime:SetFormattedText("%.1f / %.1f", PREVIEW_CAST.fraction * PREVIEW_CAST.total, PREVIEW_CAST.total)
	SetCastShown(true)
end

-- The time text and the animated ring move on every frame while a cast shows.
local function OnCastUpdate(_, elapsed)
	if not cast.active then
		return
	end
	cast.sinceText = (cast.sinceText or 0) + elapsed
	if cast.sinceText >= 0.05 then
		cast.sinceText = 0
		UpdateCastTime()
	end
	if ns.db.castAnimated then
		cast.flowElapsed = cast.flowElapsed + elapsed
		local step = math.floor(cast.flowElapsed * FLOW_FPS)
		if step > 0 then
			cast.flowElapsed = cast.flowElapsed - step / FLOW_FPS
			cast.flowFrame = (cast.flowFrame + step - 1) % FLOW_FRAMES + 1
			for _, ring in ipairs(orb.rings) do
				ring:SetSwipeTexture(FLOW_TEXTURES[cast.flowFrame])
			end
		end
	end
end

function ns.UpdateFocusCastStyle()
	if not ns.db.castAnimated then
		for _, ring in ipairs(orb.rings) do
			ring:SetSwipeTexture(ns.Media("CastRing"))
		end
	end
end

-- Range -----------------------------------------------------------------------------------------------

-- The player's attack and helpful spells, longest-reaching first, found in the spellbook for range checks.
-- Several are kept because some only work on certain targets (Soothe on beasts, say) and give no answer
-- for anything else; the first spell that answers decides.
local RANGE_SPELLS_KEPT = 6
local rangeSpells = { harm = {}, help = {} }

local function FindRangeSpells()
	local found = { harm = {}, help = {} }
	local ok = pcall(function()
		for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
			local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
			if info and not info.shouldHide and not info.offSpecID then
				for slot = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
					local item = C_SpellBook.GetSpellBookItemInfo(slot, Enum.SpellBookSpellBank.Player)
					local spellID = item and item.spellID
					if spellID and not item.isPassive and not item.isOffSpec
						and item.itemType == Enum.SpellBookItemType.Spell then
						local spell = C_Spell.GetSpellInfo(spellID)
						local yards = spell and spell.maxRange or 0
						local kind = C_Spell.IsSpellHarmful(spellID) and "harm"
							or C_Spell.IsSpellHelpful(spellID) and "help"
						if kind and yards > 0 and yards <= MAX_RANGE_SPELL_YARDS then
							table.insert(found[kind], { yards = yards, spellID = spellID })
						end
					end
				end
			end
		end
	end)
	if not ok then
		return
	end
	for kind, list in pairs(found) do
		table.sort(list, function(a, b)
			return a.yards > b.yards
		end)
		local kept = {}
		for i = 1, math.min(#list, RANGE_SPELLS_KEPT) do
			kept[i] = list[i].spellID
		end
		rangeSpells[kind] = kept
	end
end

-- Fades the frame, cast ring included, by a range answer that can be secret. Its auras keep their own
-- opacity, as they do for DibsUI's opacity modes.
local function SetInRange(inRange)
	for _, frame in ipairs({ visual, orb.castLayer }) do
		if issecretvalue(inRange) then
			frame:SetAlphaFromBoolean(inRange, 1, OUT_OF_RANGE_ALPHA)
		else
			frame:SetAlpha(inRange == false and OUT_OF_RANGE_ALPHA or 1)
		end
	end
end

-- true, false, a secret boolean, or nil when it can't be told (which shows as in range). Group members
-- use the client's own party range; anyone else is tested against one of the player's spells.
local function ReadRange()
	if not UnitExists(UNIT) then
		return nil
	end
	local isPlayer = UnitIsUnit(UNIT, "player")
	if issecretvalue(isPlayer) or isPlayer then
		return nil
	end
	local inGroup = UnitInParty(UNIT)
	if issecretvalue(inGroup) then
		return nil
	end
	if inGroup or (not issecretvalue(UnitInRaid(UNIT)) and UnitInRaid(UNIT)) then
		local inRange, checked = UnitInRange(UNIT)
		if issecretvalue(inRange) or issecretvalue(checked) then
			return inRange
		end
		return checked and inRange or nil
	end
	local canAttack = UnitCanAttack("player", UNIT)
	if issecretvalue(canAttack) then
		return nil
	end
	for _, spellID in ipairs(canAttack and rangeSpells.harm or rangeSpells.help) do
		local inRange = C_Spell.IsSpellInRange(spellID, UNIT)
		if issecretvalue(inRange) or inRange ~= nil then
			return inRange
		end
	end
end

function ns.UpdateFocusRange()
	if not visual then
		return
	end
	if previewing or not ns.db.focusRangeFade then
		SetInRange(true)
	else
		SetInRange(ReadRange())
	end
end

function ns.SetFocusRangeFade(enabled)
	ns.db.focusRangeFade = enabled
	ns.UpdateFocusRange()
end

-- Whole frame ------------------------------------------------------------------------------------------

local function UpdateIdentity(unit)
	ns.ShowName(nameText, UnitName(unit))
	UpdateNameColor(unit)
	UpdateLevel(unit)
	UpdateMarker(unit)
end

local function UpdateAll()
	local unit = GetShownUnit()
	visual:SetShown(unit ~= nil)
	if not unit then
		EndCast()
		return
	end
	UpdateHealth(unit, IMMEDIATE)
	UpdatePrediction(unit, IMMEDIATE)
	UpdateHealthColor(unit)
	UpdatePower(unit, IMMEDIATE)
	UpdateIdentity(unit)
	if unit == UNIT then
		ShowPortrait(unit)
		UpdateCast(unit)
	else
		ShowPreviewCast()
	end
end
ns.UpdateFocusFrame = UpdateAll

local function OnEvent(_, event, unit, ...)
	if event == "PLAYER_FOCUS_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
		cast.interruptedUntil, cast.interruptToken = 0, nil
		UpdateAll()
		ns.UpdateFocusRange()
		return
	end
	if not UnitExists(UNIT) then
		return
	end
	if event == "UNIT_HEALTH" then
		UpdateHealth(UNIT, SMOOTH)
		UpdatePrediction(UNIT, SMOOTH)
	elseif PREDICTION_EVENTS[event] then
		UpdatePrediction(UNIT, SMOOTH)
	elseif event == "UNIT_MAXHEALTH" or event == "UNIT_CONNECTION" then
		UpdateHealth(UNIT, IMMEDIATE)
		UpdatePrediction(UNIT, IMMEDIATE)
		UpdateHealthColor(UNIT)
	elseif event == "UNIT_FACTION" or event == "UNIT_FLAGS" then
		UpdateHealthColor(UNIT)
		UpdateNameColor(UNIT)
	elseif event == "UNIT_POWER_UPDATE" or event == "UNIT_POWER_FREQUENT" then
		UpdatePower(UNIT, SMOOTH)
	elseif event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER" then
		UpdatePower(UNIT, IMMEDIATE)
	elseif event == "UNIT_NAME_UPDATE" or event == "UNIT_LEVEL" or event == "PLAYER_LEVEL_UP" then
		UpdateIdentity(UNIT)
	elseif event == "RAID_TARGET_UPDATE" then
		UpdateMarker(UNIT)
	elseif event == "UNIT_PORTRAIT_UPDATE" or event == "UNIT_MODEL_CHANGED" then
		if not cast.active then
			ShowPortrait(UNIT) -- not over a cast's spell icon
		end
	elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
		local _, _, interruptedBy = ... -- castGUID, spellID, interruptedBy
		ShowInterrupted(UNIT, interruptedBy)
	elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
		-- A channel that's cut short names who did it. Only a readable GUID can be told apart from a
		-- channel that simply ended; a secret one is treated as an ordinary stop.
		local _, _, interruptedBy = ...
		if not issecretvalue(interruptedBy) and Present(interruptedBy) then
			ShowInterrupted(UNIT, interruptedBy)
		else
			UpdateCast(UNIT)
		end
	elseif event == "UNIT_SPELLCAST_INTERRUPTIBLE" then
		ShowInterruptible(false)
	elseif event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
		ShowInterruptible(true)
	else
		-- Every other spellcast event: start, stop, fail, delay, channel start, update and stop.
		UpdateCast(UNIT)
	end
end

local UNIT_EVENTS = {
	"UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_CONNECTION", "UNIT_FACTION", "UNIT_FLAGS",
	"UNIT_HEAL_PREDICTION", "UNIT_ABSORB_AMOUNT_CHANGED", "UNIT_HEAL_ABSORB_AMOUNT_CHANGED",
	"UNIT_POWER_UPDATE", "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER",
	"UNIT_NAME_UPDATE", "UNIT_LEVEL", "UNIT_PORTRAIT_UPDATE", "UNIT_MODEL_CHANGED",
	"UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
	"UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE",
	"UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
}

local function RegisterEvents(frame)
	for _, event in ipairs(UNIT_EVENTS) do
		-- A client without one of these refuses it; the rest still register.
		pcall(frame.RegisterUnitEvent, frame, event, UNIT)
	end
	frame:RegisterEvent("PLAYER_FOCUS_CHANGED")
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	frame:RegisterEvent("PLAYER_LEVEL_UP")
	frame:RegisterEvent("RAID_TARGET_UPDATE")
	frame:SetScript("OnEvent", OnEvent)
end

-- Placement ------------------------------------------------------------------------------------------

-- The saved place is the orb centre relative to the bottom centre of the screen, in UIParent units, as
-- for the main frames. The frame itself starts Layout.margin left of the orb.
local function ApplyPlacement()
	local db, scale = ns.db, GetScale()
	root:SetScale(scale)
	root:SetSize(GetFrameWidth(), Layout.height)
	root:ClearAllPoints()
	root:SetPoint("LEFT", UIParent, "BOTTOM", db.focusX / scale - Layout.margin, db.focusY / scale)
end

local function SavePosition()
	local db, scale = ns.db, GetScale()
	local _, centerY = root:GetCenter()
	db.focusX = (root:GetLeft() + Layout.margin) * scale - UIParent:GetWidth() / 2
	db.focusY = centerY * scale
end

local function FinishMoving()
	if mover and mover.isMoving then
		mover.isMoving = false
		root:StopMovingOrSizing()
		root:SetUserPlaced(false)
		SavePosition()
		ApplyPlacement()
	end
end

-- The click area covers the orb and the bars. It's a secure button, so it can't change in combat.
local function LayoutButton()
	local reach = Layout.orbQuad / 2
	button:ClearAllPoints()
	button:SetPoint("TOPLEFT", root, "LEFT", Layout.margin - reach, reach)
	button:SetPoint("BOTTOMRIGHT", root, "LEFT", Layout.margin + Layout.health.tip + ns.GetFocusBarGrowth(Layout.health), -reach)
end

local function LayoutAll()
	ApplyPlacement()
	LayoutButton()
	LayoutBar(health)
	LayoutBar(power)
	local anchor, h, p = ns.focusAuraAnchor, Layout.health, Layout.power
	anchor:ClearAllPoints()
	anchor:SetPoint("TOPLEFT", anchor.origin, "CENTER", h.hitInner, h.yCenter + h.height / 2)
	anchor:SetPoint("BOTTOMRIGHT", anchor.origin, "CENTER", h.tip + ns.GetFocusBarGrowth(h), p.yCenter - p.height / 2)
end

-- While unlocked the frame shows a stand-in if there's no focus, and a handle to drag it by.
function ns.UpdateFocusMover()
	if not mover then
		return
	end
	local unlocked = not ns.db.locked and not InCombatLockdown()
	if not unlocked then
		FinishMoving()
	end
	mover:SetShown(unlocked)
	if previewing ~= unlocked then
		previewing = unlocked
		UpdateAll()
	end
end

local function CreateMover()
	mover = CreateFrame("Frame", nil, root)
	mover:SetAllPoints()
	mover:SetFrameStrata("MEDIUM")
	mover:EnableMouse(true)
	mover:RegisterForDrag("LeftButton")

	local tint = ns.CreateArt(mover, "BACKGROUND", "Flat")
	tint:SetAllPoints()
	tint:SetVertexColor(0.15, 0.45, 1, 0.3)

	local labelSpec = ns.Text.focusMoverLabel
	local label = ns.CreateText(mover, "focusMoverLabel")
	label:SetPoint("BOTTOM", mover, "TOP", labelSpec.x, labelSpec.y)
	label:SetText("DibsUI focus: drag to move")

	mover:SetScript("OnDragStart", function(self)
		self.isMoving = true
		root:StartMoving()
	end)
	mover:SetScript("OnDragStop", FinishMoving)
	mover:Hide()

	-- The click area is a secure button, so a drag ends the moment combat starts.
	local events = CreateFrame("Frame")
	events:RegisterEvent("PLAYER_REGEN_DISABLED")
	events:RegisterEvent("PLAYER_REGEN_ENABLED")
	events:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_REGEN_DISABLED" then
			FinishMoving()
			mover:Hide()
			if previewing then
				previewing = false
				UpdateAll()
			end
		else
			ns.UpdateFocusMover()
			ns.UpdateFocusEnabled() -- catches up on a profile switch made in combat
		end
	end)
end

-- Settings -------------------------------------------------------------------------------------------

local function RoundTo(value, range)
	return math.min(math.max(math.floor(value * 100 + 0.5) / 100, range.min), range.max)
end

-- These move and resize the secure click area, so not in combat. Each returns the value in effect.
function ns.SetFocusWidth(width)
	if not InCombatLockdown() then
		ns.db.focusWidth = RoundTo(width, ns.WidthRange)
		LayoutAll()
		if ns.OnFocusLayoutChanged then
			ns.OnFocusLayoutChanged()
		end
	end
	return ns.db.focusWidth
end

function ns.SetFocusScale(scale)
	if not InCombatLockdown() then
		ns.db.focusScale = RoundTo(scale, ns.ScaleRange)
		LayoutAll()
		if ns.OnFocusLayoutChanged then
			ns.OnFocusLayoutChanged()
		end
	end
	return ns.db.focusScale
end

-- On and off -------------------------------------------------------------------------------------------

-- Blizzard's focus frame is only touched once DibsUI takes over the Blizzard frames at login.
local blizzardTaken, blizzardFocusParent = false, nil

local function UpdateBlizzardFocusFrame(replaced)
	if not (blizzardTaken and FocusFrame) then
		return
	end
	if blizzardFocusParent == nil then
		blizzardFocusParent = FocusFrame:GetParent() or UIParent
	end
	FocusFrame:SetParent(replaced and ns.hiddenParent or blizzardFocusParent)
end

-- Switched off, DibsUI's focus frame and its auras go and Blizzard's focus frame comes back. Both
-- frames are secure, so this waits for combat to end (see the PLAYER_REGEN_ENABLED handler).
function ns.UpdateFocusEnabled()
	if not root or InCombatLockdown() then
		return
	end
	local enabled = ns.db.focusEnabled
	if enabled then
		RegisterUnitWatch(button)
	else
		UnregisterUnitWatch(button)
		button:Hide()
		FinishMoving()
	end
	root:SetShown(enabled)
	UpdateBlizzardFocusFrame(enabled)
	if enabled then
		UpdateAll()
	end
	if ns.RefreshAuraFrames then
		ns.RefreshAuraFrames()
	end
end

-- Core calls this at login, when it hides Blizzard's frames.
function ns.TakeOverFocusFrame()
	blizzardTaken = true
	ns.UpdateFocusEnabled()
end

-- Returns the value in effect: unchanged in combat.
function ns.SetFocusEnabled(enabled)
	if not InCombatLockdown() then
		ns.db.focusEnabled = enabled
		ns.UpdateFocusEnabled()
	end
	return ns.db.focusEnabled
end

-- After a profile switch.
function ns.ApplyFocusProfile()
	FinishMoving()
	LayoutAll()
	if ns.OnFocusLayoutChanged then
		ns.OnFocusLayoutChanged()
	end
	ns.UpdateFocusCastStyle()
	ns.UpdateFocusMover()
	UpdateAll()
	ns.UpdateFocusEnabled()
end

-- What auras attached to "DibsUI focus frame" sit against: the bars, from the inner end of the health
-- bar to its tip, and from its top to the bottom of the power bar.
function ns.GetFocusAuraAnchor()
	return ns.focusAuraAnchor
end

-- The scale the focus frame draws at, for auras laid out against it in UI units.
function ns.GetFocusScale()
	return GetScale()
end

-- Creation ---------------------------------------------------------------------------------------------

function ns.CreateFocus()
	root = CreateFrame("Frame", "DibsUIFocusRoot", UIParent)
	root:SetFrameStrata("LOW")
	root:SetMovable(true)
	root:SetClampedToScreen(true)
	root:SetDontSavePosition(true)
	ns.focusRoot = root

	-- The orb's centre, which everything is drawn from.
	local origin = CreateFrame("Frame", nil, root)
	origin:SetSize(1, 1)
	origin:SetPoint("CENTER", root, "LEFT", Layout.margin, 0)

	-- Left click targets the focus, right click opens its menu. RegisterUnitWatch shows it while there's a
	-- focus, since a secure frame can't be shown or hidden from addon code in combat.
	button = CreateFrame("Button", "DibsUIFocusFrame", root, "SecureUnitButtonTemplate")
	button:SetFrameLevel(ns.Level.bar)
	button:RegisterForClicks("AnyUp")
	button:SetAttribute("unit", UNIT)
	button:SetAttribute("*type1", "target")
	button:SetAttribute("*type2", "togglemenu")
	RegisterUnitWatch(button)

	-- Everything visible is on a plain frame beside the button, so it can also show the stand-in.
	visual = CreateFrame("Frame", nil, root)
	visual:SetAllPoints()
	visual:SetFrameLevel(ns.Level.bar)
	visual:Hide()
	ns.focusVisual = visual

	local base = visual:GetFrameLevel()
	health = CreateBar(visual, origin, Layout.health, base + 2)
	CreatePrediction(health)
	power = CreateBar(visual, origin, Layout.power, base + 2)
	orb = CreateOrb(visual, origin, base + 12)

	-- The auras' anchor: the bars' span, health top to power bottom. It's on the root, which always shows,
	-- so buffs attached to it keep their place with no focus. LayoutAll sizes it.
	local anchor = CreateFrame("Frame", nil, root)
	anchor.origin = origin
	ns.focusAuraAnchor = anchor
	button.body = health.body -- what the focus debuffs size themselves by

	-- Texts. The name centres over the bar, clear of nothing on its right since the level is on the orb.
	local overlay = health.overlay
	nameText = ns.CreateNameText(overlay, "focusName", button)
	ns.PlaceText(nameText, "BOTTOM", health.body, "TOP", ns.Text.focusName.x, ns.Text.focusName.y)
	health.nameText, health.nameReserved = nameText, Layout.nameReserved

	levelText = ns.CreateText(orb.indicators, "focusLevel", button)
	ns.PlaceText(levelText, "CENTER", orb.frame, "CENTER", ns.Text.focusLevel.x, ns.Text.focusLevel.y)

	healthText = ns.CreateValueText(overlay, "focusRight", health.body, "RIGHT", button)
	powerText = ns.CreateValueText(power.overlay, "focusPowerRight", power.body, "RIGHT", button)

	-- The spell's name and time under the orb.
	castName = ns.CreateText(orb.indicators, "focusCastName", button)
	ns.PlaceText(castName, "TOP", orb.frame, "CENTER", ns.Text.focusCastName.x, ns.Text.focusCastName.y)
	castTime = ns.CreateText(orb.indicators, "focusCastTime", button)
	ns.PlaceText(castTime, "TOP", castName, "BOTTOM", ns.Text.focusCastTime.x, ns.Text.focusCastTime.y)

	SetCastShown(false)
	orb.frame:HookScript("OnUpdate", OnCastUpdate)

	-- The orb's own rim sizing runs on a theme switch; the focus rim follows it.
	local updateMainRim = ns.UpdateRimSize
	ns.UpdateRimSize = function()
		if updateMainRim then
			updateMainRim()
		end
		SizeRim()
	end
	SizeRim()

	hooksecurefunc(ns, "UpdateHealPredictionShown", function()
		local unit = GetShownUnit()
		if unit then
			UpdatePrediction(unit, IMMEDIATE)
		end
	end)

	LayoutAll()
	CreateMover()
	RegisterEvents(visual)
	ns.UpdateFocusMover()
	UpdateAll()

	-- Range has no event for an enemy walking off, so it's polled, as Blizzard's party frames do.
	local spellbook = CreateFrame("Frame")
	spellbook:RegisterEvent("PLAYER_LOGIN")
	spellbook:RegisterEvent("SPELLS_CHANGED")
	spellbook:SetScript("OnEvent", FindRangeSpells)
	FindRangeSpells()
	C_Timer.NewTicker(RANGE_INTERVAL, ns.UpdateFocusRange)
end
