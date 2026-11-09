local _, ns = ...

-- How far outside the minimap's edge the button's centre sits.
local EDGE_OFFSET = 5

local button

-- Round minimaps put the button on a circle. Square ones, which some minimap addons make, put it
-- on the square's edge instead, so it doesn't float off a corner.
local function UpdatePosition()
	local angle = math.rad(ns.account.minimapAngle)
	local x, y = math.cos(angle), math.sin(angle)
	local radius = Minimap:GetWidth() / 2 + EDGE_OFFSET
	if GetMinimapShape and GetMinimapShape() == "SQUARE" then
		local scale = 1 / math.max(math.abs(x), math.abs(y))
		x, y = x * scale, y * scale
	end
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", x * radius, y * radius)
end

-- While dragging, the button follows the cursor around the minimap's edge.
local function FollowCursor()
	local centerX, centerY = Minimap:GetCenter()
	local cursorX, cursorY = GetCursorPosition()
	local scale = Minimap:GetEffectiveScale()
	ns.account.minimapAngle = math.deg(math.atan2(cursorY / scale - centerY, cursorX / scale - centerX)) % 360
	UpdatePosition()
end

function ns.CreateMinimapButton()
	button = CreateFrame("Button", "DibsUIMinimapButton", Minimap)
	button:SetSize(31, 31)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(8)
	button:RegisterForClicks("AnyUp")
	button:RegisterForDrag("LeftButton")
	button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	-- The usual round minimap button: a dark disc with the tracking border's ring over it.
	local background = button:CreateTexture(nil, "BACKGROUND")
	background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	background:SetSize(20, 20)
	background:SetPoint("TOPLEFT", 7, -5)

	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetTexture(ns.Media("MinimapIcon"))
	icon:SetSize(20, 20)
	icon:SetPoint("TOPLEFT", 7, -5)

	local border = button:CreateTexture(nil, "OVERLAY")
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetSize(53, 53)
	border:SetPoint("TOPLEFT")

	button:SetScript("OnClick", function()
		ns.ToggleConfig()
	end)

	button:SetScript("OnDragStart", function(self)
		self:LockHighlight()
		self:SetScript("OnUpdate", FollowCursor)
		GameTooltip:Hide()
	end)
	button:SetScript("OnDragStop", function(self)
		self:SetScript("OnUpdate", nil)
		self:UnlockHighlight()
	end)

	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText("DibsUI")
		GameTooltip:AddLine("Click to open the settings", 1, 1, 1)
		GameTooltip:AddLine("Drag to move this button", 1, 1, 1)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	UpdatePosition()
	button:SetShown(ns.account.showMinimapButton)
end

function ns.SetMinimapButtonShown(shown)
	ns.account.showMinimapButton = shown
	button:SetShown(shown)
end
