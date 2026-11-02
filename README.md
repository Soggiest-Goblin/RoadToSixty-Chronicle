# Road to Sixty: Chronicle

A companion addon for [Road to Sixty](#road-to-sixty) that records more of a character's journey, with an offline viewer that replays many characters and friends on one map.

Players can sync journeys in game and watch them on Road to Sixty's own map, from a Synced friends tab. See [docs/DESIGN.md](docs/DESIGN.md) for how it works and the decisions still open.

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
| Several journeys replaying at once on Road to Sixty's map | Not started; needs changes in Road to Sixty |

Forever isn't playable yet, so live testing happens on Classic Era.

## Layout

```
RoadToSixty_Chronicle/   The addon, exactly as it installs
  Chronicle.lua          Tracking and the sync test
  Settings.lua           The settings page
  MinimapButton.lua      The minimap button
  Friends.lua            Syncing journeys with friends
  FriendsTab.lua         The map's Synced friends tab
  Viewer/index.html      Single-file offline viewer
  README.md              Player instructions
docs/DESIGN.md           How it fits with Road to Sixty, and the sync plan
scripts/install.ps1      Copies the addon into a game folder
tests/                   Simulated client tests
```

## Testing with a friend

You don't need any tools for this. Both players need Road to Sixty installed and running in the same game on the same realm.

1. Open this repo and choose **Code**, then **Download ZIP**.
2. Unzip it and copy the `RoadToSixty_Chronicle` folder into that game's `Interface\AddOns` folder, such as `World of Warcraft\_classic_era_\Interface\AddOns`.
3. Fully restart WoW, because `/reload` doesn't pick up new addon files.
4. Log in. You should see a book button on the minimap, and `/chron` should report what has been recorded.
5. Right-click the book button to check the settings page, and drag the button to check it moves.
6. Open the journey map and choose the **Synced friends** tab. Each player adds the other's exact character name.
7. Choose **Sync**, and wait for the row to say `Last synced`. Click the friend to replay their journey.
8. Send back anything the tab reported, plus any errors or anything that looked wrong.

## Getting started

Road to Sixty must already be installed in the same game. Then, from the repo root:

```powershell
.\scripts\install.ps1 -WowRoot "D:\WoW\World of Warcraft" -Game classic_era
```

`-Game` accepts `forever`, `classic_era` and `anniversary`, separated by commas. Edit the addon here rather than in the game folder, because the install script mirrors this repo and overwrites anything changed there.

To run the tests on Windows:

```powershell
.\tests\run.ps1
```

They need Microsoft Edge. The first run downloads the Fengari Lua VM to `tests/.build`, so no Lua install is needed.

## Road to Sixty

Road to Sixty is Jordan's addon and isn't included here. This repo depends on it and reads its data, currently tested against version 1.18.0.

The viewer also embeds coastline shapes taken from Road to Sixty's `Gaps/land_*.tga` textures, used with Jordan's approval. No license has been chosen for this repo yet.

Never commit real `WTF` or `SavedVariables` files. They contain routes, play times and the names of other players. `.gitignore` blocks the usual names and paths.
