local printed, frameScript, tickers, timers, hooks, regs = {}, nil, {}, {}, {}, {}
print = function(s) printed[#printed+1] = tostring(s) end
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
strtrim = function(s) return (s:gsub("^%s+",""):gsub("%s+$","")) end
SlashCmdList = {}
local clock = 1785000000
GetServerTime = function() return clock end
time = function() return clock end
UNKNOWNOBJECT = "Unknown"
local inInstance, resting = false, false
CreateFrame = function() return {
  RegisterEvent=function(_, e) if e=="BAD_EVENT" then error("x") end regs[e]=true end,
  SetScript=function(_,_,f) frameScript=f end } end
C_Timer = { After=function(_,f) timers[#timers+1]=f end,
  NewTicker=function(_,f) tickers[#tickers+1]=f; return {} end }
hooksecurefunc = function(n,f) hooks[n]=f end
function TakeTaxiNode() end
local pos = { c=0, x=-9000, y=100 }
C_Map = {
  GetBestMapForUnit=function(u) if u=="party2" then return nil end return 1429 end,
  GetPlayerMapPosition=function(m,u) return {x=0.5,y=0.5,unit=u} end,
  GetWorldPosFromMapPos=function(m,p) if m==2000 then return nil end
    local off = p.unit=="party1" and 400 or 0
    return pos.c, {x=pos.x+off+(p.x or 0)*-100, y=pos.y-off+(p.y or 0)*100} end,
  GetMapInfo=function(id) return {name="Map"..id,parentMapID=947,mapType=id==947 and 1 or 3} end,
  GetMapChildrenInfo=function(id) return id==947 and {{mapID=1429},{mapID=1436},{mapID=2000}} or {} end,
}
CreateVector2D=function(x,y) return {x=x,y=y} end
IsInInstance=function() return inInstance end
UnitGUID=function(u) return ({player="Player-1-AAAA",party1="Player-1-BBBB",party2="Player-1-CCCC"})[u] end
UnitName=function(u) if u=="npc" then return "Innkeeper Farley" end if u=="NPC" then return "Bromm" end return ({player="Zed",party1="Bromm",party2="Lira"})[u] end
GetRealmName=function() return "Test Realm" end
UnitRace=function() return "Human","Human" end
UnitClass=function() return "Paladin","PALADIN" end
UnitFactionGroup=function() return "Alliance" end
UnitSex=function() return 2 end
UnitLevel=function() return 12 end
UnitXP=function() return 500 end UnitXPMax=function() return 3000 end
GetXPExhaustion=function() return nil end GetMoney=function() return 12345 end
GetBuildInfo=function() return "1.60.1","70245","x",16001 end
GetZoneText=function() return "Elwynn Forest" end
local sub="Goldshire"
GetSubZoneText=function() return sub end
IsInGroup=function() return true end IsInRaid=function() return false end
GetNumSubgroupMembers=function() return 2 end GetNumGroupMembers=function() return 3 end
UnitIsConnected=function() return true end
UnitIsUnit=function() return false end
GetRaidRosterInfo=function() return nil,nil,1 end
GetNumTalentTabs=function() return 2 end
GetTalentTabInfo=function(i) return ({"Holy","Prot"})[i],"ico",i*3 end
GetBindLocation=function() return "Goldshire" end
IsResting=function() return resting end
NumTaxiNodes=function() return 2 end
TaxiNodeGetType=function(i) return i==1 and "CURRENT" or "REACHABLE" end
TaxiNodeName=function(i) return i==1 and "Stormwind" or "Sentinel Hill" end
TaxiNodeCost=function() return 500 end

local chunk = assert(load(CHRONICLE_SRC, "Chronicle.lua"))
chunk("RoadToSixty_Chronicle")
local fire=function(e,...) frameScript(nil,e,...) end
fire("ZONE_CHANGED")                   -- before login: must be ignored
fire("ADDON_LOADED","RoadToSixty_Chronicle")
fire("PLAYER_LOGIN")
for _,f in ipairs(timers) do f() end
sub="Northshire"; clock=clock+20; fire("ZONE_CHANGED")
fire("ZONE_CHANGED")                   -- same place: no second event
sub="Goldshire"; clock=clock+20; fire("ZONE_CHANGED")   -- back: not a first visit
for _,f in ipairs(tickers) do f() end
pos.x=pos.x+500; clock=clock+15
for _,f in ipairs(tickers) do f() end
pos.x=pos.x+5; clock=clock+15          -- under TRACK_MOVED: no new row
for _,f in ipairs(tickers) do f() end
hooks.TakeTaxiNode(2)
fire("MERCHANT_SHOW"); fire("MERCHANT_SHOW") -- second is within NPC_REPEAT
fire("TRADE_SHOW"); fire("SCREENSHOT_SUCCEEDED")
resting=true; fire("PLAYER_UPDATE_RESTING"); fire("PLAYER_UPDATE_RESTING")
GetTalentTabInfo=function(i) return i,({"Holy","Prot"})[i],"txt","ico",i*5 end -- newer client shape
fire("CHARACTER_POINTS_CHANGED")
fire("HEARTHSTONE_BOUND")              -- same place: nothing
SlashCmdList.RTSCHRONICLE("note Hello \"there\"")
SlashCmdList.RTSCHRONICLE("")
SlashCmdList.RTSCHRONICLE("export")
-- A client where things come back secret must not break tracking.
issecretvalue=function(v) return v=="Player-1-BBBB" end
for _,f in ipairs(tickers) do f() end
inInstance=true; clock=clock+15; fire("SCREENSHOT_SUCCEEDED")
for _,f in ipairs(tickers) do f() end
fire("PLAYER_LOGOUT")

local function ser(v)
  local t=type(v)
  if t=="string" then return '"'..v:gsub('\\','\\\\'):gsub('"','\\"')..'"' end
  if t~="table" then return tostring(v) end
  local o,n={},#v
  for i=1,n do o[#o+1]=ser(v[i]) end
  for k,x in pairs(v) do if not(type(k)=="number" and k>=1 and k<=n and k%1==0) then
    o[#o+1]="["..ser(k).."]="..ser(x) end end
  return "{"..table.concat(o,",").."}"
end
LUA_RESULT = "RoadToSixtyChronicleDB = "..ser(RoadToSixtyChronicleDB)
LUA_PRINTED = table.concat(printed,"\n")
LUA_REGS = 0 for _ in pairs(regs) do LUA_REGS=LUA_REGS+1 end

local function count(kind)
  local n, events = 0, RoadToSixtyChronicleDB.chars["Player-1-AAAA"].events
  for _, e in ipairs(events) do if e[2] == kind then n = n + 1 end end
  return n
end
assert(LUA_REGS > 0, "no events registered")
assert(count("note") == 1, "note not recorded once")
assert(count("taxi") == 1, "flight not recorded once")
assert(count("npc") == 1, "repeat merchant visit not merged")
assert(count("bind") <= 1, "unchanged hearthstone recorded again")