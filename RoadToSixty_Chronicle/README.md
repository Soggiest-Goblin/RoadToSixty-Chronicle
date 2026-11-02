# Road to Sixty: Chronicle

Extra journey tracking on top of [Road to Sixty], plus an offline viewer that
replays the journeys of all your characters and your friends' on one map.

Road to Sixty must be installed: it records the path, levels, quests, deaths,
gear and groups. Chronicle adds where party members were, subzones, XP and gold
over time, flights, talents, hearthstones, town visits, trades, screenshots and
your own notes.

## In game

- `/chron` shows what has been recorded so far
- `/chron options` opens the settings page, also found under AddOns in the game's settings
- The book button on the minimap opens the journey map with a left-click and the settings page with a right-click
- `/chron note Finally got my mount!` pins a note to this spot on the map
- `/chron export` reminds you where the files are
- `/chron friend <name>` shares with a friend and syncs their journey
- `/chron sync <name>` syncs a friend's journey again
- `/chron synctest <name>` measures addon messages with another Chronicle player

## Synced friends

Open the journey map and choose the Synced friends tab. Type a friend's exact character name and choose Add, and have them add you. Both of you need to be online, in the same realm and faction, and running this version.

Choose Sync to fetch the journey of the character they're playing. Each of their characters is added separately. A first sync sends about 40 KB a minute, and it carries on from where it stopped if either of you logs off. Later syncs only send what's new.

Click a friend to replay their journey and see their History, or tick the box to draw their path beside yours. They also appear in the Characters tab the next time the map opens.

Adding someone shares your current character's journey with them, including play times and the names of people you've grouped with. Remove stops sharing with them and deletes their journey from your game. Your `RoadToSixty_Chronicle.lua` file holds your friends' synced journeys, so sending it to someone else shares those too.

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
