# Copies the fork and Chronicle from this repo into one or more installed games.
# The fork replaces any Road to Sixty folder there. Saved journeys aren't touched.
# Example: .\scripts\install.ps1 -WowRoot "D:\WoW\World of Warcraft" -Game classic_era
param(
    [Parameter(Mandatory = $true)][string]$WowRoot,
    [ValidateSet("forever", "classic_era", "anniversary")][string[]]$Game = @("classic_era")
)
$ErrorActionPreference = "Stop"
$repo = Split-Path $PSScriptRoot

foreach ($g in $Game) {
    $addons = Join-Path $WowRoot "_${g}_\Interface\AddOns"
    if (-not (Test-Path $addons)) { throw "No AddOns folder at $addons" }
    foreach ($folder in "RoadToSixty", "RoadToSixty_Chronicle") {
        $target = Join-Path $addons $folder
        robocopy (Join-Path $repo $folder) $target /MIR /NFL /NDL /NJH /NJS /NP | Out-Null
        if ($LASTEXITCODE -ge 8) { throw "Copy to $target failed with robocopy code $LASTEXITCODE" }
        "Installed to $target"
    }
}
$global:LASTEXITCODE = 0
