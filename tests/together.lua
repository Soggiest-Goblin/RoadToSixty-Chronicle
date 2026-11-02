-- The fork's replaying together, run from the real Map.lua on stand-ins, and
-- the Characters tab's filter from the real Panel.lua.
assert(load(MAP_SRC, "Map.lua"))
assert(MAP_SRC:find('local TOGETHER_SPEEDS = {\n    { 120, "2m/s" }', 1, true) or MAP_SRC:find('local TOGETHER_SPEEDS = {\r\n    { 120, "2m/s" }', 1, true),
  "slowest speed is not 2m/s")
local from = assert(MAP_SRC:find("-- Replaying together: every path", 1, true))
local to = assert(MAP_SRC:find("local function OnUpdate(_, elapsed)", from, true))
local prelude = [[
local T = ...
local state, ns, charMarkers, otherLines = T.state, T.ns, T.charMarkers, T.otherLines
local infoText, speedButton, togetherButton = T.infoText, T.speedButton, T.togetherButton
local TOGETHER_SPEEDS, TOGETHER_GAP, SPEEDS = { { 600, "10m/s" }, { 3600, "1h/s" } }, 600, { 1, 2 }
local OFFLINE_GAP = 1800
local ApplyTogether
local function PlaceCharacters() end
local function FormatTime(t) return "t" .. t end
local function SetPlaying(on) state.playing = on end
local function ApplyCursor() end
local function FollowHead() end
]]
local function LastIndex(times, t)
  local lo, hi = 0, #times
  while lo < hi do
    local mid = math.floor((lo + hi + 1) / 2)
    if times[mid] <= t then lo = mid else hi = mid - 1 end
  end
  return lo
end
local function Stub() return { SetText = function(s, v) s.text = v end, SetShown = function(s, v) s.shown = v end } end

local T = { ns = { LastIndex = LastIndex, FormatDuration = function(t) return t .. "s" end } }
T.infoText, T.speedButton, T.togetherButton = Stub(), Stub(), Stub()
-- Both log off for hours, at different times.
local friend = { n = 3, pt = { 105, 120, 4000 }, px = { 1, 2, 3 }, py = { 4, 5, 6 },
  pj = { [3] = "l" }, brk = { true, false, true } }
local old = { n = 2, px = { 9, 9 }, py = { 9, 9 } }     -- saved before paths had times
T.charMarkers = { Stub(), Stub() }
T.charMarkers[1].entry, T.charMarkers[2].entry = "friend", "old"
T.otherLines = { Stub(), Stub(), Stub() }
T.state = { n = 4, pt = { 100, 110, 5000, 5010 }, pj = { [3] = "l" }, brk = { true, false, true, false },
  cur = 4, togetherSpeed = 1, speedIndex = 1, charCount = 2, otherTracks = { friend, old },
  trackOf = { friend = friend, old = old }, otherLineCount = 3,
  otherDrawn = { { [6] = 2, track = friend }, { [6] = 3, track = friend }, { [6] = 2, track = old } } }
local body = MAP_SRC:sub(from, to - 1) ..
  "\nreturn TogetherBounds, NextMove, ApplyTogether, StepTogether, EndTogether, PlayedTimes\n"
local Bounds, Next, Apply, Step, End, Played = assert(load(prelude .. body, "together"))(T)
local s, marker = T.state, T.charMarkers[1]

-- Real time: nobody shows before their first point, and a character that
-- logged off waits where it was until it returns.
s.togetherMode = "real"
local a, b = Bounds()
assert(a == 100 and b == 5010, "real bounds")
assert(Next(100) == 105 and Next(120) == 4000 and Next(5010) == nil, "next move")
s.clock, s.clockTo, s.playing = 100, 5010, true
Apply()
assert(marker.shown == false and T.otherLines[1].shown == false and T.otherLines[3].shown == true, "before the start")
assert(T.infoText.text == "t100", "date not shown")
s.clock = 3000
Apply()
assert(marker.shown == true and marker.x == 2, "not waiting where it logged off")
assert(T.otherLines[1].shown == true and T.otherLines[2].shown == false, "lines while logged off")
s.clock = 120
Step(0.016)                     -- the long stretch nobody moved in is skipped
assert(s.clock == 4000 and s.cur == 2, "gap not skipped: " .. s.clock)
assert(marker.x == 3 and T.otherLines[2].shown == true, "did not return")

-- Time played: logins cost nothing, and everyone starts at the same moment.
s.togetherMode = "game"
s.pg, friend.pg = nil, nil
a, b = Bounds()
assert(a == 0 and b == 20, "game bounds: " .. a .. " " .. b)
s.clock, s.clockTo, s.playing = 0, b, true
Apply()
assert(marker.shown == true and marker.x == 1, "friend not at their start")
assert(T.infoText.text == "0s played", "played time not shown")
s.clock = 14
Apply()
assert(marker.x == 1, "friend ahead of their time played")
s.clock = 16
Apply()
assert(marker.x == 3, "login gap not removed")
s.clock = 15
Step(0.5)
assert(s.clock == 20 and s.playing == false and s.cur == 4, "end not reached")

-- What counts as time away.
local pg = Played({ n = 3, pt = { 0, 100, 5000 }, pj = { [3] = "h" }, brk = { true, false, true } })
assert(pg[3] == 5000, "a hearthstone is not a logoff")
pg = Played({ n = 3, pt = { 0, 100, 5000 }, pj = {}, brk = { true, false, true } })
assert(pg[3] == 100, "an old save's long break is a logoff")
pg = Played({ n = 3, pt = { 0, 100, 5000 }, pj = {}, brk = { true, false, false } })
assert(pg[3] == 5000, "standing still is still playing")

End()
assert(s.clock == nil and s.togetherMode == nil and T.togetherButton.text == "Together" and T.speedButton.text == "1x", "end")

-- The Characters tab's filter.
local ns = {}
assert(load(PANEL_SRC, "Panel.lua"))("RoadToSixty", ns)
local entries = {
  { name = "Zed" }, { name = "Alt" },
  { name = "Bromm", chronicleFriend = true, battleTag = "Bromm#1234" },
  { name = "Brommalt", chronicleFriend = true, battleTag = "Bromm#1234" },
  { name = "Ann", chronicleFriend = true },
}
local groups = ns.Panel:CharacterGroups(entries)
assert(#groups == 4 and groups[1].key == "all" and groups[2].key == "mine", "groups")
assert(groups[3].label == "Bromm#1234" and groups[4].label == "Ann", "friend groups")
assert(#ns.Panel:FilterCharacters(entries, "all") == 5, "all")
local mine = ns.Panel:FilterCharacters(entries, "mine")
assert(#mine == 2 and mine[2].name == "Alt", "mine")
local theirs = ns.Panel:FilterCharacters(entries, "Bromm#1234")
assert(#theirs == 2 and theirs[2].name == "Brommalt", "a friend's characters")
assert(#ns.Panel:FilterCharacters(entries, "Ann") == 1, "a friend with no tag")
