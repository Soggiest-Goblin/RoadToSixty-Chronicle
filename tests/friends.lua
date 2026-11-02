-- Two clients syncing journeys through Friends.lua, with a modelled server,
-- and FriendsTab.lua against stand-in widgets of Road to Sixty's side panel.
local clock, queue, seq = 0, {}, 0
local function At(d, f) seq = seq + 1; queue[#queue + 1] = { t = clock + d, n = seq, f = f } end
local function Run()
  while #queue > 0 do
    table.sort(queue, function(a, b) if a.t ~= b.t then return a.t < b.t end return a.n < b.n end)
    local e = table.remove(queue, 1); clock = e.t; e.f()
  end
end

local clients = {}
local dropEvery                 -- every nth batch message is lost when set
local carried = 0

local function Widget(kind, parent, c)
  local w = { kind = kind, parent = parent, scripts = {}, kids = {}, checked = false }
  if parent and parent.kids then parent.kids[#parent.kids + 1] = w end
  function w:SetScript(name, fn) self.scripts[name] = fn end
  function w:GetScript(name) return self.scripts[name] end
  function w:HookScript(name, fn)
    local before = self.scripts[name]
    self.scripts[name] = function(...) if before then before(...) end fn(...) end
  end
  function w:Show() self.shown = true end
  function w:Hide() self.shown = false end
  function w:SetShown(on) self.shown = on and true or false end
  function w:SetChecked(on) self.checked = on and true or false end
  function w:GetChecked() return self.checked end
  function w:SetText(text) self.text = text end
  function w:GetText() return self.text end
  function w:GetWidth() return 268 end
  function w:GetObjectType() return kind end
  function w:GetChildren() return table.unpack(self.kids) end
  function w:CreateFontString() return Widget("text", nil, c) end
  function w:CreateTexture() return Widget("texture", nil, c) end
  return setmetatable(w, { __index = function(_, key)
    if key == "label" or key == "underline" or key == "pathToggle" or key == "entry" or key == "rec" then return nil end
    return function() end
  end })
end

local function Client(name, other, guid)
  local c = { printed = {}, frames = {}, sentMax = 0 }
  local env = setmetatable({}, { __index = _G })
  c.env = env
  env._G = env
  env.print =function(s) c.printed[#c.printed + 1] = tostring(s) end
  env.strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
  env.GetTime = function() return clock end
  env.date = function() return "Nov 02" end
  env.C_Timer = { After = function(d, f) At(d, f) end }
  env.UnitGUID = function() return guid end
  env.UnitName = function() return name end
  env.UnitClass = function() return "Paladin", "PALADIN" end
  env.UnitLevel = function() return 12 end
  env.GetRealmName = function() return "Era" end
  env.Ambiguate = function(n) return (n:gsub("%-.*", "")) end
  env.CreateFrame = function(kind, _, parent)
    local w = Widget(kind, parent, c)
    c.frames[#c.frames + 1] = w
    return w
  end
  env.GameTooltip = Widget("Tooltip")
  env.RoadToSixtyChronicleDB = {}
  env.RoadToSixtyDB = { showPaths = {}, roster = {
    [guid] = { name = name, realm = "Era", c = 0, x = 10, y = 20, zone = 1429 } } }
  env.C_ChatInfo = {
    RegisterAddonMessagePrefix = function(p) assert(#p <= 16, "prefix too long") return true end,
    SendAddonMessage = function(prefix, text, channel, target)
      assert(not text:find("\0", 1, true), "null in message")
      if #text > 255 then error("message too long: " .. #text) end
      c.sentMax = math.max(c.sentMax, #text)
      if target:gsub("%-.*", ""):lower() ~= other:lower() then return true end
      carried = carried + 1
      if dropEvery and text:sub(1, 1) == "B" and carried % dropEvery == 0 then return true end
      if text:sub(1, 1) == "Q" then clients[other].lastAsked = text:match("^Q:(%x+)") end
      At(0.05, function()
        if c.offline or clients[other].offline or clients[other].mute then return end
        clients[other].event("CHAT_MSG_ADDON", prefix, text, channel, name .. "-Era")
      end)
      return true
    end,
  }
  local ns = { Print = env.print, Guard = function(fn, ...) assert(xpcall(fn, debug.traceback, ...)) end,
    Now = function() return 1785000000 + math.floor(clock) end, Clean = function(v) return v end }
  c.ns = ns
  assert(load(FRIENDS_SRC, "Friends.lua", "t", env))("RoadToSixty_Chronicle", ns)
  function c.event(event, ...)
    for _, f in ipairs(c.frames) do
      if f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
    end
  end
  return c
end

local function Journey(points, events)
  local steps = {}
  for i = 1, points do steps[i] = "1,3,-2" end
  local list = {}
  for i = 1, events do list[i] = { 1785000000 + i, "quest", 0, i, -i, "Quest \"|cff00ff00é~%" .. i .. "|r\"", nil, true } end
  return {
    journeyId = "Player-1-FRIEND:0", played = 777,
    segments = { { m = "w", c = 0, t = 1785000000, x = 100, y = -50, d = table.concat(steps, ";") },
      { m = "t", c = 1, t = 1785009000, x = 5, y = 6, d = "", j = "b" } },
    events = list,
    levels = { [2] = { t = 1785000100, gear = { 1, 2, 3 } } },
    kills = { d = "1,10,1;", last = 1785000000, names = { "Boar" } },
    recipes = { Cooking = { Stew = true } }, people = {},
    totals = { kills = 1, killXP = 10, questXP = 0, deaths = 0, quests = events, instances = 0, distance = 9, flown = 0 },
    guild = false,
  }
end

clients.Zed = Client("Zed", "Bromm", "Player-1-AAAA")
clients.Bromm = Client("Bromm", "Zed", "Player-1-FFFF")
local z, b = clients.Zed, clients.Bromm
b.env.RoadToSixtyCharDB = Journey(9000, 300)      -- long enough for several batches
z.env.RoadToSixtyCharDB = Journey(5, 2)
z.env.RoadToSixtyCharDB.journeyId = "Player-1-ZED:0"
z.event("PLAYER_LOGIN"); b.event("PLAYER_LOGIN")
Run()
local F, status = z.ns.Friends, function(rec) return z.ns.Friends:Status(rec) end

-- 1. Nothing is shared with someone who wasn't added.
F:Add("bromm")
Run()
local rec = z.env.RoadToSixtyChronicleDB.friends.bromm
assert(rec.name == "Bromm" and not rec.journey, "took a journey without being added")
assert(status(rec) == "Waiting for them to add you.", "refusal not shown: " .. status(rec))

-- 2. The first sync brings the whole journey, batch by batch.
b.ns.Friends:Add("Zed")
Run()
F:Sync("Bromm")
Run()
local sent = b.env.RoadToSixtyCharDB
local got = rec.journey
assert(rec.synced and status(rec):find("^Last synced"), "sync did not finish: " .. status(rec))
assert(got.segments[1].d == sent.segments[1].d, "path differs")
assert(got.segments[2].j == "b" and got.segments[2].d == "", "last segment wrong")
assert(#got.events == 300 and got.events[300][6] == sent.events[300][6] and got.events[1][8] == true and got.events[1][7] == nil,
  "events differ")
assert(got.levels[2].gear[3] == 3 and got.recipes.Cooking.Stew and got.totals.quests == 300 and got.guild == false, "fields differ")
assert(rec.class == "PALADIN" and rec.level == 12 and rec.played == 777 and rec.c == 0 and rec.x == 10, "summary wrong")
local roster = z.env.RoadToSixtyDB.roster
assert(roster["Player-1-FFFF"] == rec and rec.key == "Player-1-FFFF", "not on the roster")
assert(z.sentMax <= 255 and b.sentMax <= 255, "message too long")

-- 3. A later sync only costs what is new.
local before = carried
sent.segments[2].d = "1,2,3;4,5,6"
sent.events[301] = { 1785999999, "level", 0, 1, 1 }
sent.events[300][6] = "filled in later"
F:Sync("Bromm")
Run()
assert(carried - before < 40, "resent too much: " .. (carried - before))
assert(rec.journey.segments[2].d == "1,2,3;4,5,6" and #rec.journey.events == 301, "new data missing")
assert(rec.journey.events[300][6] == "filled in later", "recent event not refreshed")

-- 4. A sync that stops carries on from where it got to.
local fresh = Journey(9000, 300)
fresh.journeyId = "Player-1-FFFF:9"
b.env.RoadToSixtyCharDB = fresh
At(60, function() b.offline = true end)
F:Sync("Bromm")
Run()
assert(status(rec):find("^Stopped"), "stop not reported: " .. status(rec))
local kept = #rec.journey.segments[1].d
assert(kept > 0 and kept < #fresh.segments[1].d, "nothing kept from the stopped sync")
b.offline = false
Run()
before = carried
F:Sync("Bromm")
Run()
assert(rec.journey.journeyId == "Player-1-FFFF:9", "new journey not taken")
assert(rec.journey.segments[1].d == fresh.segments[1].d, "carried on wrong")
assert(#rec.journey.events == 300, "events lost")

-- 6. Friends leave Road to Sixty's roster at logout and return at login, and
-- any a crash left there are cleared.
z.event("PLAYER_LOGOUT")
assert(roster["Player-1-FFFF"] == nil and roster["Player-1-AAAA"], "roster wrong after logout")
roster["Player-1-0DD"] = { chronicleFriend = true }
z.event("PLAYER_LOGIN")
Run()
assert(roster["Player-1-0DD"] == nil and roster["Player-1-FFFF"] == rec, "roster wrong after login")

-- 7. A friend can't overwrite one of this account's characters, and junk does nothing.
local mine = roster["Player-1-AAAA"]
local bad = {
  "B:zz:1:1:x", "B:ff:0:0:", "Q:ff", "Q:ff:1:x:y:z:", "N:ff", "::", "",
}
for _, text in ipairs(bad) do
  z.event("CHAT_MSG_ADDON", "RTSChronFriends", text, "WHISPER", "Stranger-Era")
  z.event("CHAT_MSG_ADDON", "RTSChronFriends", text, "WHISPER", "Bromm-Era")
end
Run()
b.env.UnitGUID = function() return "Player-1-AAAA" end
F:Sync("Bromm")
Run()
b.env.UnitGUID = function() return "Player-1-FFFF" end
assert(roster["Player-1-AAAA"] == mine and rec.guid == "Player-1-FFFF", "own character overwritten")
assert(status(rec):find("did not fit"), "bad batch not reported: " .. status(rec))

-- 8. Broken and hostile batches are refused without error.
local head = "{~sg~sPlayer-1-FFFF~sj~sPlayer-1-FFFF:9~ss~{~n1~{~si~n1~sm~sw~sc~n0~st~n1~sx~n1~sy~n1~sd~"
local hostile = {
  "x", "n1~", "{~", "}~", "{~n1~}~", "s~s~", ("{~sa~"):rep(100),
  head .. "s1,1,1;os.exit()~}~}~}~",       -- a path that isn't numbers
  "{~sg~sPlayer-1-1~ss~{~}~}~",            -- no journey id
  "{~sg~s../../x~sj~sa~ss~{~}~}~",         -- not a guid
}
for _, data in ipairs(hostile) do
  b.mute = true
  F:Sync("Bromm")
  z.event("CHAT_MSG_ADDON", "RTSChronFriends", "B:" .. b.lastAsked .. ":1:1:" .. data, "WHISPER", "Bromm-Era")
  assert(status(rec):find("did not fit"), "took " .. data .. ": " .. status(rec))
  b.mute = false
  Run()
end
-- A stranger can't answer for a friend.
b.mute = true
F:Sync("Bromm")
z.event("CHAT_MSG_ADDON", "RTSChronFriends", "B:" .. b.lastAsked .. ":1:1:n1~", "WHISPER", "Stranger-Era")
assert(status(rec) == "Asking...", "took a batch from a stranger")
b.mute = false
Run()
-- The tab, on a stand-in of Road to Sixty's panel.
local window = Widget("Frame", nil, z)
local panel = Widget("Frame", window, z)
local opened, drawn
local function Tab(text)
  local t = Widget("Button", panel, z)
  t.label, t.underline = Widget("text"), Widget("texture")
  t.label:SetText(text)
  t.scripts.OnClick = function() end
  return t
end
local history, characters = Tab("History"), Tab("Characters")
local panes = { Widget("Frame", panel, z), Widget("Frame", panel, z) }
local row = Widget("Button", panes[2], z)
row.pathToggle = Widget("CheckButton", row, z)
row.scripts.OnClick = function(self) opened = self.entry end
row.pathToggle.scripts.OnClick = function(self) drawn = { row.entry, self:GetChecked() } end
z.env.RoadToSixtyJourneyFrame = window
_G.unpack = _G.unpack or table.unpack
-- Loaded here as the tab looks for the map every second until it exists.
assert(load(TAB_SRC, "FriendsTab.lua", "t", z.env))("RoadToSixty_Chronicle", z.ns)
z.event("PLAYER_LOGIN")
Run()
local tab
for _, w in ipairs(panel.kids) do
  if w.kind == "Button" and w ~= history and w ~= characters then tab = w end
end
assert(tab and tab.label:GetText() == "Synced friends", "tab not added")
tab.scripts.OnClick()
assert(not panes[1].shown and not panes[2].shown and tab.underline.shown, "tab did not take over the panel")
local friendRow
for _, f in ipairs(z.frames) do
  if rawget(f, "rec") == rec then friendRow = f end
end
assert(friendRow, "no row for the friend")
friendRow.scripts.OnClick(friendRow)
assert(opened == rec, "click did not show the journey")
friendRow.path:SetChecked(true)
friendRow.path.scripts.OnClick(friendRow.path)
assert(z.env.RoadToSixtyDB.showPaths[rec.key] == true and drawn[1] == rec and drawn[2] == true, "path toggle failed")
history.scripts.OnClick()
assert(not tab.underline.shown and not rawget(tab, "pane"), "tab stayed selected")
friendRow.remove.scripts.OnClick()
assert(z.env.RoadToSixtyChronicleDB.friends.bromm == nil and roster["Player-1-FFFF"] == nil, "remove left data behind")
assert(not friendRow.shown, "row stayed")
