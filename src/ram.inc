; Named RAM / IO addresses.
; Format: DEF name EQU $addr ;@ type description
;   type: u8 | u16 (little endian) | u8[N] | code[N] | const
; Lines without ";@" are plain constants.

DEF wObjects EQU $C200 ;@ u8[$100] Objects: 16 bytes each (state, y, x, sprite, attribute bits, flip, attributes, ...)
DEF wSndChannel EQU $DF70 ;@ u8 Sound engine: channel being updated (1-4)
DEF wSFXPlaying EQU $DFE1 ;@ u8 Square channel sound effect playing (0 = none); followed by its frame counter, period and step
DEF wCurrentSong EQU $DFE9 ;@ u8 Song the sound engine is playing (0 = none)
DEF wWaveSFXPlaying EQU $DFF1 ;@ u8 Wave channel sound effect playing (0 = none)
DEF wNoiseSFXPlaying EQU $DFF9 ;@ u8 Noise channel sound effect playing (0 = none)
DEF hJoyHeld EQU $FF80 ;@ u8 Buttons held: bit 7 Down, 6 Up, 5 Left, 4 Right, 3 Start, 2 Select, 1 B, 0 A
DEF hJoyPressed EQU $FF81 ;@ u8 Buttons newly pressed this frame (same bit layout as hJoyHeld)
DEF hObjState EQU $FF86 ;@ u8 Object being drawn: state byte (0 = visible, $80 = hidden, other = skip)
DEF hObjY EQU $FF87 ;@ u8 Object being drawn: Y (OAM space)
DEF hObjX EQU $FF88 ;@ u8 Object being drawn: X (OAM space)
DEF hObjSprite EQU $FF89 ;@ u8 Object being drawn: sprite id (index into SpriteTable); reused for the tile number
DEF hObjAttrBits EQU $FF8A ;@ u8 Object being drawn: extra OAM attribute bits ORed into every tile
DEF hObjFlip EQU $FF8B ;@ u8 Object being drawn: bit 6 = flip vertically, bit 5 = flip horizontally (also ORed into the attributes)
DEF hObjAttr EQU $FF8C ;@ u8 Object being drawn: base OAM attributes
DEF hOAMPtrHi EQU $FF8D ;@ u8 High byte of the next free shadow OAM entry (DrawObjects)
DEF hOAMPtrLo EQU $FF8E ;@ u8 Low byte of the next free shadow OAM entry (DrawObjects)
DEF hObjCount EQU $FF8F ;@ u8 Number of objects DrawObjects still has to draw
DEF hSpriteYOff EQU $FF90 ;@ u8 Sprite being drawn: Y offset from its header
DEF hSpriteXOff EQU $FF91 ;@ u8 Sprite being drawn: X offset from its header
DEF hTileX EQU $FF92 ;@ u8 Tile being drawn: screen X
DEF hTileY EQU $FF93 ;@ u8 Tile being drawn: screen Y
DEF hTileAttr EQU $FF94 ;@ u8 Tile being drawn: OAM attributes
DEF hObjHidden EQU $FF95 ;@ u8 Non-zero while drawing a hidden object (its tiles get Y = $FF)
DEF hObjPtrHi EQU $FF96 ;@ u8 High byte of the object being drawn
DEF hObjPtrLo EQU $FF97 ;@ u8 Low byte of the object being drawn
DEF hCoordY EQU $FFB2 ;@ u8 Y coordinate in OAM space (screen y + 16)
DEF hCoordX EQU $FFB3 ;@ u8 X coordinate in OAM space (screen x + 8)
DEF hBGMapAddr EQU $FFB4 ;@ u16 BG map address computed by CoordsToBGMapAddr
DEF hBoardCopyStage EQU $FFE3 ;@ u8 0 = idle; 2..$13 = copying wBGMap0Copy to VRAM one board row per VBlank, bottom row first

