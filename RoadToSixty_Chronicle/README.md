# Road to Sixty: Chronicle

Extra journey tracking on top of [Road to Sixty], plus an offline viewer that
replays the journeys of all your characters and your friends' on one map.

Road to Sixty must be installed: it records the path, levels, quests, deaths,
gear and groups. Chronicle adds where party members were, subzones, XP and gold
over time, flights, talents, hearthstones, town visits, trades, screenshots and
your own notes.

## In game

- `/chron` shows what has been recorded so far
- `/chron note Finally got my mount!` pins a note to this spot on the map
- `/chron export` reminds you where the files are
- `/chron synctest <name>` measures addon messages with another Chronicle player

Works on Forever, Classic Era and the Anniversary realms, wherever Road to Sixty does: both folders go in that game's `Interface\AddOns`.

## Viewing

1. Log out or type `/reload`. WoW only writes saved data at those moments.
2. Open `Viewer/index.html` in Chrome or Edge.
3. Drag in that game's `WTF` folder, such as `World of Warcraft\_classic_era_\WTF`.

## Sharing with friends

Your friend installs Road to Sixty and this folder, plays, then sends you these
two files from `WTF\Account\<account>\SavedVariables`:

- `RoadToSixty.lua`
- `RoadToSixty_Chronicle.lua`

Put each friend's pair in a folder of its own and drag that in, or drop the files
in one friend at a time. They hold that account's characters, routes, play times
and the names of people grouped with, so only send them to people you trust with
that. The viewer never uploads anything and only reads files as data.
