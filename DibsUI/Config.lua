local _, ns = ...

local WIDTH, HEIGHT = 730, 540
local COLUMN_WIDTH = 280
local COLUMN_GAP = 32

local INPUT_WIDTH = 44
local DROPDOWN_WIDTH = 190

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
	section:SetSize(COLUMN_WIDTH, 26)

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

-- A label on the left and Blizzard's dropdown on the right.
local function CreateDropdownRow(parent, text, rowWidth, dropdownWidth)
	local row = CreateFrame("Frame", nil, parent)
	row:SetSize(rowWidth or COLUMN_WIDTH, 34)

	local label = CreateLabel(row, "GameFontHighlight", text)
	label:SetPoint("LEFT")

	local dropdown = CreateFrame("DropdownButton", nil, row, "WowStyle1DropdownTemplate")
	dropdown:SetWidth(dropdownWidth or DROPDOWN_WIDTH)
	dropdown:SetPoint("RIGHT")
	row.dropdown = dropdown
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

-- Layout options: these move secure frames, so they're locked in combat.
local function BuildLookAndFeel(page, left, right)
	local section = CreateSection(page, "Frames")
	section:SetPoint("TOPLEFT", left, 0)

	local showToT = CreateToggleRow(page, "Show target of target", ns.SetTargetOfTargetShown)
	showToT:SetPoint("TOPLEFT", section, "BOTTOMLEFT", 0, -2)

	local surnames = CreateToggleRow(page, "Show last names", ns.SetSurnamesShown)
	surnames:SetPoint("TOPLEFT", showToT, "BOTTOMLEFT")

	local scale = CreateSliderRow(page, "Scale", ns.ScaleRange, FormatScale,
		function() return ns.db.scale end, ns.SetScale)
	scale:SetPoint("TOPLEFT", surnames, "BOTTOMLEFT", 0, -2)

	local width = CreateSliderRow(page, "Width", ns.WidthRange, FormatScale,
		function() return ns.db.width end, ns.SetWidth)
	width:SetPoint("TOPLEFT", scale, "BOTTOMLEFT")

	local petWidth = CreateSliderRow(page, "Pet and target of target width", ns.WidthRange, FormatScale,
		function() return ns.db.petWidth end, ns.SetPetWidth)
	petWidth:SetPoint("TOPLEFT", width, "BOTTOMLEFT")

	local positionSection = CreateSection(page, "Position")
	positionSection:SetPoint("TOPLEFT", right, 0)

	-- Center at the left, level with Up, which sits above Down, with Left and Right either side of
	-- Down at the right of the column.
	local center = CreateButton(page, "Center horizontally", 150)
	center:SetPoint("TOPLEFT", positionSection, "BOTTOMLEFT", 0, -6)
	center:SetScript("OnClick", ns.CenterHorizontally)

	local down = CreateButton(page, "Down", 52)
	down:SetPoint("TOPRIGHT", positionSection, "BOTTOMRIGHT", -54, -30)
	down:SetScript("OnClick", function() ns.Nudge(0, -1) end)

	local up = CreateButton(page, "Up", 52)
	up:SetPoint("BOTTOM", down, "TOP", 0, 2)
	up:SetScript("OnClick", function() ns.Nudge(0, 1) end)

	local leftButton = CreateButton(page, "Left", 52)
	leftButton:SetPoint("RIGHT", down, "LEFT", -2, 0)
	leftButton:SetScript("OnClick", function() ns.Nudge(-1, 0) end)

	local rightButton = CreateButton(page, "Right", 52)
	rightButton:SetPoint("LEFT", down, "RIGHT", 2, 0)
	rightButton:SetScript("OnClick", function() ns.Nudge(1, 0) end)

	-- Opacity, under Position. None of it is protected, so it stays usable in combat.
	local opacitySection = CreateSection(page, "Opacity")
	opacitySection:SetPoint("TOPLEFT", positionSection, "BOTTOMLEFT", 0, -64)

	local modeRow = CreateDropdownRow(page, "Mode")
	modeRow:SetPoint("TOPLEFT", opacitySection, "BOTTOMLEFT", 0, -2)

	local modeHint = CreateLabel(page, "GameFontDisableSmall", "")
	modeHint:SetPoint("TOPLEFT", modeRow, "BOTTOMLEFT", 0, 0)
	modeHint:SetWidth(COLUMN_WIDTH)

	local manual = CreateSliderRow(page, "Manual opacity", { min = 0, max = 100, step = 5 }, FormatPercent,
		function() return math.floor(ns.db.manualOpacity * 100 + 0.5) end,
		function(value) ns.SetManualOpacity(value / 100) end)
	manual:SetPoint("TOPLEFT", modeHint, "BOTTOMLEFT", 0, -4)

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

	return options
