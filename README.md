# Snake Stages

A Snake arcade game for Godot 4.7 and GDScript, with Campaign, Endless, and Adventure modes.

Open `project.godot` in Godot and press **F6** with `main.tscn` open, or **F5** to run the project. Press Enter or click Start run to play.

## Modes and medals

Choose **Campaign** or **Endless** from the main menu. Clearing a campaign stage permanently unlocks that same stage in Endless, even if the campaign run later ends. New profiles begin with no Endless arenas unlocked. Campaign best, cleared stages, and each arena's Endless best are saved separately.

Players with saves from before Endless was added can use **Restore earlier progress** on the Campaign menu once to record their highest previously cleared stage. This preserves their old high score and sound preference. New saves do not offer this migration option.

In Endless, choose an unlocked arena and keep scoring until a collision ends your run. Its layout and speed remain fixed. Food has no quota, and there are no stage-clear bonuses or transitions. Shield, Shed, and bonus pickups work as in Campaign. Replay restarts the selected arena; Menu returns to mode and arena selection.

Each arena awards **Bronze**, **Silver**, or **Gold** from your highest Endless score. Targets scale with that stage's food value: 15, 35, and 65 times the points for one food. For example, stage 1 targets are 150 / 350 / 650; stage 6 targets are 900 / 2,100 / 3,900. Bonus points count. These are initial balance targets for playtesting. Earning Gold does not end the run, and lower-scoring runs never remove medals. All targets are visible in the arena preview; in-game medal progress stays in the sidebar.

If a player fills every available cell in Endless, the game automatically sheds 30% of the tail to make room for more food and keep the run going, at the same speed and without removing points.

## Controls

- Arrow keys or WASD: turn. The snake moves automatically; reversing into your neck is blocked.
- Space or Escape: pause/resume. Losing window focus also pauses the game.
- Enter: start, resume, advance to the next stage, or replay.
- R: restart the campaign or the selected Endless arena.
- M: toggle sound.
- Phone: tap the large direction buttons or swipe on the board. Runs begin with a **Go!** screen so you can inspect the board first.

## iPhone / PWA

The web build includes compact portrait and landscape layouts, touch steering, offline caching, and home-screen installation from Safari. Desktop keyboard play is retained. See [WEB.md](WEB.md) for building, publishing to GitHub Pages, installing, and device testing. Phone progress is stored locally and does not automatically sync with Windows.

## Adventure

Choose **Adventure** on the menu for seven fixed, replayable mazes. All seven are available immediately, independently of Campaign unlocks. Reach the cyan **E** exit to finish; food is optional. The shortest exit route grows from 31 to 81 moves, the first two courses have wider lanes, and later courses require precise turns through single-cell corridors. Pace increases by 8% between mazes, from 170 ms to about 107 ms per move, and stays fixed within a maze.

Food and pickups have fixed positions so retries are fair. Food grows the snake by one segment and awards 25 points. Shield and 50-point Bonus pickups are available from the start and do not expire. Adventure has no Shed pickups or automatic shrinking. Shield works as in the other modes: one protected collision stops movement until a safe direction is selected.

Scores are banked only on reaching the exit:

- Finish: **1,000 points**.
- Time: up to **1,000 points**. Finish at or before the displayed par time for the full bonus; it falls linearly to zero at twice par. There is no time limit.
- Length: **75 points for each segment beyond the starting four**, awarded at the exit, in addition to food points.
- Food and Bonus pickup points are added to those finish bonuses.

The clock measures active play, excluding the starting grace period, pauses, focus-loss pauses, and shield recovery. Bronze requires 1,000 points, Silver requires 2,000, and Gold targets scale with the amount of food in each maze. Gold is achievable by collecting all food and reaching the exit quickly. Each level saves its best completed score and fastest completed time independently; slower or lower-scoring runs never replace a better record. An unfinished run earns no medal.

