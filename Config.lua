local _, ns = ...

-- The window's starting size, and the smallest it can be dragged to. It remembers its size.
local WIDTH, HEIGHT = 760, 580
local MIN_WIDTH, MIN_HEIGHT = 540, 360

-- Each tab's sections flow into as many columns as fit, up to three, each at least this wide.
local COLUMN_WIDTH = 280 -- a row's width until its page lays it out
local COLUMN_MIN_WIDTH = 220
local COLUMN_GAP = 24
local MAX_COLUMNS = 3
local SECTION_GAP = 14 -- between sections in a column
local SECTION_HEIGHT = 26
local PAGE_PADDING = 16

local INPUT_WIDTH = 44
local DROPDOWN_WIDTH = 190
local DROPDOWN_MIN_WIDTH = 100

-- The switch art's size, from generate_art.py. The knob's centre moves KNOB_TRAVEL either side of the middle.
local TOGGLE_WIDTH, TOGGLE_HEIGHT = 36, 20
local KNOB_QUAD, KNOB_TRAVEL = 24, 8
local TOGGLE_SLIDE_TIME = 0.12
local TOGGLE_ON = { 1.00, 0.76, 0.10 }
local TOGGLE_OFF = { 0.30, 0.30, 0.33 }

local function FormatScale(value)
	return string.format("%.2f", value)
end

local function FormatSize(value)
	return string.format("%d", value)
end

local function FormatPercent(value)
	return string.format("%d%%", value)
end

local function CreateLabel(parent, fontObject, text)
	local label = parent:CreateFontString(nil, "OVERLAY", fontObject)
	label:SetJustifyH("LEFT")
	label:SetText(text)
	return label
end

-- A gold heading with a divider under it, the way the game's settings group their options.
local function CreateSection(parent, text)
	local section = CreateFrame("Frame", nil, parent)
	section:SetSize(COLUMN_WIDTH, SECTION_HEIGHT)

	local label = CreateLabel(section, "GameFontNormal", text)
	label:SetPoint("TOPLEFT", 0, -2)

	local divider = section:CreateTexture(nil, "ARTWORK")
	divider:SetAtlas("Options_HorizontalDivider")
	divider:SetHeight(1)
	divider:SetPoint("BOTTOMLEFT", 0, 4)
	divider:SetPoint("BOTTOMRIGHT", 0, 4)
	return section
end

-- An iOS style switch: a pill that turns gold with its knob sliding right when on.
local function CreateToggle(parent, onChange)
	local toggle = CreateFrame("Button", nil, parent)
	toggle:SetSize(TOGGLE_WIDTH, TOGGLE_HEIGHT)
	toggle:SetMotionScriptsWhileDisabled(true)

	local track = ns.CreateArt(toggle, "BACKGROUND", "ToggleTrack")
	track:SetAllPoints()

	local glow = ns.CreateArt(toggle, "HIGHLIGHT", "ToggleTrack")
	glow:SetAllPoints()
	glow:SetBlendMode("ADD")
	glow:SetAlpha(0.15)

	local knob = ns.CreateArt(toggle, "ARTWORK", "ToggleKnob")
	knob:SetSize(KNOB_QUAD, KNOB_QUAD)

	-- 0 is off and 1 is on. In between while the knob slides.
	local position, from, to, elapsed = 0, 0, 0, 0

	local function Draw()
		knob:SetPoint("CENTER", toggle, "CENTER", (position * 2 - 1) * KNOB_TRAVEL, 0)
		track:SetVertexColor(
			TOGGLE_OFF[1] + (TOGGLE_ON[1] - TOGGLE_OFF[1]) * position,
			TOGGLE_OFF[2] + (TOGGLE_ON[2] - TOGGLE_OFF[2]) * position,
			TOGGLE_OFF[3] + (TOGGLE_ON[3] - TOGGLE_OFF[3]) * position)
	end

	local function Slide(self, delta)
		elapsed = elapsed + delta
		local progress = math.min(elapsed / TOGGLE_SLIDE_TIME, 1)
		position = from + (to - from) * (1 - (1 - progress) ^ 2)
		Draw()
		if progress >= 1 then
			self:SetScript("OnUpdate", nil)
		end
	end

	function toggle:SetChecked(checked, animate)
		self.checked = checked
		to = checked and 1 or 0
		if animate then
			from, elapsed = position, 0
			self:SetScript("OnUpdate", Slide)
		else
			self:SetScript("OnUpdate", nil)
			position = to
			Draw()
		end
	end

	function toggle:GetChecked()
		return self.checked
	end

	toggle:SetScript("OnClick", function(self)
		self:SetChecked(not self.checked, true)
		PlaySound(self.checked and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
		onChange(self.checked)
	end)
	toggle:SetScript("OnEnable", function(self) self:SetAlpha(1) end)
	toggle:SetScript("OnDisable", function(self) self:SetAlpha(0.4) end)

	toggle:SetChecked(false)
	return toggle
end

-- A label with a switch at the right. Clicking anywhere on the row flips the switch.
local function CreateToggleRow(parent, text, onChange)
	local row = CreateFrame("Button", nil, parent)
	row:SetSize(COLUMN_WIDTH, 30)

	local label = CreateLabel(row, "GameFontHighlight", text)
	label:SetPoint("LEFT")

	local toggle = CreateToggle(row, onChange)
	toggle:SetPoint("RIGHT")
	row.toggle = toggle
	row.label = label

	row:SetScript("OnClick", function()
		if toggle:IsEnabled() then
			toggle:Click()
		end
	end)

	function row:SetEnabled(enabled)
		toggle:SetEnabled(enabled)
		label:SetFontObject(enabled and "GameFontHighlight" or "GameFontDisable")
	end

	return row
end

-- A label, Blizzard's minimal slider with step arrows, and a box for typing an exact value.
local function CreateSliderRow(parent, text, range, format, getValue, setValue)
	local row = CreateFrame("Frame", nil, parent)
	row:SetSize(COLUMN_WIDTH, 48)

	local label = CreateLabel(row, "GameFontHighlight", text)
	label:SetPoint("TOPLEFT", 0, -4)
	row.label = label

	local input = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
	input:SetSize(INPUT_WIDTH, 20)
	input:SetPoint("BOTTOMRIGHT", 0, 2)
	input:SetAutoFocus(false)
	input:SetMaxLetters(5)
	input:SetJustifyH("CENTER")

	local slider = CreateFrame("Frame", nil, row, "MinimalSliderWithSteppersTemplate")
	slider:SetPoint("BOTTOMLEFT", 0, 2)
	slider:SetPoint("RIGHT", input, "LEFT", -12, 0)
	slider:SetHeight(20)
	slider:Init(getValue(), range.min, range.max, math.floor((range.max - range.min) / range.step + 0.5))

	-- The slider can only rest on its steps, while a typed value can be exact. So moving the
	-- slider from code mustn't feed its snapped value back in as a new setting.
	local isSyncing = false

	function row:Sync()
		isSyncing = true
		slider:SetValue(getValue())
		isSyncing = false
		input:SetText(format(getValue()))
		input:SetCursorPosition(0)
	end

	slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
		if not isSyncing then
			setValue(value)
			input:SetText(format(getValue()))
		end
	end, row)

	input:SetScript("OnEnterPressed", function(self)
		local value = tonumber((self:GetText():gsub("%%", "")))
		if value then
			setValue(value)
		end
		self:ClearFocus()
		row:Sync()
	end)
	input:SetScript("OnEditFocusLost", function(self)
		self:HighlightText(0, 0)
		row:Sync()
	end)
	input:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
	end)

	function row:SetEnabled(enabled)
		if not enabled then
			input:ClearFocus()
		end
		slider:SetEnabled(enabled)
		input:SetEnabled(enabled)
		label:SetFontObject(enabled and "GameFontHighlight" or "GameFontDisable")
	end

	return row
