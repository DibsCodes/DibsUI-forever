local _, ns = ...

-- DibsUI's tabs in the shared settings window. The window, the profiles, the minimap button and the
-- controls themselves live in DibsUI-Options, which every DibsUI addon uses (see its README.md).

local W = DibsUIOptions.Widgets

local COLUMN_WIDTH = W.COLUMN_WIDTH
local COLUMN_GAP = W.COLUMN_GAP
local SECTION_GAP = W.SECTION_GAP
local PAGE_PADDING = W.PAGE_PADDING
local TOGGLE_ON = W.TOGGLE_ON

local FormatScale, FormatSize, FormatPercent = W.FormatScale, W.FormatSize, W.FormatPercent
local CreateLabel, CreateHint = W.CreateLabel, W.CreateHint
local ShowTooltip, HideTooltip = W.ShowTooltip, W.HideTooltip
local CreateToggle, CreateToggleRow, CreatePlaceholderRow = W.CreateToggle, W.CreateToggleRow, W.CreatePlaceholderRow
local CreateDropdownRow, CreateButton, CreateSwatch, PickColor = W.CreateDropdownRow, W.CreateButton, W.CreateSwatch, W.PickColor
local SetUpChoiceMenu = W.SetUpChoiceMenu
local CreateCard, PlaceCard, LayoutCards = W.CreateCard, W.PlaceCard, W.LayoutCards
local CreatePageHeader, CreateFlow = W.CreatePageHeader, W.CreateFlow

-- DibsUI's font list, with its own Barlow first.
local function SetUpFontMenu(dropdown, get, set, nilLabel)
	W.SetUpFontMenu(dropdown, get, set, nilLabel, ns.GetFonts)
end

-- A width slider whose chain links one of DibsUI's width pairs ("main" or "outer").
local function CreateSliderRow(parent, text, range, format, getValue, setValue, link)
	local widthLink = link and {
		names = link.names,
		isLinked = function() return ns.IsWidthLinked(link.pair) end,
		setLinked = function(linked) ns.SetWidthLinked(link.pair, linked) end,
	}
	return W.CreateSliderRow(parent, text, range, format, getValue, setValue, widthLink)
end

-- Text editor -------------------------------------------------------------------------------------

-- The text picker is no wider than this, so its dropdown sits near its label.
local PICKER_WIDTH = 440
-- The editor is one framed panel: the picker across its top, and the picked text's settings indented
-- under it beside a gold line, so they read as belonging to that text.
local EDITOR_PADDING = 12
local EDITOR_INDENT = 22
local EDITOR_TITLE_HEIGHT = 28

-- DibsUI-Options' gold, or the game's from an older DibsUI-Options without it.
local GOLD = W.GOLD or { 1, 0.82, 0 }

local function CreateEditorPanel(content)
	local panel = CreateFrame("Frame", nil, content)
	local back = panel:CreateTexture(nil, "BACKGROUND")
	back:SetAllPoints()
	back:SetColorTexture(1, 1, 1, 0.035)
	local edges = {
		{ "TOPLEFT", "TOPRIGHT", nil, 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1 },
		{ "TOPLEFT", "BOTTOMLEFT", 1, nil }, { "TOPRIGHT", "BOTTOMRIGHT", 1, nil },
	}
	for _, edge in ipairs(edges) do
		local line = panel:CreateTexture(nil, "BORDER")
		line:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.22)
		line:SetPoint(edge[1])
		line:SetPoint(edge[2])
		if edge[3] then line:SetWidth(edge[3]) else line:SetHeight(edge[4]) end
	end
	panel.accent = panel:CreateTexture(nil, "ARTWORK")
	panel.accent:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.55)
	panel.accent:SetWidth(2)
	-- Larger and white, so it reads as the parent of the gold section headings under it.
	panel.title = CreateLabel(panel, "GameFontHighlightLarge", "")
	return panel
end

