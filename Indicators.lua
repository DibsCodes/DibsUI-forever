local _, ns = ...

-- Small status pieces on the player bar: a sleeping Zzz at its top left while resting, and the PvP
-- flag under its outer bottom corner with the time left before it drops.

local SLANT = 18 -- how far the bar's top edge reaches past its bottom edge at the outer end

-- Blizzard's own animated Zzz from its player frame: 42 frames on a 7 by 6 sheet, once round in 1.5 seconds.
local REST = {
	atlas = "UI-HUD-UnitFrame-Player-Rest-Flipbook",
	size = 26,
	rows = 7,
	columns = 6,
	frames = 42,
	duration = 1.5,
	x = 2, -- BOTTOMLEFT of the Zzz to the TOPLEFT of the player bar, which is its outer tip
	y = -1,
}

-- Blizzard's player frame icons, sized by height so each keeps its own shape.
local PVP = {
	factionAtlas = {
		Alliance = "UI-HUD-UnitFrame-Player-PVP-AllianceIcon",
		Horde = "UI-HUD-UnitFrame-Player-PVP-HordeIcon",
	},
	freeForAllAtlas = "UI-HUD-UnitFrame-Player-PVP-FFAIcon",
	height = 20,
	x = SLANT - 4, -- TOPLEFT of the icon to the BOTTOMLEFT of the player bar, so it sits under its outer corner
	y = -3,
}

local function IsTrue(value)
	return not issecretvalue(value) and value == true
end

local function CreateRestIndicator(button)
	local frame = CreateFrame("Frame", "DibsUIRestIndicator", button.overlay)
	frame:SetSize(REST.size, REST.size)
	frame:SetPoint("BOTTOMLEFT", button.body, "TOPLEFT", REST.x, REST.y)

	local zzz = frame:CreateTexture(nil, "ARTWORK")
	zzz:SetAtlas(REST.atlas)
	zzz:SetAllPoints()

	local loop = frame:CreateAnimationGroup()
	loop:SetLooping("REPEAT")
	local flipBook = loop:CreateAnimation("FlipBook")
	flipBook:SetTarget(zzz)
	flipBook:SetDuration(REST.duration)
	flipBook:SetFlipBookRows(REST.rows)
	flipBook:SetFlipBookColumns(REST.columns)
	flipBook:SetFlipBookFrames(REST.frames)
	flipBook:SetFlipBookFrameWidth(0)
	flipBook:SetFlipBookFrameHeight(0)

	-- The loop only runs while it's on screen.
	frame:SetScript("OnShow", function() loop:Play() end)
	frame:SetScript("OnHide", function() loop:Stop() end)

	frame:RegisterEvent("PLAYER_UPDATE_RESTING")
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	frame:SetScript("OnEvent", function(self)
		self:SetShown(IsTrue(IsResting()))
	end)
	frame:SetShown(IsTrue(IsResting()))
end

-- Which icon the player's PvP state calls for, following Blizzard's player frame: free for all first,
-- then the faction while flagged. Mercenaries fight for the other side, so they show its icon.
local function GetPvPIcon()
	if C_GameRules and Enum.GameRule and Enum.GameRule.UnitFramePvPContextualDisabled
		and C_GameRules.IsGameRuleActive(Enum.GameRule.UnitFramePvPContextualDisabled) then
		return nil
	end
	if IsTrue(UnitIsPVPFreeForAll("player")) then
		return PVP.freeForAllAtlas, true
	end
	local faction = UnitFactionGroup("player")
	if issecretvalue(faction) or not PVP.factionAtlas[faction] or not IsTrue(UnitIsPVP("player")) then
		return nil
	end
	if IsTrue(UnitIsMercenary("player")) then
		faction = faction == "Horde" and "Alliance" or "Horde"
	end
	return PVP.factionAtlas[faction], false
end

-- 4:59, or 0:09 near the end. The flag lasts five minutes, so minutes and seconds are enough.
local function FormatTimeLeft(seconds)
	seconds = math.max(math.ceil(seconds), 0)
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function CreatePvPIndicator(button)
	local frame = CreateFrame("Frame", "DibsUIPvPIndicator", button.overlay)
	frame:SetSize(PVP.height, PVP.height)
	frame:SetPoint("TOPLEFT", button.body, "BOTTOMLEFT", PVP.x, PVP.y)

	local icon = frame:CreateTexture(nil, "ARTWORK")
	icon:SetPoint("TOPLEFT")

	-- The time sits on its own frame, since the text settings show and hide the font string itself.
	local timer = CreateFrame("Frame", nil, frame)
	timer:SetAllPoints()
	local text = ns.CreateText(timer, "pvpTimer", button)
	ns.PlaceText(text, "LEFT", icon, "RIGHT", ns.Text.pvpTimer.x, ns.Text.pvpTimer.y)
	ns.SetTextColor(text, 1, 0.82, 0)

	local shownAtlas
	local function SetIcon(atlas)
		if atlas ~= shownAtlas then
			shownAtlas = atlas
			icon:SetAtlas(atlas)
			local info = C_Texture.GetAtlasInfo(atlas)
			local width = info and info.height > 0 and PVP.height * info.width / info.height or PVP.height
			icon:SetSize(width, PVP.height)
		end
	end

	-- The client counts the flag down in milliseconds and only says so when the count starts, stops or
	-- jumps, so the text counts on by itself in between, like Blizzard's.
	local endsAt
	local sinceTick = 0
	timer:SetScript("OnUpdate", function(_, elapsed)
		sinceTick = sinceTick + elapsed
		if sinceTick < 0.2 then
			return
		end
		sinceTick = 0
		local left = endsAt - GetTime()
		if left <= 0 then
			timer:Hide()
		else
			text:SetText(FormatTimeLeft(left))
		end
	end)

	local function Update()
		local atlas, isFreeForAll = GetPvPIcon()
		if not (ns.db.showPvPIcon and atlas) then
			frame:Hide()
			return
		end
		SetIcon(atlas)
		frame:Show()
		-- Free for all has no countdown.
		local timeLeft = not isFreeForAll and IsTrue(IsPVPTimerRunning()) and GetPVPTimer()
		if timeLeft and not issecretvalue(timeLeft) and timeLeft > 0 then
			endsAt = GetTime() + timeLeft / 1000
			text:SetText(FormatTimeLeft(timeLeft / 1000))
			sinceTick = 0
			timer:Show()
		else
			timer:Hide()
		end
	end

	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	frame:RegisterEvent("PLAYER_FLAGS_CHANGED")
	frame:RegisterEvent("PLAYER_PVP_FLAG_CHANGED")
	frame:RegisterEvent("PVP_TIMER_UPDATE")
	frame:RegisterUnitEvent("UNIT_FACTION", "player")
	frame:SetScript("OnEvent", Update)
	ns.UpdatePvPIndicator = Update
	Update()
end

function ns.CreateIndicators()
	local button = DibsUIPlayerHealth
	CreateRestIndicator(button)
	CreatePvPIndicator(button)
end

-- Not a protected frame, so this works in combat.
function ns.SetPvPIconShown(shown)
	ns.db.showPvPIcon = shown
	ns.UpdatePvPIndicator()
end
