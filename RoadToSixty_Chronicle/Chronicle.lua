local addonName, ns = ...

-- Records what Road to Sixty does not, for Viewer/index.html. Road to Sixty
-- keeps the path, levels, quests, deaths, gear and groups; this adds where
-- party members were, subzones, XP and gold over time, flights and more.
-- Its own data lives in one account-wide file, so sharing a journey is two
-- files: SavedVariables/RoadToSixtyTogether.lua and RoadToSixty_Chronicle.lua.
--
-- Road to Sixty's namespace is private to it, so nothing here calls into it.
-- Settings.lua is the settings page; ns carries what it needs from this file.
--
--   RoadToSixtyChronicleDB = {
--     version, build (client build the maps were read from), interface
--     (the client's interface number, which tells the viewer which map art),
--     off = { [what] = true } tracking turned off: an event kind below, or
--     party or stats,
--     minimap = { angle, hide } the minimap button,
--     syncTests = results of /chron synctest, newest last,
--     friends = friends and their synced journeys, see Friends.lua,
--     maps  = { [uiMapID] = { name, parent, type, c, n1, w1, n2, w2 } }: every
--             map's world rectangle in yards, top left and bottom right
--             (north, west); c and on are nil for maps with no world position,
--     chars = { [GUID] = {
--       name, realm, race, sex, class, faction,
--       seen   = { [subzone] = true } places been, to mark first visits,
--       stats  = "t,level,xp,xpMax,rested,money;..." one row a minute, on change,
--       people = { [GUID] = { name, class, d = "t,c,x,y,level;..." } } where
--                party members were, sampled outdoors,
--       events = same shape as Road to Sixty's: { time, kind, c, x, y, ... }
--     } },
--   }
--
-- Times are the realm's clock, positions world yards (x north, y west), as
-- Road to Sixty saves them, so the two line up. Events inside instances use
-- the last outdoor position. Kinds and their fields from index 6 on:
--   env   build, interface         session start
--   sub   zone, subzone, first     moved to another subzone; first = true on
--                                  the character's first visit
--   taxi  from, to, cost           took a flight
--   tal   points                   talents changed: "Arms 5 / Fury 0 / Prot 0"
--   bind  place                    hearthstone bound
--   rest  on                       entered or left a rested area
--   npc   what, name               vendor, trainer, bank, auction or mail
--   trade name                     opened a trade with someone
--   shot                           took a screenshot
--   note  text                     /chron note
--
-- Anything may come back secret or be missing on one client or another, so
-- every client read goes through Safe and Clean, and a read that fails just
-- records nothing.

local VERSION = 1
local TRACK_INTERVAL = 15       -- seconds between samples of where the party is
local TRACK_MOVED = 30          -- yards a member must move to be written again
local TRACK_STILL = 300         -- seconds after which they are written anyway
local STATS_INTERVAL = 60       -- seconds between XP and gold samples
local PACK_INTERVAL = 60        -- seconds between writes of the buffers into their strings
local NPC_REPEAT = 300          -- seconds before the same NPC counts as a new visit
local MAP_DELAY = 5             -- seconds after login before reading the maps
local WORLD_MAP = 947
local MINIMAP_ANGLE = 170       -- where the minimap button starts, degrees
local COSMIC_MAP = 946

-- /chron synctest: how fast this client really moves addon messages between
-- two players, which decides what an in-game sync can carry. Rates are
-- messages a second. The stages stay small on purpose: a client can be
-- disconnected for sending too much, and these total under 16 KB.
local PREFIX = "RTSChronicle"
local TEST_LENGTH = 240         -- characters in each test message
local TEST_STAGES = { { rate = 1, count = 12 }, { rate = 2, count = 20 }, { rate = 4, count = 32 } }
local TEST_REST = 12            -- seconds between stages, for the client's allowance to refill
local TEST_WAIT = 6             -- seconds to wait for an answer
local TEST_GIVE_UP = 3          -- refused messages that end a stage early

local db, me
local ready = false
local position = {}             -- last outdoor position: c, x, y
local statsLast                 -- text of the last stats row, without its time
local statsBuffer, trackBuffers = {}, {}
local trackLast = {}            -- guid -> { c, x, y, t } last written
local npcLast = {}              -- name -> time last logged
local lastSub
local errors = 0

local function Clean(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

local function Drop(ok, ...)
    if ok then return ... end
end

-- What fn(...) gives, or nothing when it is missing or errors.
local function Safe(fn, ...)
    if fn then return Drop(pcall(fn, ...)) end
end

local function Print(msg)
    print("|cff33ff99Together|r: " .. msg)
end

-- Runs a handler, reporting the first error, so tracking never gets in the
-- way of the game or of Road to Sixty.
local function Guard(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then
        errors = errors + 1
        if errors == 1 then
            Print("|cffff4040Tracking hit an error: " .. tostring(err) .. "|r")
        end
    end
end

local function Now()
    local t = GetServerTime and GetServerTime()
    return t and t > 0 and t or time()
end

local function Round(v)
    return math.floor(v + 0.5)
end

-- Where unit is: continentID, world x, world y, or nil when hidden.
local function WorldOf(unit)
    local mapID = Clean(Safe(C_Map.GetBestMapForUnit, unit))
    if not mapID then return end
    local pos = Clean(Safe(C_Map.GetPlayerMapPosition, mapID, unit))
    if not pos or (pos.x == 0 and pos.y == 0) then return end
    local c, world = Safe(C_Map.GetWorldPosFromMapPos, mapID, pos)
    c, world = Clean(c), Clean(world)
    if not c or not world then return end
    return c, Round(world.x), Round(world.y)
end

local function Log(kind, ...)
    if db.off[kind] then return end
    if not IsInInstance() then
        local c, x, y = WorldOf("player")
        if c then position.c, position.x, position.y = c, x, y end
    end
    local e = { Now(), kind, position.c or -1, position.x or 0, position.y or 0, ... }
    table.insert(me.events, e)
    return e
end

-- Maps --------------------------------------------------------------------------

-- The world rectangle of a map: continent, then north and west of its top
-- left and bottom right corners.
local function MapRect(mapID)
    local c, a = Safe(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(0, 0))
    local _, b = Safe(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(1, 1))
    c, a, b = Clean(c), Clean(a), Clean(b)
    if c and a and b then return c, Round(a.x), Round(a.y), Round(b.x), Round(b.y) end
end

local function AddMap(mapID)
    local info = Clean(Safe(C_Map.GetMapInfo, mapID))
    if not info or not info.name then return end
    db.maps[mapID] = { info.name, info.parentMapID, info.mapType, MapRect(mapID) }
end

-- Reads every map once for each client build: the viewer has no game data,
-- so this is how it knows the names and where the zones are.
local function ReadMaps()
    local build = select(2, GetBuildInfo())
    if db.build == build and next(db.maps) then return end
    db.build = build
    for _, root in ipairs({ COSMIC_MAP, WORLD_MAP }) do
        AddMap(root)
        for _, info in ipairs(Safe(C_Map.GetMapChildrenInfo, root, nil, true) or {}) do
            AddMap(info.mapID)
        end
    end
end

-- Subzones ------------------------------------------------------------------------

local function CheckSub()
    local zone, sub = Clean(Safe(GetZoneText)) or "", Clean(Safe(GetSubZoneText)) or ""
    if zone == "" then return end
    local place = sub ~= "" and sub or zone
    if place == lastSub then return end
    lastSub = place
    local key = zone .. "/" .. place
    local first = not me.seen[key] or nil
    me.seen[key] = true
    Log("sub", zone, sub ~= "" and sub or nil, first)
end

-- XP and gold ----------------------------------------------------------------------

local function SampleStats()
    if db.off.stats then return end
    local xp, xpMax, money = UnitXP("player") or 0, UnitXPMax("player") or 0, GetMoney() or 0
    -- These all read 0 while logging out; a real row has at least an XP bar or gold.
    if xpMax == 0 and money == 0 then return end
    local row = ("%d,%d,%d,%d,%d"):format(UnitLevel("player") or 0, xp, xpMax, GetXPExhaustion() or 0, money)
    if row == statsLast then return end
    statsLast = row
    statsBuffer[#statsBuffer + 1] = Now() .. "," .. row .. ";"
end

-- Party positions ------------------------------------------------------------------

-- The units worth following: the party, or a raid's own subgroup, since
-- forty tracks would be most of the file and hardly any of the story.
local function TrackedUnits()
    local units = {}
    if IsInRaid() then
        local mine
        for i = 1, GetNumGroupMembers() do
            if UnitIsUnit("raid" .. i, "player") then
                mine = select(3, GetRaidRosterInfo(i))
            end
        end
        for i = 1, GetNumGroupMembers() do
            if select(3, GetRaidRosterInfo(i)) == mine and not UnitIsUnit("raid" .. i, "player") then
                units[#units + 1] = "raid" .. i
            end
        end
    else
        for i = 1, GetNumSubgroupMembers() do
            units[#units + 1] = "party" .. i
        end
    end
    return units
end

local function TrackUnit(unit, t)
    local guid = Clean(UnitGUID(unit))
    local name = Clean(UnitName(unit))
    if not guid or not name or name == UNKNOWNOBJECT or not UnitIsConnected(unit) then return end
    local c, x, y = WorldOf(unit)
    if not c then return end
    local last = trackLast[guid]
    if last and last[1] == c and t - last[4] < TRACK_STILL then
        local dx, dy = x - last[2], y - last[3]
        if dx * dx + dy * dy < TRACK_MOVED * TRACK_MOVED then return end
    end
    trackLast[guid] = { c, x, y, t }
    local p = me.people[guid]
    if not p then
        p = { d = "" }
        me.people[guid] = p
    end
    p.name, p.class = name, select(2, UnitClass(unit)) or p.class
    local buffer = trackBuffers[guid] or {}
    trackBuffers[guid] = buffer
    buffer[#buffer + 1] = ("%d,%d,%d,%d,%d;"):format(t, c, x, y, Clean(UnitLevel(unit)) or 0)
end

local function SampleParty()
    if db.off.party or IsInInstance() or not IsInGroup() then return end
    local t = Now()
    for _, unit in ipairs(TrackedUnits()) do
        TrackUnit(unit, t)
    end
end

local function Pack()
    if #statsBuffer > 0 then
        me.stats = me.stats .. table.concat(statsBuffer)
        wipe(statsBuffer)
    end
    for guid, buffer in pairs(trackBuffers) do
        if #buffer > 0 then
            local p = me.people[guid]
            p.d = p.d .. table.concat(buffer)
            wipe(buffer)
        end
    end
end

-- Talents ---------------------------------------------------------------------------

-- Classic clients give name, icon, points; newer ones id, name, text, icon, points.
local function TalentTab(i)
    local a, b, c, _, e = GetTalentTabInfo(i)
    if type(a) == "number" then return b, e end
    return a, c
end

local function CheckTalents(baseline)
    if not GetNumTalentTabs then return end
    local parts = {}
    for i = 1, GetNumTalentTabs() do
        local name, points = Safe(TalentTab, i)
        if name then parts[#parts + 1] = ("%s %d"):format(name, tonumber(points) or 0) end
    end
    local text = table.concat(parts, " / ")
    if text ~= "" and text ~= me.talents then
        if me.talents or not baseline then Log("tal", text) end
        me.talents = text
    end
end

-- Places ----------------------------------------------------------------------------

local function CheckBind()
    local place = Clean(Safe(GetBindLocation))
    if place and place ~= me.bind then
        me.bind = place
        Log("bind", place)
    end
end

local function NoteNPC(what)
    local name = Clean(Safe(UnitName, "npc")) or ""
    local t = Now()
    local key = what .. name
    if npcLast[key] and t - npcLast[key] < NPC_REPEAT then return end
    npcLast[key] = t
    Log("npc", what, name ~= "" and name or nil)
end

-- Which flight is being taken, from the open taxi map.
local function NoteTaxi(index)
    local from
    for i = 1, NumTaxiNodes() do
        if TaxiNodeGetType(i) == "CURRENT" then from = TaxiNodeName(i) end
    end
    Log("taxi", from, TaxiNodeName(index), TaxiNodeCost(index))
end

-- Sync test -------------------------------------------------------------------------

-- Messages, split by colons, each with the id of the test:
--   H:id                       are you there?
--   W:id:version:interface:in  yes; in = 1 inside an instance
--   D:id:stage:n:padding       a test message
--   E:id:stage                 that stage is over
--   A:id:stage:received:ms     how many came, over how many milliseconds
-- The other player needs Chronicle and nothing else: answering is automatic.

local test                      -- the test this client is running
local incoming = {}             -- sender -> { id, stage, received, first, last }

-- Sends one message. Returns true, or false and why: clients give nothing or
-- a boolean, or newer ones an Enum.SendAddonMessageResult, where 0 is success.
local function Send(text, channel, target)
    local send = C_ChatInfo and C_ChatInfo.SendAddonMessage or SendAddonMessage
    if not send then return false, "no addon messages on this client" end
    local ok, result = pcall(send, PREFIX, text, channel, target)
    if not ok then return false, tostring(result) end
    if result == false or (type(result) == "number" and result ~= 0) then
        return false, tostring(result)
    end
    return true
end

local function FinishTest()
    local t = test
    test = nil
    db.syncTests = db.syncTests or {}
    table.insert(db.syncTests, {
        t = Now(), channel = t.channel, target = t.target, peer = t.peer, interface = db.interface,
        inside = IsInInstance() and true or false, stages = t.results,
    })
    local best = 0
    for i, r in ipairs(t.results) do
        Print(("Stage %d, %d a second: sent %d, refused %d, arrived %s."):format(
            i, r.rate, r.sent, r.refused, r.received and tostring(r.received) or "no reply"))
        if r.refused == 0 and r.received == r.sent then
            best = math.max(best, r.rate * TEST_LENGTH)
        end
    end
    if best > 0 then
        Print(("Clean up to about %d bytes a second, so 125 KB would take about %d minutes."):format(
            best, math.ceil(125 * 1024 / best / 60)))
    else
        Print("No stage arrived whole.")
    end
    if t.why then Print("First refusal: " .. t.why) end
    Print("Saved. /reload writes it to RoadToSixty_Chronicle.lua, or paste these lines to share them.")
end

local RunStage

local function NextStage()
    if not test then return end
    test.stage = test.stage + 1
    if test.stage > #TEST_STAGES then
        FinishTest()
    else
        Print(("Stage %d of %d..."):format(test.stage, #TEST_STAGES))
        RunStage()
    end
end

-- The stage's result is in, or never coming.
local function EndStage(received, ms)
    local r = test and test.results[test.stage]
    if not r or r.done then return end
    r.done, r.received, r.ms = true, received, ms
    C_Timer.After(TEST_REST, function() Guard(NextStage) end)
end

function RunStage()
    local stage, id = test.stage, test.id
    local plan = TEST_STAGES[stage]
    local r = { rate = plan.rate, sent = 0, refused = 0 }
    test.results[stage] = r
    local function SendOne(n)
        if not test or test.id ~= id or r.refused >= TEST_GIVE_UP then return end
        local head = ("D:%s:%d:%d:"):format(id, stage, n)
        local ok, why = Send(head .. ("x"):rep(TEST_LENGTH - #head), test.channel, test.target)
        if ok then
            r.sent = r.sent + 1
        else
            r.refused = r.refused + 1
            test.why = test.why or why
        end
    end
    for n = 1, plan.count do
        C_Timer.After((n - 1) / plan.rate, function() Guard(SendOne, n) end)
    end
    local finished = plan.count / plan.rate + 1
    -- Sent twice, as the end of a throttled stage may be refused too.
    for _, delay in ipairs({ finished, finished + TEST_WAIT / 2 }) do
        C_Timer.After(delay, function()
            if test and test.id == id then Send(("E:%s:%d"):format(id, stage), test.channel, test.target) end
        end)
    end
    C_Timer.After(finished + TEST_WAIT, function()
        Guard(function()
            if test and test.id == id and test.stage == stage then EndStage(nil) end
        end)
    end)
end

local function StartTest(arg)
    local word = arg:upper()
    local channel = (word == "PARTY" or word == "RAID" or word == "GUILD") and word or "WHISPER"
    local id = ("%x"):format(Now() % 0xffffff)
    test = { id = id, channel = channel, target = channel == "WHISPER" and arg or nil, stage = 0, results = {} }
    Print(("Testing with %s. This takes about two minutes, keep playing."):format(arg))
    local ok, why = Send("H:" .. id, channel, test.target)
    if not ok then
        test = nil
        Print("|cffff4040Could not send: " .. tostring(why) .. "|r")
        return
    end
    C_Timer.After(TEST_WAIT, function()
        if test and test.id == id and test.stage == 0 then
            test = nil
            Print(("No answer from %s. They need Road to Sixty: Together on, must be online, and a whisper needs the exact name (and same faction)."):format(arg))
        end
    end)
end

-- Each message is answered or used only if it fits, as anyone can send one.
local function OnMessage(prefix, text, channel, sender)
    prefix, text, sender = Clean(prefix), Clean(text), Clean(sender)
    if prefix ~= PREFIX or type(text) ~= "string" or type(sender) ~= "string" then return end
    local short = Ambiguate and Ambiguate(sender, "none") or sender
    if short == UnitName("player") then return end
    local kind, id, a, b = text:match("^(%u):(%x+):?([^:]*):?([^:]*)")
    if not kind then return end
    local reply = channel == "WHISPER" and sender or nil
    if kind == "H" then
        incoming[sender] = { id = id, received = 0 }
        Send(("W:%s:%s:%d:%d"):format(id, VERSION, db.interface or 0, IsInInstance() and 1 or 0), channel, reply)
    elseif kind == "D" then
        local got = incoming[sender]
        if got and got.id == id then
            local now = GetTime()
            if got.stage ~= a then
                got.stage, got.received, got.first = a, 0, now
            end
            got.received, got.last = got.received + 1, now
        end
    elseif kind == "E" then
        local got = incoming[sender]
        if got and got.id == id then
            local same = got.stage == a
            Send(("A:%s:%s:%d:%d"):format(id, a, same and got.received or 0,
                same and Round((got.last - got.first) * 1000) or 0), channel, reply)
        end
    elseif test and test.id == id then
        if kind == "W" and test.stage == 0 then
            test.peer = short
            Print(("%s answered (Road to Sixty: Together version %s, interface %s)."):format(short, a, b))
            NextStage()
        elseif kind == "A" and tonumber(a) == test.stage then
            local received, ms = text:match("^A:%x+:%d+:(%d+):(%d+)$")
            if received then EndStage(tonumber(received), tonumber(ms)) end
        end
    end
end

-- Events ----------------------------------------------------------------------------

local frame = CreateFrame("Frame")
local handlers = {}

local function On(event, fn)
    if pcall(frame.RegisterEvent, frame, event) then handlers[event] = fn end
end

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" and ... == addonName then
        RoadToSixtyChronicleDB = RoadToSixtyChronicleDB or {}
        db = RoadToSixtyChronicleDB
        db.version = VERSION
        db.maps = db.maps or {}
        db.chars = db.chars or {}
        db.off = db.off or {}
        db.minimap = db.minimap or { angle = MINIMAP_ANGLE }
    elseif event == "PLAYER_LOGIN" then
        Guard(handlers.Login)
    elseif ready and handlers[event] then
        Guard(handlers[event], ...)
    end
end)
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

function handlers.Login()
    local guid = Clean(UnitGUID("player"))
    if not guid then return end
    me = db.chars[guid] or { events = {}, people = {}, seen = {}, stats = "" }
    db.chars[guid] = me
    me.name, me.realm = UnitName("player"), GetRealmName()
    me.race = select(2, UnitRace("player"))
    me.class = select(2, UnitClass("player"))
    me.faction = UnitFactionGroup("player")
    me.sex = UnitSex("player")
    local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    if loaded and Safe(loaded, "RoadToSixty") then
        Print("|cffff4040Road to Sixty is on as well. Turn it off in the AddOns list, as the two can't run together.|r")
    end
    me.stats = me.stats:gsub("%d+,%d+,0,0,0,0;", "")    -- rows 1.0.0 saved while logging out
    ready = true

    local _, build, _, interface = GetBuildInfo()
    db.interface = interface
    Log("env", build, interface)
    local register = C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix or RegisterAddonMessagePrefix
    if register then Safe(register, PREFIX) end
    CheckSub()
    SampleStats()
    C_Timer.After(MAP_DELAY, function()
        Guard(ReadMaps)
        Guard(CheckTalents, true)
        Guard(CheckBind)
    end)
    C_Timer.NewTicker(TRACK_INTERVAL, function() Guard(SampleParty) end)
    C_Timer.NewTicker(STATS_INTERVAL, function() Guard(SampleStats) end)
    C_Timer.NewTicker(PACK_INTERVAL, function() Guard(Pack) end)
    if hooksecurefunc and TakeTaxiNode then
        hooksecurefunc("TakeTaxiNode", function(index) Guard(NoteTaxi, index) end)
    end
end

On("PLAYER_LOGOUT", function()
    SampleStats()
    Pack()
end)
On("ZONE_CHANGED", CheckSub)
On("ZONE_CHANGED_INDOORS", CheckSub)
On("ZONE_CHANGED_NEW_AREA", CheckSub)
On("PLAYER_ENTERING_WORLD", CheckSub)
On("PLAYER_LEVEL_UP", SampleStats)
On("CHARACTER_POINTS_CHANGED", function() CheckTalents(false) end)
On("HEARTHSTONE_BOUND", CheckBind)
On("PLAYER_UPDATE_RESTING", function()
    local resting = IsResting() and true or false
    if resting ~= me.resting then
        me.resting = resting
        Log("rest", resting)
    end
end)
On("MERCHANT_SHOW", function() NoteNPC("vendor") end)
On("TRAINER_SHOW", function() NoteNPC("trainer") end)
On("BANKFRAME_OPENED", function() NoteNPC("bank") end)
On("AUCTION_HOUSE_SHOW", function() NoteNPC("auction") end)
On("MAIL_SHOW", function() NoteNPC("mail") end)
On("TRADE_SHOW", function()
    Log("trade", Clean(Safe(UnitName, "NPC")))
end)
On("SCREENSHOT_SUCCEEDED", function() Log("shot") end)
On("CHAT_MSG_ADDON", OnMessage)

-- For the settings page ---------------------------------------------------------------

function ns.Settings()
    return db.off
end

function ns.MinimapSettings()
    return db.minimap
end

function ns.TestRunning()
    return test ~= nil
end

ns.StartTest = StartTest
ns.Print, ns.Guard, ns.Now, ns.Clean = Print, Guard, Now, Clean

function ns.Status()
    if not me then return "Not ready yet." end
    Pack()
    local people = 0
    for _ in pairs(me.people) do people = people + 1 end
    return ("This character: %d events, %d party members tracked, %d errors this session."):format(
        #me.events, people, errors)
end

-- Commands --------------------------------------------------------------------------

SLASH_RTSCHRONICLE1 = "/chron"
SLASH_RTSCHRONICLE2 = "/chronicle"
SlashCmdList.RTSCHRONICLE = function(input)
    local cmd, rest = strtrim(input or ""):match("^(%S*)%s*(.-)$")
    cmd = cmd:lower()
    if not me then
        Print("Not ready yet.")
    elseif cmd == "note" and rest ~= "" then
        Log("note", rest)
        Print("Noted here: " .. rest)
    elseif cmd == "synctest" then
        if test then
            Print("A test is already running.")
        elseif rest == "" then
            Print("/chron synctest <name>, or party or guild. They need Road to Sixty: Together too.")
        else
            StartTest(rest)
        end
    elseif cmd == "friend" and rest ~= "" then
        ns.Friends:Add(rest)
    elseif cmd == "sync" and rest ~= "" then
        ns.Friends:Sync(rest)
    elseif cmd == "autosync" then
        if ns.Friends:ParseAutoSync(rest:lower()) then
            Print("Automatic sync: " .. (rest:lower() == "off" and "off" or "every " .. rest .. " minutes") .. ".")
        else
            Print("/chron autosync <5, 15, 30 or off>")
        end
    elseif cmd == "options" then
        ns.OpenSettings()
    elseif cmd == "export" then
        Pack()
        Print("The game writes saved data at logout or /reload. After that, send or drag in these two files from WTF\\Account\\<account>\\SavedVariables:")
        Print("  RoadToSixtyTogether.lua and RoadToSixty_Chronicle.lua")
    else
        Pack()
        local people = 0
        for _ in pairs(me.people) do people = people + 1 end
        Print(("%d events, %d party members tracked, %d KB of XP and gold, %d errors."):format(
            #me.events, people, math.floor(#me.stats / 1024), errors))
        Print("/chron options - open the settings page")
        Print("/chron note <text> - pin a note here on the map")
        Print("/chron export - how to get your journey out of the game")
        Print("/chron friend <name> - share with a friend and sync their journey")
        Print("/chron sync <name> - sync a friend's journey again")
        Print("/chron autosync <5, 15, 30 or off> - sync with online friends every so many minutes")
        Print("/chron synctest <name> - measure addon messages with another player")
    end
end
