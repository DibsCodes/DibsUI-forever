local _, ns = ...

local function FormatValue(value)
	return string.format("%.2f", value)
end

local function StyleText(fontString, spec)
	fontString:SetFont(ns.Text.font, spec.size, ns.Text.outline)
	fontString:SetTextColor(1, 1, 1)
end

-- A labelled slider with a box for typing an exact value. Returns its controls and a Sync function.
local function CreateSliderRow(frame, labelText, range, anchor, anchorOffsetY, getValue, setValue)
	local label = ns.CreateText(frame, ns.Text.configLabel)
	label:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, anchorOffsetY)
	label:SetText(labelText)

	local slider = CreateFrame("Slider", nil, frame, "UISliderTemplate")
	slider:SetSize(190, 17)
	slider:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -8)
	slider:SetMinMaxValues(range.min, range.max)
	slider:SetValueStep(range.step)
	slider:SetObeyStepOnDrag(true)

	local low = ns.CreateText(frame, ns.Text.configRange)
	low:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -2)
	low:SetText(FormatValue(range.min))

	local high = ns.CreateText(frame, ns.Text.configRange)
	high:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", 0, -2)
	high:SetText(FormatValue(range.max))

	local input = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
	input:SetSize(50, 20)
	input:SetPoint("LEFT", slider, "RIGHT", 14, 0)
	input:SetAutoFocus(false)
	input:SetMaxLetters(5)
	input:SetFont(ns.Text.font, ns.Text.configValue.size, ns.Text.outline)
	input:SetTextColor(1, 1, 1)

	-- The slider can only rest on its steps, while a typed value can be exact. So moving the
	-- slider from code mustn't feed its snapped value back in as a new setting.
	local isSyncing = false

	local function Sync()
		isSyncing = true
		slider:SetValue(getValue())
		isSyncing = false
		input:SetText(FormatValue(getValue()))
		input:SetCursorPosition(0)
	end

	slider:SetScript("OnValueChanged", function(_, value)
		if not isSyncing then
			setValue(value)
			input:SetText(FormatValue(getValue()))
		end
	end)

	input:SetScript("OnEnterPressed", function(self)
		local value = tonumber(self:GetText())
		if value then
			setValue(value)
		end
		self:ClearFocus()
		Sync()
	end)
	input:SetScript("OnEditFocusLost", function(self)
		self:HighlightText(0, 0)
		Sync()
	end)
	input:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
	end)

	return slider, input, Sync, low
end

local function CreateButton(frame, text, width)
	local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	button:SetSize(width, 22)
	button:SetText(text)
	StyleText(button:GetFontString(), ns.Text.configValue)
	return button
end

local function CreateConfig()
	local frame = CreateFrame("Frame", "DibsUIConfig", UIParent, "BasicFrameTemplateWithInset")
	frame:SetSize(300, 396)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetDontSavePosition(true)
	tinsert(UISpecialFrames, frame:GetName())

	StyleText(frame.TitleText, ns.Text.configTitle)
	frame.TitleText:SetText("DibsUI")

	local lock = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
	lock:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -32)
	StyleText(lock.Text, ns.Text.configLabel)
	lock.Text:SetText("Lock position")
	lock:SetScript("OnClick", function(self)
		ns.SetLocked(self:GetChecked())
	end)

	-- The controls line up 6 units in from the checkbox, whose art has that much empty space.
	local rowAnchor = CreateFrame("Frame", nil, frame)
	rowAnchor:SetSize(1, 1)
	rowAnchor:SetPoint("TOPLEFT", lock, "BOTTOMLEFT", 6, 0)

	local scaleSlider, scaleInput, syncScale, scaleLow = CreateSliderRow(frame, "Scale", ns.ScaleRange, rowAnchor, -8,
		function() return ns.db.scale end, ns.SetScale)
	local widthSlider, widthInput, syncWidth, widthLow = CreateSliderRow(frame, "Width", ns.WidthRange, scaleLow, -10,
		function() return ns.db.width end, ns.SetWidth)
	local petWidthSlider, petWidthInput, syncPetWidth, petWidthLow = CreateSliderRow(frame, "Pet width", ns.WidthRange, widthLow, -10,
		function() return ns.db.petWidth end, ns.SetPetWidth)

	local positionLabel = ns.CreateText(frame, ns.Text.configLabel)
	positionLabel:SetPoint("TOPLEFT", petWidthLow, "BOTTOMLEFT", 0, -10)
	positionLabel:SetText("Position")

	local center = CreateButton(frame, "Center horizontally", 172)
	center:SetPoint("TOPLEFT", positionLabel, "BOTTOMLEFT", 0, -6)
	center:SetScript("OnClick", ns.CenterHorizontally)

	-- Up above Down, with Left and Right either side of Down.
	local down = CreateButton(frame, "Down", 56)
	down:SetPoint("TOP", center, "BOTTOM", 0, -30)
	down:SetScript("OnClick", function() ns.Nudge(0, -1) end)

	local up = CreateButton(frame, "Up", 56)
	up:SetPoint("BOTTOM", down, "TOP", 0, 2)
	up:SetScript("OnClick", function() ns.Nudge(0, 1) end)

	local left = CreateButton(frame, "Left", 56)
	left:SetPoint("RIGHT", down, "LEFT", -2, 0)
	left:SetScript("OnClick", function() ns.Nudge(-1, 0) end)

	local right = CreateButton(frame, "Right", 56)
	right:SetPoint("LEFT", down, "RIGHT", 2, 0)
	right:SetScript("OnClick", function() ns.Nudge(1, 0) end)

	local combatNote = ns.CreateText(frame, ns.Text.configRange)
	combatNote:SetPoint("BOTTOM", frame, "BOTTOM", 0, 10)
	combatNote:SetText("Settings are locked during combat")

	local controls = { lock, scaleSlider, scaleInput, widthSlider, widthInput, petWidthSlider, petWidthInput, center, up, down, left, right }

	local function SetControlsEnabled(enabled)
		if not enabled then
			scaleInput:ClearFocus()
			widthInput:ClearFocus()
			petWidthInput:ClearFocus()
		end
		for _, control in ipairs(controls) do
			control:SetEnabled(enabled)
		end
		combatNote:SetShown(not enabled)
	end

	frame:RegisterEvent("PLAYER_REGEN_DISABLED")
	frame:RegisterEvent("PLAYER_REGEN_ENABLED")
	frame:SetScript("OnEvent", function(_, event)
		SetControlsEnabled(event == "PLAYER_REGEN_ENABLED")
	end)

	frame:SetScript("OnShow", function()
		lock:SetChecked(ns.db.locked)
		syncScale()
		syncWidth()
		syncPetWidth()
		SetControlsEnabled(not InCombatLockdown())
	end)

	return frame
end

local config

SLASH_DIBSUI1 = "/dibsui"
SlashCmdList.DIBSUI = function()
	if not config then
		config = CreateConfig()
		config:Hide()
	end
	config:SetShown(not config:IsShown())
end
