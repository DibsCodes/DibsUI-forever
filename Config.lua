local _, ns = ...

-- The window's starting size, and the smallest it can be dragged to. It remembers its size.
local WIDTH, HEIGHT = 900, 640
local MIN_WIDTH, MIN_HEIGHT = 720, 420

-- The tabs down the left.
local NAV_WIDTH = 186
local NAV_ROW_HEIGHT = 30

-- Each page's sections flow into as many columns as fit, up to three, each at least this wide.
local COLUMN_WIDTH = 280 -- a row's width until its page lays it out
local COLUMN_MIN_WIDTH = 220
local COLUMN_GAP = 24
local MAX_COLUMNS = 3
local SECTION_GAP = 14 -- between sections in a column
local SECTION_HEIGHT = 26
local PAGE_PADDING = 16
local HEADER_HEIGHT = 30 -- a page heading over a group of sections
local HEADER_GAP = 22 -- above a page heading that follows sections

local INPUT_WIDTH = 44
local DROPDOWN_WIDTH = 190
local DROPDOWN_MIN_WIDTH = 100

-- The switch art's size, from generate_art.py. The knob's centre moves KNOB_TRAVEL either side of the middle.
local TOGGLE_WIDTH, TOGGLE_HEIGHT = 36, 20
local KNOB_QUAD, KNOB_TRAVEL = 24, 8
local TOGGLE_SLIDE_TIME = 0.12
local TOGGLE_ON = { 1.00, 0.76, 0.10 }
local TOGGLE_OFF = { 0.30, 0.30, 0.33 }

local LINK_SIZE = 20
local LINKED_COLOR = TOGGLE_ON
local UNLINKED_COLOR = { 0.55, 0.55, 0.58 }

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

local function CreateHint(parent, text)
	local hint = CreateLabel(parent, "GameFontDisableSmall", text)
	hint:SetWordWrap(true)
	return hint
end

local function ShowTooltip(owner, title, text)
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	GameTooltip:SetText(title)
	if text then
		GameTooltip:AddLine(text, 1, 1, 1, true)
	end
	GameTooltip:Show()
end

local function HideTooltip()
	GameTooltip:Hide()
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

-- A switch for something that isn't built yet: greyed out and off, with a tag saying so. Each one keeps
-- the name of the feature it's holding a place for, which is also in the implementation notes.
local function CreatePlaceholderRow(parent, text, feature)
	local row = CreateToggleRow(parent, text, function() end)
	row.feature = feature
	row:SetEnabled(false)
	row.toggle:SetChecked(false)
	local tag = CreateLabel(row, "GameFontDisableSmall", "Coming soon")
	tag:SetPoint("RIGHT", row.toggle, "LEFT", -8, 0)
	row:SetScript("OnEnter", function(self)
		ShowTooltip(self, text, "Not built yet. This switch will work in a later version.")
	end)
	row:SetScript("OnLeave", HideTooltip)
	-- Combat locking leaves these alone.
	row.SetEnabled = function() end
	return row
end

-- A chain that shows whether two frames share one width. Gold and joined while linked, grey and pulled
-- apart while not. Clicking it links or unlinks them.
local function CreateLinkButton(parent, pair, names)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(LINK_SIZE, LINK_SIZE)
	button:SetMotionScriptsWhileDisabled(true)
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints()
	local glow = button:CreateTexture(nil, "HIGHLIGHT")
	glow:SetAllPoints()
	glow:SetBlendMode("ADD")
	glow:SetAlpha(0.35)

	function button:Sync()
		local linked = ns.IsWidthLinked(pair)
		local art = ns.Media(linked and "LinkOn" or "LinkOff")
		local color = linked and LINKED_COLOR or UNLINKED_COLOR
		icon:SetTexture(art)
		glow:SetTexture(art)
		icon:SetVertexColor(color[1], color[2], color[3])
	end

	button:SetScript("OnClick", function(self)
		ns.SetWidthLinked(pair, not ns.IsWidthLinked(pair))
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		if parent.OnLinkChanged then
			parent:OnLinkChanged()
		end
		self:GetScript("OnEnter")(self)
	end)
	button:SetScript("OnEnter", function(self)
		if ns.IsWidthLinked(pair) then
			ShowTooltip(self, "Widths linked", string.format(
				"The %s and %s share one width. Changing either one on its own tab unlinks them. Click to unlink.",
				names[1], names[2]))
		else
			ShowTooltip(self, "Widths unlinked", string.format(
				"The %s and %s each have their own width. Click to link them again: the %s takes the %s's width.",
				names[1], names[2], names[2], names[1]))
		end
	end)
	button:SetScript("OnLeave", HideTooltip)
	button:SetScript("OnEnable", function(self) self:SetAlpha(1) end)
	button:SetScript("OnDisable", function(self) self:SetAlpha(0.4) end)
	return button