end

-- A label on the left and Blizzard's dropdown on the right. In a narrow section the dropdown gives up
-- width so it doesn't run into its label.
local function CreateDropdownRow(parent, text, rowWidth, dropdownWidth)
	local row = CreateFrame("Frame", nil, parent)
	row:SetSize(rowWidth or COLUMN_WIDTH, 34)

	local label = CreateLabel(row, "GameFontHighlight", text)
	label:SetPoint("LEFT")

	local dropdown = CreateFrame("DropdownButton", nil, row, "WowStyle1DropdownTemplate")
	dropdown:SetWidth(dropdownWidth or DROPDOWN_WIDTH)
	dropdown:SetPoint("RIGHT")
	row.dropdown = dropdown

	function row:FitWidth(width)
		local room = width - label:GetStringWidth() - 16
		dropdown:SetWidth(math.max(math.min(dropdownWidth or DROPDOWN_WIDTH, room), DROPDOWN_MIN_WIDTH))
	end
	return row
end

-- The newer grey and gold buttons from Blizzard's recent panels, in place of the old red ones.
local function CreateButton(parent, text, width)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(width, 24)
	button:SetNormalAtlas("common-button-tertiary-normal")
	button:SetPushedAtlas("common-button-tertiary-pressed")
	button:SetDisabledAtlas("common-button-tertiary-disabled")
	button:SetHighlightAtlas("common-button-tertiary-hover", "BLEND")
	button:SetNormalFontObject(GameFontNormal)
	button:SetHighlightFontObject(GameFontHighlight)
	button:SetDisabledFontObject(GameFontDisable)
	button:SetPushedTextOffset(0, -1)
	button:SetText(text)
	return button
end

-- Each font shows in its own typeface in the dropdown. Menus don't allow SetFont on their text,
-- so every font gets a font object instead.
local previewFonts = {}

