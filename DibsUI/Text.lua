local _, ns = ...

-- The text spots that can be changed in the settings, named by where they sit and grouped as they're
-- listed there. A spot with values can show any of ns.ValueFormats; the rest always show the same thing.
-- defaultColor describes the color a spot has until a custom one is chosen.
ns.TextGroups = {
	{ label = "Player bar", fields = {
		{ key = "playerName", label = "Above", shows = "Name and level", defaultColor = "Class color, with a yellow level" },
		{ key = "playerLeft", label = "Left side", values = "health", defaultFormat = "missing", defaultColor = "White" },
		{ key = "playerRight", label = "Right side", values = "health", defaultFormat = "current", defaultColor = "White" },
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
	} },
	{ label = "Cast", fields = {
		{ key = "castName", label = "Top line", shows = "Spell name", defaultColor = "White" },
		{ key = "castTime", label = "Bottom line", shows = "Time", defaultColor = "White" },
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

-- The game's own fonts. Only the ones this client can load are offered.
local GAME_FONTS = {
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

-- What a spot uses until the settings say otherwise. Font and color default to nil: the standard
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

-- A font that's gone, such as one from a LibSharedMedia addon that's been removed, falls back to the default.
local function SetFont(text, font, size)
	if not (font and text:SetFont(font, size, ns.Text.outline)) then
		text:SetFont(ns.Text.font, size, ns.Text.outline)
	end
end

local function ApplyTextStyle(text)
	local key = text.styleKey
	local font, size = ns.GetTextOption(key, "font"), ns.GetTextOption(key, "size")
	SetFont(text, font, size)
	if text.lead then
		SetFont(text.lead, font, math.floor(size * ns.Text.lead.scale + 0.5))
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
function ns.PlaceText(text, point, relativeTo, relativePoint, x, y)
	text.anchors = text.anchors or {}
	table.insert(text.anchors, { point, relativeTo, relativePoint, x, y })
	text:SetPoint(point, relativeTo, relativePoint,
		x + ns.GetTextOption(text.styleKey, "offsetX"), y + ns.GetTextOption(text.styleKey, "offsetY"))
end

local function Reposition(text)
	if text.lead then
		LayoutValue(text)
	elseif text.anchors then
		local x, y = ns.GetTextOption(text.styleKey, "offsetX"), ns.GetTextOption(text.styleKey, "offsetY")
		text:ClearAllPoints()
		for _, anchor in ipairs(text.anchors) do
			text:SetPoint(anchor[1], anchor[2], anchor[3], anchor[4] + x, anchor[5] + y)
		end
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
		text:SetFont(ns.Text.font, ns.Text[key].size, ns.Text.outline)
		text:SetTextColor(1, 1, 1)
	end
	return text
end

-- A health or power spot, placed at point ("LEFT", "RIGHT" or "CENTER") of anchorFrame. Fill it with ns.ShowValue.
function ns.CreateValueText(parent, key, anchorFrame, point, hoverRegion)
	local text = NewText(parent, key, hoverRegion)
	text.lead = parent:CreateFontString(nil, "OVERLAY")
	text.lead:SetWordWrap(false)
	text.anchorFrame, text.anchorPoint = anchorFrame, point
	LayoutValue(text)
	Register(text)
	return text
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
-- "offsetX" or "offsetY".
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
		Reposition(text)
		if text.lead and text.unit then
			ns.ShowValue(text, text.unit, text.powerType)
		end
		ApplyTextStyle(text)
		UpdateVisibility(text)
	end
end

-- After switching profiles, every text takes on the new profile's styles.
function ns.RefreshAllText()
	for _, texts in pairs(styledTexts) do
		for _, text in ipairs(texts) do
			Reposition(text)
			if text.lead and text.unit then
				ns.ShowValue(text, text.unit, text.powerType)
			end
			ApplyTextStyle(text)
			UpdateVisibility(text)
		end
	end
end

ns.TextStyleParts = { "font", "size", "color", "enabled", "mouseover", "format", "offsetX", "offsetY" }

function ns.ResetTextStyle(key)
	for _, part in ipairs(ns.TextStyleParts) do
		ns.SetTextStyle(key, part, nil)
	end
end
