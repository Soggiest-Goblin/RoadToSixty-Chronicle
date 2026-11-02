# Copies the addon from this repo into one or more installed games.
# Example: .\scripts\install.ps1 -WowRoot "D:\WoW\World of Warcraft" -Game classic_era
param(
    [Parameter(Mandatory = $true)][string]$WowRoot,
    [ValidateSet("forever", "classic_era", "anniversary")][string[]]$Game = @("classic_era")
)
$ErrorActionPreference = "Stop"
$source = Join-Path (Split-Path $PSScriptRoot) "RoadToSixty_Chronicle"

foreach ($g in $Game) {
    $addons = Join-Path $WowRoot "_${g}_\Interface\AddOns"
    if (-not (Test-Path $addons)) { throw "No AddOns folder at $addons" }
    if (-not (Test-Path (Join-Path $addons "RoadToSixty"))) {
        Write-Warning "Road to Sixty is not installed in $addons, and Chronicle needs it."
    }
    $target = Join-Path $addons "RoadToSixty_Chronicle"
    robocopy $source $target /MIR /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "Copy to $target failed with robocopy code $LASTEXITCODE" }
    "Installed to $target"
}
$global:LASTEXITCODE = 0
