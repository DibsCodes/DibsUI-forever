local _, ns = ...

local WIDTH, HEIGHT = 640, 440
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
		local value = tonumber(self:GetText())
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
local function CreateDropdownRow(parent, text)
	local row = CreateFrame("Frame", nil, parent)
	row:SetSize(COLUMN_WIDTH, 34)

	local label = CreateLabel(row, "GameFontHighlight", text)
	label:SetPoint("LEFT")

	local dropdown = CreateFrame("DropdownButton", nil, row, "WowStyle1DropdownTemplate")
	dropdown:SetWidth(DROPDOWN_WIDTH)
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
local function BuildFrameOptions(page, column)
	local section = CreateSection(page, "Frames")
	section:SetPoint("TOPLEFT", column, 0)

	local lock = CreateToggleRow(page, "Lock position", ns.SetLocked)
	lock:SetPoint("TOPLEFT", section, "BOTTOMLEFT", 0, -2)

	local showToT = CreateToggleRow(page, "Show target of target", ns.SetTargetOfTargetShown)
	showToT:SetPoint("TOPLEFT", lock, "BOTTOMLEFT")

	local scale = CreateSliderRow(page, "Scale", ns.ScaleRange, FormatScale,
		function() return ns.db.scale end, ns.SetScale)
	scale:SetPoint("TOPLEFT", showToT, "BOTTOMLEFT", 0, -2)

	local width = CreateSliderRow(page, "Width", ns.WidthRange, FormatScale,
		function() return ns.db.width end, ns.SetWidth)
	width:SetPoint("TOPLEFT", scale, "BOTTOMLEFT")

	local petWidth = CreateSliderRow(page, "Pet and target of target width", ns.WidthRange, FormatScale,
		function() return ns.db.petWidth end, ns.SetPetWidth)
	petWidth:SetPoint("TOPLEFT", width, "BOTTOMLEFT")

	local positionSection = CreateSection(page, "Position")
	positionSection:SetPoint("TOPLEFT", petWidth, "BOTTOMLEFT", 0, -10)

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

	local left = CreateButton(page, "Left", 52)
	left:SetPoint("RIGHT", down, "LEFT", -2, 0)
	left:SetScript("OnClick", function() ns.Nudge(-1, 0) end)

	local right = CreateButton(page, "Right", 52)
	right:SetPoint("LEFT", down, "RIGHT", 2, 0)
	right:SetScript("OnClick", function() ns.Nudge(1, 0) end)

	local options = {}

	function options.Sync()
		lock.toggle:SetChecked(ns.db.locked)
		showToT.toggle:SetChecked(ns.db.showTargetOfTarget)
		scale:Sync()
		width:Sync()
		petWidth:Sync()
	end

	function options.SetEnabled(enabled)
		for _, control in ipairs({ lock, showToT, scale, width, petWidth, center, up, down, left, right }) do
			control:SetEnabled(enabled)
		end
	end

	return options
end