-- One of a frame's text spots at a time, picked from a dropdown: whether it shows, what it shows, and
-- how it looks. keys are the spots it offers, in the order of ns.TextGroups. None of it is protected,
-- so it all works in combat. Returns the sections, the picker first and marked to span its own row,
-- and a refresh for them.
local function CreateTextEditor(content, keys, relayout)
	local fields, offered, groupsSeen = {}, {}, {}
	for _, key in ipairs(keys) do
		offered[key] = true
	end
	for _, group in ipairs(ns.TextGroups) do
		for _, field in ipairs(group.fields) do
			if offered[field.key] then
				fields[#fields + 1] = field
				groupsSeen[group.label] = true
			end
		end
	end
	-- Name the group as well when the spots come from more than one, such as the target bar and its power bar.
	local groupCount = 0
	for _ in pairs(groupsSeen) do
		groupCount = groupCount + 1
	end
	local function FieldLabel(field)
		return groupCount > 1 and (field.group .. ": " .. field.label) or field.label
	end

	local selected = fields[1]
	local refresh

	local function Set(part, value)
		ns.SetTextStyle(selected.key, part, value)
	end

	local panel = CreateEditorPanel(content)
	-- The picker sits at the top of the panel, right under the page heading that names these texts.
	local pickCard = CreateCard(panel)
	local fieldRow = pickCard:Add(CreateDropdownRow(pickCard, "Text to edit", nil, 260))
	-- When a spot only shows some of the time, such as the druid mana, this says when.
	local note = pickCard:Add(CreateHint(pickCard, ""), 4)
	note:Hide()
	local reset = pickCard:Add(CreateButton(pickCard, "Reset this text", 134), 6, true)
	reset:SetScript("OnClick", function()
		ns.ResetTextStyle(selected.key)
		refresh()
	end)

	local displayCard = CreateCard(panel, "Display")
	local showRow = displayCard:Add(CreateToggleRow(displayCard, "Show", function(checked) Set("enabled", checked) end))
	local mouseoverRow = displayCard:Add(CreateToggleRow(displayCard, "Only on mouseover", function(checked) Set("mouseover", checked) end))
	local formatRow = displayCard:Add(CreateDropdownRow(displayCard, "Shows"))

	local fontCard = CreateCard(panel, "Font")
	local fontRow = fontCard:Add(CreateDropdownRow(fontCard, "Font"))
	local outlineRow = fontCard:Add(CreateDropdownRow(fontCard, "Outline"))
	local size = fontCard:Add(CreateSliderRow(fontCard, "Size", ns.TextSizeRange, FormatSize,
		function() return ns.GetTextOption(selected.key, "size") end,
		function(value)
			Set("size", math.min(math.max(math.floor(value + 0.5), ns.TextSizeRange.min), ns.TextSizeRange.max))
		end))

	-- Moves the spot from where it normally sits, in UI units. Positive Y is up.
	local positionCard = CreateCard(panel, "Position")
	local function OffsetRow(text, part)
		return positionCard:Add(CreateSliderRow(positionCard, text, ns.TextOffsetRange, FormatSize,
			function() return ns.GetTextOption(selected.key, part) end,
			function(value)
				Set(part, math.min(math.max(math.floor(value + 0.5), ns.TextOffsetRange.min), ns.TextOffsetRange.max))
			end))
	end
	local offsetX = OffsetRow("X offset", "offsetX")
	local offsetY = OffsetRow("Y offset", "offsetY")

	local colorCard = CreateCard(panel, "Color")
	local colorRow = colorCard:Add(CreateToggleRow(colorCard, "Custom color", function(checked)
		Set("color", checked and { ns.GetTextDefaultColor(selected.key) } or nil)
		refresh()
	end))
	local swatch = CreateSwatch(colorRow)
	swatch:SetPoint("RIGHT", colorRow.toggle, "LEFT", -12, 0)
	local hint = colorCard:Add(CreateHint(colorCard, ""))

	swatch:SetScript("OnClick", function()
		local key = selected.key
		local previous = ns.GetTextOption(key, "color")
		local r, g, b = ns.GetTextDefaultColor(key)
		if previous then
			r, g, b = previous[1], previous[2], previous[3]
		end
		PickColor(r, g, b, function(color)
			ns.SetTextStyle(key, "color", color)
			refresh()
		end, function()
			ns.SetTextStyle(key, "color", previous)
			refresh()
		end)
	end)

	function refresh()
		local key = selected.key
		fieldRow.dropdown:GenerateMenu()
		panel.title:SetText(FieldLabel(selected) .. " settings")
		note:SetText(selected.note or "")
		if note:IsShown() ~= (selected.note ~= nil) then
			note:SetShown(selected.note ~= nil)
			relayout()
		end
		showRow.toggle:SetChecked(ns.GetTextOption(key, "enabled"))
		mouseoverRow.toggle:SetChecked(ns.GetTextOption(key, "mouseover"))
		-- A spot without values always shows the same thing, which the dropdown names while switched off.
		formatRow.dropdown:SetDefaultText(selected.shows or "")
		formatRow.dropdown:GenerateMenu()
		formatRow.dropdown:SetEnabled(selected.values ~= nil)
		fontRow.dropdown:GenerateMenu()
		outlineRow.dropdown:GenerateMenu()
		size:Sync()
		offsetX:Sync()
		offsetY:Sync()
		local color = ns.GetTextOption(key, "color")
		colorRow.toggle:SetChecked(color ~= nil)
		local r, g, b = ns.GetTextDefaultColor(key)
		if color then
			r, g, b = color[1], color[2], color[3]
		end
		swatch:SetSwatchColor(r, g, b, color == nil)
		hint:SetText("Default color: " .. selected.defaultColor)
	end

	fieldRow.dropdown:SetupMenu(function(_, root)
		root:SetScrollMode(480)
		for _, field in ipairs(fields) do
			root:CreateRadio(FieldLabel(field),
				function() return selected == field end,
				function()
					selected = field
					refresh()
				end, field)
		end
	end)
	fieldRow.dropdown:SetSelectionTranslator(function(selection)
		return FieldLabel(selection.data)
	end)

	-- Each format lists an example beside its name, and the dropdown shows just the name once picked.
	formatRow.dropdown:SetupMenu(function(_, root)
		if not selected.values then
			return
		end
		for _, format in ipairs(ns.ValueFormats) do
			root:CreateRadio(format.label .. "  |cff9d9d9d" .. format.example .. "|r",
				function() return ns.GetTextOption(selected.key, "format") == format.key end,
				function()
					Set("format", format.key)
					refresh()
				end, format)
		end
	end)
	formatRow.dropdown:SetSelectionTranslator(function(selection)
		return selection.data.label
	end)

	SetUpFontMenu(fontRow.dropdown,
		function() return ns.GetTextOption(selected.key, "font") end,
		function(font)
			Set("font", font)
			refresh()
		end, "Master font")

	SetUpChoiceMenu(outlineRow.dropdown, ns.Outlines,
		function() return ns.GetTextOption(selected.key, "outline") end,
		function(outline)
			Set("outline", outline)
			refresh()
		end)

	-- Lays the panel out at the width the page gives it, and takes the height that comes to.
	local settingsCards = { displayCard, fontCard, positionCard, colorCard }
	function panel:FitWidth(width)
		local y = EDITOR_PADDING
		y = y + PlaceCard(pickCard, panel, EDITOR_PADDING, y, math.min(width - 2 * EDITOR_PADDING, PICKER_WIDTH))
		y = y + SECTION_GAP
		local left = EDITOR_PADDING + EDITOR_INDENT
		local top = y
		panel.title:ClearAllPoints()
		panel.title:SetPoint("TOPLEFT", panel, "TOPLEFT", left, -y)
		y = y + EDITOR_TITLE_HEIGHT
		local bottom = LayoutCards(settingsCards, panel, left, y, width - left - EDITOR_PADDING)
		panel.accent:ClearAllPoints()
		panel.accent:SetPoint("TOPLEFT", panel, "TOPLEFT", EDITOR_PADDING + 6, -(top - 2))
		panel.accent:SetPoint("BOTTOMLEFT", panel, "TOPLEFT", EDITOR_PADDING + 6, -bottom)
		self:SetHeight(bottom + EDITOR_PADDING)
	end

	-- To the page it's one section on its own row.
	local editor = CreateCard(content)
	editor.span = 100000
	editor:Add(panel)
	return { editor }, refresh, pickCard
end

-- Pages -------------------------------------------------------------------------------------------

-- Look and feel, size, position and opacity. Size and position move secure frames, so they're locked in combat.
local function BuildGeneral(content)
	local lookCard = CreateCard(content, "Look & feel")
	local themeRow = lookCard:Add(CreateDropdownRow(lookCard, "Theme"))
	local themeHint = lookCard:Add(CreateHint(lookCard, ""), 6)
	local showToT = lookCard:Add(CreateToggleRow(lookCard, "Show target of target", ns.SetTargetOfTargetShown))
	local surnames = lookCard:Add(CreateToggleRow(lookCard, "Show last names", ns.SetSurnamesShown))
	local prediction = lookCard:Add(CreateToggleRow(lookCard, "Show incoming heals and absorbs", ns.SetHealPredictionShown))
	local pvpIcon = lookCard:Add(CreateToggleRow(lookCard, "Show PvP timer", ns.SetPvPIconShown))
	local masterRow = lookCard:Add(CreateDropdownRow(lookCard, "Master font"), 6)
	local applyFont = lookCard:Add(CreateButton(lookCard, "Use for all text", 150), 4, true)
	local fontHint = lookCard:Add(CreateHint(lookCard,
		"Texts with a font of their own keep it until you press Use for all text. That includes buff texts and combat text."), 6)

	local function SyncTheme()
		themeRow.dropdown:GenerateMenu()
		themeHint:SetText(ns.GetTheme().description)
	end
	ns.SyncThemeControl = SyncTheme -- for a theme picked in DibsUI-Party
	SetUpChoiceMenu(themeRow.dropdown, ns.Themes,
		function() return ns.GetTheme().key end,
		function(theme)
			ns.SetTheme(theme)
			SyncTheme()
		end)

	SetUpFontMenu(masterRow.dropdown,
		function() return ns.GetMasterFont() end,
		function(font)
			ns.SetMasterFont(font)
			masterRow.dropdown:GenerateMenu()
		end)
	applyFont:SetScript("OnClick", ns.ApplyMasterFontToAll)

	local sizeCard = CreateCard(content, "Size and position")
	local scale = sizeCard:Add(CreateSliderRow(sizeCard, "Scale", ns.ScaleRange, FormatScale,
		function() return ns.db.scale end, ns.SetScale))
	local width = sizeCard:Add(CreateSliderRow(sizeCard, "Width", ns.WidthRange, FormatScale,
		function() return ns.GetFrameWidth("player") end,
		function(value) ns.SetPairWidth("main", value) end,
		{ pair = "main", names = { "player bar", "target bar" } }))
	local outerWidth = sizeCard:Add(CreateSliderRow(sizeCard, "Pet and target of target width", ns.WidthRange, FormatScale,
		function() return ns.GetFrameWidth("pet") end,
		function(value) ns.SetPairWidth("outer", value) end,
		{ pair = "outer", names = { "pet bar", "target of target bar" } }))
	local widthHint = sizeCard:Add(CreateHint(sizeCard, ""), 2)

	local unlockHint = sizeCard:Add(CreateHint(sizeCard,
		"Press Unlock frames at the top of this window to drag the frames, buffs and combat text around."), 12)
	local center = sizeCard:Add(CreateButton(sizeCard, "Center horizontally", 150), 8, true)
	center:SetScript("OnClick", ns.CenterHorizontally)

	-- Up above Down, with Left and Right either side of Down.
	local pad = sizeCard:Add(CreateFrame("Frame", nil, sizeCard), 8, true)
	pad:SetSize(160, 50)

	local up = CreateButton(pad, "Up", 52)
	up:SetPoint("TOP")
	up:SetScript("OnClick", function() ns.Nudge(0, 1) end)

	local down = CreateButton(pad, "Down", 52)
	down:SetPoint("TOP", up, "BOTTOM", 0, -2)
	down:SetScript("OnClick", function() ns.Nudge(0, -1) end)

	local leftButton = CreateButton(pad, "Left", 52)
	leftButton:SetPoint("RIGHT", down, "LEFT", -2, 0)
	leftButton:SetScript("OnClick", function() ns.Nudge(-1, 0) end)

	local rightButton = CreateButton(pad, "Right", 52)
	rightButton:SetPoint("LEFT", down, "RIGHT", 2, 0)
	rightButton:SetScript("OnClick", function() ns.Nudge(1, 0) end)

	-- None of the opacity settings are protected, so they stay usable in combat.
	local opacityCard = CreateCard(content, "Opacity")
	local modeRow = opacityCard:Add(CreateDropdownRow(opacityCard, "Mode"))
	local modeHint = opacityCard:Add(CreateHint(opacityCard, ""))
	local manual = opacityCard:Add(CreateSliderRow(opacityCard, "Manual opacity", { min = 0, max = 100, step = 5 }, FormatPercent,
		function() return math.floor(ns.db.manualOpacity * 100 + 0.5) end,
		function(value) ns.SetManualOpacity(value / 100) end), 4)

	local function SyncOpacity()
		modeRow.dropdown:GenerateMenu()
		modeHint:SetText(ns.OpacityModesByKey[ns.db.opacityMode].description)
		manual:Sync()
		manual:SetEnabled(ns.db.opacityMode == "manual")
	end

	SetUpChoiceMenu(modeRow.dropdown, ns.OpacityModes,
		function() return ns.db.opacityMode end,
		function(mode)
			ns.SetOpacityMode(mode)
			SyncOpacity()
		end)

	local lowHealthCard = CreateCard(content, "Low health")
	local lowHealth = lowHealthCard:Add(CreateToggleRow(lowHealthCard, "Glow when health is low", function(checked)
		ns.SetLowHealthGlow(checked)
		lowHealthCard:Sync()
	end))
	local threshold = lowHealthCard:Add(CreateSliderRow(lowHealthCard, "Glow below", ns.LowHealthRange, FormatPercent,
		function() return ns.db.lowHealthThreshold end,
		function(value) ns.SetLowHealthThreshold(value) end), 4)
	function lowHealthCard:Sync()
		lowHealth.toggle:SetChecked(ns.db.lowHealthGlow)
		threshold:Sync()
		threshold:SetEnabled(ns.db.lowHealthGlow)
	end

	local isLocked = false
	local options = {}

	-- While a pair is unlinked, its width here is greyed: each frame's own tab sets it. The link still works.
	local function SyncWidthLocks()
		local mainLinked, outerLinked = ns.IsWidthLinked("main"), ns.IsWidthLinked("outer")
		width:SetEnabled(not isLocked and mainLinked, not isLocked)
		outerWidth:SetEnabled(not isLocked and outerLinked, not isLocked)
		local text = ""
		if not mainLinked and not outerLinked then
			text = "Unlinked: each bar's width is set on the Player & Pet and Target tabs."
		elseif not mainLinked then
			text = "Unlinked: the player and target bar widths are set on the Player & Pet and Target tabs."
		elseif not outerLinked then
			text = "Unlinked: the pet and target of target widths are set on the Player & Pet and Target tabs."
		end
		if widthHint:GetText() ~= text then
			widthHint:SetText(text)
			widthHint:SetShown(text ~= "")
			if options.relayout then
				options.relayout()
			end
		end
	end
	widthHint:Hide()
	width.OnLinkChanged = function() width:Sync() SyncWidthLocks() end
	outerWidth.OnLinkChanged = function() outerWidth:Sync() SyncWidthLocks() end

	function options.Sync()
		showToT.toggle:SetChecked(ns.db.showTargetOfTarget)
		surnames.toggle:SetChecked(ns.db.showSurnames)
		prediction.toggle:SetChecked(ns.db.showHealPrediction)
		pvpIcon.toggle:SetChecked(ns.db.showPvPIcon)
		masterRow.dropdown:GenerateMenu()
		SyncTheme()
		SyncOpacity()
		lowHealthCard:Sync()
		scale:Sync()
		width:Sync()
		outerWidth:Sync()
		SyncWidthLocks()
	end

	function options.SetCombatLocked(locked)
		isLocked = locked
		for _, control in ipairs({ showToT, scale, center, up, down, leftButton, rightButton }) do
			control:SetEnabled(not locked)
		end
		SyncWidthLocks()
	end

	options.Layout = CreateFlow(content, { lookCard, sizeCard, opacityCard, lowHealthCard })
	return options
end

-- A frame tab's Look & feel section: its own width, linked to the frame across the orb, the switch for
-- the frame beyond it, and that frame's width. These move secure frames, so they're locked in combat.
local function CreateFrameLookCard(content, spec)
	local card = CreateCard(content, "Look & feel")
	local width = card:Add(CreateSliderRow(card, spec.widthLabel, ns.WidthRange, FormatScale,
		function() return ns.GetFrameWidth(spec.frame) end,
		function(value) ns.SetFrameWidth(spec.frame, value) end,
		{ pair = "main", names = { "player bar", "target bar" } }))
	local shown = card:Add(CreateToggleRow(card, spec.toggleLabel, spec.setShown))
	local outerWidth = card:Add(CreateSliderRow(card, spec.outerLabel, ns.WidthRange, FormatScale,
		function() return ns.GetFrameWidth(spec.outerFrame) end,
		function(value) ns.SetFrameWidth(spec.outerFrame, value) end,
		{ pair = "outer", names = { "pet bar", "target of target bar" } }))
	width.OnLinkChanged = function() width:Sync() end
	outerWidth.OnLinkChanged = function() outerWidth:Sync() end

	function card:Sync()
		width:Sync()
		outerWidth:Sync()
		shown.toggle:SetChecked(spec.isShown())
	end

	function card:SetCombatLocked(locked)
		width:SetEnabled(not locked)
		outerWidth:SetEnabled(not locked)
		shown:SetEnabled(not locked)
	end
	return card
end

local function AppendAll(list, more)
	for _, item in ipairs(more) do
		list[#list + 1] = item
	end
end

-- Collects the refreshes of a page's pieces into one Sync.
local function Joined(...)
	local functions = { ... }
	return function()
		for _, sync in ipairs(functions) do
			sync()
		end
	end
end

local function BuildPlayer(content, _, relayout)
	local lookCard = CreateFrameLookCard(content, {
		frame = "player", widthLabel = "Player bar width",
		toggleLabel = "Show pet frame", setShown = ns.SetPetShown, isShown = function() return ns.db.showPet end,
		outerFrame = "pet", outerLabel = "Pet bar width",
	})
	local playerCards, playerRefresh = CreateTextEditor(content, { "playerName", "playerLeft", "playerRight", "pvpTimer" }, relayout)
	local petCards, petRefresh = CreateTextEditor(content, { "petName", "petCenter" }, relayout)

	local items = { lookCard, CreatePageHeader(content, "Player texts") }
	AppendAll(items, playerCards)
	items[#items + 1] = CreatePageHeader(content, "Pet texts")
	AppendAll(items, petCards)

	return {
		Sync = Joined(function() lookCard:Sync() end, playerRefresh, petRefresh),
		SetCombatLocked = function(locked) lookCard:SetCombatLocked(locked) end,
		Layout = CreateFlow(content, items),
	}
end

local function BuildTarget(content, _, relayout)
	local lookCard = CreateFrameLookCard(content, {
		frame = "target", widthLabel = "Target bar width",
		toggleLabel = "Show target of target", setShown = ns.SetTargetOfTargetShown,
		isShown = function() return ns.db.showTargetOfTarget end,
		outerFrame = "tot", outerLabel = "Target of target width",
	})
	local targetCards, targetRefresh = CreateTextEditor(content, { "targetName", "targetLevel", "targetRight", "targetPowerRight" }, relayout)
	local totCards, totRefresh = CreateTextEditor(content, { "totName", "totLevel" }, relayout)

	local items = { lookCard, CreatePageHeader(content, "Target texts") }
	AppendAll(items, targetCards)
	items[#items + 1] = CreatePageHeader(content, "Target of target texts")
	AppendAll(items, totCards)

	return {
		Sync = Joined(function() lookCard:Sync() end, targetRefresh, totRefresh),
		SetCombatLocked = function(locked) lookCard:SetCombatLocked(locked) end,
		Layout = CreateFlow(content, items),
	}
end

local CAST_PLACEMENTS = {
	{ key = "below", label = "Below the orb" },
	{ key = "above", label = "Above the orb" },
}

-- The orb's own settings, then its texts. None of it is protected, so it all works in combat.
local function BuildPowerOrb(content, _, relayout)
	local orbCard = CreateCard(content, "Look & feel")
	local styleRow = orbCard:Add(CreateDropdownRow(orbCard, "Liquid"))
	local styleHint = orbCard:Add(CreateHint(orbCard, ""))
	local spark = orbCard:Add(CreateToggleRow(orbCard, "Show five second rule timer", ns.SetManaSparkShown), 4)
	-- The druid mana is a text spot, so this is the same switch as that text's Show.
	local druidMana = orbCard:Add(CreateToggleRow(orbCard, "Show druid mana in bear and cat form", function(checked)
		ns.SetTextStyle("orbMana", "enabled", checked)
	end))

	local function SyncStyle()
		styleRow.dropdown:GenerateMenu()
		for _, style in ipairs(ns.OrbStyles) do
			if style.key == ns.db.orbStyle then
				styleHint:SetText(style.description)
			end
		end
	end
	SetUpChoiceMenu(styleRow.dropdown, ns.OrbStyles,
		function() return ns.db.orbStyle end,
		function(style)
			ns.SetOrbStyle(style)
			SyncStyle()
		end)

	local orbCards, orbRefresh = CreateTextEditor(content, { "orbCenter", "orbMana" }, relayout)

	local items = { orbCard, CreatePageHeader(content, "Orb texts") }
	AppendAll(items, orbCards)

	return {
		Sync = Joined(function()
			SyncStyle()
			spark.toggle:SetChecked(ns.db.showManaSpark)
			druidMana.toggle:SetChecked(ns.GetTextOption("orbMana", "enabled"))
		end, orbRefresh),
		SetCombatLocked = function() end,
		Layout = CreateFlow(content, items),
	}
end

-- The cast ring round the orb, then the cast's texts. None of it is protected, so it all works in combat.
local function BuildCastRing(content, _, relayout)
	local castCard = CreateCard(content, "Look & feel")
	local placementRow = castCard:Add(CreateDropdownRow(castCard, "Spell name and time"))
	SetUpChoiceMenu(placementRow.dropdown, CAST_PLACEMENTS,
		function() return ns.db.castTextPlacement end,
		function(placement) ns.SetCastTextPlacement(placement) end)
	local swing = castCard:Add(CreateToggleRow(castCard, "Show swing timer", ns.SetSwingTimerShown), 4)
	-- PLACEHOLDER castLatency: "Show latency" - the part of the cast lost to latency, shaded at the ring's end.
	castCard:Add(CreatePlaceholderRow(castCard, "Show latency", "castLatency"))
	local animatedRing = castCard:Add(CreateToggleRow(castCard, "Animated ring", ns.SetCastAnimated))
	local gcd = castCard:Add(CreateToggleRow(castCard, "Show global cooldown", ns.SetGCDShown))
	local icon = castCard:Add(CreateToggleRow(castCard, "Show spell icon beside the name", ns.SetCastIconShown))

	local castCards, castRefresh = CreateTextEditor(content, { "castName", "castTime" }, relayout)

	local items = { castCard, CreatePageHeader(content, "Cast texts") }
	AppendAll(items, castCards)

	return {
		Sync = Joined(function()
			placementRow.dropdown:GenerateMenu()
			swing.toggle:SetChecked(ns.db.showSwingTimer)
			animatedRing.toggle:SetChecked(ns.db.castAnimated)
			gcd.toggle:SetChecked(ns.db.castGCD)
			icon.toggle:SetChecked(ns.db.showCastIcon)
		end, castRefresh),
		SetCombatLocked = function() end,
		Layout = CreateFlow(content, items),
	}
end

local SIDEBAR_WIDTH = 170
local AURA_DROPDOWN_WIDTH = 130
local AURA_GROUP_HEIGHT = 30

-- The groups down the left, each with its own switch, and the picked group's settings beside them.
-- None of it is protected, so it all works in combat.
local function BuildAuras(content)
	local selected = ns.AuraGroups[1]
	local refresh
	local syncs = {}
	local options = {}

	local function Get(field)
		return ns.GetAuraSettings(selected.key)[field]
	end

	local function Set(field, value)
		ns.SetAuraOption(selected.key, field, value)
	end

	local function GetList(field)
		return ns.GetAuraSettings(selected.key).list[field]
	end

	local function SetList(field, value)
		ns.SetAuraListOption(selected.key, field, value)
	end

	-- Sidebar: the groups, then test mode
	local groupsCard = CreateCard(content, "Groups")
	local groupRows = {}
	for i, group in ipairs(ns.AuraGroups) do
		local row = groupsCard:Add(CreateFrame("Button", nil, groupsCard), i == 1 and 2 or 0)
		row:SetSize(SIDEBAR_WIDTH, AURA_GROUP_HEIGHT)

		local highlight = row:CreateTexture(nil, "HIGHLIGHT")
		highlight:SetAllPoints()
		highlight:SetColorTexture(1, 1, 1, 0.08)

		row.selected = row:CreateTexture(nil, "BACKGROUND")
		row.selected:SetAllPoints()
		row.selected:SetColorTexture(TOGGLE_ON[1], TOGGLE_ON[2], TOGGLE_ON[3], 0.15)

		local label = CreateLabel(row, "GameFontHighlight", group.label)
		label:SetPoint("LEFT", 8, 0)

		row.toggle = CreateToggle(row, function(checked)
			ns.SetAuraOption(group.key, "enabled", checked)
		end)
		row.toggle:SetPoint("RIGHT", -4, 0)

		row:SetScript("OnClick", function()
			selected = group
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
			refresh()
		end)
		groupRows[i] = { row = row, group = group }
	end

	local testCard = CreateCard(content, "Test mode")
	local testRow = testCard:Add(CreateToggleRow(testCard, "Show test buffs", ns.SetAuraTestMode), 2)
	testCard:Add(CreateHint(testCard,
		"Fills every group with sample buffs, so you can see the layout as you change it. Target debuffs show while you have a target, and target buffs show either way. Turns off when you reload."), 2)
	if ns.hasMasque then
		testCard:Add(CreateHint(testCard,
			"Masque is installed: pick a skin for these icons in Masque's settings (/masque)."), 10)
	end

	-- Each row's refresh, run only while the row is showing, so a row never reads a setting the picked
	-- group doesn't have.
	local function AddSync(row, sync)
		syncs[#syncs + 1] = { row = row, sync = sync }
	end

	local function IsShowing(region)
		while region and region ~= content do
			if not region:IsShown() then
				return false
			end
			region = region:GetParent()
		end
		return true
	end

	-- A slider reads its value as it's made, while the first group is picked, which may not have this
	-- setting. Its row only shows for groups that do.
	local function Slider(card, text, range, access)
		local function get()
			local value = access.get()
			return value ~= nil and value or range.min
		end
		local row = card:Add(CreateSliderRow(card, text, range, FormatSize, get, access.set))
		AddSync(row, row.Sync)
		return row
	end

	local function Toggle(card, text, access)
		local row = card:Add(CreateToggleRow(card, text, access.set))
		AddSync(row, function() row.toggle:SetChecked(access.get()) end)
		return row
	end

	local function Dropdown(card, text)
		local row = card:Add(CreateDropdownRow(card, text, nil, AURA_DROPDOWN_WIDTH))
		AddSync(row, function() row.dropdown:GenerateMenu() end)
		return row
	end

	local function Choices(card, text, list, access)
		local row = Dropdown(card, text)
		SetUpChoiceMenu(row.dropdown, list, access.get, function(key)
			access.set(key)
			refresh()
		end)
		return row
	end

	-- Each font shows in its own typeface. nil follows the master font.
	local function FontChoice(card, access)
		local row = Dropdown(card, "Font")
		SetUpFontMenu(row.dropdown, access.get, function(font)
			access.set(font)
			refresh()
		end, "Master font")
		return row
	end

	local function ColorChoice(card, access)
		local row = card:Add(CreateFrame("Frame", nil, card))
		row:SetSize(COLUMN_WIDTH, 30)
		local label = CreateLabel(row, "GameFontHighlight", "Color")
		label:SetPoint("LEFT")
		local swatch = CreateSwatch(row)
		swatch:SetPoint("RIGHT", -2, 0)
		swatch:SetScript("OnClick", function()
			local previous = access.get()
			PickColor(previous[1], previous[2], previous[3], function(color)
				access.set(color)
				refresh()
			end, function()
				access.set(previous)
				refresh()
			end)
		end)
		AddSync(row, function()
			local color = access.get()
			swatch:SetSwatchColor(color[1], color[2], color[3])
		end)
		return row
	end

	-- A text's font, size, color and offsets from where it normally sits.
	local function TextChoices(card, access, fields)
		FontChoice(card, access(fields.font))
		Slider(card, "Size", ns.AuraTextSizeRange, access(fields.size))
		ColorChoice(card, access(fields.color))
		Slider(card, "X offset", ns.AuraTextOffsetRange, access(fields.x))
		Slider(card, "Y offset", ns.AuraTextOffsetRange, access(fields.y))
	end

	-- Reads and writes one setting of the picked group, or of its list mode.
	local function Field(field)
		return { get = function() return Get(field) end, set = function(value) Set(field, value) end }
	end

	local function ListField(field)
		return { get = function() return GetList(field) end, set = function(value) SetList(field, value) end }
	end

	-- Position settings belong to the mode in use, since list mode has its own.
	local function IsList()
		return selected.hasListMode == true and Get("mode") == "list"
	end

	local function PositionField(field)
		return {
			get = function() return IsList() and GetList(field) or Get(field) end,
			set = function(value)
				if IsList() then
					SetList(field, value)
				else
					Set(field, value)
				end
			end,
		}
	end

	-- Layout first, for the groups that have a list mode
	local modeCard = CreateCard(content, "Layout")
	Choices(modeCard, "Mode", ns.AuraModes, Field("mode"))
	local modeHint = modeCard:Add(CreateHint(modeCard, ""))

	-- Then position, of the mode in use. Anchored groups have none, and say where they sit instead.
	local positionCard = CreateCard(content, "Position")
	Choices(positionCard, "Frame point", ns.AuraPoints, PositionField("point"))
	Choices(positionCard, "Attach to", ns.AuraAnchorTargets, PositionField("anchorTo"))
	Choices(positionCard, "Attach point", ns.AuraPoints, PositionField("anchorPoint"))
	Slider(positionCard, "X offset", ns.AuraOffsetRange, PositionField("x"))
	Slider(positionCard, "Y offset", ns.AuraOffsetRange, PositionField("y"))
	positionCard:Add(CreateHint(positionCard,
		"Sizes and offsets follow your UI scale. You can also drag the frame while frames are unlocked."), 4)

	local anchoredCard = CreateCard(content, "Position")
	local anchoredNote = anchoredCard:Add(CreateLabel(anchoredCard, "GameFontHighlightSmall", ""), 4)
	anchoredNote:SetWordWrap(true)

	-- Then the icons: standard mode
	local iconCard = CreateCard(content, "Icons")
	Slider(iconCard, "Icon size", ns.AuraIconSizeRange, Field("iconSize"))
	Slider(iconCard, "Spacing", ns.AuraSpacingRange, Field("spacing"))
	-- Groups that set the player's own auras apart give them their own size.
	local ownSize = Slider(iconCard, "Your debuffs icon size", ns.AuraIconSizeRange, Field("ownIconSize"))
	local growthRow = Choices(iconCard, "Growth", ns.AuraGrowths, Field("growth"))
	local frameSize = Slider(iconCard, "Frame width", ns.AuraFrameSizeRange, Field("frameSize"))

	-- or list mode
	local listIconCard = CreateCard(content, "Icons")
	Toggle(listIconCard, "Icon on the right", {
		get = function() return GetList("iconSide") == "RIGHT" end,
		set = function(checked) SetList("iconSide", checked and "RIGHT" or "LEFT") end,
	})
	-- A list growing up starts at the bottom, so it can rise from beside a bar.
	Toggle(listIconCard, "Grow up", ListField("growUp"))
	Slider(listIconCard, "Icon size", ns.AuraIconSizeRange, ListField("iconSize"))
	Slider(listIconCard, "Spacing", ns.AuraSpacingRange, ListField("spacing"))

	-- Then the texts
	local textCard = CreateCard(content, "Time text")
	TextChoices(textCard, Field, { font = "font", size = "textSize", color = "textColor", x = "textX", y = "textY" })

	local nameCard = CreateCard(content, "Name")
	TextChoices(nameCard, ListField, { font = "nameFont", size = "nameSize", color = "nameColor", x = "nameX", y = "nameY" })

	local timeCard = CreateCard(content, "Time")
	TextChoices(timeCard, ListField, { font = "timeFont", size = "timeSize", color = "timeColor", x = "timeX", y = "timeY" })

	local settingsCards = { modeCard, positionCard, anchoredCard, iconCard, listIconCard, textCard, nameCard, timeCard }

	function refresh()
		for _, entry in ipairs(groupRows) do
			entry.row.selected:SetShown(entry.group == selected)
			entry.row.toggle:SetChecked(ns.GetAuraSettings(entry.group.key).enabled)
		end
		testRow.toggle:SetChecked(ns.auraTestMode)

		local hasListMode = selected.hasListMode == true
		local isAnchored = selected.anchored == true
		local isList = IsList()
		modeCard:SetShown(hasListMode)
		if hasListMode then
			modeHint:SetText(ns.AuraModesByKey[Get("mode")].description)
		end
		iconCard:SetShown(not isList)
		textCard:SetShown(not isList)
		listIconCard:SetShown(isList)
		nameCard:SetShown(isList)
		timeCard:SetShown(isList)
		positionCard:SetShown(not isAnchored)
		anchoredCard:SetShown(isAnchored)
		anchoredNote:SetText(selected.anchorNote or "")

		-- Anchored groups take their growth and width from the frame they sit on.
		growthRow:SetShown(not isAnchored)
		frameSize:SetShown(not isAnchored)
		ownSize:SetShown(selected.hasOwnSize == true)
		if not isAnchored then
			-- Growth that fills up or down first wraps at the frame's height instead.
			local growth = ns.AuraGrowthsByKey[Get("growth")]
			local isVertical = growth.line == "UP" or growth.line == "DOWN"
			frameSize.label:SetText(isVertical and "Frame height" or "Frame width")
		end
		for _, entry in ipairs(syncs) do
			if IsShowing(entry.row) then
				entry.sync()
			end
		end
		if options.relayout then
			options.relayout()
		end
	end

	-- Dragging the frame while unlocked changes its offsets, which the sliders follow.
	function ns.OnAuraSettingsMoved(groupKey)
		if groupKey == selected.key and content:IsVisible() then
			refresh()
		end
	end

	-- The sidebar keeps its width at the left, and the picked group's sections flow beside it.
	function options.Layout(pageWidth)
		local sidebarBottom = PAGE_PADDING + PlaceCard(groupsCard, content, PAGE_PADDING, PAGE_PADDING, SIDEBAR_WIDTH)
		sidebarBottom = sidebarBottom + SECTION_GAP + PlaceCard(testCard, content, PAGE_PADDING, sidebarBottom + SECTION_GAP, SIDEBAR_WIDTH)
		local settingsX = PAGE_PADDING + SIDEBAR_WIDTH + COLUMN_GAP
		local settingsBottom = LayoutCards(settingsCards, content, settingsX, PAGE_PADDING, pageWidth - SIDEBAR_WIDTH - COLUMN_GAP)
		return math.max(sidebarBottom, settingsBottom)
	end

	options.Sync = refresh
	options.SetCombatLocked = function() end
	return options
end

local COMBAT_TEXT_ATTACH = {
	{ key = "player", label = "Player bar",
		hint = "Rises from above the player bar, and above your short buffs while you have any." },
	{ key = "free", label = "Where you drag it",
		hint = "Stays where you dropped it." },
}

-- Blizzard's scrolling combat text: where it rises from, its font and scale, and colors for kinds of
-- hits. None of it is protected, so it all works in combat.
local function BuildCombatText(content, _, relayout)
	local refresh

	local positionCard = CreateCard(content, "Position")
	local moveRow = positionCard:Add(CreateToggleRow(positionCard, "Move combat text", function(checked)
		ns.SetCombatTextOption("enabled", checked)
		refresh()
	end))
	local attachRow = positionCard:Add(CreateDropdownRow(positionCard, "Attach to"))
	local attachHint = positionCard:Add(CreateHint(positionCard, ""))
	positionCard:Add(CreateHint(positionCard,
		"Press Unlock frames to drag the Combat text box. Dropping it keeps it where you put it."), 4)
	local function OffsetRow(text, key)
		return positionCard:Add(CreateSliderRow(positionCard, text, ns.CombatTextOffsetRange, FormatSize,
			function() return ns.GetCombatTextOption(key) end,
			function(value)
				ns.SetCombatTextOption(key, math.floor(value + 0.5))
			end), 4)
	end
	local offsetX = OffsetRow("X offset", "offsetX")
	local offsetY = OffsetRow("Y offset", "offsetY")
	local reset = positionCard:Add(CreateButton(positionCard, "Reset position", 134), 6, true)
	reset:SetScript("OnClick", function()
		ns.ResetCombatTextPosition()
		refresh()
	end)

	SetUpChoiceMenu(attachRow.dropdown, COMBAT_TEXT_ATTACH,
		function() return ns.GetCombatTextOption("attach") end,
		function(key)
			ns.SetCombatTextOption("attach", key)
			refresh()
		end)

	local fontCard = CreateCard(content, "Font and scale")
	local fontRow = fontCard:Add(CreateDropdownRow(fontCard, "Font"))
	local outlineRow = fontCard:Add(CreateDropdownRow(fontCard, "Outline"))
	local scale = fontCard:Add(CreateSliderRow(fontCard, "Scale", ns.CombatTextScaleRange, FormatScale,
		function() return ns.GetCombatTextOption("scale") end,
		function(value)
			ns.SetCombatTextOption("scale", math.floor(value * 100 + 0.5) / 100)
		end))
	fontCard:Add(CreateHint(fontCard,
		"Scale changes the text, the space between lines and how far they rise, all together."), 2)

	-- nil is the game's own combat text font.
	SetUpFontMenu(fontRow.dropdown,
		function() return ns.GetCombatTextOption("font") end,
		function(font)
			ns.SetCombatTextOption("font", font)
			refresh()
		end, "Game's combat font")

	SetUpChoiceMenu(outlineRow.dropdown, ns.CombatTextOutlines,
		function() return ns.GetCombatTextOption("outline") end,
		function(outline)
			ns.SetCombatTextOption("outline", outline)
			refresh()
		end)

	-- One switch per kind of hit, with a swatch beside it. Switched off, the kind keeps Blizzard's color.
	local colorCard = CreateCard(content, "Colors")
	local colorRows = {}
	for _, group in ipairs(ns.CombatTextColorGroups) do
		local row = colorCard:Add(CreateToggleRow(colorCard, group.label, function(checked)
			ns.SetCombatTextColor(group.key, checked and { unpack(group.default) } or nil)
			refresh()
		end))
		local swatch = CreateSwatch(row)
		swatch:SetPoint("RIGHT", row.toggle, "LEFT", -12, 0)
		swatch:SetScript("OnClick", function()
			local previous = ns.GetCombatTextColor(group.key)
			local start = previous or group.default
			PickColor(start[1], start[2], start[3], function(color)
				ns.SetCombatTextColor(group.key, color)
				refresh()
			end, function()
				ns.SetCombatTextColor(group.key, previous)
				refresh()
			end)
		end)
		colorRows[#colorRows + 1] = { row = row, swatch = swatch, group = group }
	end
	colorCard:Add(CreateHint(colorCard,
		"Switched off, a kind keeps Blizzard's color. Crits count with their kind. New colors show on the next hit."), 2)

	local aboutCard = CreateCard(content, "The game's options")
	local about = aboutCard:Add(CreateLabel(aboutCard, "GameFontHighlightSmall",
		"These change the game's own scrolling combat text, which only shows while it's switched on in the game's options. Which kinds of text show, and whether they scroll up, down or in an arc, are set there too.\n\nThe damage numbers over enemies are drawn by the game, so addons can't change them."), 2)
	about:SetWordWrap(true)

	local shownAttach

	function refresh()
		local enabled = ns.GetCombatTextOption("enabled")
		moveRow.toggle:SetChecked(enabled)
		attachRow.dropdown:GenerateMenu()
		attachRow.dropdown:SetEnabled(enabled)
		offsetX:Sync()
		offsetY:Sync()
		offsetX:SetEnabled(enabled)
		offsetY:SetEnabled(enabled)
		reset:SetEnabled(enabled)
		fontRow.dropdown:GenerateMenu()
		outlineRow.dropdown:GenerateMenu()
		scale:Sync()
		for _, entry in ipairs(colorRows) do
			local color = ns.GetCombatTextColor(entry.group.key)
			entry.row.toggle:SetChecked(color ~= nil)
			local shown = color or entry.group.default
			entry.swatch:SetSwatchColor(shown[1], shown[2], shown[3], color == nil)
		end
		-- The hint wraps to a different height for each choice, so the page is laid out again.
		local attach = ns.GetCombatTextOption("attach")
		if attach ~= shownAttach then
			shownAttach = attach
			for _, choice in ipairs(COMBAT_TEXT_ATTACH) do
				if choice.key == attach then
					attachHint:SetText(choice.hint)
				end
			end
			relayout()
		end
	end

	-- Dragging the box while unlocked changes where it's attached, which the dropdown follows.
	function ns.OnCombatTextMoved()
		if content:IsVisible() then
			refresh()
		end
	end

	return {
		Sync = refresh,
		SetCombatLocked = function() end,
		Layout = CreateFlow(content, { positionCard, fontCard, colorCard, aboutCard }),
	}
end

-- The tabs DibsUI adds to the settings window, in order. DibsUI-Options adds Profiles after every addon's.
ns.ConfigTabs = {
	{ label = "General", build = BuildGeneral },
	{ label = "Player & Pet Frame", build = BuildPlayer },
	{ label = "Target Frame", build = BuildTarget },
	{ label = "Power Orb", build = BuildPowerOrb },
	{ label = "Cast Ring", build = BuildCastRing },
	{ label = "Buffs & Debuffs", build = BuildAuras },
	{ label = "Incoming Combat Text", build = BuildCombatText },
}