; generic hardware constants (as in the other gbbolt games)
DEF vTiles0 EQU $8000 ;@ const Tile data block 0
DEF vBGMap0 EQU $9800 ;@ const BG tile map 0 (32x32 tiles)
DEF vBGMap1 EQU $9C00 ;@ const BG tile map 1 (32x32 tiles)
DEF WORK_RAM0 EQU $C000 ;@ const Work RAM, first 4 KB ($C000-$CFFF)
DEF WORK_RAM1 EQU $D000 ;@ const Work RAM, second 4 KB ($D000-$DFFF)
DEF OAM_START EQU $FE00 ;@ const Object attribute memory (40 sprites x 4 bytes)
DEF HRAM_START EQU $FF80 ;@ const High RAM ($FF80-$FFFE)
DEF WAVE_RAM EQU $FF30 ;@ const Wave pattern RAM of sound channel 3 (32 4-bit samples)
DEF BTN_A EQU $01 ;@ const hJoyHeld / hJoyPressed bit
DEF BTN_B EQU $02 ;@ const
DEF BTN_SELECT EQU $04 ;@ const
DEF BTN_START EQU $08 ;@ const
DEF BTN_RIGHT EQU $10 ;@ const
DEF BTN_LEFT EQU $20 ;@ const
DEF BTN_UP EQU $40 ;@ const
DEF BTN_DOWN EQU $80 ;@ const
DEF wShadowOAM EQU $C000 ;@ u8[$a0] Shadow OAM: 40 sprites x (y, x, tile, attributes), copied to OAM by DMA every VBlank
DEF hTimer1 EQU $FFA6 ;@ u8 General purpose countdown, decremented once per frame while non-zero
DEF hTimer2 EQU $FFA7 ;@ u8 Second countdown, decremented once per frame while non-zero
DEF hVBlankDone EQU $FF85 ;@ u8 Set to 1 by the VBlank handler; the main loop waits for it
DEF hGameState EQU $FFE1 ;@ u8 Index into GameStateTable: the state the main loop runs each frame
DEF hOAMDMA EQU $FFB6 ;@ code[10] Copy of OAMDMARoutine in HRAM (copied there by Start)
DEF hSavedIE EQU $FFA1 ;@ u8 rIE saved while DisableLCD waits for VBlank
DEF hClearStep EQU $FF9C ;@ u8 Step of the clearing that follows a locked capsule (index into the jump table in RunClearStep)
DEF hDrawBCDFlag EQU $FFE0 ;@ u8 Set when a BCD number has to be (re)drawn; DrawBCD7 reuses it as 'a digit was printed' (leading zeros blank)
DEF wScore EQU $C0A0 ;@ u8[4] Score, 7 BCD digits, least significant byte first (capped at 9999999)
DEF hVirusLevel EQU $FFC2 ;@ u8 Virus level chosen on the options screen (0-20)
DEF hVirusLevelBCD EQU $FFC3 ;@ u8 hVirusLevel in BCD, for display
DEF hVirusLevel2P EQU $FFC4 ;@ u8 The other player's virus level in a versus game
DEF hVirusLevel2PBCD EQU $FFC5 ;@ u8 hVirusLevel2P in BCD
DEF hDemoTimer EQU $FFF0 ;@ u8 Title screen countdown (in hTimer1 periods) until the demo starts
DEF hSerialRole EQU $FFCB ;@ u8 Link cable role: $30 = master, $60 = slave, 0 = no link
DEF hSerialTx EQU $FFCF ;@ u8 Next byte to send over the link cable
DEF hSerialRx EQU $FFD0 ;@ u8 Last byte received over the link cable
DEF hTwoPlayer EQU $FFB1 ;@ u8 Non-zero in a 2-player (link) game
DEF hRepeatDelay EQU $FFAA ;@ u8 Frames until a held direction repeats on the options screen
DEF wSFXRequest EQU $DFE0 ;@ u8 Sound effect to start (read by the sound engine)
DEF wMusicRequest EQU $DFE8 ;@ u8 Song to start (read by the sound engine)
DEF hSpeed EQU $FFAD ;@ u8 Virus speed chosen on the options screen
DEF hSpeed2P EQU $FFAE ;@ u8 The other player's virus speed in a versus game
DEF hMusicType EQU $FFC1 ;@ u8 Music chosen on the options screen (0-2)
DEF hSerialDone EQU $FFCC ;@ u8 Set to 1 when a serial transfer has completed
DEF SERIAL_MASTER EQU $30 ;@ const hSerialRole / link byte: this Game Boy drives the clock
DEF SERIAL_SLAVE EQU $60 ;@ const
DEF wBottle EQU $C800 ;@ u8[$80] The bottle: 8 columns x 16 rows, one byte per cell ($FF = empty)
DEF wCapsuleList EQU $C300 ;@ u8[$80] Capsule colours dealt in order in link and demo games (the master rolls them)
DEF hCapsuleListPos EQU $FFB0 ;@ u8 Next index into wCapsuleList
DEF hNextRandom EQU $FFAF ;@ u8 Random capsule rolled ahead (RandomCapsule returns the previous one)
DEF hPrevCapsule EQU $FFFE ;@ u8 The capsule colours RandomCapsule returned last
DEF hDemoMode EQU $FFE4 ;@ u8 Non-zero while the title demo plays
DEF hSpeedIndex EQU $FFAC ;@ u8 Drop speed index: 0 / 9 / 20 for LOW / MED / HI, plus the level above 20
DEF hVirusCount EQU $FFC6 ;@ u8 Viruses left in the bottle
DEF hVirusCount2P EQU $FFC7 ;@ u8 The other player's viruses left
DEF hDropDelay EQU $FF99 ;@ u8 Frames between two steps of the falling capsule (from DropSpeedTable)
DEF hDropDelayBase EQU $FF9A ;@ u8 hDropDelay for the current speed
DEF hVirusColours EQU $FFDA ;@ u8 Virus placement: bits 2/1/0 = colour 0/1/2 would line up with one two cells away; bits 7/6/5 = colour 0/1/2 is tried first
DEF hVirusesPlaced EQU $FFD1 ;@ u8 Viruses put into the bottle so far (later: viruses left)
DEF hVirusesPlacedBCD EQU $FFD2 ;@ u8 hVirusesPlaced in BCD, for display
DEF hViruses0 EQU $FFD5 ;@ u8 Viruses of colour 0 in the bottle
DEF hViruses1 EQU $FFD6 ;@ u8 Viruses of colour 1 in the bottle
DEF hViruses2 EQU $FFD7 ;@ u8 Viruses of colour 2 in the bottle
DEF wWaveSFXRequest EQU $DFF0 ;@ u8 Wave channel sound effect to start (sound engine request)
DEF wNoiseSFXRequest EQU $DFF8 ;@ u8 Noise channel sound effect to start (sound engine request)
DEF wSoundPause EQU $DF7F ;@ u8 Sound engine request: 1 = pause, 2 = resume
DEF wChannel1 EQU $DF90 ;@ u8[16] Music channel 1: pattern list, timers, pattern pointer, instrument, frequency, flags
DEF wChannel2 EQU $DFA0 ;@ u8[16] Music channel 2: pattern list, timers, pattern pointer, instrument, frequency, flags
DEF wChannel3 EQU $DFB0 ;@ u8[16] Music channel 3: pattern list, timers, pattern pointer, instrument, frequency, flags
DEF wChannel4 EQU $DFC0 ;@ u8[16] Music channel 4: pattern list, timers, pattern pointer, instrument, frequency, flags
DEF hPaused EQU $FFAB ;@ u8 Non-zero while the game is paused
DEF hLevelCleared EQU $FFA9 ;@ u8 Set when the last virus is gone (or, in a link game, the other side reports a win)
DEF hDemoButtons EQU $FFED ;@ u8 Buttons the demo is holding down
DEF hDemoSavedHeld EQU $FFEE ;@ u8 The real hJoyHeld, kept while the demo plays
DEF wDemoHold EQU $C4EA ;@ u8 Frames the demo keeps its current buttons
DEF wDemoPtr EQU $C4EB ;@ u8[2] Next entry in DemoInputs (big-endian)
DEF wInPlay EQU $C4F1 ;@ u8 Set while a level is being played (state $04 and the states it hands over to)
DEF hBlocked EQU $FF9B ;@ u8 Set by CheckSpriteCells when a sprite overlaps a filled bottle cell or the walls
DEF hTemp EQU $FFA0 ;@ u8 Scratch byte (the old sprite id or x while trying a move)
DEF hCapsuleState EQU $FF98 ;@ u8 The capsule: 0 = falling, 1 = landed (lock it), 2 = locked
DEF hToppedOut EQU $FFC0 ;@ u8 Set when a new capsule has no room: the bottle is full
DEF hCutscenePhase EQU $FFF9 ;@ u8 Cutscene step: 0 = set up, 1 = creature crossing, then the ending text
DEF hFrameCount EQU $FFE2 ;@ u8 Counts up once per frame (VBlank)
DEF hRunColours EQU $FFD8 ;@ u8 Colours of the runs cleared this turn: 2 bits each (colour + 1), newest lowest (the link game sends them as garbage)
DEF hFoundRun EQU $FF9F ;@ u8 Set when a scan found a run of four or more
DEF hVirusColoursHit EQU $FFDB ;@ u8 Colours that lost a virus: bits 2/1/0 the first time, bits 7/6/5 again (the magnifier viruses react)
DEF hCombo EQU $FFE8 ;@ u8 Viruses cleared in this chain so far (at most 5): raises the points per virus
DEF hCapsuleCount EQU $FFF3 ;@ u8 Capsules since the last speed-up (every 10 the game gets faster)
DEF hSendGarbage EQU $FFDD ;@ u8 Link game: set when this turn's runs should go to the other side as garbage
DEF hDanger EQU $FFCE ;@ u8 Link game: set once the danger music for a nearly-won round has started
DEF hRedrawRow EQU $FFEF ;@ u8 Bottle rows still to be copied to the screen, bottom up, one per frame (16 = the whole bottle)
DEF hVBlankJob EQU $FF9D ;@ u8 Drawing job for the VBlank handler: 1 = a new virus, 2 = a bottle row, 3 = a letter of the ending text
DEF hDangerLevel EQU $FFDE ;@ u8 Link game: how close the other side is to winning (0-3), from hVirusThresholds
DEF hHalvesMoved EQU $FFF5 ;@ u8 Set when DropHalves moved something this pass
DEF hDropWait EQU $FFF7 ;@ u8 DropHalves is waiting for the bottle redraw
DEF hGarbage EQU $FFD9 ;@ u8 Link game: colours of the runs the other side sent (2 bits each, like hRunColours)
DEF hDanceTimer1 EQU $FFE5 ;@ u8 Frames since magnifier virus 1 last danced (counted in VBlank)
DEF hDanceTimer2 EQU $FFE6 ;@ u8 Frames since magnifier virus 2 last danced
DEF hDanceTimer3 EQU $FFE7 ;@ u8 Frames since magnifier virus 3 last danced
DEF hMagnifierVirus1 EQU $FFFA ;@ u8 Magnifier virus 1: 0 = dancing, 1-2 = vanishing, 3 = gone
DEF hMagnifierVirus2 EQU $FFFB ;@ u8 Magnifier virus 2: 0 = dancing, 1-2 = vanishing, 3 = gone
DEF hMagnifierVirus3 EQU $FFFC ;@ u8 Magnifier virus 3: 0 = dancing, 1-2 = vanishing, 3 = gone
DEF wSongBeat EQU $DF88 ;@ u8 Frames per beat of the current song (from a table by song); the magnifier viruses dance to it
DEF hVirusAnim EQU $FFF8 ;@ u8 Offset of the next virus animation tile to copy to VRAM (0-$50 in steps of $10)
DEF hRoundResult EQU $FFF4 ;@ u8 Link game: this side's round result to send: $FD = bottle full (lost), $F8 = all viruses cleared (won)
DEF hSerialLast EQU $FFF2 ;@ u8 The last byte the serial interrupt received, whatever it was
DEF wGarbageNext EQU $C0A5 ;@ u8 Set after a $FE: the next byte received is garbage colours
DEF wGarbageIn EQU $C0A4 ;@ u8 Garbage colours received from the other side
DEF hGarbageArrived EQU $FFDC ;@ u8 Set when a garbage header ($FE) arrived
DEF wSndTemp EQU $DF71 ;@ u8 Sound engine: scratch (id of the sound being started, vibrato type)
DEF wPanMode EQU $DF78 ;@ u8 Sound engine: 1 = fixed panning (wPanA), otherwise wPanA and wPanB alternate
DEF wPanFrame EQU $DF79 ;@ u8 Sound engine: frames since the last panning swap
DEF wPanPeriod EQU $DF7A ;@ u8 Sound engine: frames between panning swaps
DEF wPauseTimer EQU $DF7E ;@ u8 Sound engine: counts down the pause jingle
DEF wSongFlags EQU $DF80 ;@ u8 Sound engine: first byte of the song header ($9F in a pattern sets it too)
DEF wNoteLengths EQU $DF81 ;@ u16 Sound engine: pointer to the song's note length table ($9E in a pattern sets it)
DEF wNearlyFull EQU $DF8A ;@ u8 Link game: the bottle's neck has something in it (set by FindRowRuns)
DEF wDangerMusic EQU $DF8B ;@ u8 Link game: request for the danger version of the music
DEF wTempoCount EQU $DF8D ;@ u16 Sound engine: frames counted while the danger tempo ($DF8F = 3) runs
DEF wDangerLevel EQU $DF8F ;@ u8 Link game: hDangerLevel for the sound engine
DEF wPanToggle EQU $DF7B ;@ u8 Sound engine: bit 0 picks wPanA or wPanB
DEF wPanA EQU $DF7C ;@ u8 Sound engine: NR51 value A of the song
DEF wPanB EQU $DF7D ;@ u8 Sound engine: NR51 value B of the song
DEF wWins1 EQU $D000 ;@ u8 Link game: rounds won by this side (3 wins the match)
DEF wWins2 EQU $D001 ;@ u8 Link game: rounds won by the other side
DEF wVirusCell EQU $D002 ;@ u8[2] Bottle cell of the virus just placed (big-endian), for BottleCellToVRAM
DEF wScanSteps EQU $D004 ;@ u8 Cells PlaceOneVirus has scanned past its random start
DEF wCrabTimer EQU $D005 ;@ u8 Counts calls between the crab's claw moves
DEF wSwordfishTimer EQU $D006 ;@ u8 Counts calls between the swordfish's tail moves
DEF wColourPlaced EQU $D007 ;@ u8 Set by PlaceVirus0/1/2 when they put a virus in
DEF wLinkByteReady EQU $D008 ;@ u8 Link game: this exchange's byte has been chosen
DEF wEndingLetter EQU $D009 ;@ u8 Ending text: index of the next letter to type
DEF wVirusesExcited EQU $D00A ;@ u8 Cutscenes: the viruses dance faster while a creature passes
DEF wNewVirusPending EQU $D00C ;@ u8 A placed virus waits for VBlank to draw it
DEF wVirusAnim EQU $D00D ;@ u8 Set during a level: VBlankDraw animates the bottle viruses
DEF wGarbageHeaderSent EQU $D00E ;@ u8 Link game: \$FE went out, the colours follow
DEF wVirusChanges EQU $D00F ;@ u8 Counts viruses placed and cleared (not read)
DEF wVirusPlaced EQU $D010 ;@ u8 Set by TryPlaceVirus when the cell took a virus
DEF wThrowStep EQU $D012 ;@ u8 Step of Dr. Mario's throw (1 wind up, 2 throw, 13 done)
DEF wThrowPathPos EQU $D013 ;@ u8 Offset of the thrown capsule's next ThrowPath point
DEF wThrowTimer EQU $D014 ;@ u8 Frames until the throw's next step
DEF wDanceStep1 EQU $D015 ;@ u8 Magnifier virus 1: dance pose (0-3)
DEF wGarbageCopy EQU $D016 ;@ u8 Copy of hGarbage (not read)
DEF wDanceStep2 EQU $D017 ;@ u8 Magnifier virus 2: dance pose
DEF wDanceStep3 EQU $D018 ;@ u8 Magnifier virus 3: dance pose
DEF wWobble1 EQU $D019 ;@ u8 Magnifier virus 1: wobble side while hurt
DEF wWobble2 EQU $D01A ;@ u8 Magnifier virus 2: wobble side while hurt
DEF wWobble3 EQU $D01B ;@ u8 Magnifier virus 3: wobble side while hurt
DEF wHurtStep1 EQU $D01C ;@ u8 Magnifier virus 1: step of its hurt animation
DEF wHurtStep2 EQU $D01D ;@ u8 Magnifier virus 2: step of its hurt animation
DEF wHurtStep3 EQU $D01E ;@ u8 Magnifier virus 3: step of its hurt animation
DEF wLaughFrame EQU $D01F ;@ u8 Laughing viruses: normal or laughing frame
DEF wGarbageInCopy EQU $D020 ;@ u8 Copy of the garbage colours received (not read)
DEF wLevelStartWait EQU $D021 ;@ u8 Set at a level's start: the first throw waits
DEF wLevelStartTimer EQU $D022 ;@ u8 Counts the frames before a level's first throw (\$50)
DEF wRedrawVRAM EQU $D023 ;@ u8[2] BG map address of the bottle row to redraw (big-endian)
DEF wRedrawCell EQU $D026 ;@ u8 First bottle cell of the row to redraw
DEF wVanishTimer1 EQU $D027 ;@ u8 Magnifier virus 1: frames of its vanishing frame
DEF wVanishTimer2 EQU $D028 ;@ u8 Magnifier virus 2: frames of its vanishing frame
DEF wVanishTimer3 EQU $D029 ;@ u8 Magnifier virus 3: frames of its vanishing frame
DEF wNewVirusTile EQU $D035 ;@ u8 Tile of the virus just placed
DEF wNewVirusVRAM EQU $D036 ;@ u8[2] BG map address of the virus just placed (big-endian)
DEF wLinkHold EQU $D03A ;@ u8 Counts levels started; while set the master sends no link bytes
DEF wCheerFrame EQU $D03F ;@ u8 Winning Dr. Mario: throwing or arms-up frame
DEF wColumnVirus EQU $D041 ;@ u8 A virus went in a column run (the clear sound is \$06)
DEF wJinglePlayed EQU $D042 ;@ u8 The level / round end jingle has been requested
DEF wGarbageOut EQU $D046 ;@ u8 Link game: the garbage colours to send after \$FE
DEF wShowResults EQU $D04B ;@ u8 Link game: show the round results panel
DEF wClearSFXDone EQU $D050 ;@ u8 The sound after the clear jingle has played
DEF wDangerBlink EQU $D051 ;@ u8 Frame of the blinking danger sprite
DEF wPastLevel20 EQU $D052 ;@ u8 Set when the virus level reaches 21: the speed's ending follows
DEF wDemoSFXOK EQU $D054 ;@ u8 Lets one sound effect through during the demo
DEF wUnderwaterStep EQU $D056 ;@ u8 Step of the underwater tile animation (0-3)
DEF wShellTimer EQU $D05B ;@ u8 Counts calls between the shell's frames
DEF wRiseToggle EQU $D05F ;@ u8 HI ending: the viruses float up every other step
DEF wShellWait EQU $D060 ;@ u8 HI ending: frames before the shell comes
DEF wFinTimer EQU $D061 ;@ u8 Counts calls between the coelacanth's tail frames
DEF wBubbleStep EQU $D063 ;@ u8 Cutscene bubbles: steps since the first bubble started
DEF wSinkerCount EQU $D064 ;@ u8 HI ending: counts up to wSinkerLimit
DEF wSinkerLimit EQU $D065 ;@ u8 HI ending: grows to 14, then the coelacanth comes
DEF wBubbleSlot EQU $D066 ;@ u8 HI ending: shadow OAM offset for the next bubble
DEF wBubbleSteps EQU $D067 ;@ u8 HI ending: drift steps since the last new bubble
DEF wTextVRAM EQU $D068 ;@ u8[2] BG map address of the next ending letter (big-endian)
DEF wEndingText EQU $C500 ;@ u8[$40] The ending's text: CONGRATULATIONS! / VIRUS LEVEL / SPEED, typed out letter by letter
DEF wNextCapsule EQU $C210 ;@ u8[16] Object 1: the next capsule, beside Dr. Mario
DEF wRestartMusic EQU $DF89 ;@ u8 Set when song 10 ends: MainLoop starts the level music
DEF hUnusedA4 EQU $FFA4 ;@ u8 Cleared at start, otherwise unused
DEF hVirusThresholds EQU $FFC8 ;@ u8[3] Link game: a quarter, an eighth and a sixteenth of the other side's viruses
DEF hVirusesLeft2P EQU $FFD3 ;@ u8 Link game: the other side's viruses left
DEF hVirusesLeft2PBCD EQU $FFD4 ;@ u8 hVirusesLeft2P in BCD
DEF hUnusedF6 EQU $FFF6 ;@ u8 Cleared at a level's start, otherwise unused
DEF hUnusedFD EQU $FFFD ;@ u8 Cleared at a level's start, otherwise unused
