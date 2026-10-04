# From power-on to the first CLEAR

What the code does between switching the Game Boy on and the word CLEAR appearing in the
bottle at the end of the first level, in the order it happens.

## Power on

The CPU starts at `Boot`, which jumps via `Entry` to `Start`. That routine does the
Game Boy chores in one go:

- It clears all of RAM, VRAM, OAM and HRAM, and switches the LCD off at line `$94`.
- It copies the 10-byte `OAMDMARoutine` into HRAM (`hOAMDMA`). During a sprite DMA the CPU
  can only run code from HRAM, so the routine has to live there.
- It sets the palettes, switches the sound on and loads the game's tiles (`LoadGameTiles`).
- It sets up the timer to fire about 63 times a second. That interrupt (`TimerHandler`)
  drives the sound engine, so the music keeps its tempo whatever the game is doing.

Then it sets `hGameState` to 0 and falls into `MainLoop`.

## One state per frame

`MainLoop` is the whole game's heartbeat. Every frame it reads the buttons (`ReadJoypad`),
runs the current state (`RunGameState`) and waits for VBlank.

`RunGameState` is a one-liner: `rst $28` lands in `JumpTable`, which jumps to entry
`hGameState` of `GameStateTable`. The title, the options, placing viruses, playing and
the cutscenes are all just numbers in that table, and moving on means writing a new number.

Two extras in the loop:

- In a link game it swaps a byte with the other Game Boy every frame.
- A+B+SELECT+START restarts the game from `Start`.

Meanwhile the `VBlankHandler` copies the sprites to OAM and runs `VBlankDraw`, which does
one queued drawing job per frame (a new virus, a bottle row, a letter of text). It also
redraws the score (`DrawBCD7`).

## The title screen

`TitleInit` loads the title screen with the LCD off and puts the cursor on 1 PLAYER.
`TitleScreen` then does three things every frame:

- It moves the cursor between 1 PLAYER and 2 PLAYER.
- It listens on the link cable. If another Game Boy pressed START first, this one becomes
  the slave.
- It counts down `hDemoTimer`, about 8.5 seconds.

When the countdown runs out the demo starts on level 10. It plays a fixed bottle
(`DemoBottle`) with button presses from `DemoInputs`, stored as (buttons, frames) pairs.
While it runs, the timer interrupt drops the game's sound effects. Watch it in
[the demo replay](demo-replay).

## Options

START on 1 PLAYER goes to `OptionsInit1P`. The options screen has three boxes, each its
own game state: `VirusLevelSelect`, `SpeedSelect` and `MusicSelect`. Up and down move
between them.

The music box plays the choice straight away (`PlayChosenMusic`): FEVER, CHILL or OFF.
START in any box begins the game.

## Setting up level 0

`GameInit` loads the game screen, and a copy of it goes into BG map 1 for the pause
screen. Then `LevelInit` sets up the level:

- It deals three capsules (`NextCapsule`) so that a current and a next one are ready.
- The speed picks a start index into the drop table: 0 for LOW, 9 for MED, 20 for HI
  (`SetDropSpeed`, and [the drop speed chart](chart-drop-speed)).
- `VirusCountForLevel`: a level has 4 x (level + 1) viruses, so level 0 has just 4.

Then `PlaceViruses` fills the bottle at one virus per frame:

- `PlaceOneVirus` picks a random cell. `VirusRowMasks` keeps it low in the bottle on easy
  levels ([how high the viruses go](chart-virus-height)).
- `TryPlaceVirus` rules out any colour that already sits two cells away, left, right, up
  or down (`CheckLeft2`, `CheckRight2`, `CheckUp2`, `CheckDown2`). `CheckUp2` has no check
  for the top, so on the first two rows it looks at bytes past the end of the bottle.
- `DrawNewVirus` puts each one on screen in the next VBlank.

## One frame of play

`Play` runs every frame of the level:

- `HandleCapsuleInput`: A and B turn the capsule. Its four orientations are just the low
  two bits of its sprite id. If a turn hits something, it tries one column further left.
- `UpdateFall` drops it a row every `hDropDelayBase` frames, or every 3 frames while Down
  is held.
- `LockCapsule` writes the landed halves into the BG map and into `wBottle`: 8 x 16 bytes,
  one per cell. A half's tile says where its partner is: `$8x` left, `$9x` right, `$Ax`
  top, `$Bx` bottom.
- `NextCapsule` brings on the next one. Colours come from the divider register (`Random`),
  re-rolled up to three times to avoid repeats ([the capsule odds](table-capsule-odds)).

## Four in a row

After a capsule lands, `UpdateBottle` runs the clearing as a little state machine of its
own (`RunClearStep`), one step per frame:

- `FindRowRuns` and `FindColumnRuns` look for four or more of one colour.
- `ShowPops` turns the cleared cells into pop tiles, and `SplitBrokenCapsules` turns halves
  that lost their partner into lone halves.
- `DropHalves` lets everything with room below fall one row, then the search starts again.

Each virus scores through `ScoreVirus`. The points double for every earlier virus of the
same chain (`hCombo`, [points per virus](chart-chain-points)).

## CLEAR

When a step finds no viruses left (`RemovePops`), `CheckLevelCleared` switches to
`LevelCleared`. It hides the capsules, writes CLEAR and PUSH START! into the bottle
(`DrawClearText`, `DrawPushStart`) and raises the level (`VirusLevelUp`).

`LevelEndWait` plays the clear jingle and waits for START. Then `NextLevelOrCutscene`
goes back to `LevelInit` for level 1. On HI speed, levels 5, 10 and 15 are followed by an
underwater cutscene first ([the turtle](cutscene-turtle)).
