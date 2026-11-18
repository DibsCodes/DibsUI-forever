local _, ns = ...

-- The text spots that can be changed in the settings, named by where they sit and grouped as they're
-- listed there. A spot with values can show any of ns.ValueFormats; the rest always show the same thing.
-- defaultColor describes the color a spot has until a custom one is chosen.
ns.TextGroups = {
	{ label = "Player bar", fields = {
		{ key = "playerName", label = "Above", shows = "Name and level", defaultColor = "Class color, with a yellow level" },
		{ key = "playerLeft", label = "Left side", values = "health", defaultFormat = "missing", defaultColor = "White" },
		{ key = "playerRight", label = "Right side", values = "health", defaultFormat = "current", defaultColor = "White" },
		{ key = "pvpTimer", label = "PvP timer", shows = "Time left before the PvP flag drops", defaultColor = "Gold" },
	} },
	{ label = "Pet bar", fields = {
		{ key = "petName", label = "Above", shows = "Name and level", defaultColor = "White, with a yellow level" },
		{ key = "petCenter", label = "Center", values = "health", defaultFormat = "currentMax", defaultMouseover = true, defaultColor = "White" },
	} },
	{ label = "Target bar", fields = {
		{ key = "targetName", label = "Above", shows = "Name", defaultColor = "Class or reaction color" },
		{ key = "targetLevel", label = "Top right", shows = "Level", defaultColor = "Difficulty color" },
		{ key = "targetRight", label = "Right side", values = "health", defaultFormat = "percentCurrent", defaultColor = "White" },
	} },
	{ label = "Target power bar", fields = {
		{ key = "targetPowerRight", label = "Right side", values = "power", defaultFormat = "current", defaultColor = "White" },
	} },
	{ label = "Target of target", fields = {
		{ key = "totName", label = "Above", shows = "Name", defaultColor = "Class or reaction color" },
		{ key = "totLevel", label = "Top right", shows = "Level", defaultColor = "Difficulty color" },
	} },
	{ label = "Orb", fields = {
		{ key = "orbCenter", label = "Center", values = "power", defaultFormat = "current", defaultColor = "White" },
		{ key = "orbMana", label = "Druid mana", values = "power", defaultFormat = "percent", defaultColor = "Light blue",
			note = "Druids only, in bear and cat form." },
	} },
	{ label = "Cast", fields = {
		{ key = "castName", label = "Spell name", shows = "Spell name", defaultColor = "White" },
		{ key = "castTime", label = "Time", shows = "Time", defaultColor = "White" },
	} },
}

ns.TextFields = {}
for _, group in ipairs(ns.TextGroups) do
	for _, field in ipairs(group.fields) do
		field.group = group.label
		ns.TextFields[field.key] = field
	end
end

-- What a health or power spot can show.
ns.ValueFormats = {
	{ key = "current", label = "Current", example = "13k" },
	{ key = "currentMax", label = "Current / max", example = "13k / 18k" },
	{ key = "percent", label = "Percent", example = "70%" },
	{ key = "missing", label = "Missing", example = "5k, hidden when full" },
	{ key = "percentCurrent", label = "Percent and current", example = "70% - 13k" },
}

ns.ValueFormatsByKey = {}
for _, format in ipairs(ns.ValueFormats) do
	ns.ValueFormatsByKey[format.key] = format
end

-- DibsUI's own font, under the SIL Open Font License (Media/Fonts/OFL.txt). It's the master font
-- until another is picked.
ns.DEFAULT_MASTER_FONT = ns.Media("Fonts\\BarlowSemiCondensed-Bold.ttf")

-- The master font is what every text uses unless it has a font of its own.
function ns.GetMasterFont()
	return ns.db and ns.db.masterFont or ns.DEFAULT_MASTER_FONT
end

-- How a text's letters are outlined.
ns.Outlines = {
	{ key = "NONE", label = "None", flags = "" },
	{ key = "OUTLINE", label = "Outline", flags = "OUTLINE" },
	{ key = "THICKOUTLINE", label = "Thick outline", flags = "THICKOUTLINE" },
}
ns.OutlinesByKey = {}
for _, outline in ipairs(ns.Outlines) do
	ns.OutlinesByKey[outline.key] = outline
end

