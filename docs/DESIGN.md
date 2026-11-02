# Design notes

Line numbers refer to Road to Sixty 1.18.0.

## Where Chronicle stands

Chronicle is a separate addon that requires Road to Sixty. It doesn't change Road to Sixty.

Road to Sixty's `ns` table is private, so Chronicle can only reach two of its globals: `RoadToSixtyDB` (account) and `RoadToSixtyCharDB` (character). Because of that, Chronicle has its own event frame and records into its own saved variable, `RoadToSixtyChronicleDB`.

Chronicle adds these on top of what Road to Sixty records:

- Party members' positions
- Subzones and town visits
- XP and gold over time
- Flights, hearthstones and rest
- Talents
- Trades and screenshots
- Player notes
- A dump of the map hierarchy

Players control it with its settings page and with `/chron`, `/chron options`, `/chron note`, `/chron export` and `/chron synctest`.

## Goal

Friends sync journeys in game, and everything shows on Road to Sixty's map. The offline viewer stays as the detailed fallback.

## Settings page

Road to Sixty keeps its own page. Chronicle has a separate, larger one in `Settings.lua`, which contains:

- Which of the account's characters the map draws
- The sync test
- A switch for each kind of Chronicle tracking, saved in `RoadToSixtyChronicleDB.off`
- Every Road to Sixty setting

The Road to Sixty settings aren't copied. Both pages read and write the same `RoadToSixtyDB` values, so they can't disagree. There are two costs while `ns` stays private:

- `ROAD_TO_SIXTY` in `Settings.lua` repeats the option list from `Options.lua`, so a new Road to Sixty option has to be added by hand.
- Chronicle can't call `ns.Map:ApplySettings` or `ns.Map:RefreshCharacters`, so changes show the next time the map opens. The minimap button is the exception, because Chronicle can use `/rts minimap`.

Exposing the option list and those two calls publicly would remove both costs.

## Plan

### 1. Measure addon messages

`/chron synctest <name|party|guild>` sends 240-character messages at 1, 2 and then 4 per second, and saves the results to `syncTests`. The limits below are from documentation and reports, not from measurement:

- About 255 bytes per message
- A burst of 10 per prefix, then 1 per second
- Forever may block instance messaging and return secret values
- Trial and Veteran accounts can't send

The first live test, by whisper on Classic Era in the open world, delivered every message at all three rates. Sync runs at 3 messages a second, about 40 KB a minute, leaving room under the fastest rate measured.

### 2. Sync without changing Road to Sixty

Built in `Friends.lua` and `FriendsTab.lua`:

- Adding a friend is the approval. A journey is only sent to, or taken from, a player on the list.
- A sync is pulled. The asker says what it has, and the sender replies with the next batch of its current character's `RoadToSixtyCharDB`, so a stopped sync resumes and later syncs send only what's new. The journey isn't thinned.
- Batches are plain text, parsed as data and checked before they're kept. A friend's data can't replace one of the account's own characters.
- Friends' journeys are stored in Chronicle's own saved variable.
- At login Chronicle adds them to `RoadToSixtyDB.roster`, and at logout it removes them so they never become part of Road to Sixty's own data. Login clears any a crash left behind.

The roster already drives the character list, path checkboxes, view switching and stats, so friends appear there with no Road to Sixty changes.

Costs of working from outside Road to Sixty:

- This relies on its internal formats.
- The tab finds the map's panel by its structure, shrinks its two tabs to make room, and calls a character row's click scripts, because `Map:ShowJourney` and `Map:RefreshCharacters` are private. If the panel changes, the tab won't appear, and sync and the Characters tab still work.
- A sync while the map is open reaches the Characters tab the next time the map opens.
- Events changed after they were sent are only refreshed for the latest 20.
- Sync is by whisper, so it needs the same realm and faction.

### 3. Changes that need Road to Sixty

Road to Sixty currently draws other characters' paths in full and without animation (`BuildOtherTracks`, `Map.lua:1349`, called at `Map.lua:3064` and `Map.lua:3169`). Only the selected character replays. The checkboxes are in `Panel.lua:849` and `Panel.lua:926`.

| Change | Where |
|---|---|
| Replay several characters at the same time | `Map.lua` |
| All / Just Mine / specific friends toggles in the map's own list | `Panel.lua` |
| Chronicle events on the map, such as notes and flights | `Map.lua` |

## Questions for Jordan

1. **Would you rather merge these features into Road to Sixty, or keep Chronicle separate?** A small public hook on Road to Sixty's side would avoid the login and logout roster workaround.
2. **Can Road to Sixty expose a stable API?** For example, `RoadToSixty.AddExternalCharacter(entry)`, `RemoveExternalCharacter(key)`, a way to add map events, its option list, and calls to refresh an open map.
3. **What's the best way to change `Map.lua` and `Panel.lua`?** Chronicle shouldn't carry a patched copy that has to be redone after every release.
4. **Is the coastline data OK to reuse?** The viewer embeds run-length masks taken from `Gaps/land_*.tga`. This has to be settled before anything goes public.
5. **Which license should this use, and how should it be credited?** Road to Sixty has no license file, so this repo includes none of its code.
6. **Are the saved data formats stable?** If they change between versions, is there a version field Chronicle should check?

## Testing

`tests/run.ps1` runs the real `Chronicle.lua` against simulated clients:

- `mock_client.lua` covers tracking, both talent API shapes, and secret values.
- `two_clients.lua` covers a synctest between two Era clients with a modelled send limit, plus junk messages.
- `settings.lua` covers the settings page against stand-in widgets, so it checks behaviour but not how the page looks.
- `friends.lua` covers sync between two clients, including consent, resuming, hostile batches and the roster, and the tab against stand-ins for Road to Sixty's panel.

Earlier one-off checks of the viewer aren't in this repo. They used a 600,000-point file (95 ms to parse, 226 ms to build, 56 fps) and a hostile file to test escaping.

The first live test needs two accounts on Classic Era:

1. Run `/chron synctest` in the open world and in a dungeon, then record the `Stage` lines.
2. Run `/chron` and check the error count.
3. Note any Lua errors.
4. Keep the saved files locally so the viewer can be checked against real data. Don't commit them.
