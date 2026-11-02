# Copies saved journeys from Road to Sixty's file names to the fork's, as WoW
# names saved files after the addon's folder. The old files are left in place,
# and a file already at the new name is never replaced. Run it with WoW closed.
# Example: .\scripts\migrate-saves.ps1 -WowRoot "D:\WoW\World of Warcraft" -Game classic_era
param(
    [Parameter(Mandatory = $true)][string]$WowRoot,
    [ValidateSet("forever", "classic_era", "anniversary")][string[]]$Game = @("classic_era"),
    [switch]$IgnoreRunningGame      # for a folder no running game is using
)
$ErrorActionPreference = "Stop"

if (-not $IgnoreRunningGame -and (Get-Process -Name "Wow*" -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -notlike "*VoiceProxy*" })) {
    throw "WoW is running, and it would overwrite saved files at logout. Close it and run this again."
}

foreach ($g in $Game) {
    $wtf = Join-Path $WowRoot "_${g}_\WTF"
    if (-not (Test-Path $wtf)) { throw "No WTF folder at $wtf" }
    $copied, $kept = 0, 0
    foreach ($old in Get-ChildItem $wtf -Recurse -File -Filter "RoadToSixty.lua") {
        $new = Join-Path $old.DirectoryName "RoadToSixtyTogether.lua"
        if (Test-Path $new) {
            $kept++
        } else {
            Copy-Item $old.FullName $new
            $copied++
        }
    }
    "${g}: copied $copied, already there $kept"
}