end

-- A label, Blizzard's minimal slider with step arrows, and a box for typing an exact value. With a link,
-- a chain button sits at the top right, beside the label.
local function CreateSliderRow(parent, text, range, format, getValue, setValue, link)
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

	if link then
		row.link = CreateLinkButton(row, link.pair, link.names)
		row.link:SetPoint("TOPRIGHT", 0, 0)
	end

	-- The slider can only rest on its steps, while a typed value can be exact. So moving the
	-- slider from code mustn't feed its snapped value back in as a new setting.
	local isSyncing = false

	function row:Sync()
		isSyncing = true
		slider:SetValue(getValue())
		isSyncing = false
		input:SetText(format(getValue()))
		input:SetCursorPosition(0)
		if row.link then
			row.link:Sync()
		end
	end

	-- Changing a frame's own width can unlink it, which its chain shows straight away.
	local function Changed(value)
		setValue(value)
		if row.link then
			row.link:Sync()
		end
	end

	slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
		if not isSyncing then
			Changed(value)
			input:SetText(format(getValue()))
		end
	end, row)

	input:SetScript("OnEnterPressed", function(self)
		local value = tonumber((self:GetText():gsub("%%", "")))
		if value then
			Changed(value)
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

	-- The value and the link can be locked separately: a General width is greyed while unlinked, but its
	-- link still works.
	function row:SetEnabled(enabled, linkEnabled)
		if not enabled then
			input:ClearFocus()
		end
		slider:SetEnabled(enabled)
		input:SetEnabled(enabled)
		label:SetFontObject(enabled and "GameFontHighlight" or "GameFontDisable")
		if self.link then
			if linkEnabled == nil then
				linkEnabled = enabled
			end
			self.link:SetEnabled(linkEnabled)
		end
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
	row.label = label

	local dropdown = CreateFrame("DropdownButton", nil, row, "WowStyle1DropdownTemplate")
	dropdown:SetWidth(dropdownWidth or DROPDOWN_WIDTH)
	dropdown:SetPoint("RIGHT")
	row.dropdown = dropdown

	function row:FitWidth(width)
		local room = width - label:GetStringWidth() - 16
		dropdown:SetWidth(math.max(math.min(dropdownWidth or DROPDOWN_WIDTH, room), DROPDOWN_MIN_WIDTH))
	end

	function row:SetEnabled(enabled)
		dropdown:SetEnabled(enabled)
		label:SetFontObject(enabled and "GameFontHighlight" or "GameFontDisable")
	end
	return row
end

-- The newer grey and gold buttons from Blizzard's recent panels, in place of the old red ones.
-- The hover art replaces the normal art rather than being a highlight texture: highlight textures draw in
-- the HIGHLIGHT layer, above the button's text, and this art is opaque, so the text vanished on hover.
local BUTTON_ART = {
	normal = "common-button-tertiary-normal",
	hover = "common-button-tertiary-hover",
}

local function CreateButton(parent, text, width)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(width, 24)
	button:SetNormalAtlas(BUTTON_ART.normal)
	button:SetPushedAtlas("common-button-tertiary-pressed")
	button:SetDisabledAtlas("common-button-tertiary-disabled")
	button:SetNormalFontObject(GameFontNormal)
	button:SetHighlightFontObject(GameFontHighlight)
	button:SetDisabledFontObject(GameFontDisable)
	button:SetPushedTextOffset(0, -1)
	button:SetText(text)
	button:HookScript("OnEnter", function(self)
		if self:IsEnabled() then
			self:GetNormalTexture():SetAtlas(BUTTON_ART.hover)
		end
	end)
	button:HookScript("OnLeave", function(self)
		self:GetNormalTexture():SetAtlas(BUTTON_ART.normal)
	end)
	button:HookScript("OnDisable", function(self)
		self:GetNormalTexture():SetAtlas(BUTTON_ART.normal)
	end)
	return button
end

-- A color swatch the size of the game's own, shown faded while the color is the default.
local function CreateSwatch(parent)
	local swatch = CreateFrame("Button", nil, parent, "ColorSwatchTemplate")
	-- The template passes clicks on to its parent, which would flip a switch on the row as well.
	swatch:SetPropagateMouseClicks(false)
	swatch:SetSize(22, 22)
	swatch.SwatchBg:SetSize(20, 20)
	swatch.InnerBorder:SetSize(18, 18)
	swatch.Color:SetSize(16, 16)

	function swatch:SetSwatchColor(r, g, b, isDefault)
		self:SetColorRGB(r, g, b)
		self:SetAlpha(isDefault and 0.5 or 1)
	end
	return swatch
end

-- Opens the game's color picker on a color. onPick gets each color as it's dragged, and the starting one
-- again if the picker is cancelled.
local function PickColor(r, g, b, onPick, onCancel)
	ColorPickerFrame:SetupColorPickerAndShow({
		r = r, g = g, b = b,
		swatchFunc = function()
			onPick({ ColorPickerFrame:GetColorRGB() })
		end,
		cancelFunc = onCancel,
	})
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
	return a ~= nil and b ~= nil and a:upper() == b:upper()
end

-- Fills a dropdown with every font, each in its own typeface. With nilLabel, the first choice is "no font
-- of its own" (such as following the master font), which get returns as nil. A saved font that can't be
-- loaded any more shows as that first choice, which is what it falls back to.
local function SetUpFontMenu(dropdown, get, set, nilLabel)
	dropdown:SetupMenu(function(_, root)
		root:SetScrollMode(360)
		if nilLabel then
			root:CreateRadio(nilLabel, function() return get() == nil end, function() set(nil) end, false)
		end
		for _, font in ipairs(ns.GetFonts()) do
			local radio = root:CreateRadio(font.name,
				function() return SameFont(get(), font.path) end,
				function() set(font.path) end, font)
			radio:AddInitializer(function(button)
				button.fontString:SetFontObject(GetPreviewFont(font.path))
			end)
		end
	end)
	dropdown:SetSelectionTranslator(function(selection)
		return selection.data and selection.data.name or nilLabel
	end)
	-- Only fonts that load are listed, so nothing is picked when the saved one can't load: it shows what
	-- the text falls back to instead. The master font falls back to the game's.
	dropdown:SetDefaultText(nilLabel or "Friz Quadrata")
end

-- A dropdown of { key, label } choices. onPicked runs after the setting changes.
local function SetUpChoiceMenu(dropdown, list, get, set)
	dropdown:SetupMenu(function(_, root)
		for _, item in ipairs(list) do
			root:CreateRadio(item.label, function() return get() == item.key end, function() set(item.key) end, item)
		end
	end)
	dropdown:SetSelectionTranslator(function(selection)
		return selection.data.label
	end)
end

-- Layout ------------------------------------------------------------------------------------------

-- A section of a page: a heading and the rows under it, stacked. Hidden rows are left out and the rest
-- close up, so a section can change with what's picked. Rows take the section's width unless they
-- keep their own, like buttons.
-- Without a title the rows start at the top, for a section right under a page heading.
local function CreateCard(parent, title)
	local card = CreateFrame("Frame", nil, parent)
	card:SetSize(COLUMN_WIDTH, SECTION_HEIGHT)
	card.top = 0
	if title then
		local heading = CreateSection(card, title)
		heading:SetPoint("TOPLEFT")
		heading:SetPoint("TOPRIGHT")
		card.top = SECTION_HEIGHT + 2
	end
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
	local y = card.top
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

-- A larger gold heading across the page, over a group of sections such as one frame's texts.
local function CreatePageHeader(parent, text)
	local header = CreateFrame("Frame", nil, parent)
	header:SetHeight(HEADER_HEIGHT)
	local label = CreateLabel(header, "GameFontNormalLarge", text)
	label:SetPoint("TOPLEFT", 0, -2)
	local divider = header:CreateTexture(nil, "ARTWORK")
	divider:SetAtlas("Options_HorizontalDivider")
	divider:SetHeight(1)
	divider:SetPoint("BOTTOMLEFT", 0, 6)
	divider:SetPoint("BOTTOMRIGHT", 0, 6)
	header.isHeader = true
	return header
end

-- A page's contents, top to bottom: headings across the page, sections flowing into columns, and wide
-- sections (marked span) that sit on their own row, like a text picker. Returns the layout function.
local function CreateFlow(content, items)
	return function(pageWidth)
		local x, y = PAGE_PADDING, PAGE_PADDING
		local pending = {}
		local function Flush()
			if #pending > 0 then
				y = LayoutCards(pending, content, x, y, pageWidth) + SECTION_GAP
				pending = {}
			end
		end
		for i, item in ipairs(items) do
			if item.isHeader then
				Flush()
				if i > 1 then
					y = y + HEADER_GAP - SECTION_GAP
				end
				item:ClearAllPoints()
				item:SetPoint("TOPLEFT", content, "TOPLEFT", x, -y)
				item:SetWidth(pageWidth)
				y = y + HEADER_HEIGHT
			elseif item.span then
				Flush()
				if item:IsShown() then
					y = y + PlaceCard(item, content, x, y, math.min(pageWidth, item.span)) + SECTION_GAP
				end
			else
				pending[#pending + 1] = item
			end
		end
		Flush()
		return y - SECTION_GAP
	end
end

-- A tab's page: its content scrolls with the mouse wheel or the scroll bar at the right, and is laid
-- out again whenever the window changes size or a page shows or hides some of its rows.
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
	-- A page shows the current settings whenever it's opened, since another page may share some of them.
	page:SetScript("OnShow", function()
		if page.options then
			page.options.Sync()
		end
		page:Relayout()
	end)
	return page
end

-- Text editor -------------------------------------------------------------------------------------

-- The text picker is no wider than this, so its dropdown sits near its label.
local PICKER_WIDTH = 440

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

	-- The picker sits right under the page heading that names these texts, so it has no heading of its own.
	local pickCard = CreateCard(content)
	pickCard.span = PICKER_WIDTH
	local fieldRow = pickCard:Add(CreateDropdownRow(pickCard, "Text to edit", nil, 260))
	-- When a spot only shows some of the time, such as the druid mana, this says when.
	local note = pickCard:Add(CreateHint(pickCard, ""), 4)
	note:Hide()
	local reset = pickCard:Add(CreateButton(pickCard, "Reset this text", 134), 6, true)
	reset:SetScript("OnClick", function()
		ns.ResetTextStyle(selected.key)
		refresh()
	end)

	local displayCard = CreateCard(content, "Display")
	local showRow = displayCard:Add(CreateToggleRow(displayCard, "Show", function(checked) Set("enabled", checked) end))
	local mouseoverRow = displayCard:Add(CreateToggleRow(displayCard, "Only on mouseover", function(checked) Set("mouseover", checked) end))
	local formatRow = displayCard:Add(CreateDropdownRow(displayCard, "Shows"))

	local fontCard = CreateCard(content, "Font")
	local fontRow = fontCard:Add(CreateDropdownRow(fontCard, "Font"))
	local outlineRow = fontCard:Add(CreateDropdownRow(fontCard, "Outline"))
	local size = fontCard:Add(CreateSliderRow(fontCard, "Size", ns.TextSizeRange, FormatSize,
		function() return ns.GetTextOption(selected.key, "size") end,
		function(value)
			Set("size", math.min(math.max(math.floor(value + 0.5), ns.TextSizeRange.min), ns.TextSizeRange.max))
		end))

	-- Moves the spot from where it normally sits, in UI units. Positive Y is up.
	local positionCard = CreateCard(content, "Position")
	local function OffsetRow(text, part)
		return positionCard:Add(CreateSliderRow(positionCard, text, ns.TextOffsetRange, FormatSize,
			function() return ns.GetTextOption(selected.key, part) end,
			function(value)
				Set(part, math.min(math.max(math.floor(value + 0.5), ns.TextOffsetRange.min), ns.TextOffsetRange.max))
			end))
	end
	local offsetX = OffsetRow("X offset", "offsetX")
	local offsetY = OffsetRow("Y offset", "offsetY")

	local colorCard = CreateCard(content, "Color")
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

	return { pickCard, displayCard, fontCard, positionCard, colorCard }, refresh, pickCard
end

-- Pages -------------------------------------------------------------------------------------------

-- Look and feel, size, position and opacity. Size and position move secure frames, so they're locked in combat.
local function BuildGeneral(content)
	local lookCard = CreateCard(content, "Look & feel")
	local showToT = lookCard:Add(CreateToggleRow(lookCard, "Show target of target", ns.SetTargetOfTargetShown))
	local surnames = lookCard:Add(CreateToggleRow(lookCard, "Show last names", ns.SetSurnamesShown))
	local prediction = lookCard:Add(CreateToggleRow(lookCard, "Show incoming heals and absorbs", ns.SetHealPredictionShown))
	local pvpIcon = lookCard:Add(CreateToggleRow(lookCard, "Show PvP timer", ns.SetPvPIconShown))
	local masterRow = lookCard:Add(CreateDropdownRow(lookCard, "Master font"), 6)
	local applyFont = lookCard:Add(CreateButton(lookCard, "Use for all text", 150), 4, true)
	local fontHint = lookCard:Add(CreateHint(lookCard,
		"Texts with a font of their own keep it until you press Use for all text. That includes buff texts and combat text."), 6)

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
		SyncOpacity()
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

	options.Layout = CreateFlow(content, { lookCard, sizeCard, opacityCard })
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

-- The orb and the cast ring around it. None of it is protected, so it all works in combat.
local function BuildOrb(content, _, relayout)
	local orbCard = CreateCard(content) -- under the Power orb heading
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

	local castCard = CreateCard(content) -- under the Cast ring heading
	local placementRow = castCard:Add(CreateDropdownRow(castCard, "Spell name and time"))
	SetUpChoiceMenu(placementRow.dropdown, CAST_PLACEMENTS,
		function() return ns.db.castTextPlacement end,
		function(placement) ns.SetCastTextPlacement(placement) end)
	local swing = castCard:Add(CreateToggleRow(castCard, "Show swing timer", ns.SetSwingTimerShown), 4)
	-- PLACEHOLDER castLatency: "Show latency" - the part of the cast lost to latency, shaded at the ring's end.
	castCard:Add(CreatePlaceholderRow(castCard, "Show latency", "castLatency"))
	-- PLACEHOLDER castAnimated: "Animated ring" - animated textures on the cast ring.
	castCard:Add(CreatePlaceholderRow(castCard, "Animated ring", "castAnimated"))
	-- PLACEHOLDER castGCD: "Show global cooldown" - the global cooldown on the ring.
	castCard:Add(CreatePlaceholderRow(castCard, "Show global cooldown", "castGCD"))

	local castCards, castRefresh, castPick = CreateTextEditor(content, { "castName", "castTime" }, relayout)
	-- The spell icon belongs with the cast's texts, beside the spell name.
	local icon = castPick:Add(CreateToggleRow(castPick, "Show spell icon beside the name", ns.SetCastIconShown), 8)

	local items = { CreatePageHeader(content, "Power orb"), orbCard, CreatePageHeader(content, "Orb text") }
	AppendAll(items, orbCards)
	items[#items + 1] = CreatePageHeader(content, "Cast ring")
	items[#items + 1] = castCard
	items[#items + 1] = CreatePageHeader(content, "Cast text")
	AppendAll(items, castCards)

	return {
		Sync = Joined(function()
			SyncStyle()
			spark.toggle:SetChecked(ns.db.showManaSpark)
			druidMana.toggle:SetChecked(ns.GetTextOption("orbMana", "enabled"))
			placementRow.dropdown:GenerateMenu()
			swing.toggle:SetChecked(ns.db.showSwingTimer)
			icon.toggle:SetChecked(ns.db.showCastIcon)
		end, orbRefresh, castRefresh),
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

-- A flat Blizzard panel with a title and close button.
local function CreatePanel(name, parent, width, height, title, template)
	local frame = CreateFrame("Frame", name, parent, template or "DefaultPanelFlatTemplate")
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

	if not frame.CloseButton then
		CreateFrame("Button", nil, frame, "UIPanelCloseButtonDefaultAnchors")
	end
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
		Layout = CreateFlow(content, { profilesCard, manageCard }),
	}
end

local TABS = {
	{ label = "General", build = BuildGeneral },
	{ label = "Player & Pet Frame", build = BuildPlayer },
	{ label = "Target Frame", build = BuildTarget },
	{ label = "Power Orb and Cast Ring", build = BuildOrb },
	{ label = "Buffs & Debuffs", build = BuildAuras },
	{ label = "Incoming Combat Text", build = BuildCombatText },
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

-- Drag the bottom right corner to resize the window. Every page lays itself out again to fit.
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

-- Where the tabs and the page start below the title bar: under the logo, and the header row beside it.
local BODY_TOP = -64

-- The tabs down the left: a highlight on hover, and a gold bar and tint on the one that's open.
local function CreateNavButton(parent, text)
	local button = CreateFrame("Button", nil, parent)
	button:SetHeight(NAV_ROW_HEIGHT)

	local highlight = button:CreateTexture(nil, "HIGHLIGHT")
	highlight:SetAllPoints()
	highlight:SetColorTexture(1, 1, 1, 0.08)

	local selected = button:CreateTexture(nil, "BACKGROUND")
	selected:SetAllPoints()
	selected:SetColorTexture(TOGGLE_ON[1], TOGGLE_ON[2], TOGGLE_ON[3], 0.15)

	local bar = button:CreateTexture(nil, "ARTWORK")
	bar:SetWidth(3)
	bar:SetPoint("TOPLEFT")
	bar:SetPoint("BOTTOMLEFT")
	bar:SetColorTexture(TOGGLE_ON[1], TOGGLE_ON[2], TOGGLE_ON[3], 1)

	local label = CreateLabel(button, "GameFontNormal", text)
	label:SetPoint("LEFT", 12, 0)
	label:SetPoint("RIGHT", -6, 0)

	function button:SetSelected(isSelected)
		selected:SetShown(isSelected)
		bar:SetShown(isSelected)
		label:SetFontObject(isSelected and "GameFontHighlight" or "GameFontNormal")
	end
	button:SetSelected(false)
	return button
end

local function CreateConfig()
	local width, height, maxWidth, maxHeight = GetWindowSize()
	local frame = CreatePanel("DibsUIConfig", UIParent, width, height, "DibsUI", "PortraitFrameFlatTemplate")
	frame:SetPortraitToAsset(ns.Media("Logo"))
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

	-- The open page's name, beside the logo.
	local pageTitle = CreateLabel(frame, "GameFontHighlightLarge", "")
	pageTitle:SetPoint("TOPLEFT", 70, -36)

	local minimapToggle = CreateToggleRow(frame, "Show minimap button", ns.SetMinimapButtonShown)
	minimapToggle:SetWidth(minimapToggle.label:GetStringWidth() + 12 + TOGGLE_WIDTH)
	minimapToggle:SetPoint("TOPRIGHT", -14, -28)

	-- Unlocking moves every frame, so it's here where every page can reach it. It says what pressing it does.
	local lockButton = CreateButton(frame, "Unlock frames", 130)
	lockButton:SetPoint("RIGHT", minimapToggle, "LEFT", -24, 0)
	local function SyncLockButton()
		lockButton:SetText(ns.db.locked and "Unlock frames" or "Lock frames")
	end
	lockButton:SetScript("OnClick", function()
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		ns.SetLocked(not ns.db.locked)
	end)
	-- /dibsui lock can change it while the window is open.
	hooksecurefunc(ns, "SetLocked", SyncLockButton)

	local nav = CreateFrame("Frame", nil, frame, "InsetFrameTemplate")
	nav:SetPoint("TOPLEFT", 10, BODY_TOP)
	nav:SetPoint("BOTTOMLEFT", 10, 30)
	nav:SetWidth(NAV_WIDTH)

	local inset = CreateFrame("Frame", nil, frame, "InsetFrameTemplate")
	inset:SetPoint("TOPLEFT", nav, "TOPRIGHT", 6, 0)
	inset:SetPoint("BOTTOMRIGHT", -8, 30)

	local pages, navButtons = {}, {}
	frame.navButtons = navButtons

	-- After a profile switch every page shows the new profile's settings.
	local context = { window = frame }
	function context.SyncAll()
		SyncLockButton()
		for _, page in ipairs(pages) do
			page.options.Sync()
		end
	end

	local function SelectTab(index)
		for i, page in ipairs(pages) do
			navButtons[i]:SetSelected(i == index)
			page:SetShown(i == index)
		end
		pageTitle:SetText(TABS[index].label)
		ns.account.configTab = index
	end

	for i, info in ipairs(TABS) do
		local button = CreateNavButton(nav, info.label)
		button:SetPoint("TOPLEFT", 4, -6 - (i - 1) * (NAV_ROW_HEIGHT + 2))
		button:SetPoint("RIGHT", -4, 0)
		button:SetScript("OnClick", function()
			SelectTab(i)
			PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
		end)
		navButtons[i] = button

		local page = CreateScrollPage(inset)
		local function relayout() page:Relayout() end
		page.options = info.build(page.content, context, relayout)
		page.options.relayout = relayout
		pages[i] = page
	end

	local combatNote = CreateLabel(frame, "GameFontDisableSmall", "Frame size, position and profiles can't be changed during combat")
	combatNote:SetPoint("BOTTOM", 0, 11)

	local function SetCombatLocked(locked)
		lockButton:SetEnabled(not locked)
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
		minimapToggle.toggle:SetChecked(ns.account.showMinimapButton)
		context.SyncAll()
		SetCombatLocked(InCombatLockdown())
		for _, page in ipairs(pages) do
			page:Relayout()
		end
	end)

	local savedTab = tonumber(ns.account.configTab)
	SelectTab(savedTab and TABS[savedTab] and savedTab or 1)
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

function ns.OpenConfig()
	if not (config and config:IsShown()) then
		ns.ToggleConfig()
	end
end

-- Locks or unlocks the frames, like the button at the top of the window, and says which. Like the
-- button, it waits for combat to end.
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

-- The game's own settings ------------------------------------------------------------------------

-- DibsUI's page under the game's Options, AddOns: the logo, a line about it, and a button that opens
-- the full window. The settings live in that window, so this page only points to it.
local function RegisterGameSettings()
	if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then
		return
	end
	local panel = CreateFrame("Frame")

	local logo = panel:CreateTexture(nil, "ARTWORK")
	logo:SetTexture(ns.Media("Logo"))
	logo:SetSize(64, 64)
	logo:SetPoint("TOPLEFT", 12, -12)

	local title = CreateLabel(panel, "GameFontNormalHuge", "DibsUI")
	title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 12, -6)

	local version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("DibsUI", "Version")
	local subtitle = CreateLabel(panel, "GameFontHighlight",
		"Winged unit frames around a power orb." .. (version and ("  |cff9d9d9dVersion " .. version .. "|r") or ""))
	subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)

	local open = CreateButton(panel, "Open DibsUI settings", 190)
	open:SetPoint("TOPLEFT", logo, "BOTTOMLEFT", 0, -18)
	open:SetScript("OnClick", function()
		if SettingsPanel and SettingsPanel:IsShown() then
			HideUIPanel(SettingsPanel)
		end
		ns.OpenConfig()
	end)

	local help = CreateLabel(panel, "GameFontHighlightSmall",
		"You can also type /dibsui or /dui, or click DibsUI's minimap button. /dibsui lock locks or unlocks the frames.")
	help:SetPoint("TOPLEFT", open, "BOTTOMLEFT", 0, -12)

	local category = Settings.RegisterCanvasLayoutCategory(panel, "DibsUI")
	Settings.RegisterAddOnCategory(category)
	ns.settingsCategory = category
end

RegisterGameSettings()
