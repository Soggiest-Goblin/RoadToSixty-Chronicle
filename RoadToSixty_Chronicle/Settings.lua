local _, ns = ...

-- Settings page in the game's settings, under AddOns > Road to Sixty:
-- Chronicle, built the way Road to Sixty's own page is. Opened with
-- /chron options.
--
-- The Road to Sixty sections read and write RoadToSixtyDB, the same values
-- its own page uses, so the two pages always agree. Its code is private, so
-- nothing here can redraw an open map: changes show the next time the map
-- opens. Keep ROAD_TO_SIXTY in step with SECTIONS in its Options.lua.

local TITLE = "Road to Sixty: Chronicle"
local LEFT = 16          -- panel's left margin
local SECTION_GAP = 18   -- space above each section heading
local ROW = 30           -- height of one checkbox row
local BUTTON_WIDTH = 160

local panel, category
local body               -- what the panel scrolls; everything is built on it
local checks = {}        -- checkbox -> its option
local radios = {}        -- radio button -> { option, the choice it stands for }
local statusText
local y                  -- where the next piece goes, below the panel's top

local function RTS()
    return RoadToSixtyDB
end

-- An option backed by one of Road to Sixty's settings.
local function Shared(key, label, tip)
    return {
        label = label,
        tip = tip,
        get = function() return RTS()[key] end,
        set = function(on) RTS()[key] = on end,
    }
end

-- An option that turns a kind of tracking on or off.
local function Track(key, label, tip)
    return {
        label = label,
        tip = tip,
        get = function() return not ns.Settings()[key] end,
        set = function(on) ns.Settings()[key] = not on or nil end,
    }
end

local ROAD_TO_SIXTY = {
    {
        title = "General",
        {
            label = "Show the minimap button",
            tip = "Left-click it to open the journey map, right-click for Road to Sixty's options. Drag it to move it.",
            get = function() return not RTS().minimap.hide end,
            -- Its command is the one way to show or hide the button right away.
            set = function(on)
                if RTS().minimap.hide == on then SlashCmdList.ROADTOSIXTY("minimap") end
            end,
        },
        Shared("greet", "Show the welcome message at login",
            "A line in chat each login saying your journey is being recorded."),
        Shared("levelChat", "Show a summary in chat at each level up",
            "Where you reached the level, how long the last one took, and its kills, quests, deaths, distance walked and money."),
        Shared("levelShot", "Take a screenshot at each level up",
            "Saved in the game's Screenshots folder, as Print Screen does."),
    },
    {
        title = "Journey map",
        Shared("terrain", "Show terrain", "Draw the land under your path. Off shows the plain parchment map."),
        Shared("cityArt", "Show city street plans",
            "With terrain off, the capitals show their own street plans when you zoom in. Off shows the land around them instead."),
        Shared("motes", "Show sparkles along the path", "Small motes of light drifting along your journey."),
        Shared("questPops", "Show quest turn-ins during the replay",
            "A golden quest mark pops up where you handed in each quest, with its name and experience, as the replay passes it."),
        Shared("killPops", "Show kills during the replay",
            "Each kill pops up at the arrow with its experience and the creature's name, counting up when you kill several in a row."),
        Shared("killMarks", "Show where you killed",
            "A faint mark on the map for every kill. One kill barely shows, but the places you ground for a while stand out."),
        Shared("showGear", "Show gear during the replay",
            "A card in the map's corner showing what you wore, changing as the replay plays."),
    },
    {
        title = "Gear screen",
        {
            label = "Item bars",
            -- { key, name, tip }
            choices = {
                { "classic", "Classic", "A plain bar in the item's colour." },
                { "glow", "Glow", "The bar glows in the item's colour from where you put it on, with fire running over it." },
                { "edges", "Fire edges", "Fire along the top and bottom edges, the middle clear for the name." },
                { "both", "Glow and fire edges", "The glow, with fire along both edges." },
                { "comet", "Comet", "A flare where you put the item on, its fire trailing to the end, on a dark bar." },
            },
            get = function() return RTS().gearBars end,
            set = function(key) RTS().gearBars = key end,
        },
    },
}

local BUTTON = {
    label = "Show the Chronicle minimap button",
    tip = "Left-click it to open the journey map, right-click for this page. Drag it to move it.",
    get = function() return not ns.MinimapSettings().hide end,
    set = function(on)
        ns.MinimapSettings().hide = not on
        ns.MinimapButton:Refresh()
    end,
}

local TRACKING = {
    Track("party", "Where party members were", "Their positions while you group outdoors, so a replay can show who travelled with you."),
    Track("stats", "XP and gold over time", "A sample each minute, when something has changed."),
    Track("sub", "Subzones and first visits", "Each subzone you enter, marking the first time you see it."),
    Track("taxi", "Flights", "Where each flight started and ended, and what it cost."),
    Track("tal", "Talents", "Your talent points whenever they change."),
    Track("bind", "Hearthstone", "Each new place your hearthstone is bound."),
    Track("rest", "Rested areas", "When you enter and leave inns and cities."),
    Track("npc", "Town visits", "Vendors, trainers, banks, auction houses and mailboxes you use."),
    Track("trade", "Trades", "Who you opened a trade with."),
    Track("shot", "Screenshots", "Where you took each screenshot."),
}

