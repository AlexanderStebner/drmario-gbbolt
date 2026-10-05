# Dr. Mario (Game Boy) - gbbolt disassembly

**Open it: <https://gbbolt.lingora.org/drmario/>**

A complete, matching disassembly of *Dr. Mario* for the Game Boy (Nintendo, 1990), with
pseudo-code written next to every function and checked against the original code in an
emulator. It is read with [gbbolt](https://github.com/gbbolt/gbbolt): code
and pseudo-code side by side, linked line by line.

- **328 of 328 functions** have pseudo-code: 232 are verified by differential testing
  (the pseudo-code and the original code give identical results on 64 random machine
  states), the other 96 are checked (they switch the LCD off, wait for it, talk to the
  link cable or never return, so they can't run in isolation).
- **Every label and RAM variable is named**, and every function sits in a virtual folder
  (`game/viruses`, `game/lines`, `cutscenes`, `sound/music`, ...).
- **Graphics**: tile sheets, screens, the capsule sprites, sprite layouts (Dr. Mario,
  the magnifier viruses, the sea creatures of the cutscenes), the messages written into
  the bottle.
- **Sound**: the sound engine is fully annotated; all 10 songs and 17 sound effects are
  rendered from it, with a piano roll and mute / solo per channel.
- **Played by its own code** (asset plugins in `assets/`): the title demo and all six
  underwater cutscenes as videos, recorded by running the game's routines frame by
  frame; the link game's danger music at every danger level; charts of the drop speed,
  the chain points, the virus counts and heights, and the capsule odds.

Some things the code shows: viruses are placed so that none has one of its own colour
two cells away; each virus in a chain is worth double the one before; in a link game
the music speeds up and climbs in pitch as the other player gets close to winning;
pausing a 1-player game hides the bottle.

## Building

The disassembly rebuilds the original ROM byte for byte. You need
[RGBDS](https://rgbds.gbdev.io) 1.0.1, Python 3.9+ with numpy, and gbbolt next to this
folder:

```
git clone https://github.com/gbbolt/gbbolt
git clone https://github.com/gbbolt/drmario-gbbolt
cd drmario-gbbolt
python ../gbbolt/tools/audio.py             # render the music (needs ffmpeg)
python ../gbbolt/tools/gbbolt.py            # build, verify, write out/site/index.html
```

The build is checked against the SHA1 of the original ROM
(`f1006d6cf77469092f3b9f266d0a65da9c91ac42`, *Dr. Mario (World)*). No ROM is needed to
build it. If you put your own dump next to `game.json` as `drmario.gb`, it is compared
byte by byte.

## Layout

```
game.json           what gbbolt needs to know about the game
src/game.asm        the main file
src/bank_000.asm    the disassembly with its annotations
src/ram.inc         RAM variables: names, types, descriptions
src/hardware.inc    hardware registers
src/folders.txt     the virtual folders
src/sound.json      how to drive the sound engine
assets/*.py         asset plugins: replays, cutscenes, danger music, charts
```

## Legal

Dr. Mario and its code, graphics and music are the property of their respective owners
(Nintendo; the music by Hirokazu Tanaka). This repository contains no ROM. It is a
research and documentation project in the tradition of other community disassemblies;
please buy the game.

The annotations, names, pseudo-code, descriptions, plugins and configuration written for
this project are available under the MIT license (see [LICENSE](LICENSE)), as far as
they are separable from the game itself.
