local _, ns = ...

-- Minimap button, like Road to Sixty's and starting apart from it. Left-click
-- opens the journey map, right-click the settings page; drag moves it around
-- the minimap.

local MinimapButton = {}
ns.MinimapButton = MinimapButton

local ICON = "Interface\\Icons\\INV_Misc_Book_09"
local button

local function Place()
    local angle = math.rad(ns.MinimapSettings().angle)
    local radius = Minimap:GetWidth() / 2 + 5
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

-- While dragging, follow the cursor's angle around the minimap's centre.
local function FollowCursor()
    local mx, my = Minimap:GetCenter()
    local scale = Minimap:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    ns.MinimapSettings().angle = math.deg(math.atan2(cy / scale - my, cx / scale - mx)) % 360
    Place()
end

local function ShowTooltip(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    GameTooltip:AddLine("Road to Sixty: With Friends")
    GameTooltip:AddLine("Left-click: open the journey map", 1, 1, 1)
    GameTooltip:AddLine("Right-click: With Friends settings", 1, 1, 1)
    GameTooltip:AddLine("Drag: move this button", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end

local function Create()
    button = CreateFrame("Button", "RoadToSixtyChronicleMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetSize(20, 20)
    background:SetPoint("TOPLEFT", 7, -5)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(ICON)
    icon:SetSize(18, 18)
    icon:SetPoint("TOPLEFT", 7, -6)
    -- Cut the icon's own square border so it sits inside the round frame.
    icon:SetTexCoord(0.06, 0.94, 0.06, 0.94)

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")

    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            ns.OpenSettings()
        else
            SlashCmdList.ROADTOSIXTY("map")
        end
    end)
    button:SetScript("OnEnter", ShowTooltip)
    button:SetScript("OnLeave", GameTooltip_Hide)
    -- Nudge the icon while pressed, like Blizzard's buttons.
    button:SetScript("OnMouseDown", function() icon:SetPoint("TOPLEFT", 8, -7) end)
    button:SetScript("OnMouseUp", function() icon:SetPoint("TOPLEFT", 7, -6) end)
    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", FollowCursor)
        GameTooltip_Hide()
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        icon:SetPoint("TOPLEFT", 7, -6)
    end)

    Place()
end

-- Shows or hides the button to match the saved setting.
function MinimapButton:Refresh()
    if ns.MinimapSettings().hide then
        if button then button:Hide() end
        return
    end
    if not button then Create() end
    button:Show()
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    MinimapButton:Refresh()
end)
