# Road to Sixty: Chronicle

A companion addon for [Road to Sixty](#road-to-sixty) that records more of a character's journey, with an offline viewer that replays many characters and friends on one map.

The goal is to let players sync journeys in game and watch them in Road to Sixty's own map, with toggles for all characters, only yours, or chosen friends. That in-game sync isn't built yet. See [docs/DESIGN.md](docs/DESIGN.md) for the plan and the decisions still open.

## Status

| Part | State |
|---|---|
| Extra tracking (`Chronicle.lua`) | Built; tested only on simulated clients |
| Offline viewer (`Viewer/index.html`) | Built; tested only on generated data in Road to Sixty's format |
| `/chron synctest` message measurement | Built; tested only on a simulated pair of Era clients |
| In-game sync | Not started; waiting on real synctest results |
| Road to Sixty map and panel changes | Not started; needs agreement with Jordan |

**Nothing has run in a real game client yet.** The first live test will be on Classic Era, because Forever isn't playable yet.

## Layout

```
RoadToSixty_Chronicle/   The addon, exactly as it installs
  Chronicle.lua          All in-game code
  Viewer/index.html      Single-file offline viewer
  README.md              Player instructions
docs/DESIGN.md           How it fits with Road to Sixty, and the sync plan
scripts/install.ps1      Copies the addon into a game folder
tests/                   Simulated client tests
```

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

The viewer also embeds coastline shapes taken from Road to Sixty's `Gaps/land_*.tga` textures, so it needs Jordan's agreement before this repo or the viewer is made public. No license has been chosen for this repo yet.

Never commit real `WTF` or `SavedVariables` files. They contain routes, play times and the names of other players. `.gitignore` blocks the usual names and paths.