-- Font, size and color for one text field at a time, picked from a dropdown.
local function BuildTextOptions(page, column)
	local selected = ns.TextGroups[1].fields[1]

	local section = CreateSection(page, "Text")
	section:SetPoint("TOPLEFT", column, 0)

	local fieldRow = CreateDropdownRow(page, "Field")
	fieldRow:SetPoint("TOPLEFT", section, "BOTTOMLEFT", 0, -2)

	local fontRow = CreateDropdownRow(page, "Font")
	fontRow:SetPoint("TOPLEFT", fieldRow, "BOTTOMLEFT")

	local function GetStyle()
		return ns.GetTextStyle(selected.key) or {}
	end

	local size = CreateSliderRow(page, "Size", ns.TextSizeRange, FormatSize,
		function() return GetStyle().size or ns.Text[selected.key].size end,
		function(value)
			value = math.min(math.max(math.floor(value + 0.5), ns.TextSizeRange.min), ns.TextSizeRange.max)
			ns.SetTextStyle(selected.key, "size", value ~= ns.Text[selected.key].size and value or nil)
		end)
	size:SetPoint("TOPLEFT", fontRow, "BOTTOMLEFT", 0, -2)

	local refresh

	local colorRow = CreateToggleRow(page, "Custom color", function(checked)
		if checked then
			ns.SetTextStyle(selected.key, "color", { ns.GetTextDefaultColor(selected.key) })
		else
			ns.SetTextStyle(selected.key, "color", nil)
		end
		refresh()
	end)
	colorRow:SetPoint("TOPLEFT", size, "BOTTOMLEFT", 0, -2)

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
	reset:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -16)
	reset:SetScript("OnClick", function()
		ns.ResetTextStyle(selected.key)
		refresh()
	end)

	local fontToAll = CreateButton(page, "Use font for all text", 140)
	fontToAll:SetPoint("LEFT", reset, "RIGHT", 6, 0)
	fontToAll:SetScript("OnClick", function()
		local font = GetStyle().font
		for key in pairs(ns.TextFields) do
			ns.SetTextStyle(key, "font", font)
		end
		refresh()
	end)

	local function OpenColorPicker()
		local key = selected.key
		local previous = GetStyle().color
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
		local style = GetStyle()
		fieldRow.dropdown:GenerateMenu()
		fontRow.dropdown:GenerateMenu()
		size:Sync()
		colorRow.toggle:SetChecked(style.color ~= nil)
		local r, g, b = ns.GetTextDefaultColor(selected.key)
		if style.color then
			r, g, b = style.color[1], style.color[2], style.color[3]
		end
		swatch:SetColorRGB(r, g, b)
		swatch:SetAlpha(style.color and 1 or 0.5)
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

	fontRow.dropdown:SetupMenu(function(_, root)
		root:SetScrollMode(360)
		for _, font in ipairs(ns.GetFonts()) do
			local radio = root:CreateRadio(font.name,
				function() return SameFont(GetStyle().font or ns.Text.font, font.path) end,
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

	return { Sync = refresh }
end

-- Sits above the tabs, since it applies to the whole addon rather than one tab.
local function CreateMinimapToggle(frame)
	local row = CreateToggleRow(frame, "Show minimap button", ns.SetMinimapButtonShown)
	row:SetWidth(row.label:GetStringWidth() + 12 + TOGGLE_WIDTH)
	return row
end

local function BuildLookAndFeel(page)
	local left = CreateFrame("Frame", nil, page)
	left:SetSize(1, 1)
	left:SetPoint("TOPLEFT", 16, -10)
	local right = CreateFrame("Frame", nil, page)
	right:SetSize(1, 1)
	right:SetPoint("TOPLEFT", left, "TOPLEFT", COLUMN_WIDTH + COLUMN_GAP, 0)

	local frameOptions = BuildFrameOptions(page, left)
	local textOptions = BuildTextOptions(page, right)

	return {
		Sync = function()
			frameOptions.Sync()
			textOptions.Sync()
		end,
		SetCombatLocked = function(locked)
			frameOptions.SetEnabled(not locked)
		end,
	}
end

-- More tabs will join this one later.
local TABS = {
	{ label = "Look and feel", build = BuildLookAndFeel },
}

local function CreateConfig()
	local frame = CreateFrame("Frame", "DibsUIConfig", UIParent, "DefaultPanelFlatTemplate")
	frame:SetSize(WIDTH, HEIGHT)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("HIGH")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetDontSavePosition(true)
	frame:SetTitle("DibsUI")
	tinsert(UISpecialFrames, frame:GetName())

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

	local minimapToggle = CreateMinimapToggle(frame)
	minimapToggle:SetPoint("TOPRIGHT", -14, -26)

	local inset = CreateFrame("Frame", nil, frame, "InsetFrameTemplate")
	inset:SetPoint("TOPLEFT", 10, -60)
	inset:SetPoint("BOTTOMRIGHT", -8, 30)

	local pages = {}
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

		local page = CreateFrame("Frame", nil, inset)
		page:SetAllPoints()
		page:Hide()
		page.options = info.build(page)
		pages[i] = page
	end
	PanelTemplates_SetNumTabs(frame, #TABS)
	PanelTemplates_SetTab(frame, 1)
	pages[1]:Show()

	local combatNote = CreateLabel(frame, "GameFontDisableSmall", "Frame size and position can't be changed during combat")
	combatNote:SetPoint("BOTTOM", 0, 11)

	local function SetCombatLocked(locked)
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
		minimapToggle.toggle:SetChecked(ns.db.showMinimapButton)
		for _, page in ipairs(pages) do
			page.options.Sync()
		end
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
