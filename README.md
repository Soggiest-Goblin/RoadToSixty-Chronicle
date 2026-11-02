# Road to Sixty: Together

Based on the efforts of Hotdoghands' Road to Sixty: a fork, plus a companion addon that records more of a character's journey. Players can sync journeys in game, then replay their own characters and their friends' together on one map. An offline viewer is included too.

See [docs/DESIGN.md](docs/DESIGN.md) for how it works and the decisions still open.

## Status

| Part | State |
|---|---|
| Extra tracking (`Chronicle.lua`) | Built; recording checked on one live Classic Era character |
| Settings page (`Settings.lua`) | Built; tested only on simulated clients |
| Minimap button (`MinimapButton.lua`) | Built; tested only on simulated clients, dragging not tested |
| Offline viewer (`Viewer/index.html`) | Built; not yet opened with real saved files |
| `/chron synctest` message measurement | Built; run once between two live Classic Era players, all stages clean |
| In-game sync (`Friends.lua`) | Built; tested only on simulated clients |
| Synced friends tab (`FriendsTab.lua`) | Built; tested only against stand-ins for Road to Sixty's panel |
| Replaying together, by real time or time played (`RoadToSixtyTogether/Map.lua`) | Built; clock logic tested on stand-ins, not run in game |
| Character filters and BattleTag tags (`RoadToSixtyTogether/Panel.lua`) | Built; filter logic tested, not run in game |

Forever isn't playable yet, so live testing happens on Classic Era.

## Layout

```
RoadToSixtyTogether/  The fork of Road to Sixty, exactly as it installs
RoadToSixty_Chronicle/   The companion addon, exactly as it installs
  Chronicle.lua          Tracking and the sync test
  Settings.lua           The settings page
  MinimapButton.lua      The minimap button
  Friends.lua            Syncing journeys with friends
  FriendsTab.lua         The map's Synced friends tab
  Viewer/index.html      Single-file offline viewer
  README.md              Player instructions
docs/DESIGN.md           How it fits with Road to Sixty, and the sync plan
scripts/install.ps1      Copies both addons into a game folder
scripts/migrate-saves.ps1  Copies saved journeys to the fork's file names
tests/                   Simulated client tests
```

## Testing with a friend

You don't need any tools for this. Both players need to be in the same game on the same realm and faction.

1. Open this repo and choose **Code**, then **Download ZIP**.
2. Unzip it and copy the `RoadToSixtyTogether` and `RoadToSixty_Chronicle` folders into that game's `Interface\AddOns` folder, such as `World of Warcraft\_classic_era_\Interface\AddOns`. Replace any folders already there, and delete or disable any `RoadToSixty` folder, as the two can't run together. See [Keeping your journey](#keeping-your-journey) if you've played with Road to Sixty before.
3. Fully restart WoW, because `/reload` doesn't pick up new addon files.
4. Log in. You should see a campfire button on the minimap, and `/chron` should report what has been recorded.
5. Right-click the campfire button to check the settings page, and drag the button to check it moves.
6. Open the journey map and choose the **Synced friends** tab. Each player adds the other's exact character name.
7. Choose **Sync**, and wait for the row to say `Last synced`. Click the friend to replay their journey.
8. In the **Characters** tab, tick the characters to play. The **Solo** button at the top right of the map starts them in Real Time, a second click switches to Play Time, and a third returns to Solo.
9. Send back anything the tab reported, plus any errors or anything that looked wrong.

## Keeping your journey

WoW names saved files after the addon's folder, so a journey recorded with Road to Sixty has to be copied once:

1. Close WoW.
2. Open `WTF\Account\<account>\SavedVariables` and copy `RoadToSixty.lua`. Rename the copy `RoadToSixtyTogether.lua`.
3. Do the same in each `WTF\Account\<account>\<realm>\<character>\SavedVariables` folder, which holds that character's journey.

From this repo, `.\scripts\migrate-saves.ps1 -WowRoot "D:\WoW\World of Warcraft" -Game classic_era` does all of that, and leaves the original files in place.

## Getting started

From the repo root:

```powershell
.\scripts\install.ps1 -WowRoot "D:\WoW\World of Warcraft" -Game classic_era
```

`-Game` accepts `forever`, `classic_era` and `anniversary`, separated by commas. It installs both addons, with WoW closed. An earlier install of the fork under the `RoadToSixty` folder is removed, and Hotdoghands' own Road to Sixty is left alone with a warning. Edit the addons here rather than in the game folder, because the install script mirrors this repo and overwrites anything changed there.

To run the tests on Windows:

```powershell
.\tests\run.ps1
```

They need Microsoft Edge. The first run downloads the Fengari Lua VM to `tests/.build`, so no Lua install is needed.

## Publishing

CurseForge builds releases from this repo through a GitHub webhook, using `.pkgmeta`. Both `.toc` files take their version from the tag, so a copy installed with `scripts/install.ps1` shows the unfilled `@project-version@`.

A pushed tag starts a build: `v1.0.0` for a release, `v1.0.0-beta1` for a beta, and `v1.0.0-alpha1` for an alpha.
## Road to Sixty

Together is based on the efforts of Hotdoghands, the author of Road to Sixty. `RoadToSixtyTogether` is a fork of version 1.18.0, made with his approval, and the original code and art are his work. See `CREDITS.txt` in that folder. The fork keeps his saved variable names, so it can't run beside his addon.

The fork changes `Map.lua` and `Panel.lua`, plus the details in `RoadToSixtyTogether.toc`. Keep it that small where possible, so his later releases can be merged in.

The viewer also embeds coastline shapes taken from Road to Sixty's `Gaps/land_*.tga` textures, used with Hotdoghands' approval. No license has been chosen for this repo yet.

The project was first called Chronicle, and some internal names keep that: the `RoadToSixty_Chronicle` folder, its saved variable, its addon message prefixes and the `/chron` commands. Renaming those would lose players' saved data or break sync between versions.

Never commit real `WTF` or `SavedVariables` files. They contain routes, play times and the names of other players. `.gitignore` blocks the usual names and paths.