end

-- One text spot at a time, picked from a dropdown: whether it shows, what it shows, and how it looks.
-- None of it is protected, so it all works in combat.
local function BuildTextOptions(page, left, right)
	local selected = ns.TextGroups[1].fields[1]
	local refresh

	local section = CreateSection(page, "Text")
	section:SetPoint("TOPLEFT", left, 0)

	local fieldRow = CreateDropdownRow(page, "Text to edit")
	fieldRow:SetPoint("TOPLEFT", section, "BOTTOMLEFT", 0, -2)

	local showRow = CreateToggleRow(page, "Show", function(checked)
		ns.SetTextStyle(selected.key, "enabled", checked)
	end)
	showRow:SetPoint("TOPLEFT", fieldRow, "BOTTOMLEFT")

	local mouseoverRow = CreateToggleRow(page, "Only on mouseover", function(checked)
		ns.SetTextStyle(selected.key, "mouseover", checked)
	end)
	mouseoverRow:SetPoint("TOPLEFT", showRow, "BOTTOMLEFT")

	local formatRow = CreateDropdownRow(page, "Shows")
	formatRow:SetPoint("TOPLEFT", mouseoverRow, "BOTTOMLEFT")

	local fontRow = CreateDropdownRow(page, "Font")
	fontRow:SetPoint("TOPLEFT", formatRow, "BOTTOMLEFT")

	local size = CreateSliderRow(page, "Size", ns.TextSizeRange, FormatSize,
		function() return ns.GetTextOption(selected.key, "size") end,
		function(value)
			value = math.min(math.max(math.floor(value + 0.5), ns.TextSizeRange.min), ns.TextSizeRange.max)
			ns.SetTextStyle(selected.key, "size", value)
		end)
	local sizeSection = CreateSection(page, "Size and position")
	sizeSection:SetPoint("TOPLEFT", right, 0)
	size:SetPoint("TOPLEFT", sizeSection, "BOTTOMLEFT", 0, -2)

	-- Moves the spot from where it normally sits, in UI units. Positive Y is up.
	local function CreateOffsetRow(text, part)
		return CreateSliderRow(page, text, ns.TextOffsetRange, FormatSize,
			function() return ns.GetTextOption(selected.key, part) end,
			function(value)
				value = math.min(math.max(math.floor(value + 0.5), ns.TextOffsetRange.min), ns.TextOffsetRange.max)
				ns.SetTextStyle(selected.key, part, value)
			end)
	end

	local offsetX = CreateOffsetRow("X offset", "offsetX")
	offsetX:SetPoint("TOPLEFT", size, "BOTTOMLEFT")

	local offsetY = CreateOffsetRow("Y offset", "offsetY")
	offsetY:SetPoint("TOPLEFT", offsetX, "BOTTOMLEFT")

	local colorRow = CreateToggleRow(page, "Custom color", function(checked)
		if checked then
			ns.SetTextStyle(selected.key, "color", { ns.GetTextDefaultColor(selected.key) })
		else
			ns.SetTextStyle(selected.key, "color", nil)
		end
		refresh()
	end)
	local colorSection = CreateSection(page, "Color")
	colorSection:SetPoint("TOPLEFT", offsetY, "BOTTOMLEFT", 0, -6)
	colorRow:SetPoint("TOPLEFT", colorSection, "BOTTOMLEFT", 0, -2)

	-- The template passes clicks on to its parent, which would flip the switch as well.
	local swatch = CreateFrame("Button", nil, colorRow, "ColorSwatchTemplate")
	swatch:SetPropagateMouseClicks(false)
	swatch:SetSize(22, 22)
	swatch.SwatchBg:SetSize(20, 20)
	swatch.InnerBorder:SetSize(18, 18)
	swatch.Color:SetSize(16, 16)
	swatch:SetPoint("RIGHT", colorRow.toggle, "LEFT", -12, 0)

	local hint = CreateLabel(page, "GameFontDisableSmall", "")
	hint:SetPoint("TOPLEFT", colorRow, "BOTTOMLEFT", 0, 0)
	hint:SetWidth(COLUMN_WIDTH)

	local reset = CreateButton(page, "Reset this text", 134)
	reset:SetPoint("TOPLEFT", fontRow, "BOTTOMLEFT", 0, -16)
	reset:SetScript("OnClick", function()
		ns.ResetTextStyle(selected.key)
		refresh()
	end)

	local fontToAll = CreateButton(page, "Use font for all text", 140)
	fontToAll:SetPoint("LEFT", reset, "RIGHT", 6, 0)
	fontToAll:SetScript("OnClick", function()
		local font = ns.GetTextOption(selected.key, "font")
		for key in pairs(ns.TextFields) do
			ns.SetTextStyle(key, "font", font)
		end
		refresh()
	end)

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

	return { Sync = refresh, SetCombatLocked = function() end }
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

