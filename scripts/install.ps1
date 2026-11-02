# Copies both addons from this repo into one or more installed games. Run it
# with WoW closed. An earlier install of the fork under the old RoadToSixty
# folder is removed. Hotdoghands' own Road to Sixty is left alone, with a warning.
# Saved journeys aren't touched: see migrate-saves.ps1.
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
    foreach ($folder in "RoadToSixtyTogether", "RoadToSixty_Chronicle") {
        $target = Join-Path $addons $folder
        robocopy (Join-Path $repo $folder) $target /MIR /NFL /NDL /NJH /NJS /NP | Out-Null
        if ($LASTEXITCODE -ge 8) { throw "Copy to $target failed with robocopy code $LASTEXITCODE" }
        "Installed to $target"
    }
    $old = Join-Path $addons "RoadToSixty"
    $toc = Join-Path $old "RoadToSixty.toc"
    if (Test-Path $toc) {
        if (Select-String -Path $toc -Pattern "^## Title: .*(Together|With Friends|Chronicle fork)" -Quiet) {
            Remove-Item $old -Recurse -Force
            "Removed the old install of the fork at $old"
        } else {
            Write-Warning "Road to Sixty is also installed at $old. Disable or remove it, as the two can't run together."
        }
    }
}
$global:LASTEXITCODE = 0
