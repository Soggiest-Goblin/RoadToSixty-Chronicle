# Runs Chronicle.lua against simulated WoW clients in a Lua VM inside headless
# Edge, so the tests need no Lua install. Fengari is fetched once, then cached.
$ErrorActionPreference = "Stop"
$fengariVersion = "0.1.4"
$edge = "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
$build = Join-Path $PSScriptRoot ".build"
New-Item -ItemType Directory -Force $build | Out-Null

$fengari = Join-Path $build "fengari-web.js"
if (-not (Test-Path $fengari)) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest "https://cdn.jsdelivr.net/npm/fengari-web@$fengariVersion/dist/fengari-web.js" -OutFile $fengari -UseBasicParsing
}

$chronicle = [IO.File]::ReadAllText((Join-Path (Split-Path $PSScriptRoot) "RoadToSixty_Chronicle\Chronicle.lua"))
$settings = [IO.File]::ReadAllText((Join-Path (Split-Path $PSScriptRoot) "RoadToSixty_Chronicle\Settings.lua"))
$minimap = [IO.File]::ReadAllText((Join-Path (Split-Path $PSScriptRoot) "RoadToSixty_Chronicle\MinimapButton.lua"))
$friends = [IO.File]::ReadAllText((Join-Path (Split-Path $PSScriptRoot) "RoadToSixty_Chronicle\Friends.lua"))
$friendsTab = [IO.File]::ReadAllText((Join-Path (Split-Path $PSScriptRoot) "RoadToSixty_Chronicle\FriendsTab.lua"))
$failed = 0
foreach ($test in "mock_client", "two_clients", "settings", "friends") {
    $lua = [IO.File]::ReadAllText((Join-Path $PSScriptRoot "$test.lua"))
    $page = @"
<!doctype html><meta charset=utf-8><pre id=out>did not finish</pre>
<script src="fengari-web.js"></script>
<script>
const {lua,lauxlib,lualib,to_luastring}=fengari;
const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
lua.lua_pushstring(L,to_luastring($(ConvertTo-Json $chronicle -Compress)));
lua.lua_setglobal(L,to_luastring("CHRONICLE_SRC"));
lua.lua_pushstring(L,to_luastring($(ConvertTo-Json $settings -Compress)));
lua.lua_setglobal(L,to_luastring("SETTINGS_SRC"));
lua.lua_pushstring(L,to_luastring($(ConvertTo-Json $minimap -Compress)));
lua.lua_setglobal(L,to_luastring("MINIMAP_SRC"));
lua.lua_pushstring(L,to_luastring($(ConvertTo-Json $friends -Compress)));
lua.lua_setglobal(L,to_luastring("FRIENDS_SRC"));
lua.lua_pushstring(L,to_luastring($(ConvertTo-Json $friendsTab -Compress)));
lua.lua_setglobal(L,to_luastring("TAB_SRC"));
let r=lauxlib.luaL_loadstring(L,to_luastring($(ConvertTo-Json $lua -Compress)));
if(r===0)r=lua.lua_pcall(L,0,0,0);
document.getElementById("out").textContent=r?"LUA ERROR: "+lua.lua_tojsstring(L,-1):"PASSED";
</script>
"@
    $file = Join-Path $build "$test.html"
    [IO.File]::WriteAllText($file, $page, (New-Object Text.UTF8Encoding($false)))
    $edgeProfile = Join-Path $build "edge-profile"
    $dom = & $edge --headless --disable-gpu --no-first-run "--user-data-dir=$edgeProfile" --virtual-time-budget=20000 --dump-dom ([Uri]$file).AbsoluteUri | Out-String
    $result = [regex]::Match($dom, '(?s)<pre id="out">(.*?)</pre>').Groups[1].Value
    "${test}: $([Net.WebUtility]::HtmlDecode($result))"
    if ($result -ne "PASSED") { $failed++ }
}
if ($failed) { throw "$failed test(s) failed" }