-- DibsUI's fonts, then the game's own. Only the ones this client can load are offered.
local GAME_FONTS = {
	{ name = "Barlow Semi Condensed Bold", path = ns.DEFAULT_MASTER_FONT },
	{ name = "Barlow Semi Condensed Black", path = ns.Media("Fonts\\BarlowSemiCondensed-Black.ttf") },
	{ name = "Friz Quadrata", path = "Fonts\\FRIZQT__.TTF" },
	{ name = "Arial Narrow", path = "Fonts\\ARIALN.TTF" },
	{ name = "Morpheus", path = "Fonts\\MORPHEUS.TTF" },
	{ name = "Skurri", path = "Fonts\\SKURRI.TTF" },
	{ name = "2002", path = "Fonts\\2002.TTF" },
	{ name = "Page Text", path = "Fonts\\K_PAGETEXT.TTF" },
	{ name = "Damage", path = "Fonts\\K_DAMAGE.TTF" },
}

local fontProbe = UIParent:CreateFontString()

local function CanLoadFont(path)
	return fontProbe:SetFont(path, 12, "") ~= false
end

-- The game's fonts, then any from LibSharedMedia, which other addons can register at any time.
function ns.GetFonts()
	local fonts, seen = {}, {}
	local function Add(name, path)
		local id = path:upper()
		if not seen[id] and CanLoadFont(path) then
			seen[id] = true
			fonts[#fonts + 1] = { name = name, path = path }
		end
	end
	for _, font in ipairs(GAME_FONTS) do
		Add(font.name, font.path)
	end
	local media = LibStub and LibStub("LibSharedMedia-3.0", true)
	if media then
		for _, name in ipairs(media:List("font")) do
			local path = media:Fetch("font", name, true)
			if type(path) == "string" then
				Add(name, path)
			end
		end
	end
	return fonts
end

-- What a spot uses until the settings say otherwise. Font and color default to nil: the master
-- font, and whatever color the game gives the spot.
local function DefaultOption(key, part)
	local field = ns.TextFields[key]
	if part == "enabled" then
		return true
	elseif part == "mouseover" then
		return field.defaultMouseover or false
	elseif part == "format" then
		return field.defaultFormat
	elseif part == "size" then
		return ns.Text[key].size
	elseif part == "offsetX" or part == "offsetY" then
		return 0
	elseif part == "outline" then
		return ns.Text.outline
	end
end

function ns.GetTextOption(key, part)
	local style = ns.db.text[key]
	local value = style and style[part]
	if value == nil then
		return DefaultOption(key, part)
	end
	return value
end

-- Font strings by field key, so a change in the settings reaches every copy of that field.
local styledTexts = {}

local function ApplyTextColor(text)
	local color = ns.GetTextOption(text.styleKey, "color")
	local r, g, b = text.defaultR, text.defaultG, text.defaultB
	if color then
		r, g, b = color[1], color[2], color[3]
	end
	text:SetTextColor(r, g, b)
	if text.lead then
		text.lead:SetTextColor(r, g, b)
	end
end

-- A font that's gone, such as one from a LibSharedMedia addon that's been removed, falls back to the
-- master font, then to the game's.
local function SetFont(text, font, size, outline)
	local flags = ns.OutlinesByKey[outline].flags
	if not (font and text:SetFont(font, size, flags)) and not text:SetFont(ns.GetMasterFont(), size, flags) then
		text:SetFont(ns.Text.font, size, flags)
	end
end

-- A last name shows beside the first, smaller and off-white, whatever color the first name has.
local SURNAME_SCALE = 0.8
local SURNAME_COLOR = { 0.88, 0.87, 0.82 }
local LEVEL_COLOR = { 1, 1, 0 }
local NAME_GAP = 4

local function ApplyTextStyle(text)
	local key = text.styleKey
	local font, size, outline = ns.GetTextOption(key, "font"), ns.GetTextOption(key, "size"), ns.GetTextOption(key, "outline")
	SetFont(text, font, size, outline)
	if text.lead then
		SetFont(text.lead, font, math.floor(size * ns.Text.lead.scale + 0.5), outline)
	end
	if text.surname then
		SetFont(text.surname, font, math.floor(size * SURNAME_SCALE + 0.5), outline)
		SetFont(text.level, font, size, outline)
	end
	ApplyTextColor(text)
end

-- Spots shown only on mouseover appear while the mouse is over the frame they belong to. That frame may
-- not take the mouse, like the orb, so this checks the cursor's position rather than waiting for OnEnter.
local hoverTexts = {}
local hoverWatcher = CreateFrame("Frame")

local function IsHovered(text)
	local region = text.hoverRegion
	return region ~= nil and region:IsVisible() and region:IsMouseOver()
end

local function UpdateVisibility(text)
	local key = text.styleKey
	local mouseover = ns.GetTextOption(key, "mouseover")
	local hovered = mouseover and IsHovered(text)
	local shown = ns.GetTextOption(key, "enabled") and (not mouseover or hovered)
	text.wasHovered = hovered
	text:SetShown(shown)
	if text.lead then
		text.lead:SetShown(shown and text.usesLead)
	end
	if text.surname then
		text.surname:SetShown(shown and text.usesSurname)
		text.level:SetShown(shown and text.usesSurname and text.levelValue ~= nil)
	end
	hoverTexts[text] = mouseover and ns.GetTextOption(key, "enabled") or nil
	hoverWatcher:SetShown(next(hoverTexts) ~= nil)
end

hoverWatcher:Hide()
hoverWatcher:SetScript("OnUpdate", function()
	for text in pairs(hoverTexts) do
		if IsHovered(text) ~= text.wasHovered then
			UpdateVisibility(text)
		end
	end
end)

-- A two part value puts its larger first piece beside the rest: before it on a right or centred spot,
-- and first on a left spot, so it always reads "70% - 13k".
-- The settings' offset is added to the anchor on the frame, and the other piece follows.
local function LayoutValue(text)
	local key = text.styleKey
	local spec, leadSpec = ns.Text[key], ns.Text.lead
	local frame, point, lead = text.anchorFrame, text.anchorPoint, text.lead
	local x, y = spec.x + ns.GetTextOption(key, "offsetX"), spec.y + ns.GetTextOption(key, "offsetY")
	text.usesLead = ns.GetTextOption(key, "format") == "percentCurrent"
	text:ClearAllPoints()
	lead:ClearAllPoints()
	if not text.usesLead then
		text:SetPoint(point, frame, point, x, y)
	elseif point == "TOP" then
		text:SetPoint("TOPLEFT", frame, "TOP", x, y)
		lead:SetPoint("BOTTOMRIGHT", text, "BOTTOMLEFT", leadSpec.x, leadSpec.y)
	elseif point == "LEFT" then
		lead:SetPoint("LEFT", frame, "LEFT", x, y)
		text:SetPoint("BOTTOMLEFT", lead, "BOTTOMRIGHT", -leadSpec.x, -leadSpec.y)
	else
		text:SetPoint(point == "RIGHT" and "RIGHT" or "LEFT", frame, point, x, y)
		lead:SetPoint("BOTTOMRIGHT", text, "BOTTOMLEFT", leadSpec.x, leadSpec.y)
	end
end

-- Places a text that always shows the same thing, adding the settings' offset. Each anchor is kept so
-- a new offset can place it again, and they all move together, so a text held between two keeps its width.
-- A name is placed by its box, which the name lays itself out in.
function ns.PlaceText(text, point, relativeTo, relativePoint, x, y)
	local region = text.box or text
	text.anchors = text.anchors or {}
	table.insert(text.anchors, { point, relativeTo, relativePoint, x, y })
	region:SetPoint(point, relativeTo, relativePoint,
		x + ns.GetTextOption(text.styleKey, "offsetX"), y + ns.GetTextOption(text.styleKey, "offsetY"))
end

-- Places a text somewhere else, dropping where it was. The settings' offset still applies.
function ns.MoveText(text, point, relativeTo, relativePoint, x, y)
	text.anchors = nil
	;(text.box or text):ClearAllPoints()
	ns.PlaceText(text, point, relativeTo, relativePoint, x, y)
end

-- A font string remembers how wide its text is. At login the font can still be loading when a name is
-- first measured, and setting the same text again keeps that wrong width, so each piece is cleared
-- first to make the game measure it afresh.
local function FreshWidth(fontString, value)
	fontString:SetText("")
	fontString:SetText(value)
	return fontString:GetUnboundedStringWidth()
end

-- The widths of a name's first name, last name and level (with the gap before it, or 0 without one).
local function MeasureRow(text)
	local level = text.levelValue
	local nameWidth = FreshWidth(text, text.firstName)
	local surnameWidth = FreshWidth(text.surname, text.lastName)
	local levelWidth = 0
	if level ~= nil then
		levelWidth = NAME_GAP + FreshWidth(text.level, level)
	else
		text.level:SetText(nil)
	end
	return nameWidth, surnameWidth, levelWidth
end

-- Lays a name out in its box: the plain name, or "First Last" with the level after when last names are
-- on. Centring the pieces means measuring them, and text widths are secret while the text is, so a
-- secret name keeps the plain layout without its last name. The first name shortens if the row won't fit.
local function LayoutName(text)
	local name, surname, level, box = text.firstName, text.lastName, text.levelValue, text.box
	if not issecretvalue(name) and name == nil then
		return
	end
	text.remeasure = nil
	text:ClearAllPoints()
	local useRow = ns.db.showSurnames and not issecretvalue(name) and not issecretvalue(surname)
		and surname ~= nil and surname ~= ""
	if useRow then
		local nameWidth, surnameWidth, levelWidth = MeasureRow(text)
		local boxWidth = box:GetWidth()
		if issecretvalue(nameWidth) or issecretvalue(surnameWidth) or issecretvalue(levelWidth) or issecretvalue(boxWidth) then
			useRow = false
		elseif nameWidth <= 0 or surnameWidth <= 0 then
			-- The font hasn't loaded yet. The plain name shows until it has (see the watcher below).
			useRow = false
			text.remeasure = true
		else
			text.measured = { nameWidth, surnameWidth, levelWidth }
			local total = nameWidth + NAME_GAP + surnameWidth + levelWidth
			-- The first name only gets a fixed width when it has to shorten. Otherwise it sizes itself,
			-- so a width measured wrong can only put the row off centre, never hide the name.
			if boxWidth > 0 and total > boxWidth then
				text:SetWidth(math.max(nameWidth - (total - boxWidth), 1))
				total = boxWidth
			else
				text:SetWidth(0)
			end
			text:SetPoint("BOTTOMLEFT", box, "BOTTOM", -total / 2, 0)
		end
	end
	if not useRow then
		text:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT")
		text:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT")
		if level ~= nil then
			text:SetFormattedText("%s |cffffff00%d|r", name, level)
		else
			text:SetText(name)
		end
	end
	text.usesSurname = useRow
	UpdateVisibility(text)
end

-- The font can still be loading when a name is first laid out, at login or the first time a size is
-- used, such as a new target's name, so it measures too narrow or empty. For a while after each loading
-- screen, and for a few seconds after a name is shown, names in a row are measured afresh a few times a
-- second and laid out again when a width changes.
local nameTexts = {}
local SETTLE_SECONDS = 30
local NEW_NAME_SETTLE_SECONDS = 5
local SETTLE_INTERVAL = 0.25
local settleUntil, nextCheck = 0, 0
local settleWatcher = CreateFrame("Frame")
settleWatcher:Hide()

local function MeasureChanged(text)
	local widths = { MeasureRow(text) }
	for i, width in ipairs(widths) do
		if issecretvalue(width) then
			return false
		end
		if width ~= text.measured[i] then
			return true
		end
	end
	return false
end

settleWatcher:SetScript("OnUpdate", function(self)
	local now = GetTime()
	if now < nextCheck then
		return
	end
	nextCheck = now + SETTLE_INTERVAL
	local settling = false
	for _, text in ipairs(nameTexts) do
		if now <= settleUntil or now <= (text.settleUntil or 0) then
			settling = true
			if text.remeasure or (text.usesSurname and text.measured and MeasureChanged(text)) then
				LayoutName(text)
			end
		end
	end
	if not settling then
		self:Hide()
	end
end)

settleWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
settleWatcher:RegisterEvent("LOADING_SCREEN_DISABLED")
settleWatcher:SetScript("OnEvent", function(self)
	settleUntil = GetTime() + SETTLE_SECONDS
	nextCheck = 0
	self:Show()
end)

local function Reposition(text)
	if text.lead then
		LayoutValue(text)
	elseif text.anchors then
		local region = text.box or text
		local x, y = ns.GetTextOption(text.styleKey, "offsetX"), ns.GetTextOption(text.styleKey, "offsetY")
		region:ClearAllPoints()
		for _, anchor in ipairs(text.anchors) do
			region:SetPoint(anchor[1], anchor[2], anchor[3], anchor[4] + x, anchor[5] + y)
		end
	end
	if text.box then
		LayoutName(text)
	end
end

local function NewText(parent, key, hoverRegion)
	local text = parent:CreateFontString(nil, "OVERLAY")
	text:SetWordWrap(false)
	text.styleKey = key
	text.hoverRegion = hoverRegion
	text.defaultR, text.defaultG, text.defaultB = 1, 1, 1
	return text
end

local function Register(text)
	local key = text.styleKey
	styledTexts[key] = styledTexts[key] or {}
	table.insert(styledTexts[key], text)
	ApplyTextStyle(text)
	UpdateVisibility(text)
end

-- key names the field in ns.Text, which gives its default size. hoverRegion is the frame the mouse has
-- to be over when the spot is set to show only on mouseover.
function ns.CreateText(parent, key, hoverRegion)
	local text = NewText(parent, key, hoverRegion)
	if ns.TextFields[key] then
		Register(text)
	else
		SetFont(text, nil, ns.Text[key].size, ns.Text.outline)
		text:SetTextColor(1, 1, 1)
	end
	return text
end

-- A health or power spot, placed at point ("LEFT", "RIGHT", "CENTER" or "TOP") of anchorFrame. Fill it with ns.ShowValue.
function ns.CreateValueText(parent, key, anchorFrame, point, hoverRegion)
	local text = NewText(parent, key, hoverRegion)
	text.lead = parent:CreateFontString(nil, "OVERLAY")
	text.lead:SetWordWrap(false)
	text.anchorFrame, text.anchorPoint = anchorFrame, point
	LayoutValue(text)
	Register(text)
	return text
end

-- A unit's name, which can show its last name too. Place it with ns.PlaceText and fill it with ns.ShowName.
function ns.CreateNameText(parent, key, hoverRegion)
	local text = NewText(parent, key, hoverRegion)
	text.box = CreateFrame("Frame", nil, parent)
	text.box:SetHeight(1)
	text.surname = parent:CreateFontString(nil, "OVERLAY")
	text.surname:SetWordWrap(false)
	text.surname:SetTextColor(SURNAME_COLOR[1], SURNAME_COLOR[2], SURNAME_COLOR[3])
	text.surname:SetPoint("BOTTOMLEFT", text, "BOTTOMRIGHT", NAME_GAP, 0)
	text.level = parent:CreateFontString(nil, "OVERLAY")
	text.level:SetWordWrap(false)
	text.level:SetTextColor(LEVEL_COLOR[1], LEVEL_COLOR[2], LEVEL_COLOR[3])
	text.level:SetPoint("BOTTOMLEFT", text.surname, "BOTTOMRIGHT", NAME_GAP, 0)
	Register(text)
	table.insert(nameTexts, text)
	return text
end

-- name and surname straight from UnitName, which can be secret. level is for the player's own name.
function ns.ShowName(text, name, surname, level)
	text.firstName, text.lastName, text.levelValue = name, surname, level
	LayoutName(text)
	if text.usesSurname or text.remeasure then
		text.settleUntil = GetTime() + NEW_NAME_SETTLE_SECONDS
		settleWatcher:Show()
	end
end

-- The name's box changed width, so the row has to fit again.
function ns.RefreshName(text)
	LayoutName(text)
end

-- Alpha 1 below full and 0 at full, so a missing amount hides at full. The value can be secret, so
-- addon code can't check for full itself; the client evaluates this curve and hands the result to SetAlpha.
local VISIBLE_BELOW_FULL = C_CurveUtil.CreateCurve()
VISIBLE_BELOW_FULL:SetType(Enum.LuaCurveType.Step)
VISIBLE_BELOW_FULL:AddPoint(0, 1)
VISIBLE_BELOW_FULL:AddPoint(1, 0)

-- Current, max, missing, percent out of 100, and the alpha for a missing amount.
local readers = {
	health = function(unit)
		return UnitHealth(unit), UnitHealthMax(unit), UnitHealthMissing(unit),
			UnitHealthPercent(unit, true, CurveConstants.ScaleTo100), UnitHealthPercent(unit, true, VISIBLE_BELOW_FULL)
	end,
	power = function(unit, powerType)
		return UnitPower(unit, powerType), UnitPowerMax(unit, powerType), UnitPowerMissing(unit, powerType),
			UnitPowerPercent(unit, powerType, false, CurveConstants.ScaleTo100), UnitPowerPercent(unit, powerType, false, VISIBLE_BELOW_FULL)
	end,
}

-- Fills a health or power spot in its chosen format. The values can be secret, so they only go into
-- the client's own formatting and SetAlpha, never compared or worked on here. powerType is for power spots.
function ns.ShowValue(text, unit, powerType)
	text.unit, text.powerType = unit, powerType
	local current, max, missing, percent, belowFull = readers[ns.TextFields[text.styleKey].values](unit, powerType)
	local format = ns.GetTextOption(text.styleKey, "format")
	text:SetAlpha(format == "missing" and belowFull or 1)
	if format == "currentMax" then
		text:SetFormattedText("%s / %s", ns.Shorten(current), ns.Shorten(max))
	elseif format == "percent" then
		text:SetFormattedText("%.0f%%", percent)
	elseif format == "missing" then
		text:SetText(ns.Shorten(missing))
	elseif format == "percentCurrent" then
		text.lead:SetFormattedText("%.0f%%", percent)
		text:SetFormattedText("- %s", ns.Shorten(current))
	else
		text:SetText(ns.Shorten(current))
	end
end

-- The color a field shows by default, such as a class color. A custom color in the settings takes its place.
-- The color can come straight from the game, so it's stored and passed on without being looked at.
function ns.SetTextColor(text, r, g, b)
	text.defaultR, text.defaultG, text.defaultB = r, g, b
	ApplyTextColor(text)
end

-- The color a field is showing by default right now, as the starting point for a custom one. White if
-- it's never been shown, or if the game handed over a secret color, which mustn't be saved.
function ns.GetTextDefaultColor(key)
	local text = styledTexts[key] and styledTexts[key][1]
	if not text or issecretvalue(text.defaultR) or issecretvalue(text.defaultG) or issecretvalue(text.defaultB) then
		return 1, 1, 1
	end
	return text.defaultR, text.defaultG, text.defaultB
end

-- Changes one part of a field's style: "font", "size", "color", "enabled", "mouseover", "format",
-- "outline", "offsetX" or "offsetY".
-- nil, or the default value, goes back to the default and leaves nothing saved for it.
function ns.SetTextStyle(key, part, value)
	if value == DefaultOption(key, part) then
		value = nil
	end
	local styles = ns.db.text
	local style = styles[key] or {}
	style[part] = value
	styles[key] = next(style) and style or nil
	for _, text in ipairs(styledTexts[key] or {}) do
		ApplyTextStyle(text)
		Reposition(text)
		if text.lead and text.unit then
			ns.ShowValue(text, text.unit, text.powerType)
		end
		UpdateVisibility(text)
	end
end

-- After switching profiles, every text takes on the new profile's styles.
function ns.RefreshAllText()
	for _, texts in pairs(styledTexts) do
		for _, text in ipairs(texts) do
			ApplyTextStyle(text)
			Reposition(text)
			if text.lead and text.unit then
				ns.ShowValue(text, text.unit, text.powerType)
			end
			UpdateVisibility(text)
		end
	end
end

ns.TextStyleParts = { "font", "size", "color", "enabled", "mouseover", "format", "outline", "offsetX", "offsetY" }

function ns.ResetTextStyle(key)
	for _, part in ipairs(ns.TextStyleParts) do
		ns.SetTextStyle(key, part, nil)
	end
end

-- The master font, nil for DibsUI's own. Texts without a font of their own follow it, the buffs' texts
-- included. Not protected, so this works in combat.
function ns.SetMasterFont(font)
	ns.db.masterFont = font ~= ns.DEFAULT_MASTER_FONT and font or nil
	ns.RefreshAllText()
	ns.RefreshAuraFrames()
	ns.NotifySettingsChanged()
end

-- Every text drops its own font and follows the master font, buffs and combat text too. Combat text
-- has no master font of its own (nil is the game's), so it's given the master font itself.
function ns.ApplyMasterFontToAll()
	for key in pairs(ns.TextFields) do
		ns.SetTextStyle(key, "font", nil)
	end
	for _, group in ipairs(ns.AuraGroups) do
		ns.SetAuraOption(group.key, "font", nil)
		if group.hasListMode then
			ns.SetAuraListOption(group.key, "nameFont", nil)
			ns.SetAuraListOption(group.key, "timeFont", nil)
		end
	end
	ns.SetCombatTextOption("font", ns.GetMasterFont())
end
