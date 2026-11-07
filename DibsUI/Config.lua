local _, ns = ...

local Range = ns.ScaleRange

local function FormatScale(scale)
	return string.format("%.2f", scale)
end

local function CreateConfig()
	local frame = CreateFrame("Frame", "DibsUIConfig", UIParent, "BasicFrameTemplateWithInset")
	frame:SetSize(300, 170)
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

	frame.TitleText:SetFont(ns.Text.font, ns.Text.configTitle.size, ns.Text.outline)
	frame.TitleText:SetTextColor(1, 1, 1)
	frame.TitleText:SetText("DibsUI")

	local lock = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
	lock:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -32)
	lock.Text:SetFont(ns.Text.font, ns.Text.configLabel.size, ns.Text.outline)
	lock.Text:SetTextColor(1, 1, 1)
	lock.Text:SetText("Lock position")
	lock:SetScript("OnClick", function(self)
		ns.SetLocked(self:GetChecked())
	end)

	local scaleLabel = ns.CreateText(frame, ns.Text.configLabel)
	scaleLabel:SetPoint("TOPLEFT", lock, "BOTTOMLEFT", 6, -8)
	scaleLabel:SetText("Scale")

	local slider = CreateFrame("Slider", nil, frame, "UISliderTemplate")
	slider:SetSize(190, 17)
	slider:SetPoint("TOPLEFT", scaleLabel, "BOTTOMLEFT", 0, -8)
	slider:SetMinMaxValues(Range.min, Range.max)
	slider:SetValueStep(Range.step)
	slider:SetObeyStepOnDrag(true)

	local low = ns.CreateText(frame, ns.Text.configRange)
	low:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -2)
	low:SetText(FormatScale(Range.min))

	local high = ns.CreateText(frame, ns.Text.configRange)
	high:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", 0, -2)
	high:SetText(FormatScale(Range.max))

	local input = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
	input:SetSize(50, 20)
	input:SetPoint("LEFT", slider, "RIGHT", 14, 0)
	input:SetAutoFocus(false)
	input:SetMaxLetters(5)
	input:SetFont(ns.Text.font, ns.Text.configValue.size, ns.Text.outline)
	input:SetTextColor(1, 1, 1)

	-- The slider can only rest on its steps, while a typed scale can be exact. So moving the
	-- slider from code mustn't feed its snapped value back in as a new scale.
	local isSyncing = false

	local function Sync()
		isSyncing = true
		slider:SetValue(ns.db.scale)
		isSyncing = false
		input:SetText(FormatScale(ns.db.scale))
		input:SetCursorPosition(0)
	end

	slider:SetScript("OnValueChanged", function(_, value)
		if not isSyncing then
			ns.SetScale(value)
			input:SetText(FormatScale(ns.db.scale))
		end
	end)

	local function ApplyTyped(self)
		local value = tonumber(self:GetText())
		if value then
			ns.SetScale(value)
		end
		self:ClearFocus()
		Sync()
	end

	input:SetScript("OnEnterPressed", ApplyTyped)
	input:SetScript("OnEditFocusLost", function(self)
		self:HighlightText(0, 0)
		Sync()
	end)
	input:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
	end)

	local combatNote = ns.CreateText(frame, ns.Text.configRange)
	combatNote:SetPoint("BOTTOM", frame, "BOTTOM", 0, 10)
	combatNote:SetText("Settings are locked during combat")

	local function UpdateEnabled()
		local inCombat = InCombatLockdown()
		lock:SetEnabled(not inCombat)
		slider:SetEnabled(not inCombat)
		input:SetEnabled(not inCombat)
		combatNote:SetShown(inCombat)
	end

	frame:RegisterEvent("PLAYER_REGEN_DISABLED")
	frame:RegisterEvent("PLAYER_REGEN_ENABLED")
	frame:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_REGEN_DISABLED" then
			input:ClearFocus()
			lock:SetEnabled(false)
			slider:SetEnabled(false)
			input:SetEnabled(false)
			combatNote:Show()
		else
			UpdateEnabled()
		end
	end)

	frame:SetScript("OnShow", function()
		lock:SetChecked(ns.db.locked)
		Sync()
		UpdateEnabled()
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
