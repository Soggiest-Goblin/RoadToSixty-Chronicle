-- Two Classic Era clients in one VM: each runs Chronicle.lua in its own
-- environment, joined by a modelled server: 255 byte limit, 10 message burst
-- per prefix, 1 a second back. Era API shapes: no issecretvalue, boolean send
-- results, GetTalentTabInfo as name, icon, points.
local clock, queue, seq = 0, {}, 0
local function At(d, f) seq = seq + 1; queue[#queue+1] = { t = clock + d, n = seq, f = f } end
local function Run()
  while #queue > 0 do
    table.sort(queue, function(a, b) if a.t ~= b.t then return a.t < b.t end return a.n < b.n end)
    local e = table.remove(queue, 1); clock = e.t; e.f()
  end
end
local clients, RESULT = {}, {}
local BOOT = 1785000000
local function Client(name, other)
  local c = { printed = {}, allowance = 10, refill = 0, sentMax = 0 }
  local env = setmetatable({}, { __index = _G })
  c.env = env
  env.print = function(s) c.printed[#c.printed+1] = (tostring(s):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
  env.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
  env.strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
  env.SlashCmdList = {}
  env.GetServerTime = function() return BOOT + math.floor(clock) end
  env.time = env.GetServerTime
  env.GetTime = function() return clock end
  env.UNKNOWNOBJECT = "Unknown"
  env.CreateFrame = function() return { RegisterEvent = function() end, SetScript = function(_, _, f) c.fire = f end } end
  env.C_Timer = { After = function(d, f) At(d, f) end, NewTicker = function() return {} end }
  env.hooksecurefunc = function() end
  env.C_Map = { GetBestMapForUnit = function() return 1429 end,
    GetPlayerMapPosition = function() return { x = .5, y = .5 } end,
    GetWorldPosFromMapPos = function() return 0, { x = -9000, y = 100 } end,
    GetMapInfo = function(id) return { name = "Map" .. id, parentMapID = 947, mapType = 3 } end,
    GetMapChildrenInfo = function() return {} end }
  env.CreateVector2D = function(x, y) return { x = x, y = y } end
  env.IsInInstance = function() return false end
  env.UnitGUID = function() return "Player-1-" .. name end
  env.UnitName = function() return name end
  env.GetRealmName = function() return "Era" end
  env.UnitRace = function() return "Human", "Human" end
  env.UnitClass = function() return "Mage", "MAGE" end
  env.UnitFactionGroup = function() return "Alliance" end
  env.UnitSex = function() return 2 end
  env.UnitLevel = function() return 5 end
  env.UnitXP = function() return 1 end; env.UnitXPMax = function() return 2 end
  env.GetXPExhaustion = function() end; env.GetMoney = function() return 1 end
  env.GetBuildInfo = function() return "1.15.9", "70003", "x", 11509 end
  env.GetZoneText = function() return "Elwynn Forest" end
  env.GetSubZoneText = function() return "" end
  env.IsInGroup = function() return false end; env.IsInRaid = function() return false end
  env.GetNumSubgroupMembers = function() return 0 end; env.GetNumGroupMembers = function() return 0 end
  env.GetNumTalentTabs = function() return 1 end
  env.GetTalentTabInfo = function() return "Arcane", "ico", 0, "file" end
  env.GetBindLocation = function() return "Goldshire" end
  env.Ambiguate = function(n) return (n:gsub("%-.*", "")) end
  env.C_ChatInfo = {
    RegisterAddonMessagePrefix = function() return true end,
    SendAddonMessage = function(prefix, text, channel, target)
      assert(#prefix <= 16, "prefix too long")
      if #text > 255 then error("message too long: " .. #text) end
      c.sentMax = math.max(c.sentMax, #text)
      local gained = math.floor(clock - c.refill)
      if gained > 0 then c.allowance = math.min(10, c.allowance + gained); c.refill = clock end
      if c.allowance <= 0 then return false end
      c.allowance = c.allowance - 1
      local to = clients[other]
      local short = target and target:gsub("%-.*", "")
      if channel == "WHISPER" and short ~= other then return true end
      At(0.05, function()
        if to.env.RESPOND ~= false then to.fire(nil, "CHAT_MSG_ADDON", prefix, text, channel, name .. "-Era") end
      end)
      return true
    end,
  }
  return c
end
clients.Zed = Client("Zed", "Bromm")
clients.Bromm = Client("Bromm", "Zed")
for _, c in pairs(clients) do
  assert(load(CHRONICLE_SRC, "Chronicle.lua", "t", c.env))("RoadToSixty_Chronicle", {})
  c.fire(nil, "ADDON_LOADED", "RoadToSixty_Chronicle")
  c.fire(nil, "PLAYER_LOGIN")
end
Run()
local z = clients.Zed
-- 1. No such player.
z.env.SlashCmdList.RTSCHRONICLE("synctest Nobody")
Run()
-- 2. A full test by whisper, with the Era throttle.
z.env.SlashCmdList.RTSCHRONICLE("synctest Bromm")
z.env.SlashCmdList.RTSCHRONICLE("synctest Bromm") -- second start must refuse
Run()
-- 3. Junk from anyone must be ignored without error.
for _, junk in ipairs({ "", "x", "A:zz", "D:", "E:ff:1", "H:", "A:ff:1:9:9", "W:ff", ":::", ("D:ff:1:1:"):rep(40) }) do
  z.fire(nil, "CHAT_MSG_ADDON", "RTSChronicle", junk, "WHISPER", "Stranger")
end
z.fire(nil, "CHAT_MSG_ADDON", "OtherAddon", "H:ff", "WHISPER", "Stranger")
Run()
-- 4. Own group messages are not answered.
local before = z.allowance
z.fire(nil, "CHAT_MSG_ADDON", "RTSChronicle", "H:abc", "PARTY", "Zed-Era")
assert(z.allowance == before, "answered itself")
-- 5. Status works and nothing failed.
z.env.SlashCmdList.RTSCHRONICLE("")
local db = z.env.RoadToSixtyChronicleDB
LUA_RESULT = table.concat(z.printed, "\n") .. "\n-- longest message " .. z.sentMax ..
  ", interface " .. tostring(db.interface) .. ", saved tests " .. #(db.syncTests or {}) ..
  ", peer " .. tostring(db.syncTests and db.syncTests[1].peer) .. ", Bromm printed " .. #clients.Bromm.printed

assert(z.sentMax > 0 and z.sentMax <= 255, "message size out of range")
assert(#db.syncTests == 1, "expected one saved test")
assert(db.syncTests[1].peer == "Bromm", "wrong peer saved")