-- The profile in use, and every profile on the account in a list. Clicking one uses it on this
-- character. Switching places the frames again, so all of this is locked in combat.
local function BuildProfiles(page, left, right, context)
	local isLocked = false

	local section = CreateSection(page, "Profiles")
	section:SetPoint("TOPLEFT", left, 0)

	local currentLabel = CreateLabel(page, "GameFontHighlight", "Current profile")
	currentLabel:SetPoint("TOPLEFT", section, "BOTTOMLEFT", 0, -6)

	local current = CreateLabel(page, "GameFontNormalLarge", "")
	current:SetPoint("TOPLEFT", currentLabel, "BOTTOMLEFT", 0, -6)
	current:SetWidth(COLUMN_WIDTH)

	local listBack = page:CreateTexture(nil, "BACKGROUND")
	listBack:SetColorTexture(0, 0, 0, 0.3)

	local list = CreateFrame("Frame", nil, page, "WowScrollBoxList")
	list:SetPoint("TOPLEFT", current, "BOTTOMLEFT", 0, -14)
	list:SetSize(COLUMN_WIDTH - 14, PROFILE_LIST_HEIGHT)
	listBack:SetPoint("TOPLEFT", list, -2, 2)
	listBack:SetPoint("BOTTOMRIGHT", list, 16, -2)

	local scrollBar = CreateFrame("EventFrame", nil, page, "MinimalScrollBar")
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

	local manageSection = CreateSection(page, "Manage")
	manageSection:SetPoint("TOPLEFT", right, 0)

	local dialog = CreateNewProfileDialog(context.window, OnProfileChanged)

	local newProfile = CreateButton(page, "New profile", 150)
	newProfile:SetPoint("TOPLEFT", manageSection, "BOTTOMLEFT", 0, -8)
	newProfile:SetScript("OnClick", function() dialog:Show() end)

	local help = CreateLabel(page, "GameFontHighlightSmall",
		"Profiles are shared by every character on your account, and each character remembers which one it uses.\n\n"
		.. "Click a profile to use it on this character.\n\n"
		.. "The minimap button's settings are the same in every profile.")
	help:SetPoint("TOPLEFT", newProfile, "BOTTOMLEFT", 0, -14)
	help:SetWidth(COLUMN_WIDTH)
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
	}
end

local SIDEBAR_WIDTH = 170
local AURA_COLUMN_WIDTH = 230
local AURA_COLUMN_GAP = 20
local AURA_DROPDOWN_WIDTH = 130
local AURA_GROUP_HEIGHT = 30