| Maze | Full time bonus at | Food | Gold target |
|---|---:|---:|---:|
| First Passage | 10 seconds | 7 | 2,550 |
| Bent Branches | 17 seconds | 8 | 2,650 |
| Needlework | 14 seconds | 9 | 2,750 |
| The Long Way | 15 seconds | 10 | 2,850 |
| Crosscurrent | 14 seconds | 11 | 2,950 |
| Razor Turns | 12 seconds | 12 | 3,050 |
| The Labyrinth | 11 seconds | 13 | 3,150 |

After a finish, Enter advances to the next maze and R replays the current one. After maze seven, Enter returns to maze selection. The result screen breaks down the score and shows the earned medal. Medal and par targets are initial playtesting values, supported by automated complete-food runs rather than broad human balancing.

Adventure records use a separate `[adventure]` section in `user://progress.cfg`; existing Campaign and Endless records remain intact.

## Stages and scoring

Every stage moves 5% faster than the previous one. Stage 1 takes 170 milliseconds per grid step; stage 10 takes about 110 milliseconds. Movement speed remains constant throughout a stage. The pace indicator shows speed relative to stage 1.

| Stage | Name | Food goal | Wall cells | Challenge |
|---|---|---:|---:|---|
| 1 | The Garden | 5 | 0 | Open board to learn the rhythm |
| 2 | Crossroads | 6 | 10 | Two split walls |
| 3 | The Circuit | 7 | 28 | Broken rails and a central divider |
| 4 | Switchback | 8 | 42 | Alternating long horizontal barriers |
| 5 | The Pillars | 9 | 48 | Six thick columns |
| 6 | The Weave | 10 | 54 | Hook-shaped walls and narrow openings |
| 7 | The Gates | 11 | 64 | Four rows of offset gates |
| 8 | The Foundry | 12 | 70 | Solid islands and internal barriers |
| 9 | Switchyard | 13 | 80 | Thick split walls and smaller lanes |
| 10 | The Gauntlet | 14 | 83 | Offset openings, wall spurs, and side obstacles |

Food gives 10 times the stage number in points. Clearing a stage gives 100 times the stage number. Each new stage resets the snake and shield while keeping your score. A full run requires 95 food, and victory appears only after clearing stage 10. All ten layouts have a clear starting runway and connected open space.

Power-ups can appear after every second food if there is no pickup already on the board. Each pickup lasts 14 seconds; the sequence cycles through shield, shed, and bonus. S equips a one-use shield that envelops the whole snake and stops time after a collision until you pick a safe turn. The purple minus pickup sheds 30% of the current snake length from its tail (segments removed round up, with a minimum remaining length of 3). Shed is permanent until you grow again, preserves points and stage progress, and never changes movement speed. + gives 50 points. Power-ups do not count toward the stage's food goal. Speed stays constant within each stage and increases only when you advance to the next one.

High scores, campaign clears, and mute preference save locally in Godot's `user://progress.cfg`. The game works offline. All graphics and short sound effects are generated in code; no external asset downloads are required.

## Editing

- `scripts/snake_game.gd`: grid rules, stage layouts, pace, objectives, and power-ups.
- `scripts/main.gd`: interface, drawing, input, sound, and saved preferences.
- `scripts/adventure_levels.gd`: seven fixed maze maps, food counts, and par times.
- `scripts/phone_ui.gd`: compact layouts, touch targets, and swipe steering.
- `web/shell.html`: browser loading screen, safe screen margins, and offline/update status.
- `main.tscn`: main scene.
- `tests/test_rules.gd`: movement, collision, stage, spawn, and connectivity checks.
- `tests/test_adventure.gd`: complete-course playthroughs, scoring, timer, medals, menu flow, and record persistence.
- `tests/adventure_routes.json`: repeatable all-food solution routes used by Adventure tests.
- `tests/test_phone.gd`: gestures, turn buffering, shield recovery, pausing, and viewport checks.

Run `tools/Check-Project.ps1` in PowerShell to run all five suites. Supply `-ProjectPath` and `-GodotExecutable` for a different installation. The runner uses a fresh temporary APPDATA folder and checks success markers as well as process status. **Do not run persistence tests against your real player profile:** the Endless and Adventure suites write fixture saves. Manual test runs must also use a disposable APPDATA folder.

The web build supports keyboard and touch. A native iOS/App Store release is not included.