-- Every other character on the account, the most recently seen first.
local function OtherCharacters()
    local list, me = {}, UnitGUID("player")
    for key, e in pairs(RTS().roster or {}) do
        if key ~= me then list[#list + 1] = { key = key, name = e.name or key, realm = e.realm, level = e.level, seen = e.seen or 0 } end
    end
    table.sort(list, function(a, b) return a.seen > b.seen end)
    return list
end

local function CharacterOption(c)
    return {
        label = ("%s, level %s, %s"):format(c.name, c.level or "?", c.realm or "unknown realm"),
        tip = "Draw this character's path on the journey map. Same as the path checkbox in the map's character list.",
        get = function() return RTS().showPaths[c.key] == true end,
        set = function(on) RTS().showPaths[c.key] = on or nil end,
    }
end

local function ShowTip(owner, title, text)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:AddLine(title)
    GameTooltip:AddLine(text, 1, 1, 1, true)
    GameTooltip:Show()
end

-- Closes the settings window, so a window opened from it is not hidden behind.
local function CloseSettings()
    for _, window in ipairs({ SettingsPanel, InterfaceOptionsFrame }) do
        if window and window:IsShown() then
            HideUIPanel(window)
        end
    end
end

local function UpdateStatus()
    statusText:SetText(ns.Status())
end

-- A gold heading with a thin rule under it.
local function Heading(text)
    y = y - SECTION_GAP
    local heading = body:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    heading:SetPoint("TOPLEFT", LEFT, y)
    heading:SetText(text)

    local rule = body:CreateTexture(nil, "ARTWORK")
    rule:SetColorTexture(1, 0.82, 0, 0.25)
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", LEFT, y - 16)
    rule:SetPoint("TOPRIGHT", -LEFT, y - 16)
    y = y - 22
end

-- A line of small text under a heading.
local function Note(text)
    local note = body:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", LEFT, y)
    note:SetPoint("TOPRIGHT", -LEFT, y)
    note:SetJustifyH("LEFT")
    note:SetText(text)
    y = y - 34
end

local function Check(option)
    local check = CreateFrame("CheckButton", nil, body, "UICheckButtonTemplate")
    check:SetSize(26, 26)
    check:SetPoint("TOPLEFT", LEFT - 2, y)
    y = y - ROW

    local label = check:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("LEFT", check, "RIGHT", 4, 1)
    label:SetText(option.label)
    check:SetHitRectInsets(0, -label:GetStringWidth() - 8, 0, 0)

    check:SetScript("OnClick", function(self)
        option.set(self:GetChecked() and true or false)
    end)
    check:SetScript("OnEnter", function(self) ShowTip(self, option.label, option.tip) end)
    check:SetScript("OnLeave", GameTooltip_Hide)
    checks[check] = option
end

-- A choice of a few: its label, then a radio button for each on a line of
-- its own, so none is cut off in a narrow window.
local function Choice(option)
    local label = body:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("TOPLEFT", LEFT + 2, y - 6)
    label:SetText(option.label .. ":")
    y = y - 26
    for _, choice in ipairs(option.choices) do
        local radio = CreateFrame("CheckButton", nil, body, "UIRadioButtonTemplate")
        radio:SetSize(18, 18)
        radio:SetPoint("TOPLEFT", LEFT + 14, y)
        y = y - 24
        radio.text = radio:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        radio.text:SetPoint("LEFT", radio, "RIGHT", 4, 1)
        radio.text:SetText(choice[2])
        radio:SetHitRectInsets(0, -radio.text:GetStringWidth() - 6, 0, 0)
        radio:SetScript("OnClick", function()
            option.set(choice[1])
            for other, r in pairs(radios) do
                if r[1] == option then other:SetChecked(r[2] == choice[1]) end
            end
        end)
        radio:SetScript("OnEnter", function(self) ShowTip(self, choice[2], choice[3]) end)
        radio:SetScript("OnLeave", GameTooltip_Hide)
        radios[radio] = { option, choice[1] }
    end
    y = y - 6
end

local function Button(text, width, onClick)
    local button = CreateFrame("Button", nil, body, "UIPanelButtonTemplate")
    button:SetSize(width or BUTTON_WIDTH, 22)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

local function Refresh()
    if not statusText then return end
    for check, option in pairs(checks) do
        check:SetChecked(option.get())
    end
    for radio, r in pairs(radios) do
        radio:SetChecked(r[1].get() == r[2])
    end
    UpdateStatus()
end

-- Which of the roster's characters the map draws, synced friends included.
local function BuildCharacters()
    Heading("Characters on the map")
    local others = OtherCharacters()
    if #others == 0 then
        Note("Your other characters appear here once they have logged in with Road to Sixty.")
        return
    end
    local function ShowAll(on)
        for _, c in ipairs(others) do
            RTS().showPaths[c.key] = on or nil
        end
        Refresh()
    end
    local all = Button("Show all", 120, function() ShowAll(true) end)
    all:SetPoint("TOPLEFT", LEFT, y)
    local mine = Button("Just this character", 160, function() ShowAll(false) end)
    mine:SetPoint("LEFT", all, "RIGHT", 8, 0)
    y = y - 30
    for _, c in ipairs(others) do
        Check(CharacterOption(c))
    end
end

-- Friends are added and synced in the map's Synced friends tab.
local function BuildFriends()
    Heading("Friends")
    Note("Add friends in the Synced friends tab on the journey map. This test measures how fast two players can send data. Both players need Chronicle.")
    local box = CreateFrame("EditBox", nil, body, "InputBoxTemplate")
    box:SetSize(150, 22)
    box:SetPoint("TOPLEFT", LEFT + 6, y)
    box:SetAutoFocus(false)
    box:SetScript("OnEscapePressed", box.ClearFocus)
    box:SetScript("OnEnterPressed", box.ClearFocus)
    local run = Button("Run sync test", 120, function()
        local target = strtrim(box:GetText() or "")
        if target ~= "" and not ns.TestRunning() then ns.StartTest(target) end
    end)
    run:SetPoint("LEFT", box, "RIGHT", 8, 0)
    run:SetScript("OnEnter", function(self)
        ShowTip(self, "Run sync test", "Type a character's name, or party or guild. It takes about two minutes and the results appear in chat.")
    end)
    run:SetScript("OnLeave", GameTooltip_Hide)
    y = y - 30
end

-- The scrolling part of the panel: the game's scroll frame with its bar at
-- the right; body is as wide as the panel and as tall as what is built on it.
local function CreateBody()
    local ok, scroll = pcall(CreateFrame, "ScrollFrame", nil, panel, "ScrollFrameTemplate")
    if not ok then
        scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    end
    scroll:SetPoint("TOPLEFT", 0, -4)
    scroll:SetPoint("BOTTOMRIGHT", -26, 4)
    body = CreateFrame("Frame", nil, scroll)
    body:SetSize(math.max(400, scroll:GetWidth()), 600)
    scroll:SetScrollChild(body)
    scroll:SetScript("OnSizeChanged", function(_, width)
        body:SetWidth(math.max(400, width))
    end)
end

local function Build()
    CreateBody()
    local title = body:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", LEFT, -16)
    title:SetText(TITLE)

    local notes = body:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    notes:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    notes:SetText("Everything in Road to Sixty, plus Chronicle's extra tracking.")

    y = -50
    BuildCharacters()
    BuildFriends()

    Heading("Chronicle tracking")
    Check(BUTTON)
    for _, option in ipairs(TRACKING) do
        Check(option)
    end

    for _, section in ipairs(ROAD_TO_SIXTY) do
        Heading(section.title)
        for _, option in ipairs(section) do
            ---@diagnostic disable-next-line: undefined-field
            if option.choices then Choice(option) else Check(option) end
        end
    end
    Note("These match Road to Sixty's own page, and changes show the next time the map opens.")

    Heading("Journey")
    local mapButton = Button("Open journey map", nil, function()
        CloseSettings()
        SlashCmdList.ROADTOSIXTY("map")
    end)
    mapButton:SetPoint("TOPLEFT", LEFT, y)

    statusText = body:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    statusText:SetPoint("TOPLEFT", LEFT, y - 32)
    statusText:SetPoint("TOPRIGHT", -LEFT, y - 32)
    statusText:SetJustifyH("LEFT")
    statusText:SetJustifyV("TOP")
    y = y - 32 - 24

    local help = body:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    help:SetPoint("TOPLEFT", LEFT, y)
    help:SetText("Type /chron in chat for the commands.")
    body:SetHeight(-y + 40)
end

function ns.OpenSettings()
    if Settings and Settings.OpenToCategory and category then
        Settings.OpenToCategory(category:GetID())
    elseif InterfaceOptionsFrame_OpenToCategory then
        -- The old options window often opens on the wrong page the first time.
        InterfaceOptionsFrame_OpenToCategory(panel)
        InterfaceOptionsFrame_OpenToCategory(panel)
    end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    panel = CreateFrame("Frame")
    panel:Hide()
    panel.name = TITLE
    panel:SetScript("OnShow", function()
        if not statusText then Build() end
        Refresh()
    end)

    if Settings and Settings.RegisterCanvasLayoutCategory then
        category = Settings.RegisterCanvasLayoutCategory(panel, TITLE)
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end)