-- The groups down the left, each with its own switch, and the picked group's settings beside them.
-- None of it is protected, so it all works in combat.
local function BuildAuras(page, left)
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

	local groupSection = CreateSection(page, "Groups")
	groupSection:SetWidth(SIDEBAR_WIDTH)
	groupSection:SetPoint("TOPLEFT", left, 0)

	local groupRows = {}
	for i, group in ipairs(ns.AuraGroups) do
		local row = CreateFrame("Button", nil, page)
		row:SetSize(SIDEBAR_WIDTH, AURA_GROUP_HEIGHT)
		row:SetPoint("TOPLEFT", groupSection, "BOTTOMLEFT", 0, -2 - (i - 1) * AURA_GROUP_HEIGHT)

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

	local testSection = CreateSection(page, "Test mode")
	testSection:SetWidth(SIDEBAR_WIDTH)
	testSection:SetPoint("TOPLEFT", groupSection, "BOTTOMLEFT", 0, -14 - #ns.AuraGroups * AURA_GROUP_HEIGHT)

	local testRow = CreateToggleRow(page, "Show test buffs", ns.SetAuraTestMode)
	testRow:SetWidth(SIDEBAR_WIDTH)
	testRow:SetPoint("TOPLEFT", testSection, "BOTTOMLEFT", 0, -2)

	local testHint = CreateLabel(page, "GameFontDisableSmall",
		"Fills every group with sample buffs, so you can see the layout as you change it. Turns off when you reload.")
	testHint:SetPoint("TOPLEFT", testRow, "BOTTOMLEFT", 0, -2)
	testHint:SetWidth(SIDEBAR_WIDTH)
	testHint:SetWordWrap(true)

	if ns.hasMasque then
		local masqueHint = CreateLabel(page, "GameFontDisableSmall",
			"Masque is installed: pick a skin for these icons in Masque's settings (/masque).")
		masqueHint:SetPoint("TOPLEFT", testHint, "BOTTOMLEFT", 0, -10)
		masqueHint:SetWidth(SIDEBAR_WIDTH)
		masqueHint:SetWordWrap(true)
	end

	-- The picked group's settings, in two columns. Groups that aren't built yet show a note instead.
	local pane = CreateFrame("Frame", nil, page)
	pane:SetAllPoints()

	local columnA = CreateFrame("Frame", nil, pane)
	columnA:SetSize(1, 1)
	columnA:SetPoint("TOPLEFT", left, "TOPLEFT", SIDEBAR_WIDTH + AURA_COLUMN_GAP, 0)
	local columnB = CreateFrame("Frame", nil, pane)
	columnB:SetSize(1, 1)
	columnB:SetPoint("TOPLEFT", columnA, "TOPLEFT", AURA_COLUMN_WIDTH + AURA_COLUMN_GAP, 0)

	local comingSoon = CreateLabel(page, "GameFontDisable", "")
	comingSoon:SetPoint("TOPLEFT", columnA, "TOPLEFT", 0, -6)

	-- Standard and list mode each have their own first column. The second column, with the mode and
	-- position, is shared.
	local standardPane = CreateFrame("Frame", nil, pane)
	standardPane:SetAllPoints()
	local listPane = CreateFrame("Frame", nil, pane)
	listPane:SetAllPoints()

	local function Section(parent, text, anchor, gap)
		local section = CreateSection(parent, text)
		section:SetWidth(AURA_COLUMN_WIDTH)
		local isColumnTop = anchor == columnA or anchor == columnB
		section:SetPoint("TOPLEFT", anchor, isColumnTop and "TOPLEFT" or "BOTTOMLEFT", 0, gap or 0)
		return section
	end

	-- Each row's refresh, run only while the row is showing, so a row never reads a setting the picked
	-- group doesn't have.
	local function AddSync(row, sync)
		syncs[#syncs + 1] = { row = row, sync = sync }
	end

	local function IsShowing(region)
		while region and region ~= page do
			if not region:IsShown() then
				return false
			end
			region = region:GetParent()
		end
		return true
	end

	local function Slider(parent, text, range, access, anchor, gap)
		local row = CreateSliderRow(parent, text, range, FormatSize, access.get, access.set)
		row:SetWidth(AURA_COLUMN_WIDTH)
		row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, gap or 0)
		AddSync(row, row.Sync)
		return row
	end

	local function Dropdown(parent, text, anchor, gap)
		local row = CreateDropdownRow(parent, text, AURA_COLUMN_WIDTH, AURA_DROPDOWN_WIDTH)
		row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, gap or 0)
		AddSync(row, function() row.dropdown:GenerateMenu() end)
		return row
	end

	local function Choices(parent, text, list, access, anchor, gap)
		local row = Dropdown(parent, text, anchor, gap)
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
	local function FontChoice(parent, access, anchor, gap)
		local row = Dropdown(parent, "Font", anchor, gap)
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

	local function ColorChoice(parent, access, anchor)
		local row = CreateFrame("Frame", nil, parent)
		row:SetSize(AURA_COLUMN_WIDTH, 30)
		row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT")
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

	-- Standard mode: icons
	local iconSection = Section(standardPane, "Icons", columnA)
	local iconSize = Slider(standardPane, "Icon size", ns.AuraIconSizeRange, Field("iconSize"), iconSection, -2)
	local spacing = Slider(standardPane, "Spacing", ns.AuraSpacingRange, Field("spacing"), iconSize)
	local growthRow = Choices(standardPane, "Growth", ns.AuraGrowths, Field("growth"), spacing)
	local frameSize = Slider(standardPane, "Frame width", ns.AuraFrameSizeRange, Field("frameSize"), growthRow)

	-- Standard mode: time text
	local textSection = Section(standardPane, "Time text", frameSize, -6)
	local fontRow = FontChoice(standardPane, Field("font"), textSection, -2)
	local textSize = Slider(standardPane, "Size", ns.AuraTextSizeRange, Field("textSize"), fontRow)
	ColorChoice(standardPane, Field("textColor"), textSize)

	-- List mode: icons
	local listIconSection = Section(listPane, "Icons", columnA)
	local rightSide = CreateToggleRow(listPane, "Icon on the right", function(checked)
		SetList("iconSide", checked and "RIGHT" or "LEFT")
	end)
	rightSide:SetWidth(AURA_COLUMN_WIDTH)
	rightSide:SetPoint("TOPLEFT", listIconSection, "BOTTOMLEFT", 0, -2)
	AddSync(rightSide, function() rightSide.toggle:SetChecked(GetList("iconSide") == "RIGHT") end)
	local listIconSize = Slider(listPane, "Icon size", ns.AuraIconSizeRange, ListField("iconSize"), rightSide)
	local listSpacing = Slider(listPane, "Spacing", ns.AuraSpacingRange, ListField("spacing"), listIconSize)

	-- List mode: name and time
	local nameSection = Section(listPane, "Name", listSpacing, -6)
	local nameFont = FontChoice(listPane, ListField("nameFont"), nameSection, -2)
	local nameSize = Slider(listPane, "Size", ns.AuraTextSizeRange, ListField("nameSize"), nameFont)
	local nameColor = ColorChoice(listPane, ListField("nameColor"), nameSize)

	local timeSection = Section(listPane, "Time", nameColor, -6)
	local timeFont = FontChoice(listPane, ListField("timeFont"), timeSection, -2)
	local timeSize = Slider(listPane, "Size", ns.AuraTextSizeRange, ListField("timeSize"), timeFont)
	ColorChoice(listPane, ListField("timeColor"), timeSize)

	-- Mode, for the groups that have a list mode
	local modeSection = Section(pane, "Layout", columnB)
	local modeRow = Choices(pane, "Mode", ns.AuraModes, Field("mode"), modeSection, -2)
	local modeHint = CreateLabel(pane, "GameFontDisableSmall", "")
	modeHint:SetPoint("TOPLEFT", modeRow, "BOTTOMLEFT", 0, 0)
	modeHint:SetWidth(AURA_COLUMN_WIDTH)
	modeHint:SetWordWrap(true)

	-- Position, of the mode in use. Anchored groups have none, and say where they sit instead.
	local positionPane = CreateFrame("Frame", nil, pane)
	positionPane:SetAllPoints()
	local positionSection = CreateSection(positionPane, "Position")
	positionSection:SetWidth(AURA_COLUMN_WIDTH)
	local pointRow = Choices(positionPane, "Frame point", ns.AuraPoints, PositionField("point"), positionSection, -2)
	local targetRow = Choices(positionPane, "Attach to", ns.AuraAnchorTargets, PositionField("anchorTo"), pointRow)
	local targetPointRow = Choices(positionPane, "Attach point", ns.AuraPoints, PositionField("anchorPoint"), targetRow)
	local offsetX = Slider(positionPane, "X offset", ns.AuraOffsetRange, PositionField("x"), targetPointRow)
	local offsetY = Slider(positionPane, "Y offset", ns.AuraOffsetRange, PositionField("y"), offsetX)

	local positionHint = CreateLabel(positionPane, "GameFontDisableSmall",
		"Sizes and offsets follow your UI scale. You can also drag the frame while frames are unlocked.")
	positionHint:SetPoint("TOPLEFT", offsetY, "BOTTOMLEFT", 0, -4)
	positionHint:SetWidth(AURA_COLUMN_WIDTH)
	positionHint:SetWordWrap(true)

	local anchoredSection = Section(pane, "Position", columnB)
	local anchoredNote = CreateLabel(pane, "GameFontHighlightSmall", "")
	anchoredNote:SetPoint("TOPLEFT", anchoredSection, "BOTTOMLEFT", 0, -6)
	anchoredNote:SetWidth(AURA_COLUMN_WIDTH)
	anchoredNote:SetWordWrap(true)
	anchoredNote:SetJustifyH("LEFT")

	function refresh()
		for _, entry in ipairs(groupRows) do
			entry.row.selected:SetShown(entry.group == selected)
			if entry.row.toggle then
				entry.row.toggle:SetChecked(ns.GetAuraSettings(entry.group.key).enabled)
			end
		end
		testRow.toggle:SetChecked(ns.auraTestMode)
		pane:SetShown(selected.built == true)
		comingSoon:SetShown(not selected.built)
		comingSoon:SetText(selected.label .. " are coming soon.")
		if not selected.built then
			return
		end

		local hasListMode = selected.hasListMode == true
		local isAnchored = selected.anchored == true
		local isList = IsList()
		modeSection:SetShown(hasListMode)
		modeRow:SetShown(hasListMode)
		modeHint:SetShown(hasListMode)
		if hasListMode then
			modeHint:SetText(ns.AuraModesByKey[Get("mode")].description)
		end
		positionSection:ClearAllPoints()
		if hasListMode then
			positionSection:SetPoint("TOPLEFT", modeHint, "BOTTOMLEFT", 0, -10)
		else
			positionSection:SetPoint("TOPLEFT", columnB, "TOPLEFT")
		end
		positionPane:SetShown(not isAnchored)
		anchoredSection:SetShown(isAnchored)
		anchoredNote:SetShown(isAnchored)
		anchoredNote:SetText(selected.anchorNote or "")
		standardPane:SetShown(not isList)
		listPane:SetShown(isList)

		-- Anchored groups take their growth and width from the frame they sit on.
		growthRow:SetShown(not isAnchored)
		frameSize:SetShown(not isAnchored)
		textSection:ClearAllPoints()
		textSection:SetPoint("TOPLEFT", isAnchored and spacing or frameSize, "BOTTOMLEFT", 0, -6)
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
	end

	-- Dragging the frame while unlocked changes its offsets, which the sliders follow.
	function ns.OnAuraSettingsMoved(groupKey)
		if groupKey == selected.key and page:IsVisible() then
			refresh()
		end
	end

	return { Sync = refresh, SetCombatLocked = function() end }
