-- The settings page against stand-in widgets: it builds, its checkboxes change
-- the shared Road to Sixty values, and its tracking switches stop recording.
local clock, printed, widgets, commands = 1785000000, {}, {}, {}

local function Widget(kind, parent)
  local w = { kind = kind, parent = parent, scripts = {}, checked = false }
  widgets[#widgets + 1] = w
  function w:SetScript(name, fn) self.scripts[name] = fn end
  function w:Show() self.shown = true end
  function w:Hide() self.shown = false end
  function w:SetChecked(on) self.checked = on and true or false end
  function w:GetChecked() return self.checked end
  function w:SetText(text) self.text = text; if self.parent then self.parent.label = text end end
  function w:GetText() return self.text end
  function w:GetWidth() return 500 end
  function w:GetStringWidth() return 100 end
  function w:CreateFontString() return Widget("text", self) end
  function w:CreateTexture() return Widget("texture", self) end
  return setmetatable(w, { __index = function() return function() end end })
end

print = function(s) printed[#printed + 1] = tostring(s) end
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
SlashCmdList = { ROADTOSIXTY = function(cmd) commands[#commands + 1] = cmd
  if cmd == "minimap" then RoadToSixtyDB.minimap.hide = not RoadToSixtyDB.minimap.hide end end }
GetServerTime = function() return clock end
time = GetServerTime
UNKNOWNOBJECT = "Unknown"
CreateFrame = function(kind, _, parent) return Widget(kind, parent) end
Minimap = Widget("Minimap")
C_Timer = { After = function() end, NewTicker = function() return {} end }
C_Map = { GetBestMapForUnit = function() return 1429 end, GetPlayerMapPosition = function() return { x = .5, y = .5 } end,
  GetWorldPosFromMapPos = function() return 0, { x = -9000, y = 100 } end }
IsInInstance = function() return false end
UnitGUID = function() return "Player-1-ME" end
UnitName = function() return "Zed" end
GetRealmName = function() return "Era" end
UnitRace = function() return "Human", "Human" end
UnitClass = function() return "Mage", "MAGE" end
UnitFactionGroup = function() return "Alliance" end
UnitSex = function() return 2 end
UnitLevel = function() return 5 end
local xp, xpMax, money = 10, 400, 25
UnitXP = function() return xp end
UnitXPMax = function() return xpMax end
GetMoney = function() return money end
GetXPExhaustion = function() end
GetBuildInfo = function() return "1.15.9", "70003", "x", 11509 end
GetZoneText = function() return "Elwynn Forest" end
local sub = "Goldshire"
GetSubZoneText = function() return sub end
IsInGroup = function() return false end
Settings = { RegisterCanvasLayoutCategory = function() return { GetID = function() return 7 end } end,
  RegisterAddOnCategory = function() end, OpenToCategory = function(id) OPENED = id end }

RoadToSixtyDB = { greet = true, levelChat = true, levelShot = true, terrain = true, cityArt = true, motes = true,
  questPops = true, killPops = true, killMarks = true, showGear = false, gearBars = "classic",
  minimap = { hide = false }, showPaths = {}, roster = {
    ["Player-1-ME"] = { name = "Zed", realm = "Era", level = 5, seen = 3 },
    ["Player-1-ALT"] = { name = "Alt", realm = "Era", level = 12, seen = 2 },
    ["Player-1-OLD"] = { name = "Old", realm = "Era", level = 30, seen = 1 } } }

local ns = {}
assert(load(CHRONICLE_SRC, "Chronicle.lua"))("RoadToSixty_Chronicle", ns)
local chronicle = widgets[2]
assert(load(SETTINGS_SRC, "Settings.lua"))("RoadToSixty_Chronicle", ns)
local loader = widgets[3]
assert(load(MINIMAP_SRC, "MinimapButton.lua"))("RoadToSixty_Chronicle", ns)
local buttonLoader = widgets[4]
local function fire(e, ...) chronicle.scripts.OnEvent(nil, e, ...) end
fire("ADDON_LOADED", "RoadToSixty_Chronicle")
RoadToSixtyChronicleDB.chars = { ["Player-1-ME"] = { events = {}, people = {}, seen = {},
  stats = "100,3,644,1400,366,43;200,3,0,0,0,0;300,3,967,1400,78,47;" } }
fire("PLAYER_LOGIN")
buttonLoader.scripts.OnEvent(nil, "PLAYER_LOGIN")
loader.scripts.OnEvent(nil, "PLAYER_LOGIN")
local me = RoadToSixtyChronicleDB.chars["Player-1-ME"]
assert(me.stats == "100,3,644,1400,366,43;300,3,967,1400,78,47;", "old logout row kept: " .. me.stats)

local panel = widgets[#widgets]
assert(panel.name == "Road to Sixty: Chronicle", "panel is not the last frame made")
panel.scripts.OnShow()

local function find(label)
  for _, w in ipairs(widgets) do
    if w.kind == "CheckButton" and w.label == label then return w end
  end
  error("no control labelled " .. label)
end
local function button(text)
  for _, w in ipairs(widgets) do
    if w.kind == "Button" and w.text == text then return w end
  end
  error("no button " .. text)
end
local function click(w)
  w:SetChecked(not w:GetChecked())
  w.scripts.OnClick(w)
end

-- The page shows what Road to Sixty has, and changes the same values.
assert(find("Show terrain"):GetChecked(), "terrain not read from Road to Sixty")
assert(not find("Show gear during the replay"):GetChecked(), "gear not read from Road to Sixty")
click(find("Show terrain"))
assert(RoadToSixtyDB.terrain == false, "terrain not written")
assert(find("Glow"):GetChecked() == false and find("Classic"):GetChecked(), "gear bars not read")
find("Glow").scripts.OnClick(find("Glow"))
assert(RoadToSixtyDB.gearBars == "glow" and find("Glow"):GetChecked() and not find("Classic"):GetChecked(), "gear bars not written")

-- The minimap button goes through Road to Sixty's command.
click(find("Show the minimap button"))
assert(RoadToSixtyDB.minimap.hide == true and commands[1] == "minimap", "minimap not hidden")
click(find("Show the minimap button"))
assert(RoadToSixtyDB.minimap.hide == false and #commands == 2, "minimap not shown")

-- Characters: this one is left out, and the buttons cover the others.
local alt = find("Alt, level 12, Era")
for _, w in ipairs(widgets) do assert(not (rawget(w, "label") or ""):find("^Zed"), "listed this character") end
click(alt)
assert(RoadToSixtyDB.showPaths["Player-1-ALT"] == true, "path not shown")
button("Show all").scripts.OnClick()
assert(RoadToSixtyDB.showPaths["Player-1-OLD"] == true and find("Old, level 30, Era"):GetChecked(), "show all failed")
button("Just this character").scripts.OnClick()
assert(next(RoadToSixtyDB.showPaths) == nil and not alt:GetChecked(), "just this character failed")

-- Tracking switches.
local function count(kind)
  local n = 0
  for _, e in ipairs(me.events) do if e[2] == kind then n = n + 1 end end
  return n
end
local before = count("sub")
click(find("Subzones and first visits"))
sub = "Northshire"; fire("ZONE_CHANGED")
assert(count("sub") == before, "subzone logged while off")
click(find("Subzones and first visits"))
assert(RoadToSixtyChronicleDB.off.sub == nil, "switch not cleared")
sub = "Westbrook"; fire("ZONE_CHANGED")
assert(count("sub") == before + 1, "subzone not logged once on")
SlashCmdList.RTSCHRONICLE("note still works")
assert(count("note") == 1, "note lost")

-- A row from logging out, when everything reads 0, is not saved.
xp, xpMax, money = 0, 0, 0
fire("PLAYER_LOGOUT")
assert(not me.stats:find(",0,0,0,0;", 1, true), "logout row saved: " .. me.stats)

SlashCmdList.RTSCHRONICLE("options")
assert(OPENED == 7, "options did not open")

-- The minimap button.
local mini
for _, w in ipairs(widgets) do
  if w.kind == "Button" and w.parent == Minimap then mini = w end
end
assert(mini and mini.shown, "minimap button not shown at login")
OPENED, commands = nil, {}
mini.scripts.OnClick(mini, "LeftButton")
assert(commands[1] == "map", "left-click did not open the map")
mini.scripts.OnClick(mini, "RightButton")
assert(OPENED == 7, "right-click did not open the settings")
click(find("Show the Chronicle minimap button"))
assert(RoadToSixtyChronicleDB.minimap.hide == true and not mini.shown, "minimap button not hidden")
click(find("Show the Chronicle minimap button"))
assert(RoadToSixtyChronicleDB.minimap.hide == false and mini.shown, "minimap button not shown again")
