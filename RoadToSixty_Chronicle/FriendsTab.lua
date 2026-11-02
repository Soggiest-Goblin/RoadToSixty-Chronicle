local _, ns = ...

-- The Synced friends tab on the journey map, beside History and Characters.
--
-- Road to Sixty's code is private, so this finds its pieces from the outside:
-- the window by its global name, the tabs by their label and underline, and a
-- character row, whose click scripts are the one way to show a journey or
-- redraw the paths. If those ever change, the tab stays out of the way and
-- Friends.lua keeps syncing. Asking Road to Sixty for a public way to do these
-- is in docs/DESIGN.md.

local WINDOW = "RoadToSixtyJourneyFrame"
local TITLE = "Synced friends"
local TAB_HEIGHT = 24
local ROW = 70
local WAIT = 1                  -- seconds between looks for the map, built on first open
local WIDTHS = { History = 70, Characters = 90 }
local TAB_WIDTH = 120
local TIP = "Add a friend and have them add you. Your current character's journey is shared with friends you add, including who you grouped with."

local mapPanel                  -- Road to Sixty's side panel
local pane, list, empty
local tab, otherTabs, otherPanes
local rows = {}

local function FindPanel(window)
    for _, child in ipairs({ window:GetChildren() }) do
        local tabs, panes = {}, {}
        for _, piece in ipairs({ child:GetChildren() }) do
            if piece.label and piece.underline then
                tabs[#tabs + 1] = piece
            elseif piece:GetObjectType() == "Frame" then
                panes[#panes + 1] = piece
            end
        end
        if #tabs == 2 and #panes == 2 then return child, tabs, panes end
    end
end

-- A row of the Characters tab: any will do, as their scripts use one entry.
local function FindRow(parent, depth)
    for _, child in ipairs({ parent:GetChildren() }) do
        if child.pathToggle then return child end
        if depth < 3 then
            local row = FindRow(child, depth + 1)
            if row then return row end
        end
    end
end

local function ShowJourney(rec)
    local row = FindRow(mapPanel, 0)
    local click = row and row:GetScript("OnClick")
    if not click or not pcall(click, { entry = rec }) then
        ns.Print(rec.name .. "'s journey is in the Characters tab.")
    end
end

-- Turns a friend's path on, redrawing the map when it can.
local function SetPath(rec, on)
    RoadToSixtyDB.showPaths[rec.key] = on or nil
    local row = FindRow(mapPanel, 0)
    local click = row and row.pathToggle:GetScript("OnClick")
    if click then
        local entry = row.entry
        row.entry = rec
        pcall(click, { GetChecked = function() return on end })
        row.entry = entry
    end
end

local function SelectTab(selected)
    pane:SetShown(selected)
    tab.label:SetTextColor(unpack(selected and { 1, 0.82, 0 } or { 0.6, 0.6, 0.6 }))
    tab.underline:SetShown(selected)
    if selected then
        for _, other in ipairs(otherTabs) do
            other.label:SetTextColor(0.6, 0.6, 0.6)
            other.underline:Hide()
        end
        for _, other in ipairs(otherPanes) do other:Hide() end
    end
end

local function CreateRow()
    local row = CreateFrame("Button", nil, list)
    row:SetHeight(ROW - 4)

    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.08)

    row.title = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.title:SetPoint("TOPLEFT", 4, -3)
    row.title:SetPoint("RIGHT", -4, 0)
    row.title:SetJustifyH("LEFT")

    row.detail = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.detail:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -2)
    row.detail:SetPoint("RIGHT", -4, 0)
    row.detail:SetJustifyH("LEFT")
    row.detail:SetWordWrap(false)

    row.sync = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.sync:SetSize(58, 20)
    row.sync:SetPoint("BOTTOMLEFT", 2, 3)
    row.sync:SetText("Sync")
    row.sync:SetScript("OnClick", function() ns.Friends:Sync(row.rec.name) end)

    row.remove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.remove:SetSize(70, 20)
    row.remove:SetPoint("LEFT", row.sync, "RIGHT", 4, 0)
    row.remove:SetText("Remove")
    row.remove:SetScript("OnClick", function() ns.Friends:Remove(row.rec.name) end)
    row.remove:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Delete their journey here and stop sharing with them")
        GameTooltip:Show()
    end)
    row.remove:SetScript("OnLeave", GameTooltip_Hide)

    row.path = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    row.path:SetSize(22, 22)
    row.path:SetPoint("BOTTOMRIGHT", -2, 2)
    row.path:SetScript("OnClick", function(self) SetPath(row.rec, self:GetChecked() and true or false) end)
    row.path:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Show this friend's path")
        GameTooltip:Show()
    end)
    row.path:SetScript("OnLeave", GameTooltip_Hide)

    row:SetScript("OnClick", function(self)
        if self.rec.journey and self.rec.key then ShowJourney(self.rec) end
    end)
    row:SetScript("OnEnter", function(self)
        if not self.rec.journey then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Click to show " .. self.rec.name .. "'s journey")
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)
    return row
end