local function GetPreviewFont(path)
	if not previewFonts[path] then
		local font = CreateFont("DibsUIFontPreview" .. (#previewFonts + 1))
		previewFonts[#previewFonts + 1] = font
		font:CopyFontObject(GameFontHighlight)
		local _, size = GameFontHighlight:GetFont()
		font:SetFont(path, size, "")
		previewFonts[path] = font
	end
	return previewFonts[path]
end

local function SameFont(a, b)
	return a:upper() == b:upper()
end

-- Layout ------------------------------------------------------------------------------------------

-- A section of a page: a heading and the rows under it, stacked. Hidden rows are left out and the rest
-- close up, so a section can change with what's picked. Rows take the section's width unless they
-- keep their own, like buttons.
local function CreateCard(parent, title)
	local card = CreateFrame("Frame", nil, parent)
	card:SetSize(COLUMN_WIDTH, SECTION_HEIGHT)
	local heading = CreateSection(card, title)
	heading:SetPoint("TOPLEFT")
	heading:SetPoint("TOPRIGHT")
	card.entries = {}

	-- gap is the space above the row.
	function card:Add(region, gap, keepWidth)
		self.entries[#self.entries + 1] = { region = region, gap = gap or 0, keepWidth = keepWidth }
		return region
	end
	return card
end

local function GetRegionHeight(region)
	if region.GetStringHeight then
		return region:GetStringHeight() or 0
	end
	return region:GetHeight() or 0
end

-- Stacks a section's shown rows at this width. Returns its height.
local function LayoutCard(card, width)
	card:SetWidth(width)
	local y = SECTION_HEIGHT + 2
	for _, entry in ipairs(card.entries) do
		local region = entry.region
		if region:IsShown() then
			y = y + entry.gap
			region:ClearAllPoints()
			region:SetPoint("TOPLEFT", card, "TOPLEFT", 0, -y)
			if not entry.keepWidth then
				region:SetWidth(width)
				if region.FitWidth then
					region:FitWidth(width)
				end
			end
			y = y + GetRegionHeight(region)
		end
	end
	card:SetHeight(y)
	return y
end

local function PlaceCard(card, parent, x, y, width)
	local height = LayoutCard(card, width)
	card:ClearAllPoints()
	card:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
	return height
end

-- Lays shown sections out in as many columns as fit the width, each going under the shortest column
-- so far, so the first ones fill the top row in order. Returns how far down the tallest column ends.
local function LayoutCards(cards, parent, x, y, width)
	local columns = math.floor((width + COLUMN_GAP) / (COLUMN_MIN_WIDTH + COLUMN_GAP))
	columns = math.max(1, math.min(MAX_COLUMNS, columns))
	local columnWidth = (width - (columns - 1) * COLUMN_GAP) / columns
	local depths = {}
	for i = 1, columns do
		depths[i] = 0
	end
	for _, card in ipairs(cards) do
		if card:IsShown() then
			local shortest = 1
			for i = 2, columns do
				if depths[i] < depths[shortest] then
					shortest = i
				end
			end
			local height = PlaceCard(card, parent, x + (shortest - 1) * (columnWidth + COLUMN_GAP), y + depths[shortest], columnWidth)
			depths[shortest] = depths[shortest] + height + SECTION_GAP
		end
	end
	local deepest = 0
	for i = 1, columns do
		deepest = math.max(deepest, depths[i] - SECTION_GAP)
	end
	return y + deepest
end

-- A tab's page: its content scrolls with the mouse wheel or the scroll bar at the right, and is laid
-- out again whenever the window changes size or a tab shows or hides some of its rows.
local function CreateScrollPage(parent)
	local page = CreateFrame("Frame", nil, parent)
	page:SetAllPoints()
	page:Hide()

	local scrollBar = CreateFrame("EventFrame", nil, page, "MinimalScrollBar")
	scrollBar:SetPoint("TOPRIGHT", -8, -8)
	scrollBar:SetPoint("BOTTOMRIGHT", -8, 8)

	local scroll = CreateFrame("ScrollFrame", nil, page)
	scroll:SetClipsChildren(true)
	scroll:SetPoint("TOPLEFT", 0, -2)
	scroll:SetPoint("BOTTOMRIGHT", scrollBar, "BOTTOMLEFT", -4, -6)

	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(1, 1)
	scroll:SetScrollChild(content)
	ScrollUtil.InitScrollFrameWithScrollBar(scroll, scrollBar)
	page.content = content

	function page:Relayout()
		local width = scroll:GetWidth()
		if not self.options or not width or width <= 2 * PAGE_PADDING then
			return
		end
		local height = self.options.Layout(width - 2 * PAGE_PADDING)
		content:SetSize(width, height + PAGE_PADDING)
	end

	scroll:SetScript("OnSizeChanged", function() page:Relayout() end)
	page:SetScript("OnShow", function() page:Relayout() end)
	return page
end


-- Frames, size, position and opacity. Size and position move secure frames, so they're locked in combat.
local function BuildGeneral(content)
	local framesCard = CreateCard(content, "Frames")
	local showToT = framesCard:Add(CreateToggleRow(framesCard, "Show target of target", ns.SetTargetOfTargetShown))
	local surnames = framesCard:Add(CreateToggleRow(framesCard, "Show last names", ns.SetSurnamesShown))

	local sizeCard = CreateCard(content, "Scale and width")
	local scale = sizeCard:Add(CreateSliderRow(sizeCard, "Scale", ns.ScaleRange, FormatScale,
		function() return ns.db.scale end, ns.SetScale))
	local width = sizeCard:Add(CreateSliderRow(sizeCard, "Width", ns.WidthRange, FormatScale,
		function() return ns.db.width end, ns.SetWidth))
	local petWidth = sizeCard:Add(CreateSliderRow(sizeCard, "Pet and target of target width", ns.WidthRange, FormatScale,
		function() return ns.db.petWidth end, ns.SetPetWidth))

	local positionCard = CreateCard(content, "Position")
	local center = positionCard:Add(CreateButton(positionCard, "Center horizontally", 150), 6, true)
	center:SetScript("OnClick", ns.CenterHorizontally)

	-- Up above Down, with Left and Right either side of Down.
	local pad = positionCard:Add(CreateFrame("Frame", nil, positionCard), 8, true)
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
	local modeHint = opacityCard:Add(CreateLabel(opacityCard, "GameFontDisableSmall", ""))
	modeHint:SetWordWrap(true)
	local manual = opacityCard:Add(CreateSliderRow(opacityCard, "Manual opacity", { min = 0, max = 100, step = 5 }, FormatPercent,
		function() return math.floor(ns.db.manualOpacity * 100 + 0.5) end,
		function(value) ns.SetManualOpacity(value / 100) end), 4)

	local function SyncOpacity()
		modeRow.dropdown:GenerateMenu()
		modeHint:SetText(ns.OpacityModesByKey[ns.db.opacityMode].description)
		manual:Sync()
		manual:SetEnabled(ns.db.opacityMode == "manual")
	end

	modeRow.dropdown:SetupMenu(function(_, root)
		for _, mode in ipairs(ns.OpacityModes) do
			root:CreateRadio(mode.label,
				function() return ns.db.opacityMode == mode.key end,
				function()
					ns.SetOpacityMode(mode.key)
					SyncOpacity()
				end, mode)
		end
	end)

	local options = {}

	function options.Sync()
		showToT.toggle:SetChecked(ns.db.showTargetOfTarget)
		surnames.toggle:SetChecked(ns.db.showSurnames)
		SyncOpacity()
		scale:Sync()
		width:Sync()
		petWidth:Sync()
	end

	function options.SetCombatLocked(locked)
		for _, control in ipairs({ showToT, scale, width, petWidth, center, up, down, leftButton, rightButton }) do
			control:SetEnabled(not locked)
		end
	end

	function options.Layout(pageWidth)
		return LayoutCards({ framesCard, sizeCard, positionCard, opacityCard }, content, PAGE_PADDING, PAGE_PADDING, pageWidth)
	end

	return options
end

-- The text picker is no wider than this, so its dropdown sits near its label.
local PICKER_WIDTH = 440

-- One text spot at a time, picked from a dropdown: whether it shows, what it shows, and how it looks.
-- None of it is protected, so it all works in combat.
local function BuildTextOptions(content)
	local selected = ns.TextGroups[1].fields[1]
	local refresh

	local pickCard = CreateCard(content, "Text")
	local fieldRow = pickCard:Add(CreateDropdownRow(pickCard, "Text to edit", nil, 260))
	local reset = pickCard:Add(CreateButton(pickCard, "Reset this text", 134), 6, true)
	reset:SetScript("OnClick", function()
		ns.ResetTextStyle(selected.key)
		refresh()
	end)

	local displayCard = CreateCard(content, "Display")
	local showRow = displayCard:Add(CreateToggleRow(displayCard, "Show", function(checked)
		ns.SetTextStyle(selected.key, "enabled", checked)
	end))
	local mouseoverRow = displayCard:Add(CreateToggleRow(displayCard, "Only on mouseover", function(checked)
		ns.SetTextStyle(selected.key, "mouseover", checked)
	end))
	local formatRow = displayCard:Add(CreateDropdownRow(displayCard, "Shows"))

	local fontCard = CreateCard(content, "Font and size")
	local fontRow = fontCard:Add(CreateDropdownRow(fontCard, "Font"))
	local size = fontCard:Add(CreateSliderRow(fontCard, "Size", ns.TextSizeRange, FormatSize,
		function() return ns.GetTextOption(selected.key, "size") end,
		function(value)
			value = math.min(math.max(math.floor(value + 0.5), ns.TextSizeRange.min), ns.TextSizeRange.max)
			ns.SetTextStyle(selected.key, "size", value)
		end))
	local fontToAll = fontCard:Add(CreateButton(fontCard, "Use font for all text", 150), 6, true)
	fontToAll:SetScript("OnClick", function()
		local font = ns.GetTextOption(selected.key, "font")
		for key in pairs(ns.TextFields) do
			ns.SetTextStyle(key, "font", font)
		end
		refresh()
	end)

	-- Moves the spot from where it normally sits, in UI units. Positive Y is up.
	local positionCard = CreateCard(content, "Position")
	local function CreateOffsetRow(text, part)
		return positionCard:Add(CreateSliderRow(positionCard, text, ns.TextOffsetRange, FormatSize,
			function() return ns.GetTextOption(selected.key, part) end,
			function(value)
				value = math.min(math.max(math.floor(value + 0.5), ns.TextOffsetRange.min), ns.TextOffsetRange.max)
				ns.SetTextStyle(selected.key, part, value)
			end))
	end
	local offsetX = CreateOffsetRow("X offset", "offsetX")
	local offsetY = CreateOffsetRow("Y offset", "offsetY")

	local colorCard = CreateCard(content, "Color")
	local colorRow = colorCard:Add(CreateToggleRow(colorCard, "Custom color", function(checked)
		if checked then
			ns.SetTextStyle(selected.key, "color", { ns.GetTextDefaultColor(selected.key) })
		else
			ns.SetTextStyle(selected.key, "color", nil)
		end
		refresh()
	end))

	-- The template passes clicks on to its parent, which would flip the switch as well.
	local swatch = CreateFrame("Button", nil, colorRow, "ColorSwatchTemplate")
	swatch:SetPropagateMouseClicks(false)
	swatch:SetSize(22, 22)
	swatch.SwatchBg:SetSize(20, 20)
	swatch.InnerBorder:SetSize(18, 18)
	swatch.Color:SetSize(16, 16)
	swatch:SetPoint("RIGHT", colorRow.toggle, "LEFT", -12, 0)

	local hint = colorCard:Add(CreateLabel(colorCard, "GameFontDisableSmall", ""))
	hint:SetWordWrap(true)

	local function OpenColorPicker()
		local key = selected.key
		local previous = ns.GetTextOption(key, "color")
		local r, g, b = ns.GetTextDefaultColor(key)
		if previous then
			r, g, b = previous[1], previous[2], previous[3]
		end
		ColorPickerFrame:SetupColorPickerAndShow({
			r = r, g = g, b = b,
			swatchFunc = function()
				ns.SetTextStyle(key, "color", { ColorPickerFrame:GetColorRGB() })
				refresh()
			end,
			cancelFunc = function()
				ns.SetTextStyle(key, "color", previous)
				refresh()
			end,
		})
	end
	swatch:SetScript("OnClick", OpenColorPicker)

	function refresh()
		local key = selected.key
		fieldRow.dropdown:GenerateMenu()
		showRow.toggle:SetChecked(ns.GetTextOption(key, "enabled"))
		mouseoverRow.toggle:SetChecked(ns.GetTextOption(key, "mouseover"))
		-- A spot without values always shows the same thing, which the dropdown names while switched off.
		formatRow.dropdown:SetDefaultText(selected.shows or "")
		formatRow.dropdown:GenerateMenu()
		formatRow.dropdown:SetEnabled(selected.values ~= nil)
		fontRow.dropdown:GenerateMenu()
		size:Sync()
		offsetX:Sync()
		offsetY:Sync()
		local color = ns.GetTextOption(key, "color")
		colorRow.toggle:SetChecked(color ~= nil)
		local r, g, b = ns.GetTextDefaultColor(key)
		if color then
			r, g, b = color[1], color[2], color[3]
		end
		swatch:SetColorRGB(r, g, b)
		swatch:SetAlpha(color and 1 or 0.5)
		hint:SetText("Default color: " .. selected.defaultColor)
	end

	fieldRow.dropdown:SetupMenu(function(_, root)
		root:SetScrollMode(480)
		for _, group in ipairs(ns.TextGroups) do
			root:CreateTitle(group.label)
			for _, field in ipairs(group.fields) do
				root:CreateRadio(field.label,
					function() return selected == field end,
					function()
						selected = field
						refresh()
					end, field)
			end
		end
	end)
	fieldRow.dropdown:SetSelectionTranslator(function(selection)
		return selection.data.group .. ": " .. selection.data.label
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
					ns.SetTextStyle(selected.key, "format", format.key)
					refresh()
				end, format)
		end
	end)
	formatRow.dropdown:SetSelectionTranslator(function(selection)
		return selection.data.label
	end)

	fontRow.dropdown:SetupMenu(function(_, root)
		root:SetScrollMode(360)
		for _, font in ipairs(ns.GetFonts()) do
			local radio = root:CreateRadio(font.name,
				function() return SameFont(ns.GetTextOption(selected.key, "font") or ns.Text.font, font.path) end,
				function()
					ns.SetTextStyle(selected.key, "font", not SameFont(font.path, ns.Text.font) and font.path or nil)
					refresh()
				end, font)
			radio:AddInitializer(function(button)
				button.fontString:SetFontObject(GetPreviewFont(font.path))
			end)
		end
	end)
	-- A saved font that can't be loaded any more shows as the default it falls back to.
	fontRow.dropdown:SetDefaultText("Friz Quadrata")

	-- The picker spans the top, and the rest flow under it.
	local function Layout(pageWidth)
		local top = PAGE_PADDING + PlaceCard(pickCard, content, PAGE_PADDING, PAGE_PADDING, math.min(pageWidth, PICKER_WIDTH))
		return LayoutCards({ displayCard, fontCard, positionCard, colorCard }, content, PAGE_PADDING, top + SECTION_GAP, pageWidth)
	end

	return { Sync = refresh, SetCombatLocked = function() end, Layout = Layout }
end

-- Sits above the tabs, since it applies to the whole addon rather than one tab.
local function CreateTopToggle(frame, text, onChange)
	local row = CreateToggleRow(frame, text, onChange)
	row:SetWidth(row.label:GetStringWidth() + 12 + TOGGLE_WIDTH)
	return row
end

-- A flat Blizzard panel with a title and close button.
local function CreatePanel(name, parent, width, height, title)
	local frame = CreateFrame("Frame", name, parent, "DefaultPanelFlatTemplate")
	frame:SetSize(width, height)
	frame:SetToplevel(true)
	frame:EnableMouse(true)
	frame:SetTitle(title)

	-- The flat background is built from atlas pieces, and the simulator is missing some of them. A plain
	-- fill underneath keeps the window from being see-through if a client lacks them too.
	local fill = frame.Bg:CreateTexture(nil, "BACKGROUND", nil, -8)
	fill:SetAllPoints()
	local color = PANEL_BACKGROUND_COLOR
	if color then
		fill:SetColorTexture(color.r, color.g, color.b, 1)
	else
		fill:SetColorTexture(0.07, 0.07, 0.08, 1)
	end

	CreateFrame("Button", nil, frame, "UIPanelCloseButtonDefaultAnchors")
	return frame
end

local DIALOG_WIDTH, DIALOG_HEIGHT = 340, 200

-- Asks for a name and which profile to start from. onCreated runs once the profile exists and is in use.
local function CreateNewProfileDialog(config, onCreated)
	local dialog = CreatePanel("DibsUINewProfile", config, DIALOG_WIDTH, DIALOG_HEIGHT, "New profile")
	dialog:SetPoint("CENTER", config)
	dialog:SetFrameStrata("DIALOG")
	dialog:Hide()
	tinsert(UISpecialFrames, dialog:GetName())

	local content = CreateFrame("Frame", nil, dialog)
	content:SetPoint("TOPLEFT", 20, -36)
	content:SetPoint("BOTTOMRIGHT", -20, 16)

	local nameLabel = CreateLabel(content, "GameFontHighlight", "Name")
	nameLabel:SetPoint("TOPLEFT", 0, -8)

	local nameBox = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
	nameBox:SetSize(DROPDOWN_WIDTH - 6, 22)
	nameBox:SetPoint("TOPRIGHT", -3, -3)
	nameBox:SetAutoFocus(false)
	nameBox:SetMaxLetters(32)

	local copyRow = CreateDropdownRow(content, "Copy from")
	copyRow:SetPoint("TOPLEFT", 0, -34)
	copyRow:SetWidth(DIALOG_WIDTH - 40)

	local problem = CreateLabel(content, "GameFontNormalSmall", "")
	problem:SetTextColor(1, 0.3, 0.3)
	problem:SetPoint("TOPLEFT", copyRow, "BOTTOMLEFT", 0, -6)
	problem:SetWidth(DIALOG_WIDTH - 40)

	local create = CreateButton(content, "Create", 110)
	create:SetPoint("BOTTOMRIGHT", content, "BOTTOM", -4, 0)

	local cancel = CreateButton(content, "Cancel", 110)
	cancel:SetPoint("BOTTOMLEFT", content, "BOTTOM", 4, 0)
	cancel:SetScript("OnClick", function() dialog:Hide() end)

	-- A profile name, or false to start from the default settings.
	local copyFrom

	copyRow.dropdown:SetupMenu(function(_, root)
		root:SetScrollMode(300)
		root:CreateRadio("Default settings", function() return copyFrom == false end, function() copyFrom = false end, false)
		for _, name in ipairs(ns.GetProfileNames()) do
			root:CreateRadio(name, function() return copyFrom == name end, function() copyFrom = name end, name)
		end
	end)

	create:SetScript("OnClick", function()
		local name, reason = ns.CreateProfile(nameBox:GetText(), copyFrom or nil)
		if name then
			dialog:Hide()
			onCreated()
		else
			problem:SetText(reason)
		end
	end)

	nameBox:SetScript("OnEnterPressed", function() create:Click() end)
	nameBox:SetScript("OnEscapePressed", function() dialog:Hide() end)
	nameBox:SetScript("OnTextChanged", function() problem:SetText("") end)

	dialog:SetScript("OnShow", function()
		copyFrom = ns.profileName
		copyRow.dropdown:GenerateMenu()
		nameBox:SetText("")
		problem:SetText("")
		nameBox:SetFocus()
	end)
	dialog:SetScript("OnHide", function()
		nameBox:ClearFocus()
	end)

	return dialog
end

StaticPopupDialogs.DIBSUI_DELETE_PROFILE = {
	text = "Delete the profile \"%s\"? Characters using it will go back to Default.",
	button1 = DELETE,
	button2 = CANCEL,
	OnAccept = function(_, data)
		if ns.DeleteProfile(data.name) then
			data.onDeleted()
		end
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	showAlert = true,
}

local PROFILE_ROW_HEIGHT = 28
local PROFILE_LIST_HEIGHT = 224
local PROFILE_SCROLL_BAR_ROOM = 18

-- The profile in use, and every profile on the account in a list. Clicking one uses it on this
-- character. Switching places the frames again, so all of this is locked in combat.
local function BuildProfiles(content, context)
	local isLocked = false

	local profilesCard = CreateCard(content, "Profiles")
	profilesCard:Add(CreateLabel(profilesCard, "GameFontHighlight", "Current profile"), 4)
	local current = profilesCard:Add(CreateLabel(profilesCard, "GameFontNormalLarge", ""), 6)

	-- The list keeps its own height and scroll bar, and stretches with the section.
	local listHolder = profilesCard:Add(CreateFrame("Frame", nil, profilesCard), 12)
	listHolder:SetHeight(PROFILE_LIST_HEIGHT)

	local listBack = listHolder:CreateTexture(nil, "BACKGROUND")
	listBack:SetColorTexture(0, 0, 0, 0.3)
	listBack:SetAllPoints()

	local list = CreateFrame("Frame", nil, listHolder, "WowScrollBoxList")
	list:SetPoint("TOPLEFT", 2, -2)
	list:SetPoint("BOTTOMRIGHT", -PROFILE_SCROLL_BAR_ROOM, 2)

	local scrollBar = CreateFrame("EventFrame", nil, listHolder, "MinimalScrollBar")
	scrollBar:SetPoint("TOPLEFT", list, "TOPRIGHT", 4, 0)
	scrollBar:SetPoint("BOTTOMLEFT", list, "BOTTOMRIGHT", 4, 0)

	local function Refresh()
		current:SetText(ns.profileName)
		list:SetDataProvider(CreateDataProvider(ns.GetProfileNames()))
	end

	local function OnProfileChanged()
		context.SyncAll()
	end

	local view = CreateScrollBoxListLinearView()
	view:SetElementExtent(PROFILE_ROW_HEIGHT)
	view:SetElementInitializer("Button", function(row, name)
		if not row.label then
			local highlight = row:CreateTexture(nil, "HIGHLIGHT")
			highlight:SetAllPoints()
			highlight:SetColorTexture(1, 1, 1, 0.08)

			row.inUse = row:CreateTexture(nil, "BACKGROUND")
			row.inUse:SetAllPoints()
			row.inUse:SetColorTexture(TOGGLE_ON[1], TOGGLE_ON[2], TOGGLE_ON[3], 0.15)

			row.label = CreateLabel(row, "GameFontHighlight", "")
			row.label:SetPoint("LEFT", 10, 0)
			row.label:SetPoint("RIGHT", -64, 0)

			row.tag = CreateLabel(row, "GameFontNormalSmall", "In use")
			row.tag:SetPoint("RIGHT", -10, 0)

			row.delete = CreateFrame("Button", nil, row)
			row.delete:SetSize(18, 18)
			row.delete:SetPoint("RIGHT", -8, 0)
			row.delete:SetNormalAtlas("common-icon-redx")
			row.delete:SetHighlightAtlas("common-icon-redx", "ADD")
		end

		local inUse = name == ns.profileName
		row.label:SetText(name)
		row.inUse:SetShown(inUse)
		row.tag:SetShown(inUse)
		row.delete:SetShown(ns.CanDeleteProfile(name))

		row:SetScript("OnClick", function()
			if not isLocked and ns.UseProfile(name) then
				PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
				OnProfileChanged()
			end
		end)
		row.delete:SetScript("OnClick", function()
			if not isLocked then
				StaticPopup_Show("DIBSUI_DELETE_PROFILE", name, nil, { name = name, onDeleted = Refresh })
			end
		end)
	end)
	ScrollUtil.InitScrollBoxListWithScrollBar(list, scrollBar, view)
	ScrollUtil.AddManagedScrollBarVisibilityBehavior(list, scrollBar)

	local manageCard = CreateCard(content, "Manage")
	local dialog = CreateNewProfileDialog(context.window, OnProfileChanged)

	local newProfile = manageCard:Add(CreateButton(manageCard, "New profile", 150), 8, true)
	newProfile:SetScript("OnClick", function() dialog:Show() end)

	local help = manageCard:Add(CreateLabel(manageCard, "GameFontHighlightSmall",
		"Profiles are shared by every character on your account, and each character remembers which one it uses.\n\n"
		.. "Click a profile to use it on this character.\n\n"
		.. "The minimap button's settings are the same in every profile."), 14)
	help:SetWordWrap(true)

	return {
		Sync = Refresh,
		SetCombatLocked = function(locked)
			isLocked = locked
			newProfile:SetEnabled(not locked)
			list:SetAlpha(locked and 0.5 or 1)
			if locked then
				dialog:Hide()
			end
		end,
		Layout = function(pageWidth)
			return LayoutCards({ profilesCard, manageCard }, content, PAGE_PADDING, PAGE_PADDING, pageWidth)
		end,
	}
end

local SIDEBAR_WIDTH = 170
local AURA_DROPDOWN_WIDTH = 130
local AURA_GROUP_HEIGHT = 30

-- The groups down the left, each with its own switch, and the picked group's settings beside them.
-- None of it is protected, so it all works in combat.
local function BuildAuras(content, context, relayout)
	local selected = ns.AuraGroups[1]
	local refresh
	local syncs = {}

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

		local label = CreateLabel(row, group.built and "GameFontHighlight" or "GameFontDisable", group.label)
		label:SetPoint("LEFT", 8, 0)

		if group.built then
			row.toggle = CreateToggle(row, function(checked)
				ns.SetAuraOption(group.key, "enabled", checked)
			end)
			row.toggle:SetPoint("RIGHT", -4, 0)
		else
			local soon = CreateLabel(row, "GameFontDisableSmall", "Soon")
			soon:SetPoint("RIGHT", -8, 0)
		end

		row:SetScript("OnClick", function()
			selected = group
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
			refresh()
		end)
		groupRows[i] = { row = row, group = group }
	end

	local testCard = CreateCard(content, "Test mode")
	local testRow = testCard:Add(CreateToggleRow(testCard, "Show test buffs", ns.SetAuraTestMode), 2)
	local testHint = testCard:Add(CreateLabel(testCard, "GameFontDisableSmall",
		"Fills every group with sample buffs, so you can see the layout as you change it. Target debuffs show while you have a target, and target buffs show either way. Turns off when you reload."), 2)
	testHint:SetWordWrap(true)
	if ns.hasMasque then
		local masqueHint = testCard:Add(CreateLabel(testCard, "GameFontDisableSmall",
			"Masque is installed: pick a skin for these icons in Masque's settings (/masque)."), 10)
		masqueHint:SetWordWrap(true)
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
		row.dropdown:SetupMenu(function(_, root)
			for _, item in ipairs(list) do
				root:CreateRadio(item.label,
					function() return access.get() == item.key end,
					function()
						access.set(item.key)
						refresh()
					end, item)
			end
		end)
		return row
	end

	-- Each font shows in its own typeface. nil is the default font.
	local function FontChoice(card, access)
		local row = Dropdown(card, "Font")
		row.dropdown:SetupMenu(function(_, root)
			root:SetScrollMode(360)
			for _, font in ipairs(ns.GetFonts()) do
				local radio = root:CreateRadio(font.name,
					function() return SameFont(access.get() or ns.Text.font, font.path) end,
					function()
						access.set(not SameFont(font.path, ns.Text.font) and font.path or nil)
						refresh()
					end, font)
				radio:AddInitializer(function(button)
					button.fontString:SetFontObject(GetPreviewFont(font.path))
				end)
			end
		end)
		row.dropdown:SetDefaultText("Friz Quadrata")
		return row
	end

	local function ColorChoice(card, access)
		local row = card:Add(CreateFrame("Frame", nil, card))
		row:SetSize(COLUMN_WIDTH, 30)
		local label = CreateLabel(row, "GameFontHighlight", "Color")
		label:SetPoint("LEFT")
		local swatch = CreateFrame("Button", nil, row, "ColorSwatchTemplate")
		swatch:SetSize(22, 22)
		swatch.SwatchBg:SetSize(20, 20)
		swatch.InnerBorder:SetSize(18, 18)
		swatch.Color:SetSize(16, 16)
		swatch:SetPoint("RIGHT", -2, 0)
		swatch:SetScript("OnClick", function()
			local previous = access.get()
			ColorPickerFrame:SetupColorPickerAndShow({
				r = previous[1], g = previous[2], b = previous[3],
				swatchFunc = function()
					access.set({ ColorPickerFrame:GetColorRGB() })
					refresh()
				end,
				cancelFunc = function()
					access.set(previous)
					refresh()
				end,
			})
		end)
		AddSync(row, function() swatch:SetColorRGB(unpack(access.get())) end)
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

	-- Groups that aren't built yet say so instead.
	local soonCard = CreateCard(content, "Coming soon")
	local soonNote = soonCard:Add(CreateLabel(soonCard, "GameFontDisable", ""), 6)

	-- Mode, for the groups that have a list mode
	local modeCard = CreateCard(content, "Layout")
	Choices(modeCard, "Mode", ns.AuraModes, Field("mode"))
	local modeHint = modeCard:Add(CreateLabel(modeCard, "GameFontDisableSmall", ""))
	modeHint:SetWordWrap(true)

	-- Standard mode
	local iconCard = CreateCard(content, "Icons")
	Slider(iconCard, "Icon size", ns.AuraIconSizeRange, Field("iconSize"))
	Slider(iconCard, "Spacing", ns.AuraSpacingRange, Field("spacing"))
	-- Groups that set the player's own auras apart give them their own size.
	local ownSize = Slider(iconCard, "Your debuffs icon size", ns.AuraIconSizeRange, Field("ownIconSize"))
	local growthRow = Choices(iconCard, "Growth", ns.AuraGrowths, Field("growth"))
	local frameSize = Slider(iconCard, "Frame width", ns.AuraFrameSizeRange, Field("frameSize"))

	local textCard = CreateCard(content, "Time text")
	TextChoices(textCard, Field, { font = "font", size = "textSize", color = "textColor", x = "textX", y = "textY" })

	-- List mode
	local listIconCard = CreateCard(content, "Icons")
	Toggle(listIconCard, "Icon on the right", {
		get = function() return GetList("iconSide") == "RIGHT" end,
		set = function(checked) SetList("iconSide", checked and "RIGHT" or "LEFT") end,
	})
	-- A list growing up starts at the bottom, so it can rise from beside a bar.
	Toggle(listIconCard, "Grow up", ListField("growUp"))
	Slider(listIconCard, "Icon size", ns.AuraIconSizeRange, ListField("iconSize"))
	Slider(listIconCard, "Spacing", ns.AuraSpacingRange, ListField("spacing"))

	local nameCard = CreateCard(content, "Name")
	TextChoices(nameCard, ListField, { font = "nameFont", size = "nameSize", color = "nameColor", x = "nameX", y = "nameY" })

	local timeCard = CreateCard(content, "Time")
	TextChoices(timeCard, ListField, { font = "timeFont", size = "timeSize", color = "timeColor", x = "timeX", y = "timeY" })

	-- Position, of the mode in use. Anchored groups have none, and say where they sit instead.
	local positionCard = CreateCard(content, "Position")
	Choices(positionCard, "Frame point", ns.AuraPoints, PositionField("point"))
	Choices(positionCard, "Attach to", ns.AuraAnchorTargets, PositionField("anchorTo"))
	Choices(positionCard, "Attach point", ns.AuraPoints, PositionField("anchorPoint"))
	Slider(positionCard, "X offset", ns.AuraOffsetRange, PositionField("x"))
	Slider(positionCard, "Y offset", ns.AuraOffsetRange, PositionField("y"))
	local positionHint = positionCard:Add(CreateLabel(positionCard, "GameFontDisableSmall",
		"Sizes and offsets follow your UI scale. You can also drag the frame while frames are unlocked."), 4)
	positionHint:SetWordWrap(true)

	local anchoredCard = CreateCard(content, "Position")
	local anchoredNote = anchoredCard:Add(CreateLabel(anchoredCard, "GameFontHighlightSmall", ""), 4)
	anchoredNote:SetWordWrap(true)

	local settingsCards = { soonCard, modeCard, iconCard, listIconCard, textCard, nameCard, timeCard, positionCard, anchoredCard }

	function refresh()
		for _, entry in ipairs(groupRows) do
			entry.row.selected:SetShown(entry.group == selected)
			if entry.row.toggle then
				entry.row.toggle:SetChecked(ns.GetAuraSettings(entry.group.key).enabled)
			end
		end
		testRow.toggle:SetChecked(ns.auraTestMode)

		local built = selected.built == true
		local hasListMode = built and selected.hasListMode == true
		local isAnchored = selected.anchored == true
		local isList = built and IsList()
		soonCard:SetShown(not built)
		soonNote:SetText(selected.label .. " are coming soon.")
		modeCard:SetShown(hasListMode)
		if hasListMode then
			modeHint:SetText(ns.AuraModesByKey[Get("mode")].description)
		end
		iconCard:SetShown(built and not isList)
		textCard:SetShown(built and not isList)
		listIconCard:SetShown(isList)
		nameCard:SetShown(isList)
		timeCard:SetShown(isList)
		positionCard:SetShown(built and not isAnchored)
		anchoredCard:SetShown(built and isAnchored)
		anchoredNote:SetText(selected.anchorNote or "")

		-- Anchored groups take their growth and width from the frame they sit on.
		growthRow:SetShown(not isAnchored)
		frameSize:SetShown(not isAnchored)
		ownSize:SetShown(selected.hasOwnSize == true)
		if built and not isAnchored then
			-- Growth that fills up or down first wraps at the frame's height instead.
			local growth = ns.AuraGrowthsByKey[Get("growth")]
			local isVertical = growth.line == "UP" or growth.line == "DOWN"
			frameSize.label:SetText(isVertical and "Frame height" or "Frame width")
		end
		if built then
			for _, entry in ipairs(syncs) do
				if IsShowing(entry.row) then
					entry.sync()
				end
			end
		end
		relayout()
	end

	-- Dragging the frame while unlocked changes its offsets, which the sliders follow.
	function ns.OnAuraSettingsMoved(groupKey)
		if groupKey == selected.key and content:IsVisible() then
			refresh()
		end
	end

	-- The sidebar keeps its width at the left, and the picked group's sections flow beside it.
	local function Layout(pageWidth)
		local sidebarBottom = PAGE_PADDING + PlaceCard(groupsCard, content, PAGE_PADDING, PAGE_PADDING, SIDEBAR_WIDTH)
		sidebarBottom = sidebarBottom + SECTION_GAP + PlaceCard(testCard, content, PAGE_PADDING, sidebarBottom + SECTION_GAP, SIDEBAR_WIDTH)
		local settingsX = PAGE_PADDING + SIDEBAR_WIDTH + COLUMN_GAP
		local settingsBottom = LayoutCards(settingsCards, content, settingsX, PAGE_PADDING, pageWidth - SIDEBAR_WIDTH - COLUMN_GAP)
		return math.max(sidebarBottom, settingsBottom)
	end

	return { Sync = refresh, SetCombatLocked = function() end, Layout = Layout }
end

local TABS = {
	{ label = "General", build = BuildGeneral },
	{ label = "Text", build = BuildTextOptions },
	{ label = "Buffs/Debuffs", build = BuildAuras },
	{ label = "Profiles", build = BuildProfiles },
}

-- The saved size, kept between the smallest the window can be and the screen.
local function GetWindowSize()
	local maxWidth = math.max(MIN_WIDTH, UIParent:GetWidth() or MIN_WIDTH)
	local maxHeight = math.max(MIN_HEIGHT, UIParent:GetHeight() or MIN_HEIGHT)
	local width = tonumber(ns.account.configWidth) or WIDTH
	local height = tonumber(ns.account.configHeight) or HEIGHT
	return math.min(math.max(width, MIN_WIDTH), maxWidth), math.min(math.max(height, MIN_HEIGHT), maxHeight), maxWidth, maxHeight
end

-- Where the settings start below the title: under the tabs, which share a row with the switches at
-- the top when the window is wide enough, and drop below them when it isn't.
local INSET_TOP, INSET_TOP_STACKED = -60, -88

-- Drag the bottom right corner to resize the window. Every tab lays itself out again to fit.
local function CreateResizeGrip(frame)
	local grip = CreateFrame("Button", nil, frame)
	grip:SetSize(16, 16)
	grip:SetPoint("BOTTOMRIGHT", -4, 4)
	grip:SetFrameLevel(frame:GetFrameLevel() + 20)
	grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
	grip:SetScript("OnMouseDown", function(_, button)
		if button == "LeftButton" then
			frame:StartSizing("BOTTOMRIGHT")
		end
	end)
	grip:SetScript("OnMouseUp", function()
		frame:StopMovingOrSizing()
		ns.account.configWidth = math.floor(frame:GetWidth() + 0.5)
		ns.account.configHeight = math.floor(frame:GetHeight() + 0.5)
	end)
	return grip
end

local function CreateConfig()
	local width, height, maxWidth, maxHeight = GetWindowSize()
	local frame = CreatePanel("DibsUIConfig", UIParent, width, height, "DibsUI")
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("HIGH")
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:SetResizable(true)
	if frame.SetResizeBounds then
		frame:SetResizeBounds(MIN_WIDTH, MIN_HEIGHT, maxWidth, maxHeight)
	else
		frame:SetMinResize(MIN_WIDTH, MIN_HEIGHT)
		frame:SetMaxResize(maxWidth, maxHeight)
	end
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetDontSavePosition(true)
	tinsert(UISpecialFrames, frame:GetName())
	CreateResizeGrip(frame)

	local minimapToggle = CreateTopToggle(frame, "Show minimap button", ns.SetMinimapButtonShown)
	minimapToggle:SetPoint("TOPRIGHT", -14, -26)

	-- Unlocking moves every frame, so it's here where every tab can reach it.
	local unlockToggle = CreateTopToggle(frame, "Unlock frames", function(checked)
		ns.SetLocked(not checked)
	end)
	unlockToggle:SetPoint("RIGHT", minimapToggle, "LEFT", -28, 0)
	-- /dibsui lock can change it while the window is open. A click on the switch is already showing,
	-- sliding across.
	hooksecurefunc(ns, "SetLocked", function()
		if unlockToggle.toggle:GetChecked() ~= not ns.db.locked then
			unlockToggle.toggle:SetChecked(not ns.db.locked)
		end
	end)

	local inset = CreateFrame("Frame", nil, frame, "InsetFrameTemplate")
	inset:SetPoint("TOPLEFT", 10, INSET_TOP)
	inset:SetPoint("BOTTOMRIGHT", -8, 30)

	local pages = {}

	-- After a profile switch every tab shows the new profile's settings.
	local context = { window = frame }
	function context.SyncAll()
		unlockToggle.toggle:SetChecked(not ns.db.locked)
		for _, page in ipairs(pages) do
			page.options.Sync()
		end
	end

	for i, info in ipairs(TABS) do
		local tab = CreateFrame("Button", nil, frame, "PanelTopTabButtonTemplate")
		tab:SetID(i)
		tab:SetText(info.label)
		if i == 1 then
			tab:SetPoint("BOTTOMLEFT", inset, "TOPLEFT", 8, -2)
		else
			tab:SetPoint("LEFT", frame.Tabs[i - 1], "RIGHT", 4, 0)
		end
		tab:SetScript("OnClick", function(self)
			PanelTemplates_SetTab(frame, self:GetID())
			for index, page in ipairs(pages) do
				page:SetShown(index == self:GetID())
			end
			PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
		end)

		local page = CreateScrollPage(inset)
		page.options = info.build(page.content, context, function() page:Relayout() end)
		pages[i] = page
	end
	PanelTemplates_SetNumTabs(frame, #TABS)
	PanelTemplates_SetTab(frame, 1)
	pages[1]:Show()

	local function FitHeader()
		local tabsWidth = 18
		for _, tab in ipairs(frame.Tabs) do
			tabsWidth = tabsWidth + (tab:GetWidth() or 0) + 4
		end
		local togglesWidth = (unlockToggle:GetWidth() or 0) + 28 + (minimapToggle:GetWidth() or 0) + 14
		local stacked = (frame:GetWidth() or 0) < tabsWidth + togglesWidth + 16
		inset:SetPoint("TOPLEFT", 10, stacked and INSET_TOP_STACKED or INSET_TOP)
	end
	frame:HookScript("OnSizeChanged", FitHeader)

	local combatNote = CreateLabel(frame, "GameFontDisableSmall", "Frame size, position and profiles can't be changed during combat")
	combatNote:SetPoint("BOTTOM", 0, 11)

	local function SetCombatLocked(locked)
		unlockToggle:SetEnabled(not locked)
		for _, page in ipairs(pages) do
			page.options.SetCombatLocked(locked)
		end
		combatNote:SetShown(locked)
	end

	frame:RegisterEvent("PLAYER_REGEN_DISABLED")
	frame:RegisterEvent("PLAYER_REGEN_ENABLED")
	frame:SetScript("OnEvent", function(_, event)
		SetCombatLocked(event == "PLAYER_REGEN_DISABLED")
	end)

	frame:SetScript("OnShow", function()
		FitHeader()
		minimapToggle.toggle:SetChecked(ns.account.showMinimapButton)
		context.SyncAll()
		SetCombatLocked(InCombatLockdown())
		for _, page in ipairs(pages) do
			page:Relayout()
		end
	end)

	return frame
end

local config

function ns.ToggleConfig()
	if not config then
		config = CreateConfig()
		config:Hide()
	end
	config:SetShown(not config:IsShown())
end

-- Locks or unlocks the frames, like the switch at the top of the window, and says which. Like the
-- switch, it waits for combat to end.
function ns.ToggleLocked()
	if InCombatLockdown() then
		print("|cffffd100DibsUI|r: frames can't be locked or unlocked during combat.")
		return
	end
	ns.SetLocked(not ns.db.locked)
	if ns.db.locked then
		print("|cffffd100DibsUI|r: frames locked.")
	else
		print("|cffffd100DibsUI|r: frames unlocked. Type /dibsui lock again to lock them.")
	end
end

-- /dibsui opens or closes the settings, and /dibsui lock locks or unlocks the frames.
SLASH_DIBSUI1 = "/dibsui"
SLASH_DIBSUI2 = "/dui"
SlashCmdList.DIBSUI = function(message)
	local command = (message or ""):match("^%s*(.-)%s*$"):lower()
	if command == "lock" then
		ns.ToggleLocked()
	else
		ns.ToggleConfig()
	end
end