end

local TABS = {
	{ label = "Look and feel", build = BuildLookAndFeel },
	{ label = "Text options", build = BuildTextOptions },
	{ label = "Buffs/Debuffs", build = BuildAuras },
	{ label = "Profiles", build = BuildProfiles },
}
local function CreateConfig()
	local frame = CreatePanel("DibsUIConfig", UIParent, WIDTH, HEIGHT, "DibsUI")
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("HIGH")
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetDontSavePosition(true)
	tinsert(UISpecialFrames, frame:GetName())

	local minimapToggle = CreateTopToggle(frame, "Show minimap button", ns.SetMinimapButtonShown)
	minimapToggle:SetPoint("TOPRIGHT", -14, -26)

	-- Unlocking moves every frame, so it's here where every tab can reach it.
	local unlockToggle = CreateTopToggle(frame, "Unlock frames", function(checked)
		ns.SetLocked(not checked)
	end)
	unlockToggle:SetPoint("RIGHT", minimapToggle, "LEFT", -28, 0)

	local inset = CreateFrame("Frame", nil, frame, "InsetFrameTemplate")
	inset:SetPoint("TOPLEFT", 10, -60)
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

		-- Every tab lays out in two columns.
		local page = CreateFrame("Frame", nil, inset)
		page:SetAllPoints()
		page:Hide()
		local left = CreateFrame("Frame", nil, page)
		left:SetSize(1, 1)
		left:SetPoint("TOPLEFT", 16, -10)
		local right = CreateFrame("Frame", nil, page)
		right:SetSize(1, 1)
		right:SetPoint("TOPLEFT", left, "TOPLEFT", COLUMN_WIDTH + COLUMN_GAP, 0)
		page.options = info.build(page, left, right, context)
		pages[i] = page
	end
	PanelTemplates_SetNumTabs(frame, #TABS)
	PanelTemplates_SetTab(frame, 1)
	pages[1]:Show()

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
		minimapToggle.toggle:SetChecked(ns.account.showMinimapButton)
		context.SyncAll()
		SetCombatLocked(InCombatLockdown())
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

SLASH_DIBSUI1 = "/dibsui"
SLASH_DIBSUI2 = "/dui"
SlashCmdList.DIBSUI = ns.ToggleConfig