local function Refresh()
    if not pane then return end
    local friends = ns.Friends:List()
    local busy = ns.Friends:Busy()
    for i, rec in ipairs(friends) do
        local row = rows[i]
        if not row then
            row = CreateRow()
            row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW)
            row:SetPoint("RIGHT")
            rows[i] = row
        end
        row.rec = rec
        local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[rec.class or ""]
        row.title:SetText(rec.level and ("%s  |cffffffff%d|r"):format(rec.name, rec.level) or rec.name)
        row.title:SetTextColor(color and color.r or 1, color and color.g or 1, color and color.b or 1)
        row.detail:SetText(ns.Friends:Status(rec))
        row.sync:SetEnabled(not busy)
        row.path:SetShown(rec.key ~= nil)
        row.path:SetChecked(rec.key ~= nil and RoadToSixtyDB.showPaths[rec.key] == true)
        row:Show()
    end
    for i = #friends + 1, #rows do rows[i]:Hide() end
    list:SetHeight(math.max(1, #friends * ROW))
    empty:SetShown(#friends == 0)
end

local function CreatePane(parent)
    pane = CreateFrame("Frame", nil, parent)
    pane:SetPoint("TOPLEFT", 6, -TAB_HEIGHT - 8)
    pane:SetPoint("BOTTOMRIGHT", -6, 6)
    pane:Hide()

    local box = CreateFrame("EditBox", nil, pane, "InputBoxTemplate")
    box:SetSize(170, 22)
    box:SetPoint("TOPLEFT", 8, -2)
    box:SetAutoFocus(false)
    local function Add()
        local name = box:GetText() or ""
        box:SetText("")
        box:ClearFocus()
        ns.Friends:Add(name)
    end
    box:SetScript("OnEscapePressed", box.ClearFocus)
    box:SetScript("OnEnterPressed", Add)

    local add = CreateFrame("Button", nil, pane, "UIPanelButtonTemplate")
    add:SetSize(70, 22)
    add:SetPoint("TOPRIGHT", 0, -2)
    add:SetText("Add")
    add:SetScript("OnClick", Add)
    add:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(TITLE)
        GameTooltip:AddLine(TIP, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    add:SetScript("OnLeave", GameTooltip_Hide)

    local ok, scroll = pcall(CreateFrame, "ScrollFrame", nil, pane, "ScrollFrameTemplate")
    if not ok then
        scroll = CreateFrame("ScrollFrame", nil, pane, "UIPanelScrollFrameTemplate")
    end
    scroll:SetPoint("TOPLEFT", 0, -32)
    scroll:SetPoint("BOTTOMRIGHT", -24, 0)
    list = CreateFrame("Frame", nil, scroll)
    list:SetSize(pane:GetWidth() - 24, 1)
    scroll:SetScrollChild(list)
    scroll:SetScript("OnSizeChanged", function(_, width) list:SetWidth(width) end)

    empty = pane:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    empty:SetPoint("TOPLEFT", 8, -40)
    empty:SetPoint("RIGHT", -8, 0)
    empty:SetJustifyH("LEFT")
    empty:SetJustifyV("TOP")
    empty:SetText(TIP)
end

-- Adds the tab to the window. False if the panel isn't as expected.
local function Attach(window)
    local parent, tabs, panes = FindPanel(window)
    if not parent then return false end
    mapPanel, otherTabs, otherPanes = parent, tabs, panes

    local x = 0
    table.sort(tabs, function(a, b) return a.label:GetText() == "History" and b.label:GetText() ~= "History" end)
    for _, other in ipairs(tabs) do
        local width = WIDTHS[other.label:GetText()] or 80
        other:SetWidth(width)
        other:ClearAllPoints()
        other:SetPoint("TOPLEFT", x, 0)
        x = x + width
        other:HookScript("OnClick", function() SelectTab(false) end)
    end

    tab = CreateFrame("Button", nil, parent)
    tab:SetSize(TAB_WIDTH, TAB_HEIGHT)
    tab:SetPoint("TOPLEFT", x, 0)
    tab.label = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tab.label:SetPoint("CENTER", 0, 1)
    tab.label:SetText(TITLE)
    tab.underline = tab:CreateTexture(nil, "OVERLAY")
    tab.underline:SetPoint("BOTTOMLEFT", 12, 0)
    tab.underline:SetPoint("BOTTOMRIGHT", -12, 0)
    tab.underline:SetHeight(2)
    tab.underline:SetColorTexture(1, 0.82, 0, 0.9)
    local highlight = tab:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.06)

    CreatePane(parent)
    tab:SetScript("OnClick", function()
        SelectTab(true)
        Refresh()
    end)
    SelectTab(false)
    Refresh()
    return true
end

local function Look()
    local window = _G[WINDOW]
    if window and not mapPanel then
        -- Once the window exists, one look settles it either way.
        ns.Guard(function()
            if not Attach(window) then ns.Print("The Synced friends tab couldn't join this version of the map.") end
        end)
        return
    end
    if not window then C_Timer.After(WAIT, Look) end
end

ns.Friends.OnChange = Refresh

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", Look)
