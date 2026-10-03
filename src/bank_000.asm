; Disassembly of "drmario.gb"
; This file was created with:
; mgbdis v3.0 - Game Boy ROM disassembler by Matt Currie and contributors.
; https://github.com/mattcurrie/mgbdis

SECTION "ROM Bank $000", ROM0[$0]

;@ def RST_00()
;@ path: boot/vectors
;@ rst $00 (and a jump to address 0) restarts the game.
;@ test: skip never returns
;@ sig: 6a18a468
RST_00::
;> goto(Start)
	jp Start


	db $00, $00, $00, $00, $00

;@ def ShortDelay()
;@ path: lib/timing
;@ rst $08: a short busy wait (250 rounds of a 3-instruction loop), used
;@ between link cable transfers.
;@ sig: 0ab3aa22
ShortDelay::
;> # b is saved and restored; nothing else changes
	push bc
;>@wait for _ in range(250): pass
	ld b, $fa

jr_000_000b:
	ld b, b
	dec b
	jr nz, jr_000_000b

;> return
	pop bc
	ret


	db $ff, $bf, $ff, $af, $7f, $ee, $ff

;@ def CopyUntilFF(src: de, dest: hl) -> (hl, de)
;@ path: lib/memory
;@ rst $18: copies bytes from src to dest up to (not including) a $FF.
;@ Returns both pointers; src then points at the $FF.
;@ test: src = rand_ram(32); mem[src + rand(0, 31)] = 0xFF
;@ test: dest = rand_ram(32)
;@ sig: c0c00e6d
CopyUntilFF::
;>@loop while mem[src] != 0xFF:
	ld a, [de]
	cp $ff
;>@done     # (ret z: return dest, src)
	ret z

;>     mem[dest] = mem[src]
;>     dest += 1
	ld [hli], a
;>     src += 1
	inc de
;=@loop
	jr CopyUntilFF
;> return dest, src

	db $ef, $ff, $ef, $ff, $ea, $fe, $fb, $ff

;@ def JumpTable(index: a)
;@ path: boot/vectors
;@ Jump-table dispatch, used as `rst $28`.
;@ The `rst $28` is directly followed by a table of 16-bit addresses. Instead
;@ of returning, execution continues at entry `index` of that table.
;@ test: skip rewrites the return address on the stack
;@ sig: 0edd58b8
JumpTable::
;> offset = 2 * index
	add a
;> table = pop_return_address()       # the table starts right after `rst $28`
	pop hl
;> target = mem16[table + offset]
	ld e, a
	ld d, $00
	add hl, de
	ld e, [hl]
	inc hl
	ld d, [hl]
;> goto(target)
	push de
	pop hl
	jp hl


	db $bb, $ff, $ff, $ff, $bf, $ff, $ba, $ff, $ee, $ff, $aa, $ff

;@ def VBlankInterrupt()
;@ path: boot/vectors
;@ Interrupt vector $40.
;@ test: skip interrupt vector
;@ sig: 18856b5a
VBlankInterrupt::
;> goto(VBlankHandler)
	jp VBlankHandler


	db $ff, $bf, $ff, $be, $ff

;@ def LCDCInterrupt()
;@ path: boot/vectors
;@ Interrupt vector $48.
;@ test: skip interrupt vector
;@ sig: 313b2e30
LCDCInterrupt::
;> goto(LCDCHandler)
	jp LCDCHandler


	db $ff, $ba, $ff, $ff, $ff

;@ def TimerOverflowInterrupt()
;@ path: boot/vectors
;@ Interrupt vector $50.
;@ test: skip interrupt vector
;@ sig: 5fc2c649
TimerOverflowInterrupt::
;> goto(TimerHandler)
	jp TimerHandler


	db $ff, $af, $ff, $af, $fd


;@ def SerialHandler()
;@ path: system/link
;@ The serial interrupt: a byte has been exchanged. During a round it only
;@ takes notice of a garbage header ($FE) and the colours byte after it;
;@ otherwise the byte goes to hSerialRx. The slave then loads its next byte
;@ and starts listening again ($F0 from the master resets it).
;@ reads: wInPlay, hDemoMode, hSerialRole, hSerialTx, hTwoPlayer, wGarbageNext
;@ writes: hSerialLast, hSerialRx, hSerialDone, hSerialTx, $D008, $D020, hGarbageArrived, wGarbageIn, wGarbageNext, wGarbageInCopy, wLinkByteReady
;@ test: skip talks to the link cable
;@ sig: dc08a1fa
SerialHandler::
;> v = rSB
	push af
	push bc
	ldh a, [rSB]
;> hSerialLast = v
	ldh [hSerialLast], a
	ld b, a
;> if wInPlay and not hDemoMode:
	ld a, [wInPlay]
	and a
	jr z, jr_000_008b

	ldh a, [hDemoMode]
	and a
	jr nz, jr_000_008b

;>@gn     if wGarbageNext:                            # the colours after a $FE
;>@g1         wGarbageIn = v
;>@g2         wGarbageInCopy = v
;>@g3         wGarbageNext = 0
;>@fe     elif v == 0xFE:                             # a garbage header
;=@gn
	ld a, [wGarbageNext]
	and a
	ldh a, [hSerialLast]
	jr nz, jr_000_007f

;=@fe
	cp $fe
	jr nz, jr_000_008e

;>         hGarbageArrived = 1
;>         wGarbageNext = 1
;>@rx else:
;>@rx2     hSerialRx = v
	ld a, $01
	ldh [hGarbageArrived], a
	ld [wGarbageNext], a
	jr jr_000_008e

;=@g1
jr_000_007f:
	ld [wGarbageIn], a
;=@g2
	ld [wGarbageInCopy], a
;=@g3
	xor a
	ld [wGarbageNext], a
	jr jr_000_008e

;=@rx
jr_000_008b:
;=@rx2
	ld a, b
	ldh [hSerialRx], a

jr_000_008e:
;> wLinkByteReady = 0
	xor a
	ld [wLinkByteReady], a
;> hSerialDone = 1
	inc a
	ldh [hSerialDone], a
;> if hSerialRole != SERIAL_MASTER:                # the slave: next byte, listen again
	ldh a, [hSerialRole]
	cp $30
	jr z, jr_000_00bf

;>     rSB = hSerialTx
	ldh a, [hSerialTx]
	ldh [rSB], a
;>     SerialNextByte()
	call SerialNextByte
;>     if hSerialLast == 0xF0:                     # the master asked for a reset
;>         goto(Start)
	ldh a, [hSerialLast]
	cp $f0
	jp z, Start

;>     rSC = 0
	xor a
	ldh [rSC], a
;>     rSC = 0x80
	ld a, $80
	ldh [rSC], a
;>     if hTwoPlayer and wInPlay:
	ldh a, [hTwoPlayer]
	and a
	jr z, jr_000_00bf

	ld a, [wInPlay]
	and a
	jr z, jr_000_00bf

;>         hSerialTx = 0xE0
	ld a, $e0
	ldh [hSerialTx], a

jr_000_00bf:
;> return                                          # reti
	pop bc
	pop af
	reti


	db $f0, $b5, $57, $f0, $b4, $5f, $06, $04, $cb, $1a, $cb, $1b, $05, $20, $f9, $7b
	db $d6, $84, $e6, $fe, $07, $07, $c6, $08, $e0, $b2, $f0, $b4, $e6, $1f, $17, $17
	db $17, $c6, $08, $e0, $b3, $c9, $17, $17, $c6, $08, $e0, $b3, $c9, $ff, $af, $bf
	db $ba, $ff, $eb, $ff, $fb, $ff, $ae, $ff, $ff, $ff, $be, $ff, $fb, $ff

;@ def Boot()
;@ path: boot/vectors
;@ The cartridge entry point.
;@ test: skip never returns
;@ sig: 7f119ac7
Boot::
;> goto(Entry)
	nop
	jp Entry


HeaderLogo::
	db $ce, $ed, $66, $66, $cc, $0d, $00, $0b, $03, $73, $00, $83, $00, $0c, $00, $0d
	db $00, $08, $11, $1f, $88, $89, $00, $0e, $dc, $cc, $6e, $e6, $dd, $dd, $d9, $99
	db $bb, $bb, $67, $63, $6e, $0e, $ec, $cc, $dd, $dc, $99, $9f, $bb, $b9, $33, $3e

HeaderTitle::
	db "DR.MARIO", $00, $00, $00, $00, $00, $00, $00, $00

HeaderNewLicenseeCode::
	db $00, $00

HeaderSGBFlag::
	db $00

HeaderCartridgeType::
	db $00

HeaderROMSize::
	db $00

HeaderRAMSize::
	db $00

HeaderDestinationCode::
	db $00

HeaderOldLicenseeCode::
	db $01

HeaderMaskROMVersion::
	db $00

HeaderComplementCheck::
	db $aa

HeaderGlobalChecksum::
	db $01, $fd

;@ def Entry()
;@ path: boot/vectors
;@ Where Boot ($0100) jumps to, right after the cartridge header.
;@ test: skip never returns
;@ sig: 8d08b879
Entry::
;> goto(Start)
	jp Start


;@ def SerialNextByte()
;@ path: system/link
;@ After a garbage header ($FE) the next byte sent is the colours ($D046).
;@ reads: hSerialTx, $D046, wGarbageOut
;@ test: mem[0xD00E] = rng.choice([0, 1]); hSerialTx = rng.choice([0xFE, 0xE0, 0x10]); mem[0xD046] = rand(0, 255)
;@ sig: bceafa28
SerialNextByte::
;> if wGarbageHeaderSent:                                 # the header went out: now the colours
;>@col2     rSB = wGarbageOut
;>@col3     wGarbageHeaderSent = 0
;> else:
	ld bc, wGarbageHeaderSent
	ld a, [bc]
	and a
	jr nz, jr_000_0167

;>     wGarbageHeaderSent = 1 if hSerialTx == 0xFE else 0
	ldh a, [hSerialTx]
	cp $fe
	jr nz, jr_000_0164

	ld a, $01
	jr jr_000_0165

jr_000_0164:
	xor a

jr_000_0165:
	ld [bc], a
	ret


jr_000_0167:
;=@col2
	ld a, [wGarbageOut]
	ldh [rSB], a
;=@col3
	jr jr_000_0164

;@ def ReadBGTileAtCoords() -> a
;@ path: gfx/tilemaps
;@ Unused. Returns the BG map tile under the OAM coordinates (hCoordY, hCoordX).
;@ The tile is read twice, each time right after HBlank starts, and the two
;@ reads are ANDed together.
;@ reads: hCoordY, hCoordX
;@ writes: hBGMapAddr
;@ clobbers: b, de, hl
;@ test: skip polls the LCD status
;@ sig: de05a0f5
ReadBGTileAtCoords::
;> tile_addr = CoordsToBGMapAddr()
	call CoordsToBGMapAddr

;> wait_hblank()
.waitHBlank1
	ldh a, [rSTAT]
	and $03
	jr nz, .waitHBlank1

;> first = mem[tile_addr]
	ld b, [hl]

;> wait_hblank()
.waitHBlank2
	ldh a, [rSTAT]
	and $03
	jr nz, .waitHBlank2

;> return first & mem[tile_addr]
	ld a, [hl]
	and b
	ret

;@ def AddScoreBCD(points: de, score: hl)
;@ path: lib/math
;@ Adds a 4-digit BCD number to a 7-digit BCD score (4 bytes, least
;@ significant first). The result is capped at 9999999. Flags the score
;@ for redrawing.
;@ writes: hDrawBCDFlag
;@ test: points = rand_bcd(2)
;@ test: score = rand_ram(4)
;@ test: fill_bcd(score, 4)
;@ sig: c5fb4c76
AddScoreBCD::
;> s = bcd_to_int(mem[score]) + bcd_to_int(lo(points))                 # add + daa
;> mem[score] = to_bcd(s % 100)
	ld a, e
	add [hl]
	daa
	ld [hli], a
;> s = bcd_to_int(mem[score + 1]) + bcd_to_int(hi(points)) + s // 100   # adc + daa
;> mem[score + 1] = to_bcd(s % 100)
	ld a, d
	adc [hl]
	daa
	ld [hli], a
;> s = bcd_to_int(mem[score + 2]) + s // 100
;> mem[score + 2] = to_bcd(s % 100)
	ld a, $00
	adc [hl]
	daa
	ld [hli], a
;> s = bcd_to_int(mem[score + 3]) + s // 100
;> mem[score + 3] = to_bcd(s % 100)
	ld a, $00
	adc [hl]
	daa
	ld [hl], a
;> hDrawBCDFlag = 1
	ld a, $01
	ldh [hDrawBCDFlag], a
;> if mem[score + 3] >> 4:                   # 10 million or more
	ld a, [hl]
	swap a
	and $0f
	ret z

;>     bcd_write(score, 4, 9999999)
	ld a, $09
	ld [hld], a
	ld a, $99
	ld [hld], a
	ld [hld], a
	ld [hl], a
	ret


;@ def VBlankHandler()
;@ path: system/interrupts
;@ The VBlank interrupt: copies the shadow OAM to OAM (not while the viruses
;@ are being placed, nor during a link game's bottle redraw), runs the
;@ game's drawing, shows the 1-player score and tells the main loop.
;@ reads: hTwoPlayer, wInPlay, hRedrawRow, hGameState
;@ writes: hVBlankDone
;@ test: skip runs the OAM DMA routine in HRAM
;@ sig: 93fc96c8
VBlankHandler::
;> if not (hTwoPlayer and wInPlay and hRedrawRow) and hGameState != 0x03:
	push af
	push bc
	push de
	push hl
	ldh a, [hTwoPlayer]
	and a
	jr z, jr_000_01ba

	ld a, [wInPlay]
	and a
	jr z, jr_000_01ba

	ldh a, [hRedrawRow]
	and a
	jr nz, jr_000_01c3

jr_000_01ba:
	ldh a, [hGameState]
	cp $03
	jr z, jr_000_01c3

;>     hOAMDMA()                                   # the DMA routine in HRAM
	call hOAMDMA

jr_000_01c3:
;> VBlankDraw()
	call VBlankDraw
;> if not hTwoPlayer:
	ldh a, [hTwoPlayer]
	and a
	jr nz, jr_000_01d4

;>     DrawBCD7(0xC0A3, 0x984C)                    # the score, from its top digits
	ld de, wScore + 3
	ld hl, $984c
	call DrawBCD7

jr_000_01d4:
;> hVBlankDone = 1
	ldh a, [hTwoPlayer]
	and a
	jr z, jr_000_01df

	ld a, [wInPlay]
	and a
	jr z, jr_000_01df

jr_000_01df:
	ld a, $01
	ldh [hVBlankDone], a
;> return                                          # registers restored, reti
	pop hl
	pop de
	pop bc
	pop af
	reti



;@ def Start()
;@ path: boot
;@ Power-on and soft reset: clears the RAM, switches the LCD off at line $94,
;@ sets palettes, sound and the timer (it paces the sound engine), clears
;@ VRAM, OAM and HRAM, copies the OAM DMA routine to HRAM, loads the tiles
;@ and enters the main loop with the title (state $00).
;@ writes: $D000, $D001, $FFA4, hClearStep, hGameState, hUnusedA4, wWins1, wWins2
;@ test: skip never returns
;@ sig: 49bab9fd
Start::
;> fill(0xD000, 0, 0x1000)                         # $D000-$DFFF
	xor a
	ld hl, $dfff
	ld c, $10
	ld b, $00

jr_000_01f0:
	ld [hld], a
	dec b
	jr nz, jr_000_01f0

	dec c
	jr nz, jr_000_01f0

;> disable_interrupts()
;> rIF = 0x0D
;> rIE = 0x0D
	ld a, $0d
	di
	ldh [rIF], a
	ldh [rIE], a
;> rSCY = rSCX = 0
;> hUnusedA4 = 0
;> rSTAT = rSB = rSC = 0
;> wWins1 = wWins2 = 0                   # no wins
	xor a
	ldh [rSCY], a
	ldh [rSCX], a
	ldh [hUnusedA4], a
	ldh [rSTAT], a
	ldh [rSB], a
	ldh [rSC], a
	ld [wWins1], a
	ld [wWins2], a
;> rLCDC = 0x80
	ld a, $80
	ldh [rLCDC], a

jr_000_0215:
;> wait_ly(0x94)
	ldh a, [rLY]
	cp $94
	jr nz, jr_000_0215

;> rLCDC = 0x03                                    # LCD off
	ld a, $03
	ldh [rLCDC], a
;> rBGP = rOBP0 = 0xE1
;> rOBP1 = 0xE5
	ld a, $e1
	ldh [rBGP], a
	ldh [rOBP0], a
	ld a, $e5
	ldh [rOBP1], a
;> rNR52 = 0x80                                    # sound on
;> rNR51 = 0xFF
;> rNR50 = 0x77
	ld hl, $ff26
	ld a, $80
	ld [hld], a
	ld a, $ff
	ld [hld], a
	ld [hl], $77
;> rTMA = 0xBF                                     # timer interrupt about 63 times a second
;> rTAC = 0x04
	ld hl, $ff06
	ld a, $bf
	ld [hli], a
	ld a, $04
	ld [hl], a
;> set_rom_bank(1)
	ld a, $01
	ld [$2000], a
;> reset_stack(0xCFFF)
	ld sp, $cfff
;> fill(0xDF00, 0, 0x100)
	xor a
	ld hl, $dfff
	ld b, $00

jr_000_024b:
	ld [hld], a
	dec b
	jr nz, jr_000_024b

;> fill(0xC000, 0, 0x1000)                         # $C000-$CFFF
	ld hl, $cfff
	ld c, $10
	ld b, $00

jr_000_0256:
	ld [hld], a
	dec b
	jr nz, jr_000_0256

	dec c
	jr nz, jr_000_0256

;> fill(0x8000, 0, 0x2000)                         # VRAM
	ld hl, $9fff
	ld c, $20
	xor a
	ld b, $00

jr_000_0265:
	ld [hld], a
	dec b
	jr nz, jr_000_0265

	dec c
	jr nz, jr_000_0265

;> fill(0xFE00, 0, 0x100)                          # OAM
	ld hl, $feff
	ld b, $00

jr_000_0271:
	ld [hld], a
	dec b
	jr nz, jr_000_0271

;> fill(0xFF7F, 0, 0x80)                           # HRAM
	ld hl, hPrevCapsule
	ld b, $80

jr_000_027a:
	ld [hld], a
	dec b
	jr nz, jr_000_027a

;> copy(hOAMDMA, 0x2386, 10)                       # OAMDMARoutine
	ld c, $b6
	ld b, $0a
	ld hl, $2386

jr_000_0285:
	ld a, [hli]
	ldh [c], a
	inc c
	dec b
	jr nz, jr_000_0285

;> ClearBGMap0()
	call ClearBGMap0
;> InitSound()
	call InitSound
;> LoadGameTiles()
	call LoadGameTiles
;> rIE = 0x0D                                      # VBlank, timer, serial
	ld a, $0d
	ldh [rIE], a
;> rLCDC = 0x80
	ld a, $80
	ldh [rLCDC], a
;> rIF = rWY = rWX = 0
;> hGameState = 0                                  # TitleInit
;> hClearStep = 0
	xor a
	ldh [rIF], a
	ldh [rWY], a
	ldh [rWX], a
	ldh [hGameState], a
	ldh [hClearStep], a
;> enable_interrupts()
;> MainLoop()                                      # falls through
	ei

;@ def MainLoop()
;@ path: boot
;@ One frame: link byte bookkeeping, joypad, the game state, the link
;@ exchange and the danger tempo in a link game (the timer modulo goes up as
;@ the other side gets close to winning, so the music speeds up), the soft
;@ reset (A+B+Select+Start; the link master resets the slave too with $F0),
;@ the countdown timers, then wait for VBlank.
;@ writes: hSerialDone, hSerialRx, hVBlankDone, wDangerLevel
;@ reads: hDangerLevel, hDemoMode, hJoyHeld, hPaused, hSerialDone, hSerialLast, hSerialRole, hTwoPlayer, hVBlankDone, wInPlay
;@ test: skip never returns
;@ sig: 6943af81
MainLoop::
;> while True:
;>     disable_interrupts()
	di
;>     if wInPlay:
	ld a, [wInPlay]
	and a
	jr z, jr_000_02c0

;>         rx = hSerialLast if hSerialDone else 0xE0
;>         hSerialDone = 0
	ldh a, [hSerialDone]
	and a
	ld a, $00
	ldh [hSerialDone], a
	jr nz, jr_000_02bc

	ld a, $e0
	jr jr_000_02be

jr_000_02bc:
	ldh a, [hSerialLast]

jr_000_02be:
;>         hSerialRx = rx
	ldh [hSerialRx], a

jr_000_02c0:
;>     enable_interrupts()
	ei
;>     SerialSendQueued()
	call SerialSendQueued
;>     ReadJoypad()
	call ReadJoypad
;>     if wRestartMusic:                             # the music asks to be started again
	ld hl, wRestartMusic
	ld a, [hl]
	and a
	jr z, jr_000_02d3

;>         wRestartMusic = 0
	xor a
	ld [hl], a
;>         StartLevelMusic()
	call StartLevelMusic

jr_000_02d3:
;>     RunGameState()
	call RunGameState
;>     if not hDemoMode:
	ldh a, [hDemoMode]
	and a
	jr nz, jr_000_033a

;>         if hTwoPlayer:
	ldh a, [hTwoPlayer]
	and a
	jr z, jr_000_0311

;>             if wInPlay and not hPaused:
	ld a, [wInPlay]
	and a
	jr z, jr_000_02f1

	ldh a, [hPaused]
	and a
	jr nz, jr_000_02f1

;>                 VersusReceive()
	call VersusReceive
;>                 VersusPrepareSend()
	call VersusPrepareSend

jr_000_02f1:
;>             wDangerLevel = hDangerLevel
;>             rTMA = (0xBF, 0xC8, 0xD0)[hDangerLevel] if hDangerLevel < 3 else 0xD8
	ldh a, [hDangerLevel]
	ld [wDangerLevel], a
	and a
	jr z, jr_000_0305

	cp $01
	jr z, jr_000_0309

	cp $02
	jr z, jr_000_030d

	ld a, $d8
	jr jr_000_030f

jr_000_0305:
	ld a, $bf
	jr jr_000_030f

jr_000_0309:
	ld a, $c8
	jr jr_000_030f

jr_000_030d:
	ld a, $d0

jr_000_030f:
	ldh [rTMA], a

jr_000_0311:
;>         if hSerialRole != SERIAL_SLAVE and hJoyHeld & 0x0F == 0x0F:    # A+B+Select+Start
	ldh a, [hSerialRole]
	cp $60
	jr z, jr_000_033a

	ldh a, [hJoyHeld]
	and $0f
	cp $0f
	jr nz, jr_000_033a

;>             if not hTwoPlayer:
;>                 goto(Start)
	ldh a, [hTwoPlayer]
	and a
	jp z, Start

;>             ShortDelay()
;>             ShortDelay()
;>             hSerialDone = 0
	rst $08
	rst $08
	xor a
	ldh [hSerialDone], a
;>             rSB = 0xF0                          # reset the slave too
;>             rSC = 0x81
	ld a, $f0
	ldh [rSB], a
	ld a, $81
	ldh [rSC], a

;>             while not hSerialDone:
;>                 pass
jr_000_0332:
	ldh a, [hSerialDone]
	and a
	jr z, jr_000_0332

;>             goto(Start)
	jp Start


jr_000_033a:
;>     for timer in (0xFFA6, 0xFFA7):              # hTimer1, hTimer2
;>         if mem[timer]:
;>             mem[timer] -= 1
	ld hl, hTimer1
	ld b, $02

jr_000_033f:
	ld a, [hl]
	and a
	jr z, jr_000_0344

	dec [hl]

jr_000_0344:
	inc l
	dec b
	jr nz, jr_000_033f

;>     hFrameCount += 1
;>     hDanceTimer1 += 1
;>     hDanceTimer2 += 1
;>     hDanceTimer3 += 1
	ld hl, hFrameCount
	inc [hl]
	ld hl, hDanceTimer1
	inc [hl]
	ld hl, hDanceTimer2
	inc [hl]
	ld hl, hDanceTimer3
	inc [hl]

jr_000_0358:
;>     wait_vblank_flag()
	halt
	ldh a, [hVBlankDone]
	and a
	jr z, jr_000_0358

;>     hVBlankDone = 0
	xor a
	ldh [hVBlankDone], a
	jp MainLoop



;@ def VersusReceive()
;@ path: versus/play
;@ During a link round, what came from the other side: its virus count
;@ (below $55), $FD (its bottle is full: this side wins), $F8 (it cleared its
;@ viruses: this side loses), or garbage colours, which are added to the
;@ ones waiting in hGarbage (up to four).
;@ reads: hGarbageArrived, hSerialRx, hTwoPlayer, wGarbageIn, hGarbage
;@ writes: hSerialRx, hRoundResult, hLevelCleared, hTimer1, hGameState, hGarbage, hGarbageArrived, wGarbageIn, $D016, $FFD3, hVirusesLeft2P, wGarbageCopy
;@ test: hGarbageArrived = rng.choice([0, 1]); hSerialRx = rng.choice([0xFD, 0xF8, rand(0, 0x54), 0x60]); hTwoPlayer = rng.choice([0, 1])
;@ test: wGarbageIn = rng.choice([0, 0xE0, rand(1, 255)]); hGarbage = rng.choice([0, rand(1, 0x3F), rand(0x40, 255)])
;@ sig: 2382dfb7
VersusReceive::
;> if not hGarbageArrived:
	ldh a, [hGarbageArrived]
	and a
	jr nz, jr_000_03a3

;>     rx = hSerialRx
;>     if rx == 0xFD:                              # its bottle is full: this side wins
;>@w1         hSerialRx = 0
;>@w2         hRoundResult = 0xF8
;>@w3         if hTwoPlayer:
;>@w4             hTimer1 = 0x10
;>@w5             hGameState = 0x17                       # RoundEndSync
;>@w6         else:
;>@w7             hLevelCleared = 1
;>@l1     elif rx == 0xF8:                            # it cleared its viruses: this side loses
;>@l2         hRoundResult = 0xFD
;>@l3         hTimer1 = 0x10
;>@l4         hGameState = 0x17 if hTwoPlayer else 0x0F
;>@n1     elif rx < 0x55:                             # its viruses left
;>@n2         hVirusesLeft2P = rx
;>@n3     return
;=@l1
	ldh a, [hSerialRx]
	cp $fd
	jr z, jr_000_0379

	cp $f8
	jr z, jr_000_0394

;=@n1
	cp $55
	ret nc

;=@n2
	ldh [hVirusesLeft2P], a
;=@n3
	ret


;=@w1
jr_000_0379:
	xor a
	ldh [hSerialRx], a
;=@w2
	ld a, $f8
	ldh [hRoundResult], a
;=@w3
	ld b, $17
	ldh a, [hTwoPlayer]
	and a
	jr nz, jr_000_038c

;=@w7
	ld a, $01
	ldh [hLevelCleared], a
	ret


jr_000_038c:
;=@w4
	ld a, $10
	ldh [hTimer1], a
;=@w5
	ld a, b
	ldh [hGameState], a
	ret


jr_000_0394:
;=@l2
	ld a, $fd
	ldh [hRoundResult], a
;=@l4
	ld b, $0f
	ldh a, [hTwoPlayer]
	and a
	jr z, jr_000_038c

	ld b, $17
	jr jr_000_038c

jr_000_03a3:
;> garbage = wGarbageIn
;> if garbage == 0 or garbage == 0xE0:
;>     return
	ld a, [wGarbageIn]
	and a
	ret z

	cp $e0
	ret z

;> new = garbage
;> while not new & 0xC0:                           # line its colours up at the top
;>     new = (new << 2) & 0xFF
	ld b, a

jr_000_03ac:
	ld a, b
	and $c0
	jr nz, jr_000_03b7

	sla b
	sla b
	jr jr_000_03ac

jr_000_03b7:
;> pending = hGarbage
;> while not pending & 0xC0:                       # room for another colour
	ld c, b
	ldh a, [hGarbage]
	ld d, a

jr_000_03bb:
	ld a, d
	and $c0
	jr nz, jr_000_03d1

jr_000_03c0:
;>     while not new & 0xC0:
;>         new = (new << 2) & 0xFF
	ld a, c
	and $c0
	jr z, jr_000_03de

;>     pending = ((pending << 2) | (new >> 6)) & 0xFF
;>     new = (new << 2) & 0xFF
	sla c
	rl d
	sla c
	rl d
;>     if not new:
;>         break
	ld a, c
	and a
	jr nz, jr_000_03bb

jr_000_03d1:
;> hGarbage = pending
;> wGarbageCopy = pending
	ld a, d
	ldh [hGarbage], a
	ld [wGarbageCopy], a
;> hGarbageArrived = 0
;> wGarbageIn = 0
	xor a
	ldh [hGarbageArrived], a
	ld [wGarbageIn], a
	ret


jr_000_03de:
	sla c
	sla c
	jr jr_000_03c0

;@ def VersusPrepareSend()
;@ path: versus/play
;@ Picks this frame's byte for the other side (once per exchange, $D008):
;@ normally the virus count; garbage goes out as a header $FE and then the
;@ run colours (with a sound: $08 for the master, $0B for the slave).
;@ reads: hSendGarbage, hRunColours, hVirusesPlaced, hSerialRole, $D00E, $D046, wGarbageHeaderSent, wGarbageOut
;@ writes: hSerialTx, hSendGarbage, hRunColours, wSFXRequest, $D046, wGarbageOut
;@ test: hSendGarbage = rand(0, 2); mem[0xD008] = rng.choice([0, 0, 1]); mem[0xD00E] = rand(0, 1); mem[0xD046] = rand(0, 255)
;@ test: hVirusesPlaced = rand(0, 84); hRunColours = rand(0, 255); hSerialRole = rng.choice([SERIAL_MASTER, SERIAL_SLAVE])
;@ sig: 55841650
VersusPrepareSend::
;> if hSendGarbage == 2:                           # the colours
;>@c1     if wLinkByteReady:
;>@c2         return
;>@c3     hSerialTx = hRunColours
;>@c4     wGarbageOut = hRunColours
;>@c5     hRunColours = 0
;>@c6     hSendGarbage = 0
;>@c7     wLinkByteReady = 1
;>@c8     wSFXRequest = 0x0B if hSerialRole == SERIAL_SLAVE else 0x08
;>@h1 elif hSendGarbage == 1:                         # the header
;>@h2     if wLinkByteReady:
;>@h3         return
;>@h4     hSerialTx = 0xFE
;>@h5     wLinkByteReady += 1
;>@h6     hSendGarbage = 2
;> else:
	ld de, wLinkByteReady
	ld hl, hSendGarbage
	ld a, [hl]
	cp $02
	jr z, jr_000_0416

;=@h1
	cp $01
	jr z, jr_000_0409

;>     if wLinkByteReady:
;>         return
	ld a, [de]
	and a
	ret nz

;>     hSerialTx = wGarbageOut if wGarbageHeaderSent else hVirusesPlaced
	ld a, [wGarbageHeaderSent]
	and a
	jr nz, jr_000_0400

	ldh a, [hVirusesPlaced]
	jr jr_000_0403

jr_000_0400:
	ld a, [wGarbageOut]

jr_000_0403:
	ldh [hSerialTx], a
;>     wLinkByteReady += 1
	ld a, [de]
	inc a
	ld [de], a
	ret


jr_000_0409:
;=@h2
	ld a, [de]
	and a
;=@h3
	ret nz

;=@h4
	ld a, $fe
	ldh [hSerialTx], a
;=@h5
	ld a, [de]
	inc a
	ld [de], a
;=@h6
	ld [hl], $02
	ret


jr_000_0416:
;=@c1
	ld a, [de]
	and a
;=@c2
	ret nz

;=@c3
	ldh a, [hRunColours]
	ldh [hSerialTx], a
;=@c4
	ld [wGarbageOut], a
;=@c5
	xor a
	ldh [hRunColours], a
	ld [hl], a
;=@c7
	inc a
	ld [de], a
;=@c8
	ldh a, [hSerialRole]
	cp $60
	ld a, $0b
	jr z, jr_000_0430

	ld a, $08

jr_000_0430:
	ld [wSFXRequest], a
	ret


;@ def SerialSendQueued()
;@ path: system/link
;@ The link master starts each frame's exchange with hSerialTx.
;@ reads: hSerialRole, hSerialTx, wInPlay, $D03A, wLinkHold
;@ writes: $D008, wLinkByteReady
;@ test: skip talks to the link cable
;@ sig: c4335ad3
SerialSendQueued::
;> if wLinkHold:
;>     return
	ld a, [wLinkHold]
	and a
	ret nz

;> if hSerialRole != SERIAL_MASTER:
;>     return
	ldh a, [hSerialRole]
	cp $30
	ret nz

;> rSB = hSerialTx
	ldh a, [hSerialTx]
	ldh [rSB], a
;> SerialNextByte()
	call SerialNextByte
;> wLinkByteReady = 0
	xor a
	ld [wLinkByteReady], a
;> if not wInPlay:
;>     ShortDelay()
	ld a, [wInPlay]
	and a
	jr nz, jr_000_0450

	rst $08

jr_000_0450:
;> rSC = 0x81                                      # go, on our clock
	ld a, $81
	ldh [rSC], a
	ret


;@ def RunGameState()
;@ path: boot
;@ Runs the current game state: entry hGameState of GameStateTable.
;@ reads: hGameState
;@ test: skip dispatches into the state routines
;@ sig: 3d559786
RunGameState::
;> goto(GameStateTable[hGameState])            # rst $28 with the table right after it
	ldh a, [hGameState]
	rst $28

GameStateTable::
	dw TitleInit
	dw TitleScreen
	dw GameInit
	dw PlaceViruses
	dw Play
	dw LevelCleared
	dw RoundDraw
	dw CutsceneEndingMED
	dw CutsceneTurtle5
	dw LevelInit
	dw ThrowCapsule
	dw OptionsInit1P
	dw VirusLevelSelect
	dw SpeedSelect
	dw MusicSelect
	dw GameOver
	dw LevelEndWait
	dw NextLevelOrCutscene
	dw RoundOver
	dw CutsceneCrab10
	dw OptionsInit2P
	dw NextRound
	dw ShareCapsules
	dw RoundEndSync
	dw CutsceneSwordfish15
	dw ShareBottle
	dw CutsceneEndingHI
	dw CutsceneEndingLOW
	dw UnusedState1C

;@ def TitleInit()
;@ path: screens/title
;@ Game state $00: loads the title screen, resets the link and the 1P/2P
;@ choice, places the cursor sprite and runs the title screen.
;@ writes: hSerialTx, hSerialRx, hTwoPlayer, hGameState, hSpeed, hSpeed2P, $C4F1, $D03A, $FFE4, $FFF2, hDemoMode, wInPlay, hSerialLast, wLinkHold
;@ test: skip switches the LCD off
;@ sig: 96781e5a
TitleInit::
;> DisableLCD()
	call DisableLCD
;> ClearShadowOAM()
	call ClearShadowOAM
;> LoadScreen(0x5C26)
	ld de, $5c26
	call LoadScreen
;> rLCDC = 0x83                                    # LCD on, BG and sprites
	ld a, $83
	ldh [rLCDC], a
;> wLinkHold = 0
	xor a
	ld [wLinkHold], a
;> rSB = 0
	ldh [rSB], a
;> hSerialTx = 0
	ldh [hSerialTx], a
;> hSerialRx = 0
	ldh [hSerialRx], a
;> hSerialLast = 0
	ldh [hSerialLast], a
;> hTwoPlayer = 0                                  # cursor on 1 PLAYER
	ldh [hTwoPlayer], a
;> wInPlay = 0
	ld [wInPlay], a
;> hGameState = 0x01                               # TitleScreen from the next frame on
	inc a
	ldh [hGameState], a
;> hDemoMode = 1
	ldh [hDemoMode], a
;> mem[wShadowOAM] = 0x70                              # cursor sprite: y, x, tile
;> mem[wShadowOAM + 1] = 0x20
;> mem[wShadowOAM + 2] = 0x9B
	ld hl, wShadowOAM
	ld [hl], $70
	inc l
	ld [hl], $20
	inc l
	ld [hl], $9b
;> hSpeed = 3                                      # MED
;> hSpeed2P = 3
	ld a, $03
	ldh [hSpeed], a
	ldh [hSpeed2P], a
;> TitleScreen()                                   # falls through

;@ def ResetDemoTimer()
;@ path: screens/title
;@ writes: hDemoTimer, hTimer1, wSFXRequest, $D054, wDemoSFXOK
;@ Restarts the countdown to the demo (2 x 255 frames) and plays the menu beep.
;@ sig: 7c9222fc
ResetDemoTimer::
;> hDemoTimer = 2
	ld a, $02
	ldh [hDemoTimer], a
;> hTimer1 = 0xFF
	ld a, $ff
	ldh [hTimer1], a
;> wDemoSFXOK = 1
;> wSFXRequest = 1                                 # beep
	ld a, $01
	ld [wDemoSFXOK], a
	ld [wSFXRequest], a
	ret


;@ def TitleScreen()
;@ path: screens/title
;@ Game state $01. Counts down to the demo, listens on the link cable for
;@ another Game Boy, and moves the 1P/2P cursor. Start with 1 PLAYER goes to
;@ the options screen; with 2 PLAYER it offers to be the link master, and the
;@ side that hears the other one first becomes the slave.
;@ reads: hTimer1, hDemoTimer, hSerialDone, hSerialRx, hJoyPressed, hTwoPlayer
;@ writes: hTimer1, hDemoTimer, hSerialDone, hSerialTx, hTwoPlayer, hVirusLevel, hVirusLevelBCD, hSerialRole, hGameState, wSFXRequest, $D054, $FFF2, wShadowOAM, hSerialLast, wDemoSFXOK
;@ test: skip talks to the link cable
;@ sig: 8484122c
TitleScreen::
;> state = None
;> role = None
;> if hTimer1 == 0:
	ld hl, hTimer1
	ld a, [hl]
	and a
	jr nz, jr_000_04fe

;>     hTimer1 = 0xFF
	ld [hl], $ff
;>     hDemoTimer -= 1
	ld hl, hDemoTimer
	dec [hl]
;>     if hDemoTimer == 0:                         # time for the demo
	jr nz, jr_000_04fe

	jr jr_000_04ee

	db $af, $e0, $e4

;>         hTwoPlayer = 0
jr_000_04ee:
	xor a
	ldh [hTwoPlayer], a
;>         hVirusLevel = 10
	ld a, $0a
	ldh [hVirusLevel], a
;>         hVirusLevelBCD = 0x10
	ld a, $10
	ldh [hVirusLevelBCD], a
;>         state = 0x02                            # GameInit
	ld a, $02
	jp Jump_000_0553

;> if state is None:
;>     ShortDelay()
jr_000_04fe:
	rst $08
;>     hSerialTx = SERIAL_SLAVE                    # listen for a master, on its clock
	ld a, $60
	ldh [hSerialTx], a
;>     rSB = SERIAL_SLAVE
	ldh [rSB], a
;>     rSC = 0x80
	ld a, $80
	ldh [rSC], a
;>     if hSerialDone:
	ldh a, [hSerialDone]
	and a
	jr z, jr_000_051f

;>         hSerialDone = 0
	xor a
	ldh [hSerialDone], a
;>         if hSerialRx == SERIAL_MASTER:          # the other side pressed Start first
;>             role = SERIAL_SLAVE
	ldh a, [hSerialRx]
	cp $30
	jr z, jr_000_0549

;>         elif hSerialRx == SERIAL_SLAVE:
	cp $60
	jr z, jr_000_055d

;>@master             role = SERIAL_MASTER
;>         else:
;>             ResetDemoTimer()                    # someone is there: restart the countdown
	call ResetDemoTimer
;>             return
	ret

;>     else:
;>         buttons = hJoyPressed
jr_000_051f:
	ldh a, [hJoyPressed]
	ld b, a
;>         cursor = hTwoPlayer
	ldh a, [hTwoPlayer]
;>         if buttons & BTN_UP:
	bit 6, b
	jr nz, jr_000_0583

;>@upchk             if not cursor: return
;>@up0             cursor = 0
;>         elif buttons & (BTN_DOWN | BTN_SELECT):
	bit 7, b
	jr nz, jr_000_057f

	bit 2, b
	jr nz, jr_000_0561

;>@downchk             if buttons & BTN_DOWN and cursor: return
;>@toggle             cursor ^= 1
;>         elif not buttons & BTN_START:
;>             return
	bit 3, b
	ret z

;>         elif cursor == 0:
;>             state = 0x0B                        # OptionsInit1P
	and a
	ld a, $0b
	jr z, jr_000_0553

;>         elif hSerialRx == SERIAL_MASTER:
;>             role = SERIAL_SLAVE
	ldh a, [hSerialRx]
	cp $30
	jr z, jr_000_0549

;>         else:
;>             hSerialTx = SERIAL_MASTER           # offer to drive the clock
	ld a, $30
	ldh [hSerialTx], a
;>             rSB = SERIAL_MASTER
	ldh [rSB], a
;>             rSC = 0x81
	ld a, $81
	ldh [rSC], a
;>             return
	ret

;>         if state is None and role is None:      # the cursor moved
;>@cur1             hTwoPlayer = cursor
;>@cur2             wDemoSFXOK = 1
;>@cur3             mem[wShadowOAM] = 0x78 if cursor else 0x70   # cursor sprite y
;>@cur4             wSFXRequest = 1
;>@cur5             ResetDemoTimer()
;>@cur6             return
;> if role == SERIAL_SLAVE:
;>     hTwoPlayer = 1
jr_000_0549:
	ld a, $01
	ldh [hTwoPlayer], a
;> if role is not None:
;>     hSerialRole = role
	ld a, $60

jr_000_054f:
	ldh [hSerialRole], a
;>     state = 0x14                                # OptionsInit2P
	ld a, $14

;> hGameState = state
Jump_000_0553:
jr_000_0553:
	ldh [hGameState], a
;> hTimer1 = 0
	xor a
	ldh [hTimer1], a
;> hSerialTx = 0
	ldh [hSerialTx], a
;> hSerialLast = 0
	ldh [hSerialLast], a
	ret

;=@master
jr_000_055d:
	ld a, $30
	jr jr_000_054f

;=@toggle
jr_000_0561:
	xor $01

;=@cur1
jr_000_0563:
	ldh [hTwoPlayer], a
	ld b, a
;=@cur2
	ld a, $01
	ld [wDemoSFXOK], a
;=@cur3
	ld a, b
	and a
	ld a, $70
	jr z, jr_000_0573

	ld a, $78

jr_000_0573:
	ld [wShadowOAM], a
;=@cur4
	ld a, $01
	ld [wSFXRequest], a
;=@cur5
	call ResetDemoTimer
;=@cur6
	ret

;=@downchk
jr_000_057f:
	and a
	ret nz

	jr jr_000_0561

;=@upchk
jr_000_0583:
	and a
	ret z

;=@up0
	xor a
	jr jr_000_0563

;@ def OptionsInit1P()
;@ path: screens/options
;@ Game state $0B: sets up the options screen for one player and starts the
;@ options music.
;@ writes: wMusicRequest, hGameState, $FFEF, hRedrawRow
;@ test: skip switches the LCD off
;@ sig: e140b674
OptionsInit1P::
;> hRedrawRow = 0
	xor a
	ldh [hRedrawRow], a
;> wMusicRequest = 3
	ld a, $03
	ld [wMusicRequest], a
;> LoadOptionsScreen()
	call LoadOptionsScreen
;> ShowOptionsScreen()
	call ShowOptionsScreen
;> hGameState = 0x0C                               # VirusLevelSelect
	ld a, $0c
	ldh [hGameState], a
	ret


;@ def OptionsInit2P()
;@ path: screens/options
;@ Game state $14: sets up the options screen for a link game, with a second
;@ set of cursors for the other player.
;@ writes: hTimer2, hGameState, $FFEF, wShadowOAM, hRedrawRow
;@ test: skip switches the LCD off
;@ sig: f2cff77c
OptionsInit2P::
;> hRedrawRow = 0
	xor a
	ldh [hRedrawRow], a
;> LoadOptionsScreen()
	call LoadOptionsScreen
;> for addr, x in ((0xC009, 0x88), (0xC00D, 0x90), (0xC015, 0x34), (0xC021, 0x5D), (0xC025, 0x65),
;>                 (0xC049, 0x1C), (0xC04D, 0x24), (0xC051, 0x2C), (0xC061, 0x1C), (0xC065, 0x24), (0xC069, 0x2C)):
;>     mem[addr] = x                               # x positions of the second player's sprites
	ld a, $88
	ld [wShadowOAM + $09], a
	ld a, $90
	ld [wShadowOAM + $0D], a
	ld a, $34
	ld [wShadowOAM + $15], a
	ld a, $5d
	ld [wShadowOAM + $21], a
	ld a, $65
	ld [wShadowOAM + $25], a
	ld a, $1c
	ld [wShadowOAM + $49], a
	ld a, $24
	ld [wShadowOAM + $4D], a
	ld a, $2c
	ld [wShadowOAM + $51], a
	ld a, $1c
	ld [wShadowOAM + $61], a
	ld a, $24
	ld [wShadowOAM + $65], a
	ld a, $2c
	ld [wShadowOAM + $69], a
;> DrawVirusLevel2P()
	call DrawVirusLevel2P
;> ShowOptionsScreen()
	call ShowOptionsScreen
;> hTimer2 = 0x10
	ld a, $10
	ldh [hTimer2], a
;> hGameState = 0x0C                               # VirusLevelSelect
	ld a, $0c
	ldh [hGameState], a
	ret

;@ asset: oam end=$FF tiles=LoadGameTiles+CopyBytes(hl=$4D9E,de=$8000,bc=$300)|LoadGameTiles
;@ The options screen sprites: digits, arrows and cursors (LoadOptionsScreen).
OptionsSprites::
	db $3f, $88, $00, $00, $3f, $90, $00, $00, $49, $f0, $00, $00, $49, $f0, $00, $00
	db $3b, $34, $27, $00, $4d, $f0, $27, $40, $62, $5c, $9c, $00, $62, $64, $9c, $20
	db $6e, $f0, $9c, $40, $6e, $f0, $9c, $60, $88, $20, $fe, $00, $88, $28, $fe, $00
	db $88, $30, $fe, $00, $88, $48, $fe, $00, $88, $50, $fe, $00, $3f, $1c, $22, $00
	db $3f, $24, $18, $00, $3f, $2c, $1e, $00, $49, $f0, $0c, $00, $49, $f0, $18, $00
	db $49, $f0, $16, $00, $64, $1c, $22, $00, $64, $24, $18, $00, $64, $2c, $1e, $00
	db $6d, $f0, $0c, $00, $6d, $f0, $18, $00, $6d, $f0, $16, $ff

;@ def DrawVirusLevel()
;@ path: screens/options
;@ reads: hVirusLevel, hVirusLevelBCD
;@ Shows the virus level: two digit sprites and the arrow above the level bar.
;@ test: hVirusLevel = rand(0, 20); hVirusLevelBCD = to_bcd(hVirusLevel)
;@ sig: bad4b5ba
DrawVirusLevel::
;> DrawBCDSprites(hVirusLevelBCD, 0xC002)          # sprite 0 and 1 tiles
	ldh a, [hVirusLevelBCD]
	ld hl, wShadowOAM + $02
	call DrawBCDSprites
;> SetLevelArrowX(hVirusLevel, 0xC011)             # sprite 4 x
	ldh a, [hVirusLevel]
	ld hl, wShadowOAM + $11
	call SetLevelArrowX
	ret


;@ def DrawVirusLevel2P()
;@ path: screens/options
;@ reads: hSerialRole, hVirusLevel2P, hVirusLevel2PBCD
;@ Over the link cable, also shows the other player's virus level.
;@ test: hSerialRole = rng.choice([0, 0x30, 0x60])
;@ test: hVirusLevel2P = rand(0, 20); hVirusLevel2PBCD = to_bcd(hVirusLevel2P)
;@ sig: 8c103c09
DrawVirusLevel2P::
;> if not hSerialRole:
;>     return
	ldh a, [hSerialRole]
	and a
	ret z

;> DrawBCDSprites(hVirusLevel2PBCD, 0xC00A)        # sprite 2 and 3 tiles
	ldh a, [hVirusLevel2PBCD]
	ld hl, wShadowOAM + $0A
	call DrawBCDSprites
;> SetLevelArrowX(hVirusLevel2P, 0xC015)           # sprite 5 x
	ldh a, [hVirusLevel2P]
	ld hl, wShadowOAM + $15
	call SetLevelArrowX
	ret


;@ def VirusLevelSelect()
;@ path: screens/options
;@ Game state $0C: the virus level box. Left/right change the level (holding
;@ repeats), up/down move to another box, Start begins the game. Over the
;@ link cable the master decides: it forwards its box moves and Start ($18)
;@ to the slave, and each side shows the other's level.
;@ reads: hSerialRole, hSerialTx, hSerialRx, hJoyPressed, hJoyHeld, hTwoPlayer, hTimer2, hRepeatDelay
;@ writes: hSerialTx, hRepeatDelay, hGameState
;@ test: hSerialRole = 0; hTwoPlayer = rng.choice([0, 0, 1]); hTimer2 = rng.choice([0, 3])
;@ test: hJoyPressed = rng.choice([0, BTN_START, BTN_RIGHT, BTN_LEFT, 0]); hJoyHeld = rng.choice([0, BTN_RIGHT, BTN_LEFT])
;@ test: hRepeatDelay = rand(1, 3); hTimer1 = rng.choice([0, 4])
;@ test: hVirusLevel = rand(0, 20); hVirusLevelBCD = to_bcd(hVirusLevel)
;@ sig: 49b3a861
VirusLevelSelect::
;> VirusLevelLink()
	call VirusLevelLink
;> DrawVirusLevel2P()
	call DrawVirusLevel2P
;> DrawVirusLevel()
	call DrawVirusLevel
;> start = False
;> if hSerialRole == SERIAL_MASTER:
	ldh a, [hSerialRole]
	cp $30
	jr nz, jr_000_0693

;>     if hSerialTx == 0x18:                       # Start is on its way to the slave
;>         start = True
	ldh a, [hSerialTx]
	cp $18
	jr z, jr_000_06b3

;>     elif hSerialTx & 0xC0:                      # so is a box move
;>         return VirusLevelConfirm()
	and $c0
	jp nz, VirusLevelConfirm

;> if not start:
;>     SendVirusLevel()
jr_000_0693:
	call SendVirusLevel
;>     BlinkCursor()
	call BlinkCursor
;>     if hSerialRole == SERIAL_SLAVE:
	ldh a, [hSerialRole]
	cp $60
	jr z, jr_000_06be

;>@slave         start = hSerialRx == 0x18               # the master pressed Start
;>     elif hJoyPressed & BTN_START:
	ldh a, [hJoyPressed]
	bit 3, a
	jr z, jr_000_06c4

;>         if not hTwoPlayer:
;>             start = True
	ldh a, [hTwoPlayer]
	and a
	jr z, jr_000_06b3

;>         else:
;>             if hTimer2:                         # not right after entering the screen
;>                 return
	ldh a, [hTimer2]
	and a
	ret nz

;>             hSerialTx = 0x18                    # tell the slave
;>             return
	ld a, $18
	ldh [hSerialTx], a
	ret

;> if not start:
;>@pressed     pressed = hJoyPressed
;>@move     if hSerialRole != SERIAL_SLAVE and pressed & (BTN_UP | BTN_DOWN):
;>@move1p         if not hTwoPlayer:
;>@confirm             return VirusLevelConfirm()
;>@send         hSerialTx = pressed                     # the slave moves too
;>@sendret         return
;>@held     held = hJoyHeld
;>@right     if pressed & BTN_RIGHT:
;>@delay16         delay = 0x10
;>@left     elif not held & BTN_RIGHT:
;>@leftjp         return VirusLevelLeft(pressed, held)
;>@repeat     else:
;>@rdec         hRepeatDelay -= 1
;>@rchk         if hRepeatDelay:
;>@rret             return
;>@delay8         delay = 8
;>@up     hRepeatDelay = delay
;>@upcall     VirusLevelUp(0x20)
;>@upret     return
;> ClearShadowOAM()
OptionsStart:
jr_000_06b3:
	call ClearShadowOAM
;> InitSound()
	call InitSound
;> hGameState = 0x02                               # GameInit
	ld a, $02
	ldh [hGameState], a
	ret

;=@slave
jr_000_06be:
	ldh a, [hSerialRx]
	cp $18
	jr z, jr_000_06b3

;=@pressed
jr_000_06c4:
	ldh a, [hJoyPressed]
	ld b, a
;=@move
	ldh a, [hSerialRole]
	cp $60
	jr z, jr_000_06dc

	ld a, b
	and $c0
	jr z, jr_000_06dc

;=@move1p
	ldh a, [hTwoPlayer]
	and a
;=@confirm
	jp z, VirusLevelConfirm

;=@send
	ld a, b
	ldh [hSerialTx], a
;=@sendret
	ret

;=@held
jr_000_06dc:
	ldh a, [hJoyHeld]
	ld c, a
;=@right
	bit 4, b
;=@delay16
	ld a, $10
;=@right
	jr nz, jr_000_06f2

;=@left
	bit 4, c
;=@leftjp
	jp z, VirusLevelLeft

;=@rdec
	ldh a, [hRepeatDelay]
	dec a
	ldh [hRepeatDelay], a
;=@rchk
	ret nz

;=@delay8
	ld a, $08

;=@up
jr_000_06f2:
	ldh [hRepeatDelay], a
;=@upcall
	ld b, $20
	call VirusLevelUp
;=@upret
	ret


;@ def VirusLevelLink()
;@ path: screens/options
;@ The link side of the options screen. The master reads the slave's virus
;@ level (or speed + $20); the slave reads the master's level, or a box move
;@ ($40/$80, or $30+ / $22+), which it plays as its own up/down press,
;@ leaving its caller to jump to VirusLevelConfirm.
;@ reads: hSerialRole, hSerialRx
;@ writes: hVirusLevel2P, hVirusLevel2PBCD, hJoyPressed, hSpeed2P
;@ test: hSerialRole = rng.choice([0, SERIAL_MASTER, SERIAL_SLAVE])
;@ test: hSerialRx = rng.choice([rand(0, 0x14), 0x18, 0x19])
;@ sig: dfdc0889
VirusLevelLink::
;> if not hSerialRole:
;>     return
	ldh a, [hSerialRole]
	and a
	ret z

;> if hSerialRole != SERIAL_MASTER:                # slave: the byte came from the master
	cp $30
	jr z, jr_000_0728

;>     rx = hSerialRx
	ldh a, [hSerialRx]
	ld b, a
;>     if rx & 0xC0:                               # its up/down press
;>         pressed = rx & 0xC0
	and $c0
	jr nz, jr_000_0722

;>     elif rx >= 0x30:
;>@pup         pressed = BTN_UP
	ld a, b
	cp $30
	jr nc, jr_000_0738

;>     elif rx >= 0x22:
;>@pdown         pressed = BTN_DOWN
	cp $22
	jr nc, jr_000_0741

;>     elif rx == 0x18 or rx == 0x19:              # Start / idle
;>         return
	cp $18
	ret z

	cp $19
	ret z

;>     else:                                       # its virus level
;>         hVirusLevel2P = rx
	ld hl, hVirusLevel2P
	ld [hl], b
;>         hVirusLevel2PBCD = ToBCD(0xFFC4)        # hVirusLevel2P
	call ToBCD
	ldh [hVirusLevel2PBCD], a
;>         return
	ret

;>@store     hJoyPressed = pressed
;>@pop     pop_return_address()                        # the caller does not go on
;>@jump     return VirusLevelConfirm()
;=@store
jr_000_0722:
	ldh [hJoyPressed], a
;=@pop
	pop af
;=@jump
	jp VirusLevelConfirm

;> else:                                           # master: the byte came from the slave
;>     rx = hSerialRx
;>     if rx < 0x15:                               # its virus level
jr_000_0728:
	ldh a, [hSerialRx]
	cp $15
	jr nc, jr_000_0745

;>         hVirusLevel2P = rx
	ld hl, hVirusLevel2P
	ld [hl], a
;>         hVirusLevel2PBCD = ToBCD(0xFFC4)
	call ToBCD
	ldh [hVirusLevel2PBCD], a
;>         return
	ret

;=@pup
jr_000_0738:
	ld a, $40

;=@store
jr_000_073a:
	ldh [hJoyPressed], a
	ld b, a
;=@pop
	pop af
;=@jump
	jp VirusLevelConfirm

;=@pdown
jr_000_0741:
	ld a, $80
	jr jr_000_073a

;>     elif 0x22 <= rx < 0x25:                     # its speed + $20
TakeSpeed2P:
jr_000_0745:
	cp $22
	ret c

	cp $25
	ret nc

;>         hSpeed2P = rx - 0x20
	sub $20
	ldh [hSpeed2P], a
;>         DrawSpeed()
	call DrawSpeed
	ret


;@ def VirusLevelUp(max: b)
;@ path: screens/options
;@ Raises the virus level by one unless it is already `max` (BCD).
;@ reads: hVirusLevelBCD
;@ writes: hVirusLevel
;@ test: hVirusLevel = rand(0, 20); hVirusLevelBCD = to_bcd(hVirusLevel)
;@ test: max = rng.choice([0x20, hVirusLevelBCD])
;@ sig: 634261c1
VirusLevelUp::
;> if hVirusLevelBCD == max:
;>     return
	ld hl, hVirusLevelBCD
	ld a, [hld]
	cp b
	ret z

;> hVirusLevel += 1
	inc [hl]
;> StoreVirusLevelBCD(to_bcd(bcd_to_int(hVirusLevelBCD) + 1))   # falls through
	inc l
	add $01

;@ def StoreVirusLevelBCD(level_bcd: a)
;@ path: screens/options
;@ Stores the new BCD virus level. Entered with the BCD level plus or minus
;@ one still uncorrected: the daa here fixes it, using the caller's flags.
;@ writes: hVirusLevelBCD, $D052, wPastLevel20
;@ test: skip relies on the flags of the caller's add or sub
;@ sig: c12afbf6
StoreVirusLevelBCD::
;> hVirusLevelBCD = level_bcd                      # daa
	daa
	ld [hl], a
;> if level_bcd == 0x21:
;>     wPastLevel20 = 1
	cp $21
	ret nz

	ld a, $01
	ld [wPastLevel20], a
	ret


;@ def SendVirusLevel()
;@ path: screens/options
;@ reads: hTwoPlayer, hVirusLevel
;@ writes: hSerialTx
;@ In a 2-player game, queues the chosen virus level for the other Game Boy.
;@ test: hTwoPlayer = rng.choice([0, 1])
;@ sig: 865c67d1
SendVirusLevel::
;> if not hTwoPlayer:
;>     return
	ldh a, [hTwoPlayer]
	and a
	ret z

;> hSerialTx = hVirusLevel
	ldh a, [hVirusLevel]
	ldh [hSerialTx], a
	ret


;@ def ToBCD(src: hl) -> a
;@ path: lib/math
;@ Converts the byte at src (0-99) to BCD by counting up in decimal.
;@ test: src = rand_ram(1); mem[src] = rand(0, 99)
;@ sig: d816a104
ToBCD::
;> n = mem[src]
;> if n == 0:
;>     return 0
	ld a, [hl]
	and a
	ret z

;> return to_bcd(n)                                # add 1 + daa, n times
	ld b, a
	xor a

jr_000_0776:
	add $01
	daa
	dec b
	jr nz, jr_000_0776

	ret


;@ def DrawBCDSprites(value: a, dest: hl)
;@ path: gfx/numbers
;@ Puts the two digits of a BCD byte into the tile bytes of two consecutive
;@ shadow OAM entries (digit tiles are 0-9).
;@ test: value = rand_bcd(1); dest = 0xC002 + 4 * rand(0, 30)
;@ sig: 7e18f468
DrawBCDSprites::
;> mem[dest] = value >> 4
	ld b, a
	and $f0
	swap a
	ld [hli], a
;> mem[dest + 4] = value & 0x0F
	inc l
	inc l
	inc l
	ld a, b
	and $0f
	ld [hl], a
	ret


;@ def SetLevelArrowX(level: a, dest: hl)
;@ path: screens/options
;@ writes: wSFXRequest
;@ Moves a level arrow sprite to x = $34 + 4 * level, clicking when it moves.
;@ test: level = rand(0, 20); dest = rand_ram(1)
;@ test: mem[dest] = rng.choice([0x34 + 4 * level, rand(0, 255)])
;@ sig: 6ed3bb8d
SetLevelArrowX::
;> x = 0x34 + 4 * level
	and a
	ld b, a
	ld a, $34
	jr z, jr_000_0796

jr_000_0791:
	add $04
	dec b
	jr nz, jr_000_0791

;> if mem[dest] == x:
;>     return
jr_000_0796:
	cp [hl]
	ret z

;> mem[dest] = x
	ld [hl], a
;> wSFXRequest = 3                                 # click
	ld a, $03
	ld [wSFXRequest], a
	ret


;@ def CallVirusLevelDown()
;@ path: screens/options
;@ test: hVirusLevel = rand(0, 20); hVirusLevelBCD = to_bcd(hVirusLevel)
;@ sig: d3a4e62d
CallVirusLevelDown::
;> VirusLevelDown()
	call VirusLevelDown
	ret


;@ def VirusLevelDown()
;@ path: screens/options
;@ Lowers the virus level by one unless it is 0.
;@ reads: hVirusLevelBCD
;@ writes: hVirusLevel
;@ test: hVirusLevel = rand(0, 20); hVirusLevelBCD = to_bcd(hVirusLevel)
;@ sig: e4375586
VirusLevelDown::
;> if hVirusLevelBCD == 0:
;>     return
	ld hl, hVirusLevelBCD
	ld a, [hld]
	and a
	ret z

;> hVirusLevel -= 1
	dec [hl]
;> StoreVirusLevelBCD(to_bcd(bcd_to_int(hVirusLevelBCD) - 1))
	inc l
	sub $01
	call StoreVirusLevelBCD
	ret


;@ def VirusLevelLeft(pressed: b, held: c)
;@ path: screens/options
;@ Left on the virus level box: one step when pressed, then repeating every
;@ 8 frames after a 16 frame wait while held.
;@ reads: hRepeatDelay
;@ writes: hRepeatDelay
;@ test: pressed = rng.choice([0, BTN_LEFT]); held = rng.choice([0, BTN_LEFT]); hRepeatDelay = rand(1, 3)
;@ test: hVirusLevel = rand(0, 20); hVirusLevelBCD = to_bcd(hVirusLevel)
;@ sig: 837ae6e8
VirusLevelLeft::
;> if pressed & BTN_LEFT:
;>     delay = 0x10
	bit 5, b
	ld a, $10
	jr nz, jr_000_07c2

;> elif not held & BTN_LEFT:
;>     return
	bit 5, c
	ret z

;> else:
;>     hRepeatDelay -= 1
;>     if hRepeatDelay:
;>         return
	ldh a, [hRepeatDelay]
	dec a
	ldh [hRepeatDelay], a
	ret nz

;>     delay = 8
	ld a, $08

;> hRepeatDelay = delay
jr_000_07c2:
	ldh [hRepeatDelay], a
;> CallVirusLevelDown()
	call CallVirusLevelDown
	ret


;@ def VirusLevelConfirm()
;@ path: screens/options
;@ Leaves the virus level box: unhighlights it and moves to the music box
;@ (up) or the speed box. The master replays the move it sent the slave.
;@ reads: hSerialRole, hSerialTx, hJoyPressed
;@ writes: wSFXRequest, hJoyPressed, hSerialTx, hJoyHeld
;@ test: skip waits for the LCD
;@ sig: 21170bb0
VirusLevelConfirm::
;> wSFXRequest = 1
	ld a, $01
	ld [wSFXRequest], a
;> DrawColumn3VRAM(0x9863, 0x83, 3, 2)             # plain frame again
	ld hl, $9863
	ld a, $83
	ld bc, $0302
	call DrawColumn3VRAM
;> DrawColumn3VRAM(0x986F, 0x85, 2, 3)
	ld hl, $986f
	ld a, $85
	ld bc, $0203
	call DrawColumn3VRAM
;> FillRowVRAM(0x9864, 0x84, 11)
	ld hl, $9864
	ld a, $84
	ld b, $0b
	call FillRowVRAM
;> FillRowVRAM(0x98A4, 0x89, 11)
	ld hl, $98a4
	ld a, $89
	ld b, $0b
	call FillRowVRAM
;> if hSerialRole == SERIAL_MASTER:
	ldh a, [hSerialRole]
	cp $30
	jr nz, jr_000_0805

;>     hJoyPressed = hSerialTx                     # the move it just sent
	ldh a, [hSerialTx]
	ldh [hJoyPressed], a
;>     hSerialTx = 0x19
	ld a, $19
	ldh [hSerialTx], a
;> hJoyHeld = hJoyPressed
jr_000_0805:
	ldh a, [hJoyPressed]
	ld b, a
	ldh [hJoyHeld], a
;> if hJoyPressed & BTN_UP:
;>     return EnterMusicSelect()
	bit 6, b
	jp nz, EnterMusicSelect

;> EnterSpeedSelect()                              # falls through

;@ def EnterSpeedSelect()
;@ path: screens/options
;@ Highlights the speed box and switches to game state $0D.
;@ reads: wCurrentSong
;@ writes: hGameState, wMusicRequest
;@ test: skip waits for the LCD
;@ sig: 97500459
EnterSpeedSelect::
;> DrawColumn3VRAM(0x9903, 0x93, 3, 2)
	ld hl, $9903
	ld a, $93
	ld bc, $0302
	call DrawColumn3VRAM
;> DrawColumn3VRAM(0x9909, 0x95, 2, 3)
	ld hl, $9909
	ld a, $95
	ld bc, $0203
	call DrawColumn3VRAM
;> FillRowVRAM(0x9904, 0x94, 5)
	ld hl, $9904
	ld a, $94
	ld b, $05
	call FillRowVRAM
;> FillRowVRAM(0x9944, 0x99, 5)
	ld hl, $9944
	ld a, $99
	ld b, $05
	call FillRowVRAM
;> hGameState = 0x0D                               # SpeedSelect
	ld a, $0d
	ldh [hGameState], a
;> if wCurrentSong != 3:
;>     wMusicRequest = 3
	ld hl, wCurrentSong
	ld a, $03
	cp [hl]
	ret z

	ld [wMusicRequest], a
	ret


;@ def SpeedSelect()
;@ path: screens/options
;@ Game state $0D: the speed box. Right/left step through LOW, MED, HI
;@ (wrapping), up/down move to another box, Start begins the game; over the
;@ link cable it works like VirusLevelSelect.
;@ reads: hSerialRole, hSerialTx, hSerialRx, hJoyPressed, hTwoPlayer
;@ writes: hSerialTx
;@ test: hSerialRole = 0; hTwoPlayer = rng.choice([0, 0, 1]); hSpeed = rand(2, 4); hSpeed2P = rand(2, 4)
;@ test: hJoyPressed = rng.choice([0, BTN_RIGHT, BTN_LEFT, BTN_A])
;@ test: hTimer1 = rng.choice([0, 4])
;@ sig: 9cc037b5
SpeedSelect::
;> SpeedLink()
	call SpeedLink
;> DrawSpeed()
	call DrawSpeed
;> if hSerialRole == SERIAL_MASTER:
	ldh a, [hSerialRole]
	cp $30
	jr nz, jr_000_0860

;>     if hSerialTx == 0x18:
;>         return OptionsStart()
	ldh a, [hSerialTx]
	cp $18
	jp z, OptionsStart

;>     if hSerialTx & 0xC0:
;>         return SpeedConfirm()
	and $c0
	jp nz, SpeedConfirm

;> SendSpeed()
jr_000_0860:
	call SendSpeed
;> BlinkCursor()
	call BlinkCursor
;> if hSerialRole == SERIAL_SLAVE:
	ldh a, [hSerialRole]
	cp $60
	jr z, jr_000_087d

;>@slavestart     if hSerialRx == 0x18:                       # the master pressed Start
;>@slavego         return OptionsStart()
;> elif hJoyPressed & BTN_START:
	ldh a, [hJoyPressed]
	bit 3, a
	jr z, jr_000_0884

;>     if not hTwoPlayer:
;>         return OptionsStart()
	ldh a, [hTwoPlayer]
	and a
	jp z, OptionsStart

;>     hSerialTx = 0x18                            # tell the slave
;>     return
	ld a, $18
	ldh [hSerialTx], a
	ret

;=@slavestart
jr_000_087d:
	ldh a, [hSerialRx]
	cp $18
;=@slavego
	jp z, OptionsStart

;> pressed = hJoyPressed
jr_000_0884:
	ldh a, [hJoyPressed]
	ld b, a
;> if hSerialRole != SERIAL_SLAVE and pressed & (BTN_UP | BTN_DOWN):
	ldh a, [hSerialRole]
	cp $60
	jr z, jr_000_089c

	ld a, b
	and $c0
	jr z, jr_000_089c

;>     if not hTwoPlayer:
;>         return SpeedConfirm()
	ldh a, [hTwoPlayer]
	and a
	jp z, SpeedConfirm

;>     hSerialTx = pressed                         # the slave moves too
;>     return
	ld a, b
	ldh [hSerialTx], a
	ret

;> if pressed & BTN_RIGHT:
jr_000_089c:
	bit 4, b
	jr nz, jr_000_08a5

;>@right     SpeedRight()
;> elif pressed & BTN_LEFT:
	bit 5, b
	jr nz, jr_000_0918

	ret

;>@leftcall     SpeedLeft()
;=@right
jr_000_08a5:
	call SpeedRight
	ret


;@ def SpeedLink()
;@ path: screens/options
;@ The link side of the speed box. Each side always sends what its current
;@ box holds: a virus level ($00-$14), speed + $20 or music + $30. So when
;@ the slave receives a level it knows the master went up, and a music byte
;@ means down; it then replays that press and its caller jumps to
;@ SpeedConfirm. The master just takes the slave's speed or level.
;@ reads: hSerialRole, hSerialRx
;@ writes: hSpeed2P, hVirusLevel2P, hVirusLevel2PBCD, hJoyPressed
;@ test: hSerialRole = rng.choice([0, SERIAL_MASTER, SERIAL_SLAVE])
;@ test: hSerialRx = rng.choice([0x18, 0x19, rand(0x20, 0x2F)]) if hSerialRole == SERIAL_SLAVE else rng.choice([rand(0, 0x14), rand(0x20, 0x24), 0x18, 0x30])
;@ test: hTwoPlayer = 1
;@ sig: ecdd18ce
SpeedLink::
;> if not hSerialRole:
;>     return
	ldh a, [hSerialRole]
	and a
	ret z

;> if hSerialRole != SERIAL_MASTER:                # slave: the byte came from the master
	cp $30
	jr z, jr_000_08d5

;>     rx = hSerialRx
	ldh a, [hSerialRx]
	ld b, a
;>     if rx & 0xC0:                               # an up/down press
;>         pressed = rx
	and $c0
	jr nz, jr_000_08ce

;>     elif rx < 0x15:                             # a virus level: it went up
;>@pup         pressed = BTN_UP
	ld a, b
	cp $15
	jr c, jr_000_08f5

;>     elif rx == 0x18 or rx == 0x19:              # Start / idle
;>         return
	cp $18
	ret z

	cp $19
	ret z

;>     elif rx >= 0x30:                            # a music byte: it went down
;>@pdown         pressed = BTN_DOWN
	cp $30
	jr nc, jr_000_08fd

;>     else:                                       # its speed
;>         hSpeed2P = rx - 0x20
	sub $20
	ld hl, hSpeed2P
	ld [hl], a
;>         return
	ret

;>@store     hJoyPressed = pressed
;>@pop     pop_return_address()                        # the caller does not go on
;>@jump     return SpeedConfirm()
;=@store
jr_000_08ce:
	ld a, b
	ldh [hJoyPressed], a
;=@pop
	pop af
;=@jump
	jp SpeedConfirm

;> else:                                           # master: the byte came from the slave
;>     rx = hSerialRx
jr_000_08d5:
	ldh a, [hSerialRx]
;>     if rx >= 0x20:
	cp $20
	jr c, jr_000_08e5

;>         if rx < 0x25:                           # its speed
	cp $25
	ret nc

;>             hSpeed2P = rx - 0x20
	sub $20
	ld hl, hSpeed2P
	ld [hl], a
	ret

;>     elif rx < 0x15:                             # its virus level
TakeVirusLevel2P:
jr_000_08e5:
	cp $15
	ret nc

;>         hVirusLevel2P = rx
	ld hl, hVirusLevel2P
	ld [hl], a
;>         hVirusLevel2PBCD = ToBCD(0xFFC4)        # hVirusLevel2P
	call ToBCD
	ldh [hVirusLevel2PBCD], a
;>         DrawVirusLevel2P()
	call DrawVirusLevel2P
	ret

;=@pup
jr_000_08f5:
	ld a, $40

;=@store
jr_000_08f7:
	ldh [hJoyPressed], a
	ld b, a
;=@pop
	pop af
;=@jump
	jr jr_000_093d

;=@pdown
jr_000_08fd:
	ld a, $80
	jr jr_000_08f7

;@ def SpeedRight()
;@ path: screens/options
;@ One step right on the speed box: 4 (LOW) -> 3 (MED) -> 2 (HI) -> 4.
;@ test: hSpeed = rand(2, 4)
;@ sig: 7da0bf0d
SpeedRight::
;> hSpeed -= 1
	ld hl, hSpeed
	dec [hl]
;> if hSpeed == 1:
;>     hSpeed = 4
	ld a, [hl]
	cp $01
	ret nz

	ld a, $04
	ld [hl], a
	ret


;@ def SendSpeed()
;@ path: screens/options
;@ In a 2-player game, sends the speed (+ $20) to the other Game Boy.
;@ reads: hTwoPlayer, hSpeed
;@ writes: hSerialTx
;@ test: hTwoPlayer = rng.choice([0, 1]); hSpeed = rand(2, 4)
;@ sig: 50d97653
SendSpeed::
;> if not hTwoPlayer:
;>     return
	ldh a, [hTwoPlayer]
	and a
	ret z

;> hSerialTx = hSpeed + 0x20
	ldh a, [hSpeed]
	add $20
	ldh [hSerialTx], a
	ret


jr_000_0918:
;=@SpeedSelect.leftcall
	call SpeedLeft
	ret


;@ def SpeedLeft()
;@ path: screens/options
;@ One step left on the speed box: 2 (HI) -> 3 (MED) -> 4 (LOW) -> 2.
;@ test: hSpeed = rand(2, 4)
;@ sig: f5c795ea
SpeedLeft::
;> hSpeed += 1
	ld hl, hSpeed
	inc [hl]
;> if hSpeed == 5:
;>     hSpeed = 2
	ld a, [hl]
	cp $05
	ret nz

	ld a, $02
	ld [hl], a
	ret


;@ def DrawSpeed()
;@ path: screens/options
;@ Moves the speed arrows (and the other player's in a 2-player game).
;@ reads: hSpeed, hSpeed2P, hTwoPlayer
;@ test: hSpeed = rand(2, 4); hSpeed2P = rand(2, 4); hTwoPlayer = rng.choice([0, 1])
;@ sig: 7edd30c0
DrawSpeed::
;> SetSpeedArrow(hSpeed, 0xC019)                   # sprites 6 and 7
	ldh a, [hSpeed]
	ld hl, wShadowOAM + $19
	call SetSpeedArrow
;> if not hTwoPlayer:
;>     return
	ldh a, [hTwoPlayer]
	and a
	ret z

;> SetSpeedArrow(hSpeed2P, 0xC021)                 # sprites 8 and 9
	ldh a, [hSpeed2P]
	ld hl, wShadowOAM + $21
	call SetSpeedArrow
	ret


;@ def SpeedConfirm()
;@ path: screens/options
;@ Leaves the speed box: unhighlights it and moves to the virus level box
;@ (up) or the music box. The master replays the move it sent the slave.
;@ reads: hSerialRole, hSerialTx, hJoyPressed
;@ writes: wSFXRequest, hJoyPressed, hSerialTx, hJoyHeld, hGameState
;@ test: skip waits for the LCD
;@ sig: ccb94aa1
SpeedConfirm::
;> wSFXRequest = 1
jr_000_093d:
	ld a, $01
	ld [wSFXRequest], a
;> DrawColumn3VRAM(0x9903, 0x83, 3, 2)             # plain frame again
	ld hl, $9903
	ld a, $83
	ld bc, $0302
	call DrawColumn3VRAM
;> DrawColumn3VRAM(0x9909, 0x85, 2, 3)
	ld hl, $9909
	ld a, $85
	ld bc, $0203
	call DrawColumn3VRAM
;> FillRowVRAM(0x9904, 0x84, 5)
	ld hl, $9904
	ld a, $84
	ld b, $05
	call FillRowVRAM
;> FillRowVRAM(0x9944, 0x89, 5)
	ld hl, $9944
	ld a, $89
	ld b, $05
	call FillRowVRAM
;> if hSerialRole == SERIAL_MASTER:
	ldh a, [hSerialRole]
	cp $30
	jr nz, jr_000_097a

;>     hJoyPressed = hSerialTx                     # the move it just sent
	ldh a, [hSerialTx]
	ldh [hJoyPressed], a
;>     hSerialTx = 0x19
	ld a, $19
	ldh [hSerialTx], a
;> hJoyHeld = hJoyPressed
jr_000_097a:
	ldh a, [hJoyPressed]
	ld b, a
	ldh [hJoyHeld], a
;> if hJoyPressed & BTN_UP:
	bit 6, b
	jr z, jr_000_098b

;>     FrameVirusLevel()
	call FrameVirusLevel
;>     hGameState = 0x0C                           # VirusLevelSelect
;>     return
	ld a, $0c
	ldh [hGameState], a
	ret

;> EnterMusicSelect()                              # falls through


;@ def EnterMusicSelect()
;@ path: screens/options
;@ Highlights the music box and switches to game state $0E.
;@ writes: hGameState
;@ test: skip waits for the LCD
;@ sig: 50b2d6af
EnterMusicSelect::
;> DrawColumn3VRAM(0x9983, 0x93, 3, 2)
jr_000_098b:
	ld hl, $9983
	ld a, $93
	ld bc, $0302
	call DrawColumn3VRAM
;> DrawColumn3VRAM(0x9989, 0x95, 2, 3)
	ld hl, $9989
	ld a, $95
	ld bc, $0203
	call DrawColumn3VRAM
;> FillRowVRAM(0x9984, 0x94, 5)
	ld hl, $9984
	ld a, $94
	ld b, $05
	call FillRowVRAM
;> FillRowVRAM(0x99C4, 0x99, 5)
	ld hl, $99c4
	ld a, $99
	ld b, $05
	call FillRowVRAM
;> hGameState = 0x0E                               # MusicSelect
	ld a, $0e
	ldh [hGameState], a
	ret


;@ def PlayChosenMusic()
;@ path: screens/options
;@ Plays the music picked in the music box: FEVER (song 1), CHILL (song 2)
;@ or OFF (song 7, silence; requested every frame).
;@ reads: hMusicType, wCurrentSong
;@ writes: wMusicRequest
;@ test: hMusicType = rand(0, 2); wCurrentSong = rand(0, 8)
;@ sig: 21fbc452
PlayChosenMusic::
;> if hMusicType == 2:
;>     wMusicRequest = 7
;>     return
	ld hl, wCurrentSong
	ld b, $01
	ldh a, [hMusicType]
	and a
	jr z, jr_000_09cf

	inc b
	cp $01
	jr z, jr_000_09cf

	ld a, $07
	ld [wMusicRequest], a
	ret

;> song = hMusicType + 1
;> if wCurrentSong != song:
;>     wMusicRequest = song
jr_000_09cf:
	ld a, b
	cp [hl]
	ret z

	ld [wMusicRequest], a
	ret


;@ def MusicSelect()
;@ path: screens/options
;@ Game state $0E: the music box. Right/left cycle FEVER, CHILL, OFF and the
;@ music changes right away; up/down move to another box, Start begins the
;@ game. Over the link cable the master's choice wins.
;@ reads: hSerialRole, hSerialTx, hSerialRx, hJoyPressed, hTwoPlayer, hMusicType
;@ writes: hSerialTx, hMusicType, wSFXRequest
;@ test: hSerialRole = 0; hTwoPlayer = rng.choice([0, 0, 1]); hMusicType = rand(0, 2); wCurrentSong = rand(0, 8)
;@ test: hJoyPressed = rng.choice([0, BTN_RIGHT, BTN_LEFT, BTN_A])
;@ test: hTimer1 = rng.choice([0, 4])
;@ sig: 1f6b2a89
MusicSelect::
;> PlayChosenMusic()
	call PlayChosenMusic
;> if hSerialRole == SERIAL_MASTER:
	ldh a, [hSerialRole]
	cp $30
	jr nz, jr_000_09eb

;>     if hSerialTx == 0x18:
;>         return OptionsStart()
	ldh a, [hSerialTx]
	cp $18
	jp z, OptionsStart

;>     if hSerialTx & 0xC0:
;>         return MusicConfirm()
	and $c0
	jp nz, MusicConfirm

;> MusicLink()
jr_000_09eb:
	call MusicLink
;> CallDrawMusicType()
	call CallDrawMusicType
;> BlinkCursor()
	call BlinkCursor
;> if hSerialRole == SERIAL_SLAVE:
	ldh a, [hSerialRole]
	cp $60
	jr z, jr_000_0a0b

;>@slavestart     if hSerialRx == 0x18:                       # the master pressed Start
;>@slavego         return OptionsStart()
;>@slaveret     return                                      # the slave only follows here
;> elif hJoyPressed & BTN_START:
	ldh a, [hJoyPressed]
	bit 3, a
	jr z, jr_000_0a13

;>     if not hTwoPlayer:
;>         return OptionsStart()
	ldh a, [hTwoPlayer]
	and a
	jp z, OptionsStart

;>     hSerialTx = 0x18                            # tell the slave
;>     return
	ld a, $18
	ldh [hSerialTx], a
	ret

;=@slavestart
jr_000_0a0b:
	ldh a, [hSerialRx]
	cp $18
;=@slavego
	jp z, OptionsStart

;=@slaveret
	ret

;> pressed = hJoyPressed
jr_000_0a13:
	ldh a, [hJoyPressed]
	ld b, a
;> if pressed & (BTN_UP | BTN_DOWN):
	and $c0
	jr z, jr_000_0a24

;>     if not hTwoPlayer:
;>         return MusicConfirm()
	ldh a, [hTwoPlayer]
	and a
	jp z, MusicConfirm

;>     hSerialTx = pressed                         # the slave moves too
;>     return
	ld a, b
	ldh [hSerialTx], a
	ret

;> if pressed & BTN_RIGHT:
jr_000_0a24:
	bit 4, b
	jr nz, jr_000_0a2d

;>@rclick     wSFXRequest = 3
;>@rinc     hMusicType += 1
;>@rwrap     if hMusicType == 3:
;>@rzero         hMusicType = 0
;> elif pressed & BTN_LEFT:
	bit 5, b
	jr nz, jr_000_0a3d

	ret

;=@rclick
jr_000_0a2d:
	ld a, $03
	ld [wSFXRequest], a
;=@rinc
	ld hl, hMusicType
	inc [hl]
;=@rwrap
	ld a, [hl]
	cp $03
	ret nz

;=@rzero
	xor a
	ld [hl], a
	ret

;>     wSFXRequest = 3
jr_000_0a3d:
	ld a, $03
	ld [wSFXRequest], a
;>     if hMusicType:
;>         hMusicType -= 1
	ld hl, hMusicType
	ld a, [hl]
	and a
	jr z, jr_000_0a4b

	dec [hl]
	ret

;>     else:
;>         hMusicType = 2
jr_000_0a4b:
	ld a, $02
	ld [hl], a
	ret


;@ def MusicLink()
;@ path: screens/options
;@ The link side of the music box. The slave follows the master's music
;@ choice (+ $30) and echoes it back; an up/down press from the master makes
;@ it leave the box too (its caller jumps to MusicConfirm). The master takes
;@ the slave's level or speed bytes, otherwise it sends its music choice.
;@ reads: hSerialRole, hSerialRx, hMusicType
;@ writes: hSerialTx, hMusicType, wSFXRequest, hJoyPressed
;@ test: hSerialRole = rng.choice([0, SERIAL_MASTER, SERIAL_SLAVE]); hMusicType = rand(0, 2)
;@ test: hSerialRx = rng.choice([0x19, rand(0, 0x24), rand(0x30, 0x32)]) if hSerialRole == SERIAL_SLAVE else rng.choice([rand(0x15, 0x21), rand(0x25, 0x40)])
;@ sig: dd2cc12b
MusicLink::
;> if not hSerialRole:
;>     return
	ldh a, [hSerialRole]
	and a
	ret z

;> if hSerialRole != SERIAL_MASTER:                # slave: the byte came from the master
	cp $30
	jr z, jr_000_0a79

;>     rx = hSerialRx
	ldh a, [hSerialRx]
	ld b, a
;>     if rx & 0xC0:                               # an up/down press
	and $c0
	jr nz, jr_000_0a90

;>@store         hJoyPressed = rx
;>@pop         pop_return_address()                    # the caller does not go on
;>@jump         return MusicConfirm()
;>@idle     if rx == 0x19:                              # idle: echo it
;>@idletx         hSerialTx = rx
;>@idleret         return
;>@lt25     if rx < 0x25:
;>@lt25ret         return
;=@idle
	ld a, b
	cp $19
	jr z, jr_000_0a76

;=@lt25
	cp $25
;=@lt25ret
	ret c

;>     hSerialTx = rx                              # echo the master's music choice
	ldh [hSerialTx], a
;>     music = (rx - 0x30) & 0xFF
;>     if hMusicType != music:
	sub $30
	ld hl, hMusicType
	cp [hl]
	ret z

;>         hMusicType = music
	ld [hl], a
;>         wSFXRequest = 3                         # click
	ld a, $03
	ld [wSFXRequest], a
	ret

;=@idletx
jr_000_0a76:
	ldh [hSerialTx], a
;=@idleret
	ret

;> else:                                           # master: the byte came from the slave
;>     rx = hSerialRx
jr_000_0a79:
	ldh a, [hSerialRx]
;>     if rx < 0x15:
;>         return TakeVirusLevel2P(rx)
	cp $15
	jp c, TakeVirusLevel2P

;>     if 0x22 <= rx < 0x25:
;>         return TakeSpeed2P(rx)
	cp $22
	jr c, jr_000_0a89

	cp $25
	jp c, TakeSpeed2P

;>     hSerialTx = hMusicType + 0x30
jr_000_0a89:
	ldh a, [hMusicType]
	add $30
	ldh [hSerialTx], a
	ret

;=@store
jr_000_0a90:
	ld a, b
	ldh [hJoyPressed], a
;=@pop
	pop af
;=@jump
	jr jr_000_0aa6

	db $3e, $40, $e0, $81, $47, $f1, $18, $08, $3e, $80, $18, $f6

;@ def CallDrawMusicType()
;@ path: screens/options
;@ test: hMusicType = rand(0, 2)
;@ sig: 0e3bca62
CallDrawMusicType::
;> DrawMusicType()
	call DrawMusicType
	ret


;@ def MusicConfirm()
;@ path: screens/options
;@ Leaves the music box: unhighlights it and moves to the speed box (up) or
;@ wraps round to the virus level box.
;@ reads: hSerialRole, hSerialTx, hJoyPressed
;@ writes: wSFXRequest, hJoyPressed, hSerialTx, hJoyHeld, hGameState
;@ test: skip waits for the LCD
;@ sig: 471adc5f
MusicConfirm::
;> wSFXRequest = 1
jr_000_0aa6:
	ld a, $01
	ld [wSFXRequest], a
;> DrawColumn3VRAM(0x9983, 0x83, 3, 2)             # plain frame again
	ld hl, $9983
	ld a, $83
	ld bc, $0302
	call DrawColumn3VRAM
;> DrawColumn3VRAM(0x9989, 0x85, 2, 3)
	ld hl, $9989
	ld a, $85
	ld bc, $0203
	call DrawColumn3VRAM
;> FillRowVRAM(0x9984, 0x84, 5)
	ld hl, $9984
	ld a, $84
	ld b, $05
	call FillRowVRAM
;> FillRowVRAM(0x99C4, 0x89, 5)
	ld hl, $99c4
	ld a, $89
	ld b, $05
	call FillRowVRAM
;> if hSerialRole == SERIAL_MASTER:
	ldh a, [hSerialRole]
	cp $30
	jr nz, jr_000_0ae3

;>     hJoyPressed = hSerialTx                     # the move it just sent
	ldh a, [hSerialTx]
	ldh [hJoyPressed], a
;>     hSerialTx = 0x19
	ld a, $19
	ldh [hSerialTx], a
;> hJoyHeld = hJoyPressed
jr_000_0ae3:
	ldh a, [hJoyPressed]
	ld b, a
	ldh [hJoyHeld], a
;> if hJoyPressed & BTN_UP:
;>     return EnterSpeedSelect()
	bit 6, b
	jp nz, EnterSpeedSelect

;> FrameVirusLevel()
	call FrameVirusLevel
;> hGameState = 0x0C                               # VirusLevelSelect
	ld a, $0c
	ldh [hGameState], a
	ret


;@ def DrawMusicType()
;@ path: screens/options
;@ Moves the music cursor (sprites 10-14) under FEVER, CHILL or OFF; the OFF
;@ cursor is only 3 sprites wide, the other two are moved off screen.
;@ reads: hMusicType
;@ test: hMusicType = rand(0, 2)
;@ sig: 1561c58c
DrawMusicType::
;> x, n = {2: (0x80, 3), 1: (0x50, 5)}.get(hMusicType, (0x20, 5))
	ldh a, [hMusicType]
	ld hl, wShadowOAM + $29
	ld bc, $8003
	cp $02
	jr z, jr_000_0b0a

	ld bc, $5005
	cp $01
	jr z, jr_000_0b0a

	ld b, $20

;> for i in range(n):
;>     mem[0xC029 + 4 * i] = x + 8 * i
jr_000_0b0a:
	ld a, b
	ld de, $0004

jr_000_0b0e:
	ld [hl], a
	add $08
	add hl, de
	dec c
	jr nz, jr_000_0b0e

;> if hMusicType == 2:
	ldh a, [hMusicType]
	cp $02
	ret nz

;>     mem[wShadowOAM + 53] = 0xF0
;>     mem[wShadowOAM + 57] = 0xF0
	ld a, $f0
	ld [hl], a
	add hl, de
	ld [hl], a
	ret


;@ def SetSpeedArrow(speed: a, dest: hl)
;@ path: screens/options
;@ Moves the two arrow sprites under the speed choice (4 = LOW, 3 = MED,
;@ otherwise HI), clicking when they move.
;@ writes: wSFXRequest
;@ test: speed = rand(2, 4); dest = 0xC010 + 4 * rand(0, 20)
;@ test: mem[dest] = rng.choice([0x3C, 0x5C, 0x78, 0]); mem[dest + 4] = rng.choice([0x44, 0x64, 0x80, 0])
;@ sig: 62573695
SetSpeedArrow::
;> x = {4: 0x3C, 3: 0x5C}.get(speed, 0x78)
	ld b, $3c
	cp $04
	jr z, jr_000_0b2e

	ld b, $5c
	cp $03
	jr z, jr_000_0b2e

	ld b, $78

;> for i in range(2):
;>     if mem[dest + 4 * i] == x + 8 * i:
;>         return
;>     mem[dest + 4 * i] = x + 8 * i
jr_000_0b2e:
	ld a, b
	ld b, $02

jr_000_0b31:
	cp [hl]
	ret z

	ld [hli], a
	inc l
	inc l
	inc l
	add $08
	dec b
	jr nz, jr_000_0b31

;> wSFXRequest = 3                                 # click
	ld a, $03
	ld [wSFXRequest], a
	ret


;@ def FillRowVRAM(dest: hl, tile: a, count: b) -> hl
;@ path: gfx/tilemaps
;@ Writes count copies of a tile to VRAM, one per HBlank, interrupts off.
;@ test: skip waits for the LCD
;@ sig: e27f8628
FillRowVRAM::
;> disable_interrupts()
	di
;> for i in range(count):
;>     WaitHBlank()
;>     mem[dest] = tile
;>     dest += 1
	call WaitHBlank
	ld [hli], a
	dec b
	jr nz, FillRowVRAM

;> enable_interrupts()
;> return dest
	ei
	ret


;@ def DrawColumn3VRAM(dest: hl, tile: a, step1: b, step2: c)
;@ path: gfx/tilemaps
;@ Writes three tiles one below the other: tile, tile + step1 and
;@ tile + step1 + step2, each in an HBlank, interrupts off.
;@ test: skip waits for the LCD
;@ sig: 9bef34d5
DrawColumn3VRAM::
;> disable_interrupts()
	di
;> WaitHBlank()
;> mem[dest] = tile
	ld de, $0020
	call WaitHBlank
	ld [hl], a
;> WaitHBlank()
;> mem[dest + 32] = (tile + step1) & 0xFF
	add hl, de
	add b
	call WaitHBlank
	ld [hl], a
;> WaitHBlank()
;> mem[dest + 64] = (tile + step1 + step2) & 0xFF
	add hl, de
	add c
	call WaitHBlank
	ld [hl], a
;> enable_interrupts()
	ei
	ret


;@ def BlinkCursor()
;@ path: gfx/objects
;@ reads: hTimer1
;@ writes: hTimer1
;@ Every 9 frames flips the priority bit of shadow OAM entries 10-14, so the
;@ cursor sprites alternate between in front of and behind the background.
;@ test: hTimer1 = rng.choice([0, 0, 5])
;@ sig: 107d4527
BlinkCursor::
;> if hTimer1:
;>     return
	ldh a, [hTimer1]
	and a
	ret nz

;> hTimer1 = 9
	ld a, $09
	ldh [hTimer1], a
;> for i in range(5):
;>     mem[0xC02B + 4 * i] ^= 0x80                 # attribute byte, bit 7 = behind BG
	ld hl, wShadowOAM + $2B
	ld b, $05

jr_000_0b6f:
	ld a, [hl]
	xor $80
	ld [hli], a
	inc l
	inc l
	inc l
	dec b
	jr nz, jr_000_0b6f

	ret


;@ def WaitHBlank()
;@ path: system/lcd
;@ Waits until the LCD is in HBlank (STAT mode 0), keeping a.
;@ test: skip waits for the LCD
;@ sig: 57bc8963
WaitHBlank::
;> wait_hblank()
	push af

jr_000_0b7b:
	ldh a, [rSTAT]
	and $03
	jr nz, jr_000_0b7b

	pop af
	ret


;@ def ClearBottleRows()
;@ path: game/setup
;@ Empties the bottle below its top row.
;@ sig: f1e603e7
ClearBottleRows::
;> for addr in range(0xC808, 0xC880):
;>     mem[addr] = 0xFF
	ld hl, wBottle + $08

jr_000_0b86:
	ld [hl], $ff
	inc l
	ld a, l
	cp $80
	jr nz, jr_000_0b86

	ret


;@ def GameInit()
;@ path: game/setup
;@ Game state $02: loads the 1-player or 2-player game screen with the LCD
;@ off (in 1P a copy goes to BG map 1 too, in 2P the side panel shown through
;@ the window), clears the score and sets up the level.
;@ reads: hTwoPlayer
;@ writes: wScore, $9852
;@ test: skip switches the LCD off
;@ sig: 3f070371
GameInit::
;> DisableLCD()
	call DisableLCD
;> ClearShadowOAM()
	call ClearShadowOAM
;> CopyBytes(GameTiles, vTiles0, 0x300)            # the options screen replaced these
	ld de, $8000
	ld hl, $3d9e
	ld bc, $0300
	call CopyBytes
;> src = GameScreen2P if hTwoPlayer else GameScreen1P
	ld de, $3a2c
	ldh a, [hTwoPlayer]
	and a
	jr nz, jr_000_0bac

	ld de, $38c4

;> LoadScreen(src)
jr_000_0bac:
	push de
	call LoadScreen
	pop de
;> if not hTwoPlayer:
	ldh a, [hTwoPlayer]
	and a
	jr nz, jr_000_0bd7

;>     for k in range(4):
;>         mem[wScore + k] = 0
	xor a
	ld [wScore], a
	ld [wScore + 1], a
	ld [wScore + 2], a
	ld [wScore + 3], a
;>     mem[0x9852] = 0
	ld [$9852], a
;>     LoadScreenAt(src, vBGMap1)
	ld hl, $9c00
	call LoadScreenAt
;>     CopyRowsUntilFD(0x0CD9, 0x9D02)
	ld de, $0cd9
	ld hl, $9d02
	call CopyRowsUntilFD
	jr LevelInit

;> else:
;>     LoadBGMap1Panel(VersusPanel)
jr_000_0bd7:
	ld hl, $9c00
	ld de, $3cfc
	call LoadBGMap1Panel
;>     rWY = 0                                     # the window shows the panel on the right
	ld a, $00
	ldh [rWY], a
;>     rWX = 0x5F
	ld a, $5f
	ldh [rWX], a
;> LevelInit()                                     # falls through

;@ def LevelInit()
;@ path: game/setup
;@ Game state $09: sets up a level. Empties the bottle, creates the capsule
;@ objects and deals the first capsules, draws the game screen's sprites,
;@ picks the drop speed and switches the LCD back on. The link master rolls
;@ the 128 shared capsules (the demo uses a fixed list), then the virus
;@ counts are set and play starts with state $03 (1P) or $16 (2P).
;@ reads: rLCDC, hDemoMode, hTwoPlayer, hSpeed, hVirusLevelBCD, hSerialRole, hVirusLevel, hVirusLevel2P, wCapsuleList
;@ writes: hTimer1, hSpeedIndex, hDrawBCDFlag, $FF98, $FFFD, wObjects, hCapsuleState, hUnusedFD, wNextCapsule
;@ test: skip switches the LCD off
;@ sig: 07d0748f
LevelInit::
;> if rLCDC & 0x80:
;>     DisableLCD()
	ldh a, [rLCDC]
	and $80
	jr z, jr_000_0bf1

	call DisableLCD

;> ClearBottleRows()
jr_000_0bf1:
	call ClearBottleRows
;> ClearShadowOAMFrom6()
	call ClearShadowOAMFrom6
;> CopyUntilFF(0x2083, wObjects)                   # object 0: the falling capsule
	ld hl, wObjects
	ld de, $2083
	rst $18
;> CopyUntilFF(0x209B if hDemoMode else 0x208B, 0xC210)   # object 1: the next capsule
	ld hl, wNextCapsule
	ld de, $209b
	ldh a, [hDemoMode]
	and a
	jr nz, jr_000_0c0c

	ld de, $208b

jr_000_0c0c:
	rst $18
;> if hTwoPlayer:
;>     CopyUntilFD(Versus2PSprites, 0xC050)
	ldh a, [hTwoPlayer]
	and a
	jr z, jr_000_0c1b

	ld hl, wShadowOAM + $50
	ld de, $0ce2
	call CopyUntilFD

;> if not hDemoMode:
jr_000_0c1b:
	ldh a, [hDemoMode]
	and a
	jr nz, jr_000_0c33

;>     if hTwoPlayer:
;>         mem[wObjects + 16] = 0x80                      # no next capsule shown
	ldh a, [hTwoPlayer]
	and a
	jr z, jr_000_0c2a

	ld a, $80
	ld [wNextCapsule], a

;>     NextCapsule()                               # deal three to get going
jr_000_0c2a:
	call NextCapsule
;>     NextCapsule()
	call NextCapsule
;>     NextCapsule()
	call NextCapsule
;> mem[wObjects] = 0x80                              # the current capsule stays hidden for now
jr_000_0c33:
	ld hl, wObjects
	ld [hl], $80
;> DrawTwoObjects()
	call DrawTwoObjects
;> InitGameScreen()
	call InitGameScreen
;> hCapsuleState = 0
;> hUnusedFD = 0
	xor a
	ldh [hCapsuleState], a
	ldh [hUnusedFD], a
;> hTimer1 = 3
	ld a, $03
	ldh [hTimer1], a
;> index = {4: 0, 3: 9}.get(hSpeed, 20)            # LOW, MED, HI
	ldh a, [hSpeed]
	ld b, $00
	cp $04
	jr z, jr_000_0c57

	ld b, $09
	cp $03
	jr z, jr_000_0c57

	ld b, $14

;> if hVirusLevelBCD >= 0x21:                      # levels past 20 drop faster
;>     index = (hVirusLevelBCD - 0x20 + index) & 0xFF
jr_000_0c57:
	ldh a, [hVirusLevelBCD]
	cp $21
	jr c, jr_000_0c61

	sub $20
	add b
	ld b, a

;> hSpeedIndex = index
jr_000_0c61:
	ld a, b
	ldh [hSpeedIndex], a
;> SetDropSpeed()
	call SetDropSpeed
;> if not hTwoPlayer:
;>     DrawBCD2VRAM(hVirusLevelBCD, 0x9971)        # LEVEL on the side panel
	ld hl, $9971
	ldh a, [hTwoPlayer]
	and a
	jr nz, jr_000_0c79

	ldh a, [hVirusLevelBCD]
	ld b, a
	call DrawBCD2VRAM
;>     hDrawBCDFlag = 1
	ld a, $01
	ldh [hDrawBCDFlag], a
;> rLCDC = 0x83
jr_000_0c79:
	ld a, $83
	ldh [rLCDC], a
;> if hDemoMode:
	ldh a, [hDemoMode]
	and a
	jr nz, jr_000_0ccb

;>@demo1     LoadDemoCapsules()
;>@demo2     mem[wObjects + 3] = mem[wCapsuleList]
;>@demo3     mem[wObjects + 19] = mem[wCapsuleList]
;> elif hSerialRole == SERIAL_MASTER:              # roll the capsules both Game Boys will use
	ldh a, [hSerialRole]
	cp $30
	jr nz, jr_000_0c9d

;>     for _ in range(3):
;>         RandomCapsule()
	call RandomCapsule
	call RandomCapsule
	call RandomCapsule
;>     for k in range(0x80):
;>         mem[wCapsuleList + k] = RandomCapsule()
	ld b, $80
	ld hl, wCapsuleList

jr_000_0c96:
	call RandomCapsule
	ld [hli], a
	dec b
	jr nz, jr_000_0c96

;> VirusCountForLevel(min(hVirusLevel, 20), 0xFFC6)          # hVirusCount
jr_000_0c9d:
	ldh a, [hVirusLevel]
	cp $15
	jr c, jr_000_0ca5

	ld a, $14

jr_000_0ca5:
	ld b, a
	ld de, hVirusCount
	call VirusCountForLevel
;> if hTwoPlayer:
	ldh a, [hTwoPlayer]
	and a
	jr z, jr_000_0cc0

;>     VirusCountForLevel(hVirusLevel2P, 0xFFC7)   # hVirusCount2P
	ldh a, [hVirusLevel2P]
	ld b, a
	ld hl, hVirusThresholds
	ld de, hVirusCount2P
	call VirusCountForLevel
;>     VirusThresholds2P(0xFFC7, 0xFFC8)
	call VirusThresholds2P
;> SetStateFor1P2P(0x03, 0x16)
jr_000_0cc0:
	ld bc, $0316
	call SetStateFor1P2P
;> wLinkHold += 1                                # levels started
	ld hl, wLinkHold
	inc [hl]
	ret

;=@demo1
jr_000_0ccb:
	call LoadDemoCapsules
;=@demo2
	ld a, [wCapsuleList]
	ld [wObjects + 3], a
;=@demo3
	ld [wNextCapsule + 3], a
	jr jr_000_0c9d

	db $8f, $13, $14, $1a, $21, $23, $5e, $8f, $fd

;@ asset: oam tiles=LoadGameTiles|LoadGameTiles+CopyBytes(hl=Tiles_559E,de=$8800,bc=$520)
;@ Sprites added in a 2-player game (LevelInit).
Versus2PSprites::
	db $78, $68, $ff, $00, $80, $68, $ff
	db $00, $78, $70, $ff, $00, $80, $70, $ff, $00, $78, $8c, $ff, $00, $80, $8c, $ff
	db $00, $78, $94, $ff, $00, $80, $94, $ff, $00, $fd

;@ def LoadDemoCapsules()
;@ path: screens/demo
;@ Copies the demo's fixed capsule sequence into wCapsuleList.
;@ sig: 54a3d8d8
LoadDemoCapsules::
;> CopyUntilFF(0x0D0B, wCapsuleList)
	ld hl, wCapsuleList
	ld de, $0d0b
	rst $18
	ret

	db $10, $10, $04, $00, $00, $12, $0a, $10, $0c, $14, $14, $00, $08, $08, $12, $12
	db $0c, $06, $08, $0a, $12, $10, $04, $00, $08, $ff

;@ def DrawBCD2VRAM(value: b, dest: hl)
;@ path: gfx/numbers
;@ Writes the two digits of a BCD byte to the BG map, each in an HBlank.
;@ test: skip waits for the LCD
;@ sig: 3be80842
DrawBCD2VRAM::
;> WaitHBlank()
;> mem[dest] = value >> 4
	ld a, b
	and $f0
	swap a
	ld c, a
	call WaitHBlank
	ld [hl], c
;> WaitHBlank()
;> mem[dest + 1] = value & 0x0F
	inc l
	ld a, b
	and $0f
	ld c, a
	call WaitHBlank
	ld [hl], c
	ret

	db $21, $cc, $98, $f0, $ad, $cd, $4a, $0d, $21, $d0, $98, $f0, $ae, $cd, $4a, $0d
	db $c9

;@ def DrawSpeedName(speed: a, dest: hl)
;@ path: gfx/tilemaps
;@ Writes HI (2), MED (3) or LOW (others) as tiles at dest.
;@ test: speed = rand(2, 4); dest = rand_ram(3)
;@ sig: 4d47b9ea
DrawSpeedName::
;>@hi if speed == 2:
;>@hiw     mem[dest] = 0x11
;>@hiw2     mem[dest + 1] = 0x12
;>@med elif speed == 3:
;>@medw     for k, t in enumerate((0x16, 0x0E, 0x0D)): mem[dest + k] = t
;>@low else:
;>@loww     for k, t in enumerate((0x15, 0x18, 0x20)): mem[dest + k] = t
;=@hi
	cp $02
	jr z, jr_000_0d5b

;=@med
	cp $03
	jr z, jr_000_0d61

;=@loww
	ld [hl], $15
	inc l
	ld [hl], $18
	inc l
	ld [hl], $20
	ret


jr_000_0d5b:
;=@hiw
	ld [hl], $11
	inc l
;=@hiw2
	ld [hl], $12
	ret


jr_000_0d61:
;=@medw
	ld [hl], $16
	inc l
	ld [hl], $0e
	inc l
	ld [hl], $0d
	ret


;@ def VirusCountForLevel(level: b, dest: de)
;@ path: game/setup
;@ A level has 4 * (level + 1) viruses.
;@ test: level = rand(0, 20); dest = rand_ram(1)
;@ sig: 30a9d860
VirusCountForLevel::
;> mem[dest] = (4 * (level + 1)) & 0xFF
	ld a, b
	inc a
	ld c, a
	ld b, $03

jr_000_0d6f:
	add c
	dec b
	jr nz, jr_000_0d6f

	ld [de], a
	ret


;@ def VirusThresholds2P(src: de, dest: hl)
;@ path: game/setup
;@ Stores a quarter, an eighth and a sixteenth of the virus count at src.
;@ test: src = rand_ram(1); mem[src] = rand(4, 84); dest = rand(0xC100, 0xC1F0)
;@ sig: 5d868626
VirusThresholds2P::
;> n = mem[src]
;> mem[dest] = n >> 2
	ld a, [de]
	srl a
	srl a
	ld [hli], a
;> mem[dest + 1] = n >> 3
	srl a
	ld [hli], a
;> mem[dest + 2] = n >> 4
	srl a
	ld [hl], a
	ret


;@ def SetStateFor1P2P(state1p: b, state2p: c)
;@ path: game/setup
;@ Switches to state1p, or state2p in a 2-player game.
;@ reads: hTwoPlayer
;@ writes: hGameState
;@ test: hTwoPlayer = rng.choice([0, 1]); state1p = rand(0, 0x1C); state2p = rand(0, 0x1C)
;@ sig: 1f41690c
SetStateFor1P2P::
;> hGameState = state2p if hTwoPlayer else state1p
	ldh a, [hTwoPlayer]
	and a
	ld a, b
	jr z, jr_000_0d89

	ld a, c

jr_000_0d89:
	ldh [hGameState], a
	ret




;@ def CopyUntilFDLong(src: de, dest: hl) -> (hl, de)
;@ path: gfx/tilemaps
;@ CopyRowsUntilFD with 128 instead of 8 bytes in the first row: in practice
;@ a straight copy until $FD.
;@ test: src = rand_ram(48); mem[src + rand(0, 40)] = 0xFD
;@ test: dest = rand_ram(128)
;@ sig: 890f6235
CopyUntilFDLong::
;> count = 0x80
;> while True:
;>     row = dest
;>     while True:
;>         if mem[src] == 0xFD:
;>             return row, src
;>         mem[dest] = mem[src]
;>         dest += 1
;>         src += 1
;>         count = (count - 1) & 0xFF
;>         if count == 0: break
;>     dest = (row + 32) & 0xFFFF
	ld b, $80
	jr jr_000_0d92

;@ def CopyRowsUntilFD(src: de, dest: hl) -> (hl, de)
;@ path: gfx/tilemaps
;@ Copies tiles from src into rows of the BG map at dest until a $FD.
;@ Meant as rows of 8, but the column counter is never reset: only the
;@ first row is 8 wide, later ones take up to 256 bytes. Returns the start
;@ of the row it stopped in and src at the $FD.
;@ test: src = rand_ram(48); mem[src + rand(0, 40)] = 0xFD
;@ test: dest = rand_ram(128)
;@ sig: f849b3c7
CopyRowsUntilFD::
;> count = 8
	ld b, $08

;>@rows while True:
;>     row = dest
jr_000_0d92:
	push hl

;>@cols     while True:
;>@stop         if mem[src] == 0xFD:
;>@ret             return row, src
jr_000_0d93:
	ld a, [de]
	cp $fd
	jr z, jr_000_0da6

;>         mem[dest] = mem[src]
;>         dest += 1
	ld [hli], a
;>         src += 1
	inc de
;>         count = u8(count - 1)
;>         if count == 0: break
	dec b
	jr nz, jr_000_0d93

;>     dest = u16(row + 32)                # next BG map row
	pop hl
	push de
	ld de, $0020
	add hl, de
	pop de
;=@rows
	jr jr_000_0d92

;=@ret
jr_000_0da6:
	pop hl
	ret


PauseText::
;@ asset: rows tiles=LoadGameTiles
;@ PAUSE, written over the Dr.MARIO title of the link game's panel while paused (PauseVersus).
TextPause::
	db $8f, $19, $0a, $1e, $1c, $0e, $8f, $fd

;@ def SpeedUp()
;@ path: game/score
;@ Every 10 capsules: one step faster, up to speed index 35.
;@ reads: hSpeedIndex
;@ writes: hSpeedIndex, hDropDelay, hDropDelayBase
;@ test: hSpeedIndex = rng.choice([rand(0, 34), 35])
;@ sig: 0cf6c107
SpeedUp::
;> if hSpeedIndex == 35:
;>     return
	ld hl, hSpeedIndex
	ld a, [hl]
	cp $23
	ret z

;> hSpeedIndex += 1
;> SetDropSpeed()                                  # falls through
	inc [hl]

;@ def SetDropSpeed()
;@ path: game/setup
;@ Looks up how many frames the capsule waits between steps down.
;@ reads: hSpeedIndex
;@ writes: hDropDelay, hDropDelayBase
;@ test: hSpeedIndex = rand(0, 35)
;@ sig: 1f34c7f5
SetDropSpeed::
;> hDropDelay = mem[DropSpeedTable + hSpeedIndex]
;> hDropDelayBase = hDropDelay
	ldh a, [hSpeedIndex]
	ld e, a
	ld hl, $0dc7
	ld d, $00
	add hl, de
	ld a, [hl]
	ldh [hDropDelay], a
	ldh [hDropDelayBase], a
	ret


DropSpeedTable::
	db $27, $25, $23, $21, $1f, $1d, $1b, $19, $17, $15, $14, $13, $12, $11, $10, $0f
	db $0e, $0d, $0c, $0b, $0a, $09, $09, $08, $08, $07, $07, $06, $06, $05, $05, $05
	db $05, $05, $05, $05


;@ def ShareCapsules()
;@ path: versus/setup
;@ Game state $16 (link game): the master sends its 128 capsule colours so
;@ both Game Boys deal the same capsules. Only the serial interrupt is on
;@ meanwhile. The master says $99 until the slave answers $66, sends the
;@ list, then $33 until the slave answers $77. Then both deal the first
;@ capsules and fill their bottles (state $03).
;@ reads: hSerialRole, hSerialDone, hSerialRx
;@ writes: hSerialTx, hSerialDone, hCapsuleListPos, hGameState, $D03A, wObjects, wLinkHold, wNextCapsule
;@ test: skip talks to the link cable
;@ sig: 4b20c2b0
ShareCapsules::
;> rIF = 0
	xor a
	ldh [rIF], a
;> rIE = 0x08                                      # serial only
	ld a, $08
	ldh [rIE], a
;> if hSerialRole == SERIAL_MASTER:
	ldh a, [hSerialRole]
	cp $30
	jr nz, jr_000_0e42

;>     while True:                                 # hello
;>         ShortDelay()
;>         ShortDelay()
jr_000_0df8:
	rst $08
	rst $08
;>         rSB = 0x99
	ld a, $99
	ldh [rSB], a
;>         rSC = 0x81                              # on our clock
	ld a, $81
	ldh [rSC], a
;>         hSerialDone = 0
	xor a
	ldh [hSerialDone], a

;>         while not hSerialDone:
;>             pass
jr_000_0e05:
	ldh a, [hSerialDone]
	and a
	jr z, jr_000_0e05

;>         if hSerialRx == 0x66:
;>             break
	ldh a, [hSerialRx]
	cp $66
	jr nz, jr_000_0df8

;>     for k in range(0x80):                       # the capsules
	ld hl, wCapsuleList
	ld b, $80

jr_000_0e15:
;>         ShortDelay()
;>         rSB = mem[wCapsuleList + k]
	ld a, [hli]
	rst $08
	ldh [rSB], a
;>         rSC = 0x81
	ld a, $81
	ldh [rSC], a
;>         hSerialDone = 0
	xor a
	ldh [hSerialDone], a

;>         while not hSerialDone:
;>             pass
jr_000_0e20:
	ldh a, [hSerialDone]
	and a
	jr z, jr_000_0e20

	inc b
	jr nz, jr_000_0e15

;>     while True:                                 # goodbye
;>         ShortDelay()
;>         ShortDelay()
jr_000_0e28:
	rst $08
	rst $08
;>         rSB = 0x33
	ld a, $33
	ldh [rSB], a
;>         rSC = 0x81
	ld a, $81
	ldh [rSC], a
;>         hSerialDone = 0
	xor a
	ldh [hSerialDone], a

;>         while not hSerialDone:
;>             pass
jr_000_0e35:
	ldh a, [hSerialDone]
	and a
	jr z, jr_000_0e35

;>         if hSerialRx == 0x77:
;>             break
	ldh a, [hSerialRx]
	cp $77
	jr nz, jr_000_0e28

	jr jr_000_0e8b

;> else:
;>     while True:                                 # answer the hello
jr_000_0e42:
;>         rSB = 0x66
;>         hSerialTx = 0x66
	ld a, $66
	ldh [rSB], a
	ldh [hSerialTx], a
;>         rSC = 0x80                              # on the master's clock
	ld a, $80
	ldh [rSC], a
;>         hSerialDone = 0
	xor a
	ldh [hSerialDone], a

;>         while not hSerialDone:
;>             pass
jr_000_0e4f:
	ldh a, [hSerialDone]
	and a
	jr z, jr_000_0e4f

;>         if hSerialRx == 0x99:
;>             break
	ldh a, [hSerialRx]
	cp $99
	jr nz, jr_000_0e42

;>     byte = 0x99
;>     for k in range(0x80):                       # receive the capsules
	ld b, $80
	ld hl, wCapsuleList

jr_000_0e5f:
;>         rSB = byte                              # (echoes the last byte)
	ldh [rSB], a
;>         rSC = 0x80
	ld a, $80
	ldh [rSC], a
;>         hSerialDone = 0
	xor a
	ldh [hSerialDone], a

;>         while not hSerialDone:
;>             pass
jr_000_0e68:
	ldh a, [hSerialDone]
	and a
	jr z, jr_000_0e68

;>         byte = hSerialRx
;>         mem[wCapsuleList + k] = byte
	ldh a, [hSerialRx]
	ld [hli], a
	inc b
	jr nz, jr_000_0e5f

;>     while True:                                 # answer the goodbye
jr_000_0e73:
;>         rSB = 0x77
;>         hSerialTx = 0x77
	ld a, $77
	ldh [rSB], a
	ldh [hSerialTx], a
;>         rSC = 0x80
	ld a, $80
	ldh [rSC], a
;>         hSerialDone = 0
	xor a
	ldh [hSerialDone], a

;>         while not hSerialDone:
;>             pass
jr_000_0e80:
	ldh a, [hSerialDone]
	and a
	jr z, jr_000_0e80

;>         if hSerialRx == 0x33:
;>             break
	ldh a, [hSerialRx]
	cp $33
	jr nz, jr_000_0e73

jr_000_0e8b:
;> rIF = 0
	xor a
	ldh [rIF], a
;> rIE = 0x0D                                      # VBlank, timer, serial
	ld a, $0d
	ldh [rIE], a
;> hCapsuleListPos = 0
;> hSerialDone = 0
;> wLinkHold = 0
	xor a
	ldh [hCapsuleListPos], a
	ldh [hSerialDone], a
	ld [wLinkHold], a
;> NextCapsule()
	call NextCapsule
;> NextCapsule()
	call NextCapsule
;> NextCapsule()
	call NextCapsule
;> mem[wObjects] = 0x80                              # the capsule waits; the next one shows
	ld a, $80
	ld [wObjects], a
;> mem[wObjects + 16] = 0
	xor a
	ld [wNextCapsule], a
;> DrawTwoObjects()
	call DrawTwoObjects
;> hGameState = 0x03                               # PlaceViruses
	ld a, $03
	ldh [hGameState], a
	ret


;@ def Play()
;@ path: game/play
;@ Game state $04: one frame of play. Unless paused: the demo's buttons, moving
;@ and dropping the capsule, the animations and counters, and the hand-over to
;@ state $05 once the level is cleared.
;@ reads: hPaused
;@ writes: wInPlay
;@ test: skip runs the whole game frame
;@ sig: 2b423cfe
Play::
;> wInPlay = 1
	ld a, $01
	ld [wInPlay], a
;> HandlePause()
	call HandlePause
;> if hPaused:
;>     return
	ldh a, [hPaused]
	and a
	ret nz

;> DemoCheckStart()
	call DemoCheckStart
;> DemoPlayback()
	call DemoPlayback
;> HandleCapsuleInput()
	call HandleCapsuleInput
;> UpdateFall()
	call UpdateFall
;> LockCapsule()
	call LockCapsule
;> UpdateMagnifier()
	call UpdateMagnifier
;> BlinkMagnifierDanger()
	call BlinkMagnifierDanger
;> UpdateBottle()
	call UpdateBottle
;> CheckLevelCleared()
	call CheckLevelCleared
;> DemoRestoreHeld()
	call DemoRestoreHeld
;> wInPlay = 1
	ld a, $01
	ld [wInPlay], a
	ret


;@ def BlinkMagnifierDanger()
;@ path: game/magnifier
;@ While hDanger is set, every 8 frames a warning sprite blinks: a sprite at
;@ ($3D, $8C) and tiles $3D/$3F/$3E or $06/$08/$FF in turn.
;@ reads: hDanger, hFrameCount
;@ test: hDanger = rng.choice([0, 1]); hFrameCount = rng.choice([0, 8, 5]); mem[0xD051] = rand(0, 1)
;@ sig: d50a54db
BlinkMagnifierDanger::
;> if not hDanger:
;>     return
	ldh a, [hDanger]
	and a
	ret z

;> if hFrameCount & 7:
;>     return
	ldh a, [hFrameCount]
	and $07
	ret nz

;> mem[wShadowOAM + 72] = 0x3D
;> mem[wShadowOAM + 73] = 0x8C
	ld hl, wShadowOAM + $48
	ld de, $0004
	ld a, $3d
	ld [hli], a
	ld a, $8c
	ld [hl], a
;> wDangerBlink ^= 1
;> tiles = (0x3D, 0x3F, 0x3E) if wDangerBlink else (0x06, 0x08, 0xFF)
	ld l, $42
	ld bc, wDangerBlink
	ld a, [bc]
	xor $01
	ld [bc], a
	jr nz, jr_000_0f10

;> for i, t in enumerate(tiles):
;>     mem[0xC042 + 4 * i] = t
	ld a, $06
	ld [hl], a
	add hl, de
	ld a, $08
	ld [hl], a
	add hl, de
	ld a, $ff
	ld [hl], a
	ret


jr_000_0f10:
	ld a, $3d
	ld [hl], a
	add hl, de
	ld a, $3f
	ld [hl], a
	add hl, de
	ld a, $3e
	ld [hl], a
	ret


;@ def DemoCheckStart()
;@ path: screens/demo
;@ During the demo: listens on the link cable, and pressing Start (or another
;@ Game Boy pressing Start, $30 / $37) ends the demo, leaving the caller too.
;@ reads: hDemoMode, hSerialRx, hJoyPressed
;@ test: skip talks to the link cable
;@ sig: 381cccdc
DemoCheckStart::
;> if not hDemoMode:
;>     return
	ldh a, [hDemoMode]
	and a
	ret z

;> ShortDelay()
	rst $08
;> if hSerialRx not in (0x30, 0x37):
	ldh a, [hSerialRx]
	cp $30
	jr z, jr_000_0f3f

	cp $37
	jr z, jr_000_0f3f

;>     rSB = 0                                     # listen, on the other side's clock
	xor a
	ldh [rSB], a
;>     rSC = 0x80
	ld a, $80
	ldh [rSC], a
;>     if not hJoyPressed & BTN_START:
;>         return
	ldh a, [hJoyPressed]
	bit 3, a
	ret z

;>     rSB = 0x37                                  # tell the other side
	ld a, $37
	ldh [rSB], a
;>     rSC = 0x81
	ld a, $81
	ldh [rSC], a

jr_000_0f3f:
;> pop_return_address()
	pop af
;> return EndDemo()
	jr EndDemo

;@ def DemoPlayback()
;@ path: screens/demo
;@ During the demo: plays back DemoInputs, a list of (buttons, frames) pairs
;@ ending in $FC, as if they came from the joypad; at the end the demo stops.
;@ reads: hDemoMode, wDemoHold, hDemoButtons, hJoyHeld, wDemoPtr
;@ writes: wDemoHold, hJoyPressed, hDemoButtons, hDemoSavedHeld, hJoyHeld, wDemoPtr
;@ test: hDemoMode = rng.choice([0, 1, 1]); wDemoHold = rng.choice([0, 0, 3]); hDemoButtons = rand(0, 255); hJoyHeld = rand(0, 255)
;@ test: mem[0xC4EB] = 0xC1; mem[0xC4EC] = rand(0, 0x80); mem[0xC100 + mem[0xC4EC]] = rng.choice([rand(0, 255), rand(0, 255), 0xFC])
;@ sig: 423b12fe
DemoPlayback::
;> if not hDemoMode:
;>     return
	ldh a, [hDemoMode]
	and a
	ret z

;> if wDemoHold:
	ld a, [wDemoHold]
	and a
	jr z, jr_000_0f52

;>     wDemoHold -= 1
	dec a
	ld [wDemoHold], a
;>@nopress     hJoyPressed = 0
;> else:
;>     ptr = mem[wDemoPtr] << 8 | mem[wDemoPtr + 1]
	jr jr_000_0f77

jr_000_0f52:
	ld a, [wDemoPtr]
	ld h, a
	ld a, [wDemoPtr + 1]
	ld l, a
;>     buttons = mem[ptr]
;>     if buttons == 0xFC:
;>         return EndDemo()
	ld a, [hli]
	cp $fc
	jr z, EndDemo

;>     hJoyPressed = (hDemoButtons ^ buttons) & buttons     # newly pressed
	ld b, a
	ldh a, [hDemoButtons]
	xor b
	and b
	ldh [hJoyPressed], a
;>     hDemoButtons = buttons
	ld a, b
	ldh [hDemoButtons], a
;>     wDemoHold = mem[ptr + 1]
	ld a, [hli]
	ld [wDemoHold], a
;>     mem[wDemoPtr] = (ptr + 2) >> 8
;>     mem[wDemoPtr + 1] = (ptr + 2) & 0xFF
	ld a, h
	ld [wDemoPtr], a
	ld a, l
	ld [wDemoPtr + 1], a
	jr jr_000_0f7a

;=@nopress
jr_000_0f77:
	xor a
	ldh [hJoyPressed], a

jr_000_0f7a:
;> hDemoSavedHeld = hJoyHeld
	ldh a, [hJoyHeld]
	ldh [hDemoSavedHeld], a
;> hJoyHeld = hDemoButtons
	ldh a, [hDemoButtons]
	ldh [hJoyHeld], a
	ret


	db $af, $e0, $ed, $18, $ef

;@ def EndDemo()
;@ path: screens/demo
;@ Stops the demo: back to the title screen (state $00) with the level,
;@ score and demo variables cleared.
;@ writes: hGameState, hVirusLevel, hVirusLevelBCD, wScore, hDemoButtons, hDemoSavedHeld, hCapsuleListPos, wInPlay, wDemoHold, $D00D, wDemoPtr, wVirusAnim
;@ sig: 7008e5e9
EndDemo::
;> hGameState = 0x00                               # TitleInit
	xor a
	ldh [hGameState], a
;> hVirusLevel = 0
;> hVirusLevelBCD = 0
	ldh [hVirusLevel], a
	ldh [hVirusLevelBCD], a
;> for k in range(4):
;>     mem[wScore + k] = 0
	ld [wScore], a
	ld [wScore + 1], a
	ld [wScore + 2], a
	ld [wScore + 3], a
;> hDemoButtons = 0
;> hDemoSavedHeld = 0
	ldh [hDemoButtons], a
	ldh [hDemoSavedHeld], a
;> mem[wDemoPtr] = 0
;> mem[wDemoPtr + 1] = 0
	ld [wDemoPtr], a
	ld [wDemoPtr + 1], a
;> hCapsuleListPos = 0
	ldh [hCapsuleListPos], a
;> wInPlay = 0
	ld [wInPlay], a
;> wVirusAnim = 0
	ld [wVirusAnim], a
;> wDemoHold = 0
	ld [wDemoHold], a
	ret


;@ def DemoRestoreHeld()
;@ path: screens/demo
;@ After the demo's frame: puts the real joypad state back.
;@ reads: hDemoMode, hDemoSavedHeld
;@ writes: hJoyHeld
;@ test: hDemoMode = rng.choice([0, 1])
;@ sig: 069fd93f
DemoRestoreHeld::
;> if not hDemoMode:
;>     return
	ldh a, [hDemoMode]
	and a
	ret z

;> hJoyHeld = hDemoSavedHeld
	ldh a, [hDemoSavedHeld]
	ldh [hJoyHeld], a
	ret


;@ def CheckLevelCleared()
;@ path: game/play
;@ Once the capsule has landed, goes on to state $05 (LevelCleared).
;@ reads: hLevelCleared
;@ writes: hLevelCleared, hGameState, hCapsuleState
;@ test: hLevelCleared = rng.choice([0, 1])
;@ sig: bd61d6c6
CheckLevelCleared::
;> if not hLevelCleared:
;>     return
	ldh a, [hLevelCleared]
	and a
	ret z

;> hCapsuleState = 0
;> hLevelCleared = 0
	xor a
	ldh [hCapsuleState], a
	ldh [hLevelCleared], a
;> hGameState = 0x05                               # LevelCleared
	ld a, $05
	ldh [hGameState], a
	ret


;@ def LevelCleared()
;@ path: game/end
;@ Game state $05: the last virus is gone. Hides the capsules and writes the
;@ result into the bottle (CLEAR / YOU WIN! and PUSH START!). One player goes
;@ up a level (up to 30) and on to state $10; in a link game the winner's
;@ win count goes up and state $12 follows.
;@ reads: hTwoPlayer
;@ writes: hCapsuleState, wInPlay, hTimer2, hGameState, $D00D, $D04B, $FFEF, wObjects, hRedrawRow, wNextCapsule, wShowResults, wVirusAnim
;@ test: skip draws into the bottle through helpers not translated yet
;@ sig: be029af5
LevelCleared::
;> hCapsuleState = 0
	xor a
	ldh [hCapsuleState], a
;> wInPlay = 0
	ld [wInPlay], a
;> wVirusAnim = 0
	ld [wVirusAnim], a
;> mem[wObjects] = 0x80                              # hide the capsule and the next one
;> mem[wObjects + 16] = 0x80
	ld a, $80
	ld [wObjects], a
	ld [wNextCapsule], a
;> DrawTwoObjects()
	call DrawTwoObjects
;> if hTwoPlayer:
;>     ClearBottleFromRow8()
	ldh a, [hTwoPlayer]
	and a
	jr z, jr_000_0fe6

	call ClearBottleFromRow8
	jr jr_000_0fe9

;> else:
;>     ClearBottleFromRow10()
jr_000_0fe6:
	call ClearBottleFromRow10

jr_000_0fe9:
;> DrawYouWinText()                                # (2-player only)
	call DrawYouWinText
;> DrawClearText()                                 # (1-player only)
	call DrawClearText
;> DrawPushStart()
	call DrawPushStart
;> hRedrawRow = 0x10
	ld a, $10
	ldh [hRedrawRow], a
;> if hTwoPlayer:
	ldh a, [hTwoPlayer]
	and a
	jr z, jr_000_1019

;>     wWins1 += 1                            # one more win
	ld hl, wWins1
	inc [hl]
;>     DrawWinCrowns1(0xD000)
	call DrawWinCrowns1
;>     DrawWinCrowns2(0xD001)
	ld hl, wWins2
	call DrawWinCrowns2
;>     wShowResults = 1
	ld a, $01
	ld [wShowResults], a
;>     DrawMarioThrowSprite()
	call DrawMarioThrowSprite
;>     hTimer2 = 0x10
	ld a, $10
	ldh [hTimer2], a
;>     hGameState = 0x12
;>@onep else:
;>@onep2     UpdateMagnifier()
;>@onep3     VirusLevelUp(0x30)                          # next level, up to 30
;>@onep4     hGameState = 0x10
	ld a, $12

jr_000_1016:
	ldh [hGameState], a
	ret


;=@onep
jr_000_1019:
;=@onep2
	call UpdateMagnifier
;=@onep3
	ld b, $30
	call VirusLevelUp
;=@onep4
	ld a, $10
	jr jr_000_1016

;@ def DrawMarioThrowSprite()
;@ path: gfx/objects
;@ Puts MarioThrowSprite into shadow OAM entries 8-18.
;@ sig: aab19c91
DrawMarioThrowSprite::
;> CopyUntilFD(MarioThrowSprite, 0xC020)
	ld hl, wShadowOAM + $20
	ld de, $102f
	call CopyUntilFD
	ret


;@ asset: oam tiles=LoadGameTiles|LoadGameTiles+CopyBytes(hl=Tiles_559E,de=$8800,bc=$520)
;@ Dr. Mario throwing the next capsule into the bottle (DrawMarioThrowSprite).
MarioThrowSprite::
	db $70, $28, $ff, $10, $78, $28, $1c, $10, $78, $30, $1d, $10, $68, $30, $10, $10
	db $70, $30, $1a, $10, $80, $30, $18, $10, $68, $38, $11, $10, $70, $38, $1b, $10
	db $78, $38, $1e, $10, $80, $38, $19, $10, $78, $40, $1f, $10, $fd

;@ def DrawWinCrowns1(wins: hl)
;@ path: versus/results
;@ Shows the left player's wins as markers from WinCrowns1 (two sprites each)
;@ in shadow OAM from entry 30 on.
;@ test: wins = rand_ram(1); mem[wins] = rand(0, 3)
;@ sig: d782f958
DrawWinCrowns1::
;> for n in range(mem[wins], 0, -1):
;>     for k in range(8):
;>         mem[0xC070 + 8 * n + k] = mem[WinCrowns1 - 8 + 8 * n + k]
	ld a, [hl]
	and a
	ret z

	ld c, a

jr_000_1060:
	ld b, c
	ld hl, wShadowOAM + $70
	ld de, $0008

jr_000_1067:
	add hl, de
	dec b
	jr nz, jr_000_1067

	push hl
	ld hl, $10c7
	ld b, c

jr_000_1070:
	add hl, de
	dec b
	jr nz, jr_000_1070

	pop de
	ld b, $08

jr_000_1077:
	ld a, [hli]
	ld [de], a
	inc de
	dec b
	jr nz, jr_000_1077

	dec c
	jr nz, jr_000_1060

	ret


;@ def DrawWinCrowns2(wins: hl)
;@ path: versus/results
;@ The right player's wins, from WinCrowns2 into shadow OAM from entry 0 on.
;@ test: wins = rand_ram(1); mem[wins] = rand(0, 3)
;@ sig: c731b6b5
DrawWinCrowns2::
;> for n in range(mem[wins], 0, -1):
;>     for k in range(8):
;>         mem[0xBFF8 + 8 * n + k] = mem[WinCrowns2 - 8 + 8 * n + k]
	ld a, [hl]
	and a
	ret z

	ld c, a

jr_000_1085:
	ld b, c
	ld hl, $bff8
	ld de, $0008

jr_000_108c:
	add hl, de
	dec b
	jr nz, jr_000_108c

	push hl
	ld hl, $10df
	ld b, c

jr_000_1095:
	add hl, de
	dec b
	jr nz, jr_000_1095

	pop de
	ld b, $08

jr_000_109c:
	ld a, [hli]
	ld [de], a
	inc de
	dec b
	jr nz, jr_000_109c

	dec c
	jr nz, jr_000_1085

	ret


;@ def HideWinCrowns()
;@ path: versus/results
;@ Blanks the crown sprites (shadow OAM entries 0-5 and 30-35).
;@ sig: ec4c1ace
HideWinCrowns::
;> BlankTiles6(0xC002, 4)
	ld hl, wShadowOAM + $02
	ld de, $0004
	call BlankTiles6
;> BlankTiles6(0xC07A, 4)
	ld l, $7a
	call BlankTiles6
	ret


;@ def BlankTiles6(tiles: hl, step: de) -> hl
;@ path: versus/results
;@ test: tiles = 0xC002 + 4 * rand(0, 30); step = 4
;@ sig: fe4b56fe
BlankTiles6::
;> for i in range(6):
;>     mem[tiles + step * i] = 0xFF
;> return tiles + 6 * step
	ld b, $06
	ld a, $ff

jr_000_10b9:
	ld [hl], a
	add hl, de
	dec b
	jr nz, jr_000_10b9

	ret


;@ def HideVirusCounts2P()
;@ path: versus/play
;@ Blanks the eight digit sprites of the two virus counts.
;@ sig: 1ceca186
HideVirusCounts2P::
;> for i in range(8):
;>     mem[0xC052 + 4 * i] = 0xFF
	ld b, $08
	ld hl, wShadowOAM + $52
	ld de, $0004
	ld a, $ff

jr_000_10c9:
	ld [hl], a
	add hl, de
	dec b
	jr nz, jr_000_10c9

	ret


;@ asset: oam length=24 tiles=LoadGameTiles
;@ Win markers on the left side, two sprites per win (DrawWinCrowns1).
WinCrowns1::
	db $8c, $71, $8b, $00, $8c, $79, $8b, $20, $80, $71, $8b, $00, $80, $79, $8b, $20
	db $74, $71, $8b, $00, $74, $79, $8b, $20

;@ asset: oam length=24 tiles=LoadGameTiles
;@ Win markers on the right side (DrawWinCrowns2).
WinCrowns2::
	db $8c, $87, $8b, $00, $8c, $8f, $8b, $20
	db $80, $87, $8b, $00, $80, $8f, $8b, $20, $74, $87, $8b, $00, $74, $8f, $8b, $20
;@ asset: rows tiles=LoadGameTiles
;@ MISS, written into the bottle (DrawMissText).
TextMiss::
	db $16, $12, $1c, $1c, $fd

;@ asset: rows tiles=LoadGameTiles
;@ CLEAR, written into the bottle when a level is done (DrawClearText).
TextClear::
	db $0c, $15, $0e, $0a, $1b, $fd

;@ asset: rows tiles=LoadGameTiles
;@ YOU / WIN! for the winner of a link round (DrawYouWinText).
TextYouWin::
	db $22, $18, $1e, $fe, $20
	db $12, $17, $25, $fd

;@ asset: rows tiles=LoadGameTiles
;@ YOU / LOST for the loser of a link round (DrawYouLostText).
TextYouLost::
	db $22, $18, $1e, $fe, $15, $18, $1c, $1d, $fd

;@ asset: rows tiles=LoadGameTiles
;@ PUSH, above START! (DrawPushStart).
TextPush::
	db $19, $1e, $1c
	db $11, $fd

;@ asset: rows tiles=LoadGameTiles
;@ START! (DrawPushStart).
TextStart::
	db $1c, $1d, $0a, $1b, $1d, $25, $fd

;@ asset: rows tiles=LoadGameTiles
;@ PLEASE, above WAIT: the link slave waits for the master (DrawPushStart).
TextPlease::
	db $19, $15, $0e, $0a, $1c, $0e, $fd
;@ asset: rows tiles=LoadGameTiles
;@ WAIT (DrawPushStart).
TextWait::
	db $20, $0a, $12, $1d, $fd

;@ asset: rows tiles=LoadGameTiles
;@ DRAW, when both link players finish together (DrawDrawText).
TextDraw::
	db $0d, $1b, $0a, $20, $fd


;@ def RoundDraw()
;@ path: versus/results
;@ Game state $06: both sides finished at once. Writes DRAW (with the
;@ crossed-out box if this side's bottle was full) and PUSH START!, shows the
;@ crowns and goes to state $12.
;@ reads: hRoundResult
;@ writes: hCapsuleState, wInPlay, hRedrawRow, hTimer2, hGameState, $D00D, $D04B, wObjects, wNextCapsule, wShowResults, wVirusAnim
;@ test: skip calls helpers not translated yet
;@ sig: 66183018
RoundDraw::
;> hCapsuleState = 0
	xor a
	ldh [hCapsuleState], a
;> wInPlay = 0
	ld [wInPlay], a
;> wVirusAnim = 0
	ld [wVirusAnim], a
;> mem[wObjects] = 0x80
;> mem[wObjects + 16] = 0x80
	ld a, $80
	ld [wObjects], a
	ld [wNextCapsule], a
;> DrawTwoObjects()
	call DrawTwoObjects
;> DrawWinCrowns1(0xD000)
	ld hl, wWins1
	call DrawWinCrowns1
;> DrawWinCrowns2(0xD001)
	ld hl, wWins2
	call DrawWinCrowns2
;> if hRoundResult != 0xFD:
	ldh a, [hRoundResult]
	cp $fd
	jr z, jr_000_1164

;>     ClearBottleFromRow8()
;>@full else:                                         # this side's bottle filled up
;>@full2     ClearBottleFromRow5()
;>@full3     DrawLoserMark()
	call ClearBottleFromRow8
	jr jr_000_116a

;=@full2
jr_000_1164:
	call ClearBottleFromRow5
;=@full3
	call DrawLoserMark

jr_000_116a:
;> DrawDrawText()
	call DrawDrawText
;> DrawPushStart()
	call DrawPushStart
;> wShowResults = 1
	ld a, $01
	ld [wShowResults], a
;> MarioBehindBG()
	call MarioBehindBG
;> hRedrawRow = 0x10
	ld a, $10
	ldh [hRedrawRow], a
;> hTimer2 = 0x10
	ld a, $10
	ldh [hTimer2], a
;> hGameState = 0x12
	ld a, $12
	ldh [hGameState], a
	ret


;@ def NextCapsule()
;@ path: game/capsules
;@ The next capsule becomes the current one (object 0, placed at the top of
;@ the bottle) and a new next capsule is dealt: from wCapsuleList in link and
;@ demo games, so both sides get the same ones, otherwise rolled like
;@ RandomCapsule but against the capsule just handed over.
;@ reads: hDemoMode, hTwoPlayer, hCapsuleListPos, hNextRandom, hDropDelayBase, wObjects, wNextCapsule
;@ writes: hCapsuleListPos, hNextRandom, hDropDelay, wObjects, wNextCapsule
;@ test: hDemoMode = rng.choice([0, 0, 1]); hTwoPlayer = rng.choice([0, 0, 1]); hCapsuleListPos = rand(0, 0x7F)
;@ test: rDIV = rand(0, 255); hNextRandom = 2 * rand(0, 11); mem[0xC213] = 2 * rand(0, 11)
;@ test: for k in range(0x80): mem[0xC300 + k] = 2 * rand(0, 11)
;@ test: mem[0xC210] = 0; mem[0xC211] = 0x3B; mem[0xC212] = 0x6A
;@ test: for k in range(4, 16): mem[0xC210 + k] = 0
;@ sig: 310644cf
NextCapsule::
;> mem[wObjects] = 0                                 # current capsule: visible,
;> mem[wObjects + 1] = 0x20                              # at the bottle's mouth,
;> mem[wObjects + 2] = 0x30
;> mem[wObjects + 3] = mem[wObjects + 19]                       # with the next capsule's colours
	ld hl, wObjects
	ld [hl], $00
	inc l
	ld [hl], $20
	inc l
	ld [hl], $30
	inc l
	ld a, [wNextCapsule + 3]
	ld [hl], a
;> last = mem[wObjects + 19] & 0xFC
	and $fc
	ld c, a
;> if hDemoMode or hTwoPlayer:
	ldh a, [hDemoMode]
	and a
	jr nz, jr_000_11a2

	ldh a, [hTwoPlayer]
	and a
	jr z, jr_000_11b5

;>     new = mem[wCapsuleList + hCapsuleListPos]
jr_000_11a2:
	ld h, $c3
	ldh a, [hCapsuleListPos]
	ld l, a
	ld e, [hl]
;>     hCapsuleListPos = (hCapsuleListPos + 1) % 0x80
	inc hl
	ld a, l
	cp $80
	jr nz, jr_000_11b0

	ld l, $00

jr_000_11b0:
	ld a, l
	ldh [hCapsuleListPos], a
	jr jr_000_11cb

;> else:
;>     for tries in range(3, 0, -1):
;>         roll = Random()
;>         new = hNextRandom
;>         if tries == 1 or ((new | roll | last) & 0xFC) != last:
;>             break
jr_000_11b5:
	ld h, $03

jr_000_11b7:
	call Random
	ld d, a
	ldh a, [hNextRandom]
	ld e, a
	dec h
	jr z, jr_000_11c8

	or d
	or c
	and $fc
	cp c
	jr z, jr_000_11b7

;>     hNextRandom = roll
jr_000_11c8:
	ld a, d
	ldh [hNextRandom], a
;> mem[wObjects + 19] = new                               # next capsule, beside Dr. Mario
;> mem[wObjects + 17] = 0x3B
;> mem[wObjects + 18] = 0x6A
jr_000_11cb:
	ld a, e
	ld [wNextCapsule + 3], a
	ld a, $3b
	ld [wNextCapsule + 1], a
	ld a, $6a
	ld [wNextCapsule + 2], a
;> DrawNextCapsule()
	call DrawNextCapsule
;> hDropDelay = hDropDelayBase
	ldh a, [hDropDelayBase]
	ldh [hDropDelay], a
	ret


;@ def RandomCapsule() -> a
;@ path: game/capsules
;@ Deals a random capsule. It rolls up to three times, re-rolling while the
;@ new roll, the one rolled ahead and the last capsule share no bits beyond
;@ the last capsule's; it returns the capsule rolled ahead last time and
;@ keeps the new roll for next time.
;@ reads: hPrevCapsule, hNextRandom
;@ writes: hPrevCapsule, hNextRandom
;@ test: rDIV = rand(0, 255); hPrevCapsule = 2 * rand(0, 11); hNextRandom = 2 * rand(0, 11)
;@ sig: 9fc4b766
RandomCapsule::
;> last = hPrevCapsule & 0xFC
	push hl
	push bc
	ldh a, [hPrevCapsule]
	and $fc
	ld c, a
;> for tries in range(3, 0, -1):
;>     roll = Random()
;>     ahead = hNextRandom
;>     if tries == 1 or ((ahead | roll | last) & 0xFC) != last:
;>         break
	ld h, $03

jr_000_11ea:
	call Random
	ld d, a
	ldh a, [hNextRandom]
	ld e, a
	dec h
	jr z, jr_000_11fb

	or d
	or c
	and $fc
	cp c
	jr z, jr_000_11ea

;> hNextRandom = roll
jr_000_11fb:
	ld a, d
	ldh [hNextRandom], a
;> hPrevCapsule = ahead
;> return ahead
	ld a, e
	ldh [hPrevCapsule], a
	pop bc
	pop hl
	ret


;@ def Random() -> a
;@ path: game/capsules
;@ A random capsule colour pair from the divider register: counts DIV - 1
;@ steps through 0, 2, 4 ... $16 (twelve values) and returns where it stops.
;@ test: rDIV = rand(0, 255)
;@ sig: 47af657b
Random::
;> b = rDIV
	ldh a, [rDIV]
	ld b, a

;> return 2 * (((b - 1) & 0xFF) % 12)             # count up in steps of 2, wrapping at $18
jr_000_1207:
	xor a

jr_000_1208:
	dec b
	ret z

	inc a
	inc a
	cp $18
	jr z, jr_000_1207

	jr jr_000_1208

	db $c9

;=@UpdateFall.fastgate
jr_000_1213:
	ldh a, [hTimer2]
	and a
	jr nz, jr_000_123f

	ldh a, [hCapsuleState]
	and a
	jr nz, jr_000_123f

;=@UpdateFall.fastset
	ld a, $03
	ldh [hTimer2], a
	jr jr_000_1251

;@ def UpdateFall()
;@ path: game/play
;@ Moves the capsule down: a row every hDropDelay frames, or every 3 frames
;@ while only Down is held. When it cannot go further it has landed. A new
;@ capsule that has no room at the mouth of the bottle ends the game: it is
;@ locked where it is and the game over state takes over, leaving Play
;@ straight away.
;@ reads: hJoyHeld, hDropDelay, hDropDelayBase, hCapsuleState, hTimer2, hTwoPlayer
;@ writes: hDropDelay, hTimer2, hTemp, hCapsuleState, wSFXRequest, $D00E, $FFF4, hGameState, hSerialTx, hToppedOut, wWaveSFXRequest, hRoundResult, wGarbageHeaderSent
;@ test: mem[0xC200] = rng.choice([0, 0, 0x80]); mem[0xC201] = 0x28 + 8 * rand(0, 13); mem[0xC202] = 0x18 + 8 * rand(0, 7); mem[0xC203] = rand(0, 0x17)
;@ test: for k in range(4, 16): mem[0xC200 + k] = 0
;@ test: hJoyHeld = rng.choice([0, BTN_DOWN, BTN_DOWN | BTN_LEFT]); hDropDelay = rng.choice([0, 0, 3]); hDropDelayBase = rand(5, 0x27)
;@ test: hCapsuleState = rng.choice([0, 0, 2]); hTimer2 = rng.choice([0, 0, 2])
;@ test: for k in range(0x80): mem[0xC800 + k] = rng.choice([0xFF, 0xFF, 0xFF, 0xE0])
;@ test: hObjHidden = 0
;@ sig: 18f597b3
UpdateFall::
;> if mem[wObjects] == 0x80:                        # no capsule
;>     return
	ld hl, wObjects
	ld a, [hli]
	cp $80
	ret z

;> if mem[wObjects + 1] == 0x20:                         # just appeared at the mouth
;>@sdraw     DrawObject0()
;>@shit     if CheckCapsuleCollision():                 # no room: the bottle is full
;>@top         hToppedOut = 1
;>@top2p         if hTwoPlayer:
;>@tx             hSerialTx = 0xFD                        # tell the other side
;>@tx2             hRoundResult = 0xFD
;>@d00e             wGarbageHeaderSent = 0
;>@landed         hCapsuleState = 1
;>@lock         LockCapsule()
;>@silence         InitSound()
;>@over         hGameState = 0x17 if hTwoPlayer else 0x0F
;>@wave         wWaveSFXRequest = 2
;>@pop         pop_return_address()                        # leave Play too
;>@ret         return
	ld a, [hl]
	cp $20
	jr z, jr_000_1270

;> if hJoyHeld & (BTN_DOWN | BTN_LEFT | BTN_RIGHT) == BTN_DOWN:    # only Down: fast
;>@fastgate     if hTimer2 or hCapsuleState:
;>@fastdraw         DrawObject0()                           # (jumps to the DrawObject0 below)
;>@fastret         return
;>@fastset     hTimer2 = 3
jr_000_122f:
	ldh a, [hJoyHeld]
	and $b0
	cp $80
	jr z, jr_000_1213

;> elif hDropDelay:
	ldh a, [hDropDelay]
	and a
	jr z, jr_000_1243

;>     hDropDelay -= 1
	dec a
	ldh [hDropDelay], a

jr_000_123f:
;>     DrawObject0()
	call DrawObject0
;>     return
	ret


jr_000_1243:
;> else:
;>     if hCapsuleState == 2:
;>         return
	ldh a, [hCapsuleState]
	cp $02
	ret z

;>     hDropDelay = hDropDelayBase
	ldh a, [hDropDelayBase]
	ldh [hDropDelay], a
;>     wSFXRequest = 7
	ld a, $07
	ld [wSFXRequest], a

jr_000_1251:
;> old_y = mem[wObjects + 1]                             # one row down
;> hTemp = old_y
	ld hl, wObjects + 1
	ld a, [hl]
	ldh [hTemp], a
;> mem[wObjects + 1] = (old_y + 8) & 0xFF
	add $08
	ld [hl], a
;> DrawObject0()
	call DrawObject0
;> if CheckCapsuleCollision():                     # landed: back up and stop
	call CheckCapsuleCollision
	and a
	ret z

;>     mem[wObjects + 1] = old_y
	ldh a, [hTemp]
	ld hl, wObjects + 1
	ld [hl], a
;>     DrawObject0()
	call DrawObject0
;>     hCapsuleState = 1
	ld a, $01
	ldh [hCapsuleState], a
	ret


;=@sdraw
jr_000_1270:
	call DrawObject0
;=@shit
	call CheckCapsuleCollision
	and a
	jr nz, jr_000_127b

	jr jr_000_122f

jr_000_127b:
;=@top
	ld a, $01
	ldh [hToppedOut], a
;=@top2p
	ldh a, [hTwoPlayer]
	and a
	jr z, jr_000_128e

;=@tx
	ld a, $fd
	ldh [hSerialTx], a
;=@tx2
	ldh [hRoundResult], a
;=@d00e
	xor a
	ld [wGarbageHeaderSent], a

jr_000_128e:
;=@landed
	ld a, $01
	ldh [hCapsuleState], a
;=@lock
	call LockCapsule
;=@silence
	call InitSound
;=@over
	ld b, $0f
	ldh a, [hTwoPlayer]
	and a
	jr z, jr_000_12a1

	ld b, $17

jr_000_12a1:
	ld a, b
	ldh [hGameState], a
;=@wave
	ld a, $02
	ld [wWaveSFXRequest], a
;=@pop
	pop af
;=@ret
	ret


;@ def RoundEndSync()
;@ path: versus/play
;@ Game state $17: a side has finished its round. It shows the panel and
;@ keeps sending its result (hRoundResult) until the other side's arrives:
;@ the same result is a draw (state $06), otherwise a full bottle loses
;@ (state $0F) and cleared viruses win (state $05).
;@ reads: hRoundResult, hSerialRx
;@ writes: wInPlay, rLCDC, hSerialTx, hGameState, $D00D, wVirusAnim
;@ test: hRoundResult = rng.choice([0xFD, 0xF8]); hSerialRx = rng.choice([0xFD, 0xF8, 0x30])
;@ sig: 54d4c4c0
RoundEndSync::
;> wInPlay = 0
	xor a
	ld [wInPlay], a
;> wVirusAnim = 0
	ld [wVirusAnim], a
;> rLCDC = 0xE3                                    # with the window: the side panel
	ld a, $e3
	ldh [rLCDC], a
;> HideVirusCounts2P()
	call HideVirusCounts2P
;> HideWinMarkers()
	call HideWinMarkers
;> hSerialTx = hRoundResult
	ldh a, [hRoundResult]
	ldh [hSerialTx], a
;> if hSerialRx not in (0xFD, 0xF8):               # nothing from the other side yet
;>     return
	ldh a, [hSerialRx]
	cp $fd
	jr z, jr_000_12c9

	cp $f8
	ret nz

jr_000_12c9:
;> if hSerialRx == hRoundResult:
;>@draw     hGameState = 0x06                           # RoundDraw
;>@lost elif hRoundResult == 0xFD:
;>@lost2     hGameState = 0x0F                           # GameOver
;>@won else:
;>@won2     hGameState = 0x05                           # LevelCleared
	ld hl, hRoundResult
	ldh a, [hSerialRx]
	cp [hl]
	jr z, jr_000_12e0

;=@lost
	ld a, [hl]
	cp $fd
	jr z, jr_000_12db

;=@won2
	ld a, $05
	ldh [hGameState], a
	ret


;=@lost2
jr_000_12db:
	ld a, $0f
	ldh [hGameState], a
	ret


;=@draw
jr_000_12e0:
	ld a, $06
	ldh [hGameState], a
	ret


;@ def HideWinMarkers()
;@ path: versus/play
;@ Blanks the six win marker sprites (shadow OAM entries 32-37).
;@ sig: 3ba90e89
HideWinMarkers::
;> for i in range(6):
;>     mem[0xC082 + 4 * i] = 0xFF
	ld hl, wShadowOAM + $82
	ld b, $06
	ld de, $0004
	ld a, $ff

jr_000_12ef:
	ld [hl], a
	add hl, de
	dec b
	jr nz, jr_000_12ef

	ret


;@ def GameOver()
;@ path: game/end
;@ Game state $0F: the bottle is full. Writes MISS (1P) or YOU / LOST and the
;@ crossed-out box (2P) and PUSH START! into the bottle; one player gets the
;@ game over jingle and state $10, a link loser hands the round to the other
;@ side (its win count goes up) and goes to state $12.
;@ reads: hTwoPlayer
;@ writes: hCapsuleState, wInPlay, hTimer2, hGameState, wMusicRequest, $D00D, $D04B, $FFEF, wObjects, hRedrawRow, wNextCapsule, wShowResults, wVirusAnim
;@ test: skip calls helpers not translated yet
;@ sig: 1597853a
GameOver::
;> hCapsuleState = 0
	xor a
	ldh [hCapsuleState], a
;> wInPlay = 0
	ld [wInPlay], a
;> wVirusAnim = 0
	ld [wVirusAnim], a
;> mem[wObjects] = 0x80
;> mem[wObjects + 16] = 0x80
	ld a, $80
	ld [wObjects], a
	ld [wNextCapsule], a
;> DrawTwoObjects()
	call DrawTwoObjects
;> if hTwoPlayer:
;>     ClearBottleFromRow5()
	ldh a, [hTwoPlayer]
	and a
	jr z, jr_000_1313

	call ClearBottleFromRow5
	jr jr_000_1316

;> else:
;>     ClearBottleFromRow10()
jr_000_1313:
	call ClearBottleFromRow10

jr_000_1316:
;> DrawYouLostText()                               # (2-player only)
	call DrawYouLostText
;> DrawMissText()                                  # (1-player only)
	call DrawMissText
;> DrawPushStart()
	call DrawPushStart
;> if hTwoPlayer:
;>     DrawLoserMark()
	ldh a, [hTwoPlayer]
	and a
	jr z, jr_000_1329

	call DrawLoserMark
	jr jr_000_132c

;> else:
;>     LaughMagnifierViruses()
jr_000_1329:
	call LaughMagnifierViruses

jr_000_132c:
;> hRedrawRow = 0x10
	ld a, $10
	ldh [hRedrawRow], a
;> if hTwoPlayer:
	ld b, $10
	ldh a, [hTwoPlayer]
	and a
	jr z, jr_000_1356

;>     wWins2 += 1                            # a win for the other side
	ld hl, wWins2
	inc [hl]
;>     DrawWinCrowns2(0xD001)
	call DrawWinCrowns2
;>     DrawWinCrowns1(0xD000)
	ld hl, wWins1
	call DrawWinCrowns1
;>     wShowResults = 1
	ld a, $01
	ld [wShowResults], a
;>     MarioBehindBG()
	call MarioBehindBG
;>     hTimer2 = 0x10
	ld a, $10
	ldh [hTimer2], a
;>     hGameState = 0x12
;>@one else:
;>@one2     wMusicRequest = 8                           # game over jingle
;>@one3     hGameState = 0x10                           # LevelEndWait
	ld b, $12

jr_000_1352:
	ld a, b
	ldh [hGameState], a
	ret


;=@one
jr_000_1356:
;=@one2
	ld a, $08
	ld [wMusicRequest], a
;=@one3
	jr jr_000_1352

;@ def MarioBehindBG()
;@ path: versus/results
;@ Puts the 11 sprites from shadow OAM entry 8 (Dr. Mario) behind the background.
;@ sig: cc113bf9
MarioBehindBG::
;> for i in range(11):
;>     mem[0xC023 + 4 * i] |= 0x80
	ld hl, wShadowOAM + $23
	ld de, $0004
	ld b, $0b

jr_000_1365:
	set 7, [hl]
	add hl, de
	dec b
	jr nz, jr_000_1365

	ret


;@ def DrawLoserMark()
;@ path: versus/results
;@ Draws LoserMark over the bottle.
;@ sig: 51c552c4
DrawLoserMark::
;> CopyUntilFDLong(LoserMark, 0xC83A)
	ld hl, wBottle + $3A
	ld de, $1376
	call CopyUntilFDLong
	ret


;@ asset: rows width=8 tiles=LoadGameTiles
;@ A crossed-out box drawn over the loser's bottle in a link game (DrawLoserMark):
;@ rows of 8 bottle cells starting at column 2, $FE = blank.
LoserMark::
	db $fc, $fc, $fc, $fc, $fe, $fe, $fe, $fe, $fc, $ef, $ee, $fc, $fe, $fe, $fe, $fe
	db $fc, $ee, $ef, $fc, $fe, $fe, $fe, $fe, $fc, $fc, $fc, $fc, $fd

;@ def LaughPanelVirus()
;@ path: versus/results
;@ Puts PanelVirusSprite at shadow OAM entry 26 and lets virus 2 laugh:
;@ every 8 frames its tiles switch between normal and +$0A.
;@ reads: hFrameCount
;@ test: hFrameCount = rng.choice([0, 8, 3]); mem[0xD01F] = rand(0, 1); hTwoPlayer = 1
;@ sig: 45cfaedc
LaughPanelVirus::
;> CopyUntilFF(PanelVirusSprite, 0xC068)
	ld hl, wShadowOAM + $68
	ld de, $13b3
	rst $18
;> if hFrameCount & 7:
;>     return
	ldh a, [hFrameCount]
	and $07
	ret nz

;> wLaughFrame ^= 1
;> if wLaughFrame:
	ld hl, wLaughFrame
	ld a, [hl]
	xor $01
	ld [hl], a
	jr z, jr_000_13ac

;>     DrawMagnifierVirus2()
	call DrawMagnifierVirus2
	ret


jr_000_13ac:
;> else:
;>     AddToTiles4(0xC05A)
	ld hl, wShadowOAM + $5A
	call AddToTiles4
	ret


;@ asset: oam end=$FF tiles=LoadGameTiles|LoadGameTiles+CopyBytes(hl=Tiles_559E,de=$8800,bc=$520)
;@ Copied to OAM entry 26 by LaughPanelVirus.
PanelVirusSprite::
	db $70, $34, $8c, $00, $ff

;@ def LevelEndWait()
;@ path: game/end
;@ Game state $10 (1 player): after a cleared level plays the clear jingle
;@ (song 4) and sound, after a full bottle keeps animating; then waits for
;@ Start. Cleared: on to state $11. Full bottle: back to the options screen,
;@ with the virus level brought back to 20 if it had gone past.
;@ reads: hToppedOut, hJoyPressed, hVirusLevelBCD, $FFEF, hRedrawRow
;@ writes: wMusicRequest, hGameState, hToppedOut, hCapsuleState, rLCDC, hVirusLevel, hVirusLevelBCD, $D01F, $D042, $FFEF, hRedrawRow, wJinglePlayed, wLaughFrame
;@ test: skip calls helpers not translated yet
;@ sig: f3d094e3
LevelEndWait::
;> if not hToppedOut:
	ldh a, [hToppedOut]
	and a
	jr nz, jr_000_13d2

;>     UpdateMagnifier()
	call UpdateMagnifier
;>     PlayClearSFX()
	call PlayClearSFX
;>     if not wJinglePlayed:                         # once
	ld hl, wJinglePlayed
	ld a, [hl]
	and a
	jr nz, jr_000_13d0

;>         wJinglePlayed += 1
	inc [hl]
;>         wMusicRequest = 4                       # level clear jingle
	ld a, $04
	ld [wMusicRequest], a

jr_000_13d0:
	jr jr_000_13d5

;> else:
;>     LaughMagnifierViruses()
jr_000_13d2:
	call LaughMagnifierViruses

jr_000_13d5:
;> UpdateBottle()
	call UpdateBottle
;> if hRedrawRow:
;>     return
	ldh a, [hRedrawRow]
	and a
	ret nz

;> if hToppedOut:
;>     DrawMarioLost()
	ldh a, [hToppedOut]
	and a
	call nz, DrawMarioLost
;> if not hJoyPressed & BTN_START:
;>     return
	ldh a, [hJoyPressed]
	bit 3, a
	ret z

;> ClearBottleRows()
	call ClearBottleRows
;> if not hToppedOut:
	ldh a, [hToppedOut]
	and a
	jr nz, jr_000_13fc

;>     hRedrawRow = 0x10
	ld a, $10
	ldh [hRedrawRow], a
;>     hGameState += 1                             # NextLevelOrCutscene
	ld hl, hGameState
	inc [hl]
;>     wJinglePlayed = 0
;>@fullret     return
;>@full wLaughFrame = 0                                # full bottle: back to the options
;>@full2 hToppedOut = 0
;>@full3 hCapsuleState = 0
;>@full4 ClearShadowOAMFrom6()
;>@full5 rLCDC = 0x81
;>@full6 hGameState = 0x0B                            # OptionsInit1P
;>@full7 if hVirusLevelBCD >= 0x21:
;>@full8     hVirusLevel = 20
;>@full9     hVirusLevelBCD = 0x20
	xor a
	ld [wJinglePlayed], a
;=@fullret
	ret


;=@full
jr_000_13fc:
	xor a
	ld [wLaughFrame], a
;=@full2
	ldh [hToppedOut], a
;=@full3
	ldh [hCapsuleState], a
;=@full4
	call ClearShadowOAMFrom6
;=@full5
	ld a, $81
	ldh [rLCDC], a
;=@full6
	ld a, $0b
	ldh [hGameState], a
;=@full7
	ldh a, [hVirusLevelBCD]
	cp $21
	ret c

;=@full8
	ld a, $14
	ldh [hVirusLevel], a
;=@full9
	ld a, $20
	ldh [hVirusLevelBCD], a
	ret


;@ def PlayClearSFX()
;@ path: game/end
;@ Once the clear jingle has finished, plays sound effect $0C (once).
;@ reads: wCurrentSong, $D050, wClearSFXDone
;@ writes: wSFXRequest, $D050, wClearSFXDone
;@ test: wCurrentSong = rng.choice([0, 4]); mem[0xD050] = rng.choice([0, 1])
;@ sig: 938f22d6
PlayClearSFX::
;> if wCurrentSong:
;>     return
	ld a, [wCurrentSong]
	and a
	ret nz

;> if wClearSFXDone:
;>     return
	ld a, [wClearSFXDone]
	and a
	ret nz

;> wSFXRequest = 0x0C
	ld a, $0c
	ld [wSFXRequest], a
;> wClearSFXDone = 1
	ld a, $01
	ld [wClearSFXDone], a
	ret


;@ def NextLevelOrCutscene()
;@ path: game/end
;@ Game state $11: after a cleared level, either the next level (state $09)
;@ or an underwater cutscene with song 9. On HI speed there is one after
;@ levels 5, 10 and 15; clearing level 20 ($D052 set) gives each speed its
;@ ending: LOW $1B, MED $07, HI $1A.
;@ reads: hSpeed, hVirusLevelBCD, $D052, $FFEF, hRedrawRow, wPastLevel20
;@ writes: hGameState, wMusicRequest, hToppedOut, hCapsuleState, rLCDC, $D01F, $D050, $D052, hCutscenePhase, wClearSFXDone, wLaughFrame, wPastLevel20
;@ test: skip calls helpers not translated yet
;@ sig: 8ff35814
NextLevelOrCutscene::
;> UpdateBottle()
	call UpdateBottle
;> if hRedrawRow:
;>     return
	ldh a, [hRedrawRow]
	and a
	ret nz

;> state = 0x09                                    # LevelInit: the next level
;> if hSpeed == 4:                                 # LOW
;>@low     if wPastLevel20:
;>@lowend         state = 0x1B
;> elif hSpeed == 3:                               # MED
;>@med     if wPastLevel20:
;>@medend         state = 0x07
;> else:                                           # HI
;>@hi     level = hVirusLevelBCD
;>@hi6     if level == 0x06:
;>@hi6s         state = 0x08
;>@hi11     elif level == 0x11:
;>@hi11s         state = 0x13
;>@hi16     elif level == 0x16:
;>@hi16s         state = 0x18
;>@hiend     elif wPastLevel20:
;>@hiends         state = 0x1A
;>@music if state != 0x09:
;>@music2     wMusicRequest = 9                           # cutscene music
	ld b, $09
	ldh a, [hSpeed]
	cp $04
	jr z, jr_000_1497

	cp $03
	jr z, jr_000_1467

	jr jr_000_1471

;=@music
jr_000_1447:
;=@music2
	ld a, $09
	ld [wMusicRequest], a

;> hGameState = state
jr_000_144c:
	ld a, b
	ldh [hGameState], a
;> wLaughFrame = 0
;> hToppedOut = 0
;> hCapsuleState = 0
;> wClearSFXDone = 0
;> hCutscenePhase = 0
;> wPastLevel20 = 0
	xor a
	ld [wLaughFrame], a
	ldh [hToppedOut], a
	ldh [hCapsuleState], a
	ld [wClearSFXDone], a
	ldh [hCutscenePhase], a
	ld [wPastLevel20], a
;> ClearShadowOAMFrom6()
	call ClearShadowOAMFrom6
;> rLCDC = 0x81
	ld a, $81
	ldh [rLCDC], a
	ret


;=@med
jr_000_1467:
	ld a, [wPastLevel20]
	and a
	jr z, jr_000_144c

;=@medend
	ld b, $07
	jr jr_000_1447

;=@hi
jr_000_1471:
	ldh a, [hVirusLevelBCD]
;=@hi6
	cp $06
	jr z, jr_000_1487

;=@hi11
	cp $11
	jr z, jr_000_148b

;=@hi16
	cp $16
	jr z, jr_000_148f

;=@hiend
	ld a, [wPastLevel20]
	and a
	jr nz, jr_000_1493

	jr jr_000_144c

;=@hi6s
jr_000_1487:
	ld b, $08
	jr jr_000_1447

;=@hi11s
jr_000_148b:
	ld b, $13
	jr jr_000_1447

;=@hi16s
jr_000_148f:
	ld b, $18
	jr jr_000_1447

;=@hiends
jr_000_1493:
	ld b, $1a
	jr jr_000_1447

;=@low
jr_000_1497:
	ldh a, [hVirusLevelBCD]
	ld a, [wPastLevel20]
	and a
	jr z, jr_000_144c

;=@lowend
	ld b, $1b
	jr jr_000_1447

;@ def CutsceneEndingLOW()
;@ path: cutscenes
;@ Game state $1B: the LOW speed ending after level 20. No creature: just the
;@ dancing viruses and bubbles while CONGRATULATIONS! / VIRUS LEVEL 20 /
;@ SPEED LOW is typed out. Start skips to the next level.
;@ reads: hCutscenePhase, hJoyPressed, hFrameCount
;@ writes: hCutscenePhase
;@ test: skip switches the LCD off
;@ sig: 75477908
CutsceneEndingLOW::
;> if hCutscenePhase == 0:
	ldh a, [hCutscenePhase]
	and a
	jr nz, jr_000_14ac

;>     LoadUnderwaterScreen()
	call LoadUnderwaterScreen
;>     return
	ret


jr_000_14ac:
;> if hJoyPressed & BTN_START:
;>     return EndCutscene()
	ldh a, [hJoyPressed]
	bit 3, a
	jp nz, EndCutscene

;> DanceCutsceneViruses()
	call DanceCutsceneViruses
;> AnimateBubble1()
	call AnimateBubble1
;> AnimateBubble2()
	call AnimateBubble2
;> if hCutscenePhase == 2:
;>@text1     CopyUntilFD(EndingText, 0xC501)
;>@text2     mem[wEndingText + 36] = 2                             # virus level "20"
;>@text3     mem[wEndingText + 37] = 0
;>@text4     mem[wEndingText + 55] = 0x15                          # speed "LOW"
;>@text4b     mem[wEndingText + 56] = 0x18
;>@text4c     mem[wEndingText + 57] = 0x20
;>@text5     hCutscenePhase += 1                         # (jumps into CutsceneEndingMED for this)
;> elif hCutscenePhase == 3:
;>@type1     if hFrameCount & 7 == 0:
;>@type2         TypeEndingText()
	ldh a, [hCutscenePhase]
	cp $02
	jr z, jr_000_14ce

	cp $03
	jr z, jr_000_14eb

;> elif hCutscenePhase == 4:
;>     return
	cp $04
	ret z

;> else:                                           # phase 1: nothing crosses, go straight on
;>     hCutscenePhase += 1
	ld hl, hCutscenePhase
	inc [hl]
	ret


;=@text1
jr_000_14ce:
	ld de, $1c38
	ld hl, wEndingText + 1
	call CopyUntilFD
;=@text2
	ld a, $02
	ld l, $24
	ld [hli], a
;=@text3
	xor a
	ld [hl], a
;=@text4
	ld l, $37
	ld a, $15
	ld [hli], a
	ld a, $18
	ld [hli], a
	ld a, $20
	ld [hl], a
;=@text5
	jr jr_000_1541

;=@type1
jr_000_14eb:
	ldh a, [hFrameCount]
	and $07
	ret nz

;=@type2
	call TypeEndingText
	ret


;@ def CutsceneEndingMED()
;@ path: cutscenes
;@ Game state $07: the MED speed ending after level 20. A snail crawls across
;@ the underwater screen while the viruses dance (faster while it passes),
;@ then CONGRATULATIONS! / VIRUS LEVEL 20 / SPEED MED is typed out. Start
;@ skips to the next level at any time.
;@ reads: hCutscenePhase, hJoyPressed, hFrameCount
;@ writes: hCutscenePhase
;@ test: skip switches the LCD off
;@ sig: 786e13a0
CutsceneEndingMED::
;> if hCutscenePhase == 0:
	ldh a, [hCutscenePhase]
	and a
	jr nz, jr_000_1500

;>     LoadUnderwaterScreen()
	call LoadUnderwaterScreen
;>     DrawCutsceneSnail()
	call DrawCutsceneSnail
;>     return
	ret


jr_000_1500:
;> if hJoyPressed & BTN_START:
;>     return EndCutscene()
	ldh a, [hJoyPressed]
	bit 3, a
	jr nz, jr_000_156c

;> DanceCutsceneViruses()
	call DanceCutsceneViruses
;> AnimateBubble1()
	call AnimateBubble1
;> AnimateBubble2()
	call AnimateBubble2
;> if hCutscenePhase == 2:                         # the snail has gone: set up the text
;>@text1     CopyUntilFD(EndingText, 0xC501)
;>@text2     mem[wEndingText + 36] = 2                             # virus level "20"
;>@text3     mem[wEndingText + 37] = 0
;>@text4     mem[wEndingText + 55] = 0x16                          # speed "MED"
;>@text4b     mem[wEndingText + 56] = 0x0E
;>@text4c     mem[wEndingText + 57] = 0x0D
;>@text5     hCutscenePhase += 1
;> elif hCutscenePhase == 3:
;>@type1     if hFrameCount & 7 == 0:
;>@type2         TypeEndingText()                        # a letter every 8 frames
	ldh a, [hCutscenePhase]
	cp $02
	jr z, jr_000_1546

	cp $03
	jr z, jr_000_1563

;> elif hCutscenePhase == 4:                       # done: wait for Start
;>     return
	cp $04
	ret z

;> elif hFrameCount & 7 == 0:                      # phase 1: every 8 frames
	ldh a, [hFrameCount]
	and $07
	ret nz

;>     AnimateSnail()
	call AnimateSnail
;>     x = mem[wShadowOAM + 13]
;>     if x == 0xF1:                               # off the left edge
;>@gone         hCutscenePhase += 1
;>@ex     elif x == 0xA0:
;>@ex2         ExciteViruses()
	ld hl, wShadowOAM + $0D
	ld a, [hl]
	cp $f1
	jr z, jr_000_1541

	cp $a0
	call z, ExciteViruses
;>     if mem[wShadowOAM + 13] == 0x50:
;>         CalmViruses()
	ld a, [hl]
	cp $50
	call z, CalmViruses
;>     for i in range(4):                          # one pixel left
;>         mem[0xC00D + 4 * i] -= 1
	ld de, $0004
	ld b, e

jr_000_153b:
	dec [hl]
	add hl, de
	dec b
	jr nz, jr_000_153b

	ret


;=@gone
jr_000_1541:
	ld hl, hCutscenePhase
	inc [hl]
	ret


;=@text1
jr_000_1546:
	ld de, $1c38
	ld hl, wEndingText + 1
	call CopyUntilFD
;=@text2
	ld a, $02
	ld l, $24
	ld [hli], a
;=@text3
	xor a
	ld [hl], a
;=@text4
	ld l, $37
	ld a, $16
	ld [hli], a
	ld a, $0e
	ld [hli], a
	ld a, $0d
	ld [hl], a
;=@text5
	jr jr_000_1541

;=@type1
jr_000_1563:
	ldh a, [hFrameCount]
	and $07
	ret nz

;=@type2
	call TypeEndingText
	ret


;@ def EndCutscene()
;@ path: cutscenes
;@ Leaves a cutscene: puts the game tiles and the 1-player screen back and
;@ starts the next level (state $09).
;@ writes: hCutscenePhase, hGameState
;@ test: skip switches the LCD off
;@ sig: 5e219d78
EndCutscene::
jr_000_156c:
;> hCutscenePhase = 0
	xor a
	ldh [hCutscenePhase], a
;> DisableLCD()
	call DisableLCD
;> CopyBytes(GameTiles + 0x800, 0x8800, 0x520)     # the tiles the underwater ones replaced
	ld hl, $459e
	ld de, $8800
	ld bc, $0520
	call CopyBytes
;> LoadScreen(GameScreen1P)
	ld de, $38c4
	call LoadScreen
;> ClearShadowOAM()
	call ClearShadowOAM
;> rLCDC = 0x83
	ld a, $83
	ldh [rLCDC], a
;> hGameState = 0x09                               # LevelInit
	ld a, $09
	ldh [hGameState], a
	ret


;@ def CutsceneTurtle5()
;@ path: cutscenes
;@ Game state $08: the cutscene after level 5 on HI speed. A turtle crosses the
;@ underwater screen while the viruses dance, then CONGRATULATIONS! /
;@ VIRUS LEVEL 05 / SPEED HI is typed out. Start skips to the next level.
;@ reads: hCutscenePhase, hJoyPressed, hFrameCount
;@ writes: hCutscenePhase
;@ test: skip switches the LCD off
;@ sig: fc40d9d3
CutsceneTurtle5::
;> if hCutscenePhase == 0:
	ldh a, [hCutscenePhase]
	and a
	jr nz, jr_000_159c

;>     LoadUnderwaterScreen()
	call LoadUnderwaterScreen
;>     DrawCutsceneTurtle()
	call DrawCutsceneTurtle
;>     return
	ret


jr_000_159c:
;> if hJoyPressed & BTN_START:
;>     return EndCutscene()
	ldh a, [hJoyPressed]
	bit 3, a
	jr nz, jr_000_156c

;> DanceCutsceneViruses()
	call DanceCutsceneViruses
;> AnimateBubble1()
	call AnimateBubble1
;> AnimateBubble2()
	call AnimateBubble2
;> if hCutscenePhase == 2:                         # it has gone: set up the text
;>@text1     CopyUntilFD(EndingText, 0xC501)
;>@text2     mem[wEndingText + 36] = 0                             # virus level "05"
;>@text3     mem[wEndingText + 37] = 5
;>@text4     SetEndingSpeedHI(0xC525)
;>@text5     hCutscenePhase += 1
;> elif hCutscenePhase == 3:
;>@type1     if hFrameCount & 7 == 0:
;>@type2         TypeEndingText()                        # a letter every 8 frames
	ldh a, [hCutscenePhase]
	cp $02
	jr z, jr_000_15e3

	cp $03
	jr z, jr_000_15f8

;> elif hCutscenePhase == 4:                       # done: wait for Start
;>     return
	cp $04
	ret z

;> elif hFrameCount & 7 == 0:                      # phase 1: every 8 frames
	ldh a, [hFrameCount]
	and $07
	ret nz

;>     AnimateTurtle()
	call AnimateTurtle
;>     x = mem[wShadowOAM + 13]
;>     if x == 0xF1:                               # off the left edge
;>@gone         hCutscenePhase += 1
;>@ex     elif x == 0xA0:
;>@ex2         ExciteViruses()
	ld hl, wShadowOAM + $0D
	ld a, [hl]
	cp $f1
	jr z, jr_000_15de

	cp $a0
	call z, ExciteViruses
;>     if mem[wShadowOAM + 13] == 0x50:
;>         CalmViruses()
	ld a, [hl]
	cp $50
	call z, CalmViruses
;>     for i in range(4):                          # 1 pixel left
;>         mem[0xC00D + 4 * i] -= 1
	ld de, $0004
	ld b, $04

jr_000_15d8:
	dec [hl]
	add hl, de
	dec b
	jr nz, jr_000_15d8

	ret


;=@gone
jr_000_15de:
	ld hl, hCutscenePhase
	inc [hl]
	ret


jr_000_15e3:
;=@text1
	ld de, $1c38
	ld hl, wEndingText + 1
	call CopyUntilFD
;=@text2
	xor a
	ld l, $24
	ld [hli], a
;=@text3
	ld a, $05
	ld [hl], a
;=@text4
	call SetEndingSpeedHI
;=@text5
	jr jr_000_15de

jr_000_15f8:
;=@type1
	ldh a, [hFrameCount]
	and $07
	ret nz

;=@type2
	call TypeEndingText
	ret


;@ def CutsceneCrab10()
;@ path: cutscenes
;@ Game state $13: the cutscene after level 10 on HI speed. A crab crosses the
;@ underwater screen while the viruses dance, then CONGRATULATIONS! /
;@ VIRUS LEVEL 10 / SPEED HI is typed out. Start skips to the next level.
;@ reads: hCutscenePhase, hJoyPressed, hFrameCount
;@ writes: hCutscenePhase
;@ test: skip switches the LCD off
;@ sig: 0833310a
CutsceneCrab10::
;> if hCutscenePhase == 0:
	ldh a, [hCutscenePhase]
	and a
	jr nz, jr_000_160d

;>     LoadUnderwaterScreen()
	call LoadUnderwaterScreen
;>     DrawCutsceneCrab()
	call DrawCutsceneCrab
;>     return
	ret


jr_000_160d:
;> if hJoyPressed & BTN_START:
;>     return EndCutscene()
	ldh a, [hJoyPressed]
	bit 3, a
	jp nz, EndCutscene

;> DanceCutsceneViruses()
	call DanceCutsceneViruses
;> AnimateBubble1()
	call AnimateBubble1
;> AnimateBubble2()
	call AnimateBubble2
;> if hCutscenePhase == 2:                         # it has gone: set up the text
;>@text1     CopyUntilFD(EndingText, 0xC501)
;>@text2     mem[wEndingText + 36] = 1                             # virus level "10"
;>@text3     mem[wEndingText + 37] = 0
;>@text4     SetEndingSpeedHI(0xC525)
;>@text5     hCutscenePhase += 1
;> elif hCutscenePhase == 3:
;>@type1     if hFrameCount & 7 == 0:
;>@type2         TypeEndingText()                        # a letter every 8 frames
	ldh a, [hCutscenePhase]
	cp $02
	jr z, jr_000_1656

	cp $03
	jr z, jr_000_166b

;> elif hCutscenePhase == 4:                       # done: wait for Start
;>     return
	cp $04
	ret z

;> elif hFrameCount & 3 == 0:                      # phase 1: every 4 frames
	ldh a, [hFrameCount]
	and $03
	ret nz

;>     AnimateCrab()
	call AnimateCrab
;>     x = mem[wShadowOAM + 13]
;>     if x == 0xF2:                               # off the left edge
;>@gone         hCutscenePhase += 1
;>@ex     elif x == 0xA0:
;>@ex2         ExciteViruses()
	ld hl, wShadowOAM + $0D
	ld a, [hl]
	cp $f2
	jr z, jr_000_1651

	cp $a0
	call z, ExciteViruses
;>     if mem[wShadowOAM + 13] == 0x50:
;>         CalmViruses()
	ld a, [hl]
	cp $50
	call z, CalmViruses
;>     for i in range(4):                          # 2 pixels left
;>         mem[0xC00D + 4 * i] -= 2
	ld de, $0004
	ld b, $04

jr_000_164a:
	dec [hl]
	dec [hl]
	add hl, de
	dec b
	jr nz, jr_000_164a

	ret


;=@gone
jr_000_1651:
	ld hl, hCutscenePhase
	inc [hl]
	ret


jr_000_1656:
;=@text1
	ld de, $1c38
	ld hl, wEndingText + 1
	call CopyUntilFD
;=@text2
	ld a, $01
	ld l, $24
	ld [hli], a
;=@text3
	xor a
	ld [hl], a
;=@text4
	call SetEndingSpeedHI
;=@text5
	jr jr_000_1651

jr_000_166b:
;=@type1
	ldh a, [hFrameCount]
	and $07
	ret nz

;=@type2
	call TypeEndingText
	ret


;@ def CutsceneSwordfish15()
;@ path: cutscenes
;@ Game state $18: the cutscene after level 15 on HI speed. A swordfish crosses the
;@ underwater screen while the viruses dance, then CONGRATULATIONS! /
;@ VIRUS LEVEL 15 / SPEED HI is typed out. Start skips to the next level.
;@ reads: hCutscenePhase, hJoyPressed, hFrameCount
;@ writes: hCutscenePhase
;@ test: skip switches the LCD off
;@ sig: 48b27814
CutsceneSwordfish15::
;> if hCutscenePhase == 0:
	ldh a, [hCutscenePhase]
	and a
	jr nz, jr_000_1680

;>     LoadUnderwaterScreen()
	call LoadUnderwaterScreen
;>     DrawCutsceneSwordfish()
	call DrawCutsceneSwordfish
;>     return
	ret


jr_000_1680:
;> if hJoyPressed & BTN_START:
;>     return EndCutscene()
	ldh a, [hJoyPressed]
	bit 3, a
	jp nz, EndCutscene

;> DanceCutsceneViruses()
	call DanceCutsceneViruses
;> AnimateBubble1()
	call AnimateBubble1
;> AnimateBubble2()
	call AnimateBubble2
;> if hCutscenePhase == 2:                         # it has gone: set up the text
;>@text1     CopyUntilFD(EndingText, 0xC501)
;>@text2     mem[wEndingText + 36] = 1                             # virus level "15"
;>@text3     mem[wEndingText + 37] = 5
;>@text4     SetEndingSpeedHI(0xC525)
;>@text5     hCutscenePhase += 1
;> elif hCutscenePhase == 3:
;>@type1     if hFrameCount & 7 == 0:
;>@type2         TypeEndingText()                        # a letter every 8 frames
	ldh a, [hCutscenePhase]
	cp $02
	jr z, jr_000_16c9

	cp $03
	jr z, jr_000_16df

;> elif hCutscenePhase == 4:                       # done: wait for Start
;>     return
	cp $04
	ret z

;> elif hFrameCount & 3 == 0:                      # phase 1: every 4 frames
	ldh a, [hFrameCount]
	and $03
	ret nz

;>     AnimateSwordfish()
	call AnimateSwordfish
;>     x = mem[wShadowOAM + 13]
;>     if x == 0xEA:                               # off the left edge
;>@gone         hCutscenePhase += 1
;>@ex     elif x == 0xA0:
;>@ex2         ExciteViruses()
	ld hl, wShadowOAM + $0D
	ld a, [hl]
	cp $ea
	jr z, jr_000_16c4

	cp $a0
	call z, ExciteViruses
;>     if mem[wShadowOAM + 13] == 0x50:
;>         CalmViruses()
	ld a, [hl]
	cp $50
	call z, CalmViruses
;>     for i in range(4):                          # 2 pixels left
;>         mem[0xC00D + 4 * i] -= 2
	ld de, $0004
	ld b, $04

jr_000_16bd:
	dec [hl]
	dec [hl]
	add hl, de
	dec b
	jr nz, jr_000_16bd

	ret


;=@gone
jr_000_16c4:
	ld hl, hCutscenePhase
	inc [hl]
	ret


jr_000_16c9:
;=@text1
	ld de, $1c38
	ld hl, wEndingText + 1
	call CopyUntilFD
;=@text2
	ld a, $01
	ld l, $24
	ld [hli], a
;=@text3
	ld a, $05
	ld [hl], a
;=@text4
	call SetEndingSpeedHI
;=@text5
	jr jr_000_16c4

jr_000_16df:
;=@type1
	ldh a, [hFrameCount]
	and $07
	ret nz

;=@type2
	call TypeEndingText
	ret



;@ def CutsceneEndingHI()
;@ path: cutscenes
;@ Game state $1A: the HI speed ending after level 20, a little story in
;@ phases. The text CONGRATULATIONS! / VIRUS LEVEL 20 / SPEED HI is typed
;@ and erased again; a shell drifts in and something sinks; the viruses float
;@ up; a coelacanth swims across and eats them one by one; the shell leaves,
;@ and from then on bubbles drift across the screen for ever (phases 11 and
;@ 12 take turns). Start skips to the next level.
;@ reads: hCutscenePhase, hJoyPressed, hFrameCount, rDIV, $D065, $D066, wBubbleSlot, wSinkerLimit
;@ writes: hCutscenePhase, wNoiseSFXRequest, $D009, $D066, wShadowOAM, wBubbleSlot, wEndingLetter
;@ test: skip switches the LCD off
;@ sig: dccce3ae
CutsceneEndingHI::
;> AnimateBubble1()
	call AnimateBubble1
;> AnimateBubble2()
	call AnimateBubble2
;> if hCutscenePhase < 0x0B:
	ldh a, [hCutscenePhase]
	cp $0b
	jr nc, jr_000_1700

;>     DanceCutsceneViruses()
	call DanceCutsceneViruses
;>     if hCutscenePhase == 0:
	ldh a, [hCutscenePhase]
	and a
	jr nz, jr_000_1700

;>         LoadUnderwaterScreen()
	call LoadUnderwaterScreen
;>         return
	ret


jr_000_1700:
;> if hJoyPressed & BTN_START:
;>     return EndCutscene()
	ldh a, [hJoyPressed]
	bit 3, a
	jp nz, EndCutscene

;> phase = hCutscenePhase
;> if phase == 2:                                  # type the text
;>@p2     if hFrameCount & 7 == 0:
;>@p2b         TypeEndingText()
	ldh a, [hCutscenePhase]
	cp $02
	jr z, jr_000_1753

;> elif phase == 3:                                # start over at the first letter
;>@p3     wEndingLetter = 0
;>@p3b     mem[wTextVRAM] = 0x98
;>@p3c     mem[wTextVRAM + 1] = 0x7F
;>@p3d     hCutscenePhase += 1
	cp $03
	jr z, jr_000_175c

;> elif phase == 4:                                # blank the text buffer
;>@p4     for k in range(60):
;>@p4b         mem[0xC500 + k] = 0xFF
;>@p4c     hCutscenePhase += 1
	cp $04
	jr z, jr_000_176b

;> elif phase == 5:                                # and "type" the blanks: the text goes away
;>@p5     if hFrameCount & 1 == 0:
;>@p5b         TypeEndingText()
	cp $05
	jr z, jr_000_1778

;> elif phase == 6:                                # wait 160 frames, then the shell
;>@p6     wShellWait += 1
;>@p6b     if wShellWait != 0xA0:
;>@p6c         return
;>@p6d     wShellWait = 0
;>@p6e     DrawCutsceneShell()
;>@p6f     hCutscenePhase += 1
	cp $06
	jr z, jr_000_1781

;> elif phase == 7:                                # the shell drifts in
;>@p7     AnimateShell()
;>@p7b     if hFrameCount & 3:
;>@p7c         return
;>@p7d     x = mem[wShadowOAM + 13]
;>@p7e     if x == 0x50:
;>@p7f         wNoiseSFXRequest = 2
;>@p7g         hCutscenePhase += 1
;>@p7h         return
;>@p7i     if x == 0x90:
;>@p7j         ExciteViruses()
;>@p7k     for i in range(4):
;>@p7l         mem[0xC00D + 4 * i] -= 1
	cp $07
	jp z, Jump_000_1790

;> elif phase == 8:                                # something sinks; then the coelacanth
;>@p8     AnimateSinker()
;>@p8b     if wSinkerLimit < 0x0E:
;>@p8c         return
;>@p8d     wSinkerCount = 0
;>@p8e     DrawCutsceneCoelacanth()
;>@p8f     hCutscenePhase += 1
	cp $08
	jp z, Jump_000_17b6

;> elif phase == 9:                                # the viruses float up, the coelacanth eats them
;>@p9     AnimateSinker()
;>@p9b     if hFrameCount & 3:
;>@p9c         return
;>@p9d     if mem[wShadowOAM] < 0x48:                      # the viruses are high enough: swim
;>@p9e         AnimateCoelacanthFin()
;>@p9f         x = mem[wShadowOAM + 29]
;>@p9g         if x == 0x70: CoelacanthMouthOpen()
;>@p9h         if x == 0x5C: EatVirus3()
;>@p9i         if x == 0x54: EatVirus2()
;>@p9j         if x == 0x4C: EatVirus1()
;>@p9k         if x == 0x40: CoelacanthMouthClose()
;>@p9l         if x == 0xD0:                           # it has swum off the left edge
;>@p9m             wNoiseSFXRequest = 3
;>@p9n             mem[wShadowOAM + 130] = 0xFF                      # the sinker goes
;>@p9o             mem[wShadowOAM + 134] = 0xFF
;>@p9p             CopyUntilFD(CutsceneBurpBubbles, 0xC01C)
;>@p9q             hCutscenePhase += 1
;>@p9r             return
;>@p9s         speed = 4 if 0x40 <= x < 0xD0 else 2
;>@p9t         for i in range(21):
;>@p9u             mem[0xC01D + 4 * i] = (mem[0xC01D + 4 * i] - speed) & 0xFF
;>@p9v     wRiseToggle ^= 1                            # the viruses rise every other step
;>@p9w     if wRiseToggle == 0:
;>@p9x         for i in range(3):
;>@p9y             mem[0xC000 + 4 * i] -= 1
	cp $09
	jp z, Jump_000_17c8

;> elif phase == 10:                               # the shell drifts out to the right
;>@p10     BlinkBurpBubbles()
;>@p10b     if mem[wShadowOAM + 13] >= 0xF0:
;>@p10c         for k in range(38):                         # all sprites off screen
;>@p10d             mem[0xC001 + 4 * k] = 0xF0
;>@p10e         hCutscenePhase += 1
;>@p10f     else:
;>@p10g         for i in range(6):
;>@p10h             mem[0xC00D + 4 * i] += 1
	cp $0a
	jp z, Jump_000_1842

;> elif phase == 11:                               # a new bubble from the right
;>@p11     src = EndingBubbles + 4 * (rDIV & 7)
;>@p11b     slot = wBubbleSlot
;>@p11c     wBubbleSlot = 0 if slot + 4 == 0x98 else slot + 4
;>@p11d     for k in range(4):
;>@p11e         mem[0xC000 + slot + k] = mem[src + k]
;>@p11f     hCutscenePhase += 1
	cp $0b
	jp z, Jump_000_186d

;> elif phase == 12:                               # bubbles drift left, at different speeds
;>@p12     if hFrameCount & 7:
;>@p12b         return
;>@p12c     TwinkleEndingBubbles()
;>@p12d     for k in range(38):
;>@p12e         x = 0xC001 + 4 * k
;>@p12f         if mem[x] != 0xF0:                      # off screen: leave it
;>@p12g             mem[x] -= 2
;>@p12h             if mem[x + 1] < 0xC8:               # the small bubbles go faster
;>@p12i                 mem[x] -= 2
;>@p12j                 if rDIV & 1:
;>@p12k                     mem[x] -= 2
;>@p12l     wBubbleSteps += 1
;>@p12m     if wBubbleSteps == 6:                        # every 6 steps another bubble
;>@p12n         wBubbleSteps = 0
;>@p12o         hCutscenePhase -= 1
;> else:                                           # phase 1: set up the text
	cp $0c
	jp z, Jump_000_1897

;>     CopyUntilFD(EndingText, 0xC501)
	ld de, $1c38
	ld hl, wEndingText + 1
	call CopyUntilFD
;>     mem[wEndingText + 36] = 2                             # virus level "20"
;>     mem[wEndingText + 37] = 0
	ld a, $02
	ld l, $24
	ld [hli], a
	xor a
	ld [hl], a
;>     SetEndingSpeedHI(0xC525)
	call SetEndingSpeedHI

;>     hCutscenePhase += 1
Jump_000_174e:
jr_000_174e:
	ld hl, hCutscenePhase
	inc [hl]
	ret


;=@p2
jr_000_1753:
	ldh a, [hFrameCount]
	and $07
	ret nz

;=@p2b
	call TypeEndingText
	ret


;=@p3
jr_000_175c:
	xor a
	ld [wEndingLetter], a
;=@p3b
	ld hl, wTextVRAM
	ld a, $98
	ld [hli], a
;=@p3c
	ld a, $7f
	ld [hl], a
;=@p3d
	jr jr_000_174e

;=@p4
jr_000_176b:
	ld hl, wEndingText
	ld b, $3c
	ld a, $ff

jr_000_1772:
	ld [hli], a
	dec b
	jr nz, jr_000_1772

;=@p4c
	jr jr_000_174e

;=@p5
jr_000_1778:
	ldh a, [hFrameCount]
	and $01
	ret nz

;=@p5b
	call TypeEndingText
	ret


;=@p6
jr_000_1781:
	ld hl, wShellWait
	inc [hl]
;=@p6b
	ld a, [hl]
	cp $a0
;=@p6c
	ret nz

;=@p6d
	xor a
	ld [hl], a
;=@p6e
	call DrawCutsceneShell
;=@p6f
	jr jr_000_174e

;=@p7
Jump_000_1790:
	call AnimateShell
;=@p7b
	ldh a, [hFrameCount]
	and $03
;=@p7c
	ret nz

;=@p7d
	ld hl, wShadowOAM + $0D
	ld a, [hl]
;=@p7e
	cp $50
	jr z, jr_000_17af

;=@p7i
	cp $90
;=@p7j
	call z, ExciteViruses
;=@p7k
	ld de, $0004
	ld b, e

jr_000_17a9:
	dec [hl]
	add hl, de
	dec b
	jr nz, jr_000_17a9

;=@p7l
	ret


;=@p7f
jr_000_17af:
	ld a, $02
	ld [wNoiseSFXRequest], a
;=@p7g
	jr jr_000_174e

;=@p8
Jump_000_17b6:
	call AnimateSinker
;=@p8b
	ld a, [wSinkerLimit]
	cp $0e
	jr nc, jr_000_17c1

;=@p8c
	ret


;=@p8d
jr_000_17c1:
	xor a
	ld [bc], a
;=@p8e
	call DrawCutsceneCoelacanth
;=@p8f
	jr jr_000_174e

;=@p9
Jump_000_17c8:
	call AnimateSinker
;=@p9b
	ldh a, [hFrameCount]
	and $03
;=@p9c
	ret nz

;=@p9d
	ld hl, wShadowOAM
	ld a, [hl]
	ld de, $0004
	cp $48
	jr c, jr_000_17ee

;=@p9v
jr_000_17db:
	ld hl, wRiseToggle
	ld a, [hl]
	xor $01
	ld [hl], a
;=@p9w
	ret nz

;=@p9x
	ld hl, wShadowOAM
	ld b, $03

jr_000_17e8:
	dec [hl]
	add hl, de
	dec b
	jr nz, jr_000_17e8

;=@p9w
	ret


;=@p9e
jr_000_17ee:
	call AnimateCoelacanthFin
;=@p9f
	push hl
	ld hl, wShadowOAM + $1D
	ld b, $15
	ld c, e
	ld a, [hl]
;=@p9g
	cp $70
	call z, CoelacanthMouthOpen
;=@p9h
	cp $5c
	call z, EatVirus3
;=@p9i
	cp $54
	call z, EatVirus2
;=@p9j
	cp $4c
	call z, EatVirus1
;=@p9k
	cp $40
	call z, CoelacanthMouthClose
;=@p9l
	cp $d0
	jr z, jr_000_1828

;=@p9s
	jr nc, jr_000_181c

	cp $40
	jr nc, jr_000_181e

jr_000_181c:
	ld c, $02

jr_000_181e:
;=@p9t
	ld a, [hl]
	sub c
	ld [hl], a
	add hl, de
	dec b
	jr nz, jr_000_181e

;=@p9v
	pop hl
	jr jr_000_17db

;=@p9l
jr_000_1828:
	pop hl
;=@p9m
	ld a, $03
	ld [wNoiseSFXRequest], a
;=@p9n
	ld a, $ff
	ld [wShadowOAM + $82], a
	ld [wShadowOAM + $86], a
;=@p9p
	ld hl, wShadowOAM + $1C
	ld de, $1932
	call CopyUntilFD
;=@p9q
	jp Jump_000_174e


;=@p10
Jump_000_1842:
	call BlinkBurpBubbles
;=@p10b
	ld hl, wShadowOAM + $0D
	ld a, [hl]
	cp $f0
	jr nc, jr_000_185b

;=@p10g
	ld de, $0004
	ld b, $06

jr_000_1852:
	ld a, [hl]
	add $01
	ld [hl], a
	add hl, de
	dec b
	jr nz, jr_000_1852

	ret


;=@p10c
jr_000_185b:
	ld hl, wShadowOAM + $01
	ld b, $26
	ld de, $0004
	ld a, $f0

jr_000_1865:
	ld [hl], a
	add hl, de
	dec b
	jr nz, jr_000_1865

;=@p10e
	jp Jump_000_174e


;=@p11
Jump_000_186d:
	ldh a, [rDIV]
	and $07
	inc a
	ld de, $0004
	ld hl, $1ab9

jr_000_1878:
	add hl, de
	dec a
	jr nz, jr_000_1878

	push hl
	pop bc
;=@p11b
	ld a, [wBubbleSlot]
	ld l, a
	add $04
	cp $98
	jr nz, jr_000_1889

	xor a

jr_000_1889:
	ld [wBubbleSlot], a
;=@p11d
	ld h, $c0

jr_000_188e:
	ld a, [bc]
	ld [hli], a
	inc bc
	dec e
	jr nz, jr_000_188e

;=@p11f
	jp Jump_000_174e


;=@p12
Jump_000_1897:
	ldh a, [hFrameCount]
	and $07
	ret nz

;=@p12c
	call TwinkleEndingBubbles
;=@p12d
	ld hl, wShadowOAM + $01
	ld de, $0004
	ld b, $26

jr_000_18a7:
;=@p12f
	ld a, [hl]
	cp $f0
	jr z, jr_000_18be

;=@p12g
	dec [hl]
	dec [hl]
;=@p12h
	inc l
	ld a, [hld]
	cp $c8
	jr nc, jr_000_18be

;=@p12i
	dec [hl]
	dec [hl]
;=@p12j
	ldh a, [rDIV]
	and $01
	jr z, jr_000_18be

;=@p12k
	dec [hl]
	dec [hl]

;=@p12d
jr_000_18be:
	add hl, de
	dec b
	jr nz, jr_000_18a7

;=@p12l
	ld hl, wBubbleSteps
	inc [hl]
	ld a, [hl]
;=@p12m
	cp $06
	ret nz

;=@p12n
	xor a
	ld [hl], a
;=@p12o
	ld hl, hCutscenePhase
	dec [hl]
	ret


;@ def LoadUnderwaterScreen()
;@ path: cutscenes
;@ With the LCD off, loads the underwater tiles and screen and the three
;@ viruses, then moves on to the next cutscene phase.
;@ writes: hCutscenePhase
;@ test: skip switches the LCD off
;@ sig: 6874346b
LoadUnderwaterScreen::
;> DisableLCD()
	call DisableLCD
;> CopyBytes(Tiles_559E, 0x8800, 0x520)
	ld hl, $559e
	ld de, $8800
	ld bc, $0520
	call CopyBytes
;> LoadScreen(UnderwaterScreen)
	ld de, $3b94
	call LoadScreen
;> DrawCutsceneViruses()
	call DrawCutsceneViruses
;> rLCDC = 0x83
	ld a, $83
	ldh [rLCDC], a
;> hCutscenePhase += 1
	ld hl, hCutscenePhase
	inc [hl]
	ret


;@ def SetEndingSpeedHI(buf: hl)
;@ path: cutscenes
;@ Writes HI as the speed into the ending text buffer (the page of `buf`).
;@ test: buf = 0xC500 + rand(0, 255)
;@ sig: fc551bab
SetEndingSpeedHI::
;> mem[(buf & 0xFF00) | 0x38] = 0x11               # H
;> mem[(buf & 0xFF00) | 0x39] = 0x12               # I
	ld l, $38
	ld a, $11
	ld [hli], a
	ld a, $12
	ld [hl], a
	ret


;@ def TypeEndingText()
;@ path: cutscenes
;@ Types the next letter of the ending text: moves the BG map pointer in
;@ $D068/$D069 on (skipping from the end of one text row to the next) and
;@ asks the VBlank handler to copy it ($FF9D = 3). After 60 letters the next
;@ phase begins.
;@ writes: hCutscenePhase, $FF9D, hVBlankJob
;@ test: mem[0xD009] = rng.choice([rand(0, 0x3A), 0x3B]); mem[0xD068] = 0x98; mem[0xD069] = rng.choice([0x93, 0xD3, rand(0, 255)])
;@ sig: ce7ad4fb
TypeEndingText::
;> wEndingLetter += 1
;> if wEndingLetter == 60:
;>@done     hCutscenePhase += 1
;>@doneret     return
	ld hl, wEndingLetter
	inc [hl]
	ld a, [hl]
	cp $3c
	jr z, jr_000_1924

;> ptr = (mem[wTextVRAM] << 8 | mem[wTextVRAM + 1]) + 1
;> hi, lo = ptr >> 8, ptr & 0xFF
	ld hl, wTextVRAM
	ld a, [hli]
	ld d, a
	ld e, [hl]
	inc de
;> if lo == 0x94:                                  # past the first row: on to the next
;>@row2     lo = 0xC0
;> elif lo == 0xD4:
;>@row3     lo = 0x00
;>@row3b     hi += 1
	ld a, e
	cp $94
	jr z, jr_000_191b

	cp $d4
	jr z, jr_000_191f

;> mem[wTextVRAM + 1] = lo
;> mem[wTextVRAM] = hi
jr_000_1914:
	ld [hld], a
	ld [hl], d
;> hVBlankJob = 3
	ld a, $03
	ldh [hVBlankJob], a
	ret


;=@row2
jr_000_191b:
	ld a, $c0
	jr jr_000_1914

;=@row3
jr_000_191f:
	ld a, $00
;=@row3b
	inc d
	jr jr_000_1914

;=@done
jr_000_1924:
	ld hl, hCutscenePhase
	inc [hl]
;=@doneret
	ret


;@ def ExciteViruses()
;@ path: cutscenes
;@ The viruses dance faster ($D00A = 1) while a creature passes.
;@ writes: $D00A, wVirusesExcited
;@ sig: 6507754f
ExciteViruses::
;> wVirusesExcited = 1                                 # falls into the store below
	ld a, $01

jr_000_192b:
	ld [wVirusesExcited], a
	ret


;@ def CalmViruses()
;@ path: cutscenes
;@ sig: 6b1f11ae
CalmViruses::
;> wVirusesExcited = 0
	xor a
	jr jr_000_192b

;@ asset: oam tiles=LoadGameTiles+CopyBytes(hl=Tiles_559E,de=$8800,bc=$520)|LoadGameTiles
;@ Two bubbles the coelacanth lets out after its meal (CutsceneEndingHI).
CutsceneBurpBubbles::
	db $10, $48, $d0, $00, $18, $48, $d1, $00, $fd

;@ def DrawCutsceneViruses()
;@ path: cutscenes
;@ Puts CutsceneVirusSprites into shadow OAM entries 0-2.
;@ sig: 8c3f507f
DrawCutsceneViruses::
;> CopyUntilFD(CutsceneVirusSprites, wShadowOAM)
	ld hl, wShadowOAM
	ld de, $1945
	call CopyUntilFD
	ret


;@ asset: oam tiles=LoadGameTiles+CopyBytes(hl=Tiles_559E,de=$8800,bc=$520)|LoadGameTiles
;@ Three viruses in the underwater cutscenes (DrawCutsceneViruses).
CutsceneVirusSprites::
	db $94, $4c, $c0, $00, $94, $54, $c1, $00, $94, $5c, $c2, $00, $fd

;@ def AnimateBubble1()
;@ path: cutscenes
;@ Every 4 frames: a bubble rises 2 pixels from the bottom; it starts again
;@ every 56 steps. $D063 counts the steps for both bubbles.
;@ reads: hFrameCount
;@ test: hFrameCount = rng.choice([0, 4, 1]); mem[0xD063] = rng.choice([0, 0x37, rand(1, 0x36)]); mem[0xC098] = rand(0x20, 0x90)
;@ sig: b4eb9329
AnimateBubble1::
;> if hFrameCount & 3:
;>     return
	ldh a, [hFrameCount]
	and $03
	ret nz

;> if wBubbleStep == 0:
	ld hl, wShadowOAM + $98
	ld bc, wBubbleStep
	ld a, [bc]
	and a
	jr nz, jr_000_196a

;>     wBubbleStep += 1
	inc a
	ld [bc], a
;>     CopyUntilFD(CutsceneBubble1, 0xC098)        # back at the start
	ld de, $1975
	call CopyUntilFD
;>     return
	ret


;> wBubbleStep += 1
jr_000_196a:
	inc a
	ld [bc], a
;> if wBubbleStep == 0x38:
;>     wBubbleStep = 0
	cp $38
	jr nz, jr_000_1972

	xor a
	ld [bc], a

;> mem[wShadowOAM + 152] -= 2                                # 2 pixels up
jr_000_1972:
	dec [hl]
	dec [hl]
	ret


;@ asset: oam tiles=LoadGameTiles+CopyBytes(hl=Tiles_559E,de=$8800,bc=$520)|LoadGameTiles
;@ Cutscene sprites (AnimateBubble1).
CutsceneBubble1::
	db $90, $38, $90, $00, $fd

;@ def AnimateBubble2()
;@ path: cutscenes
;@ The second bubble: starts at step 32 of AnimateBubble1's count.
;@ reads: hFrameCount
;@ test: hFrameCount = rng.choice([0, 4, 1]); mem[0xD063] = rng.choice([0x20, rand(0, 0x37)]); mem[0xC09C] = rand(0x20, 0x90)
;@ sig: 6add5ef7
AnimateBubble2::
;> if hFrameCount & 3:
;>     return
	ldh a, [hFrameCount]
	and $03
	ret nz

;> if wBubbleStep == 0x20:
	ld hl, wShadowOAM + $9C
	ld bc, wBubbleStep
	ld a, [bc]
	cp $20
	jr nz, jr_000_1991

;>     CopyUntilFD(CutsceneBubble2, 0xC09C)
	ld de, $1994
	call CopyUntilFD
;>     return
	ret


;> mem[wShadowOAM + 156] -= 2
jr_000_1991:
	dec [hl]
	dec [hl]
	ret


;@ asset: oam tiles=LoadGameTiles+CopyBytes(hl=Tiles_559E,de=$8800,bc=$520)|LoadGameTiles
;@ Cutscene sprites (AnimateBubble2).
CutsceneBubble2::
	db $90, $80, $90, $00, $fd


;@ def AnimateSinker()
;@ path: cutscenes
;@ The first call puts CutsceneSinker at shadow OAM entry 32; after that its
;@ two sprites drop 8 pixels a frame (wrapping round the screen). $D065
;@ counts up to 14, one more each time $D064 catches up with it: the HI
;@ ending waits for that before the coelacanth comes.
;@ writes: $D065, wSinkerLimit
;@ reads: $D065, wSinkerLimit
;@ test: mem[0xD064] = rng.choice([0, rand(1, 13)]); mem[0xD065] = rand(1, 14); mem[0xC080] = rand(0, 255); mem[0xC084] = rand(0, 255)
;@ sig: de467a03
AnimateSinker::
;> if wSinkerCount == 0:
	ld hl, wShadowOAM + $80
	ld bc, wSinkerCount
	ld a, [bc]
	and a
	jr nz, jr_000_19ac

;>     wSinkerCount = 1
	inc a
	ld [bc], a
;>     CopyUntilFD(CutsceneSinker, 0xC080)
	ld de, $19ce
	call CopyUntilFD
;>     return
	ret


jr_000_19ac:
;> wSinkerCount += 1
	inc a
	ld [bc], a
;> if wSinkerCount == wSinkerLimit:
	ld d, a
	ld a, [wSinkerLimit]
	cp d
	jr nz, jr_000_19c2

;>     wSinkerCount = 0
	xor a
	ld [bc], a
;>     if wSinkerLimit != 0x0E:
	ld a, d
	cp $0e
	jr z, jr_000_19c2

;>         wSinkerLimit += 1
	inc a
	ld [wSinkerLimit], a
;>         wSinkerCount = 0
	xor a
	ld [bc], a

jr_000_19c2:
;> mem[wShadowOAM + 128] = (mem[wShadowOAM + 128] + 8) & 0xFF
	ld e, $08
	ld a, [hl]
	add e
	ld [hli], a
	inc l
	inc l
	inc l
;> mem[wShadowOAM + 132] = (mem[wShadowOAM + 132] + 8) & 0xFF
	ld a, [hl]
	add e
	ld [hl], a
	ret


;@ asset: oam tiles=LoadGameTiles+CopyBytes(hl=Tiles_559E,de=$8800,bc=$520)|LoadGameTiles
;@ Cutscene sprites (AnimateSinker).
CutsceneSinker::
	db $20, $54, $fe, $00, $30, $54, $fe, $00, $fd

;@ def DrawCutsceneSnail()
;@ path: cutscenes
;@ Puts CutsceneSnail into shadow OAM entries 3-6.
;@ sig: e886f093
DrawCutsceneSnail::
;> CopyUntilFD(CutsceneSnail, 0xC00C)
	ld hl, wShadowOAM + $0C
	ld de, $19e1
	call CopyUntilFD
	ret


;@ asset: oam tiles=LoadGameTiles+CopyBytes(hl=Tiles_559E,de=$8800,bc=$520)|LoadGameTiles
;@ A snail crossing the underwater screen: the MED speed ending after level 20 (state $07, DrawCutsceneSnail).
CutsceneSnail::
	db $50, $f0, $94, $00, $50, $f8, $95, $00, $58, $f0, $96, $00, $58, $f8, $97, $00
	db $fd


;@ def DrawCutsceneTurtle()
;@ path: cutscenes
;@ Puts CutsceneTurtle into shadow OAM entries 3-6.
;@ sig: 57cee1d6
DrawCutsceneTurtle::
;> CopyUntilFD(CutsceneTurtle, 0xC00C)
	ld hl, wShadowOAM + $0C
	ld de, $19fc
	call CopyUntilFD
	ret


;@ asset: oam tiles=LoadGameTiles+CopyBytes(hl=Tiles_559E,de=$8800,bc=$520)|LoadGameTiles
;@ A turtle: the cutscene after level 5 on HI speed (state $08, DrawCutsceneTurtle).
CutsceneTurtle::
	db $40, $f0, $98, $00, $40, $f8, $99, $00, $48, $f0, $9a, $00, $48, $f8, $9b, $00
	db $fd

;@ def DrawCutsceneCrab()
;@ path: cutscenes
;@ Puts CutsceneCrab into shadow OAM entries 3-6.
;@ sig: 6ced7047
DrawCutsceneCrab::
;> CopyUntilFD(CutsceneCrab, 0xC00C)
	ld hl, wShadowOAM + $0C
	ld de, $1a17
	call CopyUntilFD
	ret


;@ asset: oam tiles=LoadGameTiles+CopyBytes(hl=Tiles_559E,de=$8800,bc=$520)|LoadGameTiles
;@ A crab: after level 10 on HI speed (state $13, DrawCutsceneCrab).
CutsceneCrab::
	db $7c, $f0, $91, $00, $7c, $f8, $91, $20, $84, $f0, $92, $00, $84, $f8, $93, $20
	db $fd

;@ def DrawCutsceneSwordfish()
;@ path: cutscenes
;@ Puts CutsceneSwordfish into shadow OAM entries 3-6.
;@ sig: 3b8ce4c2
DrawCutsceneSwordfish::
;> CopyUntilFD(CutsceneSwordfish, 0xC00C)
	ld hl, wShadowOAM + $0C
	ld de, $1a32
	call CopyUntilFD
	ret


;@ asset: oam tiles=LoadGameTiles+CopyBytes(hl=Tiles_559E,de=$8800,bc=$520)|LoadGameTiles
;@ A swordfish: after level 15 on HI speed (state $18, DrawCutsceneSwordfish).
CutsceneSwordfish::
	db $18, $e8, $9d, $00, $10, $f0, $a0, $00, $18, $f0, $9e, $00, $18, $f8, $9f, $00
	db $fd

;@ def DrawCutsceneShell()
;@ path: cutscenes
;@ Puts CutsceneShell into shadow OAM entries 3-8.
;@ sig: c1f85bd6
DrawCutsceneShell::
;> CopyUntilFD(CutsceneShell, 0xC00C)
	ld hl, wShadowOAM + $0C
	ld de, $1a4d
	call CopyUntilFD
	ret


;@ asset: oam tiles=LoadGameTiles+CopyBytes(hl=Tiles_559E,de=$8800,bc=$520)|LoadGameTiles
;@ A round shell in the HI speed ending after level 20 (state $1A, DrawCutsceneShell).
CutsceneShell::
	db $10, $f0, $ca, $00, $10, $f8, $ca, $20, $18, $f0, $bf, $00, $18, $f8, $bf, $20
	db $fd

;@ def DrawCutsceneCoelacanth()
;@ path: cutscenes
;@ Puts CutsceneCoelacanth into shadow OAM from entry 7 on.
;@ sig: 3a598d22
DrawCutsceneCoelacanth::
;> CopyUntilFD(CutsceneCoelacanth, 0xC01C)
	ld hl, wShadowOAM + $1C
	ld de, $1a68
	call CopyUntilFD
	ret


;@ asset: oam tiles=LoadGameTiles+CopyBytes(hl=Tiles_559E,de=$8800,bc=$520)|LoadGameTiles
;@ The big coelacanth, 7x3 tiles, swimming in from the right: the HI speed ending (state $1A, DrawCutsceneCoelacanth).
CutsceneCoelacanth::
	db $30, $c8, $a2, $00, $38, $c8, $b2, $00, $40, $c8, $a9, $00, $30, $d0, $a3, $00
	db $38, $d0, $b3, $00, $40, $d0, $aa, $00, $30, $d8, $a4, $00, $38, $d8, $b4, $00
	db $40, $d8, $ab, $00, $30, $e0, $a5, $00, $38, $e0, $b5, $00, $40, $e0, $ac, $00
	db $30, $e8, $a6, $00, $38, $e8, $b6, $00, $40, $e8, $ad, $00, $30, $f0, $a7, $00
	db $38, $f0, $b7, $00, $40, $f0, $ae, $00, $30, $f8, $a8, $00, $38, $f8, $b8, $00
	db $40, $f8, $af, $00, $fd

;@ asset: oam length=32 tiles=LoadGameTiles+CopyBytes(hl=Tiles_559E,de=$8800,bc=$520)|LoadGameTiles
;@ The eight bubbles the HI ending lets drift across the screen at the end,
;@ one picked at random every 48 frames (CutsceneEndingHI).
EndingBubbles::
	db $28, $d8, $c6, $00, $38, $d8, $c6, $00, $40, $d8, $c8
	db $00, $48, $d8, $c6, $00, $58, $d8, $c6, $00, $60, $d8, $c8, $00, $68, $d8, $c6
	db $00, $78, $d8, $c6, $00

;@ def DanceCutsceneViruses()
;@ path: cutscenes
;@ Every 16 frames (every 4 while excited) the three viruses switch between
;@ two frames: their tiles go 3 up or 3 down.
;@ reads: hFrameCount, $D00A, wShadowOAM, wVirusesExcited
;@ test: hFrameCount = rand(0, 255); mem[0xD00A] = rng.choice([0, 1]); mem[0xC00A] = rng.choice([0, 0xFF])
;@ test: v = rng.choice([0xC0, 0xC3]); mem[0xC002] = v; mem[0xC006] = v + 1; mem[0xC00A] = rng.choice([v + 2, 0xFF])
;@ sig: 4627b33d
DanceCutsceneViruses::
;> if mem[wShadowOAM + 10] == 0xFF:
;>     return
	ld a, [wShadowOAM + $0A]
	cp $ff
	ret z

;> mask = 0x03 if wVirusesExcited else 0x0F
	ld b, $0f
	ld a, [wVirusesExcited]
	and a
	jr z, jr_000_1aed

	ld b, $03

jr_000_1aed:
;> if hFrameCount & mask:
;>     return
	ldh a, [hFrameCount]
	and b
	ret nz

;> step = 3 if mem[wShadowOAM + 2] == 0xC0 else -3
	ld hl, wShadowOAM + $02
	ld de, $0004
	ld b, $03
	ld a, [hl]
	cp $c0
	jr z, jr_000_1b06

;> for i in range(3):
;>     mem[0xC002 + 4 * i] = (mem[0xC002 + 4 * i] + step) & 0xFF
jr_000_1afe:
	dec [hl]
	dec [hl]
	dec [hl]
	add hl, de
	dec b
	jr nz, jr_000_1afe

	ret


jr_000_1b06:
	inc [hl]
	inc [hl]
	inc [hl]
	add hl, de
	dec b
	jr nz, jr_000_1b06

	ret


;@ def AnimateSnail()
;@ path: cutscenes
;@ Moves the snail's foot: one tile switches between $97 and $85.
;@ test: mem[0xC01A] = rng.choice([0x97, 0x85, 0x10])
;@ sig: 769840d7
AnimateSnail::
;> mem[wShadowOAM + 26] = 0x85 if mem[wShadowOAM + 26] == 0x97 else 0x97
	ld hl, wShadowOAM + $1A
	ld a, [hl]
	cp $97
	jr z, jr_000_1b19

	ld [hl], $97
	ret


jr_000_1b19:
	ld [hl], $85
	ret


;@ def AnimateTurtle()
;@ path: cutscenes
;@ Flaps the turtle's flipper: one tile switches between $9A and $9C.
;@ test: mem[0xC016] = rng.choice([0x9A, 0x9C, 0x10])
;@ sig: e6db6134
AnimateTurtle::
;> mem[wShadowOAM + 22] = 0x9C if mem[wShadowOAM + 22] == 0x9A else 0x9A
	ld hl, wShadowOAM + $16
	ld b, $9c
	ld a, [hl]
	cp $9a
	jr z, jr_000_1b28

	ld b, $9a

jr_000_1b28:
	ld [hl], b
	ret


;@ def AnimateCrab()
;@ path: cutscenes
;@ Every second call the crab's claws move: two tiles go one step apart or
;@ back together ($92 marks the open frame).
;@ test: mem[0xD005] = rand(0, 1); v = rng.choice([0x92, 0x91]); mem[0xC016] = v; mem[0xC01A] = rand(0x90, 0x94)
;@ sig: 1693d3b3
AnimateCrab::
;> wCrabTimer += 1
;> if wCrabTimer != 2:
;>     return
	ld hl, wCrabTimer
	inc [hl]
	ld a, [hl]
	cp $02
	ret nz

;> wCrabTimer = 0
	xor a
	ld [hl], a
;> if mem[wShadowOAM + 22] == 0x92:
;>@open     mem[wShadowOAM + 22] += 1
;>@open2     mem[wShadowOAM + 26] -= 1
;> else:
	ld hl, wShadowOAM + $16
	ld de, $0004
	ld a, [hl]
	cp $92
	jr z, jr_000_1b43

;>     mem[wShadowOAM + 22] -= 1
	dec [hl]
;>     mem[wShadowOAM + 26] += 1
	add hl, de
	inc [hl]
	ret


;=@open
jr_000_1b43:
	inc [hl]
;=@open2
	add hl, de
	dec [hl]
	ret


;@ def AnimateSwordfish()
;@ path: cutscenes
;@ Every second call the swordfish's tail switches frame: two tiles become
;@ ($A0, $9E) or ($FF, $A1).
;@ test: mem[0xD006] = rand(0, 1); mem[0xC012] = rng.choice([0xA0, 0xFF])
;@ sig: 5e6b40e2
AnimateSwordfish::
;> wSwordfishTimer += 1
;> if wSwordfishTimer != 2:
;>     return
	ld hl, wSwordfishTimer
	inc [hl]
	ld a, [hl]
	cp $02
	ret nz

;> wSwordfishTimer = 0
	xor a
	ld [hl], a
;> if mem[wShadowOAM + 18] != 0xA0:
	ld hl, wShadowOAM + $12
	ld de, $0004
	ld a, [hl]
	cp $a0
	jr z, jr_000_1b62

;>     mem[wShadowOAM + 18] = 0xA0
;>     mem[wShadowOAM + 22] = 0x9E
	ld [hl], $a0
	add hl, de
	ld [hl], $9e
	ret


;> else:
;>     mem[wShadowOAM + 18] = 0xFF
;>     mem[wShadowOAM + 22] = 0xA1
jr_000_1b62:
	ld [hl], $ff
	add hl, de
	ld [hl], $a1
	ret


;@ def AnimateShell()
;@ path: cutscenes
;@ Every third call two of the shell's tiles switch frame ($CB marks one of them).
;@ test: mem[0xD05B] = rand(0, 2); mem[0xC00E] = rng.choice([0xCB, 0xCA]); mem[0xC012] = rand(0xC0, 0xD0)
;@ sig: bdc43f1f
AnimateShell::
;> wShellTimer += 1
;> if wShellTimer != 3:
;>     return
	ld hl, wShellTimer
	inc [hl]
	ld a, [hl]
	cp $03
	ret nz

;> wShellTimer = 0
	xor a
	ld [hl], a
;> d = -1 if mem[wShadowOAM + 14] == 0xCB else 1
	ld hl, wShadowOAM + $0E
	ld de, $0004
	ld a, [hl]
	cp $cb
	jr z, jr_000_1b81

;> mem[wShadowOAM + 14] += d
;> mem[wShadowOAM + 18] += d
	inc [hl]
	add hl, de
	inc [hl]
	ret


jr_000_1b81:
	dec [hl]
	add hl, de
	dec [hl]
	ret


;@ def AnimateCoelacanthFin()
;@ path: cutscenes
;@ Every second call the coelacanth's tail (six tiles from shadow OAM entry
;@ 22 on) switches between two frames, from the lists after this routine.
;@ test: mem[0xD061] = rand(0, 1); mem[0xC05A] = rng.choice([0xA7, 0xB9])
;@ sig: 61489a67
AnimateCoelacanthFin::
;> wFinTimer += 1
;> if wFinTimer != 2:
;>     return
	ld hl, wFinTimer
	inc [hl]
	ld a, [hl]
	cp $02
	ret nz

;> wFinTimer = 0
	xor a
	ld [hl], a
;> frame = 0x1BB2 if mem[wShadowOAM + 90] == 0xA7 else 0x1BAB
	ld hl, wShadowOAM + $5A
	ld de, $0004
	ld bc, $1bab
	ld a, [hl]
	cp $a7
	jr z, jr_000_1b9f

	jr jr_000_1ba2

jr_000_1b9f:
	ld bc, $1bb2

jr_000_1ba2:
;> i = 0
;> while mem[frame + i] != 0xFD:
;>     mem[0xC05A + 4 * i] = mem[frame + i]
;>     i += 1
	ld a, [bc]
	cp $fd
	ret z

	ld [hl], a
	add hl, de
	inc bc
	jr jr_000_1ba2

	db $a7, $b7, $ae, $a8, $b8, $af, $fd, $b9, $bb, $bd, $ba, $bc, $be, $fd

;@ def BlinkBurpBubbles()
;@ path: cutscenes
;@ Every 8 frames the two bubbles let out by the coelacanth blink ($D0/$D1
;@ or blank).
;@ reads: hFrameCount
;@ test: hFrameCount = rng.choice([0, 8, 3]); mem[0xC01E] = rng.choice([0xD0, 0xFF])
;@ sig: ccbce847
BlinkBurpBubbles::
;> if hFrameCount & 7:
;>     return
	ldh a, [hFrameCount]
	and $07
	ret nz

;> if mem[wShadowOAM + 30] != 0xD0:
	ld hl, wShadowOAM + $1E
	ld de, $0004
	ld a, [hl]
	cp $d0
	jr z, jr_000_1bd0

;>     mem[wShadowOAM + 30] = 0xD0
;>     mem[wShadowOAM + 34] = 0xD1
	ld a, $d0
	ld [hl], a
	add hl, de
	inc a
	ld [hl], a
	ret


;> else:
;>     mem[wShadowOAM + 30] = 0xFF
;>     mem[wShadowOAM + 34] = 0xFF
jr_000_1bd0:
	ld a, $ff
	ld [hl], a
	add hl, de
	ld [hl], a
	ret


;@ def TwinkleEndingBubbles()
;@ path: cutscenes
;@ The ending's bubbles twinkle: in all 38 sprites, tiles $C6/$C8 become
;@ $C7/$C9 and back.
;@ test: for i in range(38): mem[0xC002 + 4 * i] = rng.choice([0xC6, 0xC7, 0xC8, 0xC9, 0xFF])
;@ sig: c2111c60
TwinkleEndingBubbles::
;> for i in range(38):
;>     t = 0xC002 + 4 * i
;>     if mem[t] in (0xC6, 0xC8):
;>@up2         mem[t] += 1
	ld hl, wShadowOAM + $02
	ld de, $0004
	ld b, $26

jr_000_1bde:
	ld a, [hl]
	cp $c6
	jr z, jr_000_1bf7

	cp $c7
	jr z, jr_000_1bf1

	cp $c8
	jr z, jr_000_1bf7

	cp $c9
	jr z, jr_000_1bf1

	jr jr_000_1bf2

;>@dn     elif mem[t] in (0xC7, 0xC9):
;>@dn2         mem[t] -= 1
;=@dn2
jr_000_1bf1:
	dec [hl]

jr_000_1bf2:
	add hl, de
	dec b
	jr nz, jr_000_1bde

	ret


;=@up2
jr_000_1bf7:
	inc [hl]
	jr jr_000_1bf2

;@ def EatVirus3()
;@ path: cutscenes
;@ The coelacanth eats a virus: its sprite (shadow OAM entry 2) goes blank.
;@ test: mem[0xC00A] = rand(0, 255)
;@ sig: 52519395
EatVirus3::
;> mem[wShadowOAM + 10] = 0xFF                              # (keeps a and hl)
	push af
	push hl
	ld hl, wShadowOAM + $0A

jr_000_1bff:
	ld [hl], $ff
	pop hl
	pop af
	ret


;@ def EatVirus2()
;@ path: cutscenes
;@ The second virus (entry 1), with the chomp sound $0E.
;@ writes: wSFXRequest
;@ test: mem[0xC006] = rand(0, 255)
;@ sig: 4772a04b
EatVirus2::
;> wSFXRequest = 0x0E
	push af
	push hl
	ld a, $0e
	ld [wSFXRequest], a
;> mem[wShadowOAM + 6] = 0xFF
	ld hl, wShadowOAM + $06
	jr jr_000_1bff

;@ def EatVirus1()
;@ path: cutscenes
;@ The first virus (entry 0).
;@ test: mem[0xC002] = rand(0, 255)
;@ sig: 066eea5d
EatVirus1::
;> mem[wShadowOAM + 2] = 0xFF
	push af
	push hl
	ld hl, wShadowOAM + $02
	jr jr_000_1bff

;@ def CoelacanthMouthOpen()
;@ path: cutscenes
;@ The coelacanth opens its mouth (tiles $B0, $B1).
;@ sig: a2eb011a
CoelacanthMouthOpen::
;> mem[wShadowOAM + 34] = 0xB0
;> mem[wShadowOAM + 38] = 0xB1
	push af
	push hl
	ld hl, wShadowOAM + $22
	ld a, $b0
	ld [hli], a
	inc l
	inc l
	inc l
	inc a
	ld [hl], a
	pop hl
	pop af
	ret


;@ def CoelacanthMouthClose()
;@ path: cutscenes
;@ ... and closes it (tiles $B2, $A9).
;@ sig: 7d89ffe3
CoelacanthMouthClose::
;> mem[wShadowOAM + 34] = 0xB2
;> mem[wShadowOAM + 38] = 0xA9
	push af
	push hl
	ld hl, wShadowOAM + $22
	ld a, $b2
	ld [hli], a
	inc l
	inc l
	inc l
	ld a, $a9
	ld [hl], a
	pop hl
	pop af
	ret


;@ asset: rows width=20 blank=$FF tiles=LoadGameTiles+CopyBytes(hl=Tiles_559E,de=$8800,bc=$520)
;@ The ending's text panel: CONGRATULATIONS! / VIRUS LEVEL / SPEED. The
;@ ending copies it to $C501, fills in the level ("20") and speed, and types it out.
EndingText::
	db $ff, $ff, $0c, $18, $17, $10, $1b, $0a, $1d, $1e, $15, $0a, $1d, $12, $18, $17
	db $1c, $25, $ff, $ff, $ff, $ff, $ff, $1f, $12, $1b, $1e, $1c, $ff, $15, $0e, $1f
	db $0e, $15, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $1c, $19, $0e, $0e, $0d
	db $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $fd, $ff, $ff, $ff
	db $ff, $ff, $ff, $11, $12, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
	db $ff, $ff, $ff, $ff, $ff, $ff, $15, $0e, $1f, $0e, $15, $ff, $00, $05, $ff, $ff
	db $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $17, $12, $0c, $0e, $ff, $0c, $15
	db $0e, $0a, $1b, $ff, $ff, $ff, $fd, $ff, $ff, $ff, $ff, $ff, $ff, $11, $12, $ff
	db $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
	db $15, $0e, $1f, $0e, $15, $ff, $01, $00, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
	db $ff, $ff, $ff, $17, $12, $0c, $0e, $ff, $0c, $15, $0e, $0a, $1b, $ff, $ff, $ff
	db $fd, $ff, $ff, $ff, $ff, $ff, $ff, $11, $12, $ff, $ff, $ff, $ff, $ff, $ff, $ff
	db $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $15, $0e, $1f, $0e, $15, $ff
	db $01, $05, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $17, $12, $0c
	db $0e, $ff, $0c, $15, $0e, $0a, $1b, $ff, $ff, $ff, $fd, $ff, $ff, $ff, $ff, $ff
	db $ff, $11, $12, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
	db $ff, $ff, $ff, $ff, $15, $0e, $1f, $0e, $15, $ff, $02, $00, $ff, $ff, $ff, $ff
	db $ff, $ff, $ff, $ff, $ff, $ff, $ff, $17, $12, $0c, $0e, $ff, $0c, $15, $0e, $0a
	db $1b, $ff, $ff, $ff, $fd

;@ def CopyBoardRow(dest: hl, src: de)
;@ path: game/lines
;@ Copies one 10-tile board row from src to dest and moves hBoardCopyStage on.
;@ Only the low address bytes are incremented, so a row must not cross a
;@ 256-byte boundary (board rows never do).
;@ reads: hBoardCopyStage
;@ writes: hBoardCopyStage
;@ clobbers: a, b, e, l
;@ test: dest = (rand(0x9800, 0x9BFF) & 0xFFE0) | 2
;@ test: src = (rand(0xC800, 0xCBFF) & 0xFFE0) | 2
;@ sig: f49568f8
CopyBoardRow::
;> copy(dest, src, 10)
	ld b, $0a

.loop
	ld a, [de]
	ld [hl], a
	inc l
	inc e
	dec b
	jr nz, .loop

;> hBoardCopyStage += 1
	ldh a, [hBoardCopyStage]
	inc a
	ldh [hBoardCopyStage], a
;> return
	ret

;@ def HandleCapsuleInput()
;@ path: game/play
;@ The player's control of the falling capsule. A / B turn it (the four
;@ orientations are the low two bits of its sprite id); if that collides it
;@ tries one column further left, else the turn is undone. Left / right move it
;@ a column, repeating every 6 frames after a 16 frame wait while held, and
;@ are undone when blocked.
;@ reads: hJoyPressed, hJoyHeld, hRepeatDelay
;@ writes: hTemp, hSavedIE, wSFXRequest, hRepeatDelay
;@ test: mem[0xC200] = rng.choice([0, 0, 0x80]); mem[0xC201] = 0x18 + 8 * rand(1, 15); mem[0xC202] = 0x18 + 8 * rand(0, 7); mem[0xC203] = rand(0, 0x17)
;@ test: for k in range(4, 16): mem[0xC200 + k] = 0
;@ test: hJoyPressed = rng.choice([0, BTN_A, BTN_B, BTN_RIGHT, BTN_LEFT, BTN_A | BTN_LEFT]); hJoyHeld = rng.choice([0, BTN_RIGHT, BTN_LEFT]); hRepeatDelay = rand(1, 3)
;@ test: for k in range(0x80): mem[0xC800 + k] = rng.choice([0xFF, 0xFF, 0xFF, 0xE0])
;@ test: hObjHidden = 0
;@ sig: 478806aa
HandleCapsuleInput::
;> if mem[wObjects] == 0x80:                        # no capsule in play
;>     return
	ld hl, wObjects
	ld a, [hl]
	cp $80
	ret z

;> old_sprite = mem[wObjects + 3]
;> hTemp = old_sprite
	ld l, $03
	ld a, [hl]
	ldh [hTemp], a
;> pressed = hJoyPressed
	ldh a, [hJoyPressed]
	ld b, a
;> if pressed & BTN_A:                             # turn one way
;>@a1     if mem[wObjects + 3] & 3 == 3:
;>@a2         mem[wObjects + 3] &= 0xFC
;>@a3     else:
;>@a4         mem[wObjects + 3] += 1
	bit 0, b
	jr nz, jr_000_1d91

;> elif pressed & BTN_B:                           # or the other
	bit 1, b
	jr z, jr_000_1dcf

;>     if mem[wObjects + 3] & 3:
	ld a, [hl]
	and $03
	jr z, jr_000_1d8b

;>         mem[wObjects + 3] -= 1
	dec [hl]
	jr jr_000_1d9f

;>     else:
;>         mem[wObjects + 3] |= 3
jr_000_1d8b:
	ld a, [hl]
	or $03
	ld [hl], a
	jr jr_000_1d9f

;=@a1
jr_000_1d91:
	ld a, [hl]
	and $03
	cp $03
	jr z, jr_000_1d9b

;=@a4
	inc [hl]
	jr jr_000_1d9f

jr_000_1d9b:
;=@a2
	ld a, [hl]
	and $fc
	ld [hl], a

;> if pressed & (BTN_A | BTN_B):
;>     wSFXRequest = 2
jr_000_1d9f:
	ld a, $02
	ld [wSFXRequest], a
;>     DrawObject0()
	call DrawObject0
;>     if CheckCapsuleCollision():
	call CheckCapsuleCollision
	and a
	jr z, jr_000_1dcf

;>         old_x = mem[wObjects + 2]
;>         hSavedIE = old_x                         # used as a scratch byte here
;>         mem[wObjects + 2] = (old_x - 8) & 0xFF        # one column to the left
	ld hl, wObjects + 2
	ld a, [hl]
	ldh [hSavedIE], a
	sub $08
	ld [hl], a
;>         DrawObject0()
	call DrawObject0
;>         if CheckCapsuleCollision():             # still no room: undo the turn
	call CheckCapsuleCollision
	and a
	jr z, jr_000_1dcf

;>             wSFXRequest = 0
	xor a
	ld [wSFXRequest], a
;>             mem[wObjects + 3] = old_sprite
;>             mem[wObjects + 2] = old_x
	ld hl, wObjects + 3
	ldh a, [hTemp]
	ld [hld], a
	ldh a, [hSavedIE]
	ld [hl], a
;>             DrawObject0()
	call DrawObject0

;> x = mem[wObjects + 2]
;> held = hJoyHeld
;> hTemp = x
jr_000_1dcf:
	ld hl, wObjects + 2
	ldh a, [hJoyPressed]
	ld b, a
	ldh a, [hJoyHeld]
	ld c, a
	ld a, [hl]
	ldh [hTemp], a
;> if pressed & BTN_RIGHT:
;>     delay, step = 0x10, 8
	bit 4, b
	ld a, $10
	jr nz, jr_000_1ded

;> elif held & BTN_RIGHT:
	bit 4, c
	jr z, jr_000_1e12

;>     hRepeatDelay -= 1
;>     if hRepeatDelay:
;>         return
	ldh a, [hRepeatDelay]
	dec a
	ldh [hRepeatDelay], a
	ret nz

;>     delay, step = 6, 8
;>@lp elif pressed & BTN_LEFT:
;>@lpd     delay, step = 0x10, -8
;>@lh elif held & BTN_LEFT:
;>@lhd     hRepeatDelay -= 1
;>@lhr     if hRepeatDelay:
;>@lhrr         return
;>@ld6     delay, step = 6, -8
;>@none else:
;>@noned     hRepeatDelay = 0x10
;>@nonr     return
	ld a, $06

jr_000_1ded:
;>@set hRepeatDelay = delay
	ldh [hRepeatDelay], a
;>@move mem[wObjects + 2] = (x + step) & 0xFF
	ld a, [hl]
	add $08
	ld [hl], a
;>@draw DrawObject0()
	call DrawObject0
;>@sfx wSFXRequest = 3
	ld a, $03
	ld [wSFXRequest], a
;>@hit if CheckCapsuleCollision():                  # blocked: back again
	call CheckCapsuleCollision
	and a
	ret z

jr_000_1e00:
;>     wSFXRequest = 0
	ld hl, wObjects + 2
	xor a
	ld [wSFXRequest], a
;>     mem[wObjects + 2] = x
	ldh a, [hTemp]
	ld [hl], a
;>     DrawObject0()
	call DrawObject0
;>     hRepeatDelay = 1
	ld a, $01

jr_000_1e0f:
	ldh [hRepeatDelay], a
	ret


;=@lp
jr_000_1e12:
	bit 5, b
;=@noned
	ld a, $10
;=@lp
	jr nz, jr_000_1e24

;=@lh
	bit 5, c
;=@nonr
	jr z, jr_000_1e0f

;=@lhd
	ldh a, [hRepeatDelay]
	dec a
	ldh [hRepeatDelay], a
;=@lhrr
	ret nz

;=@ld6
	ld a, $06

;=@set
jr_000_1e24:
	ldh [hRepeatDelay], a
;=@move
	ld a, [hl]
	sub $08
	ld [hl], a
;=@sfx
	ld a, $03
	ld [wSFXRequest], a
;=@draw
	call DrawObject0
;=@hit
	call CheckCapsuleCollision
	and a
	ret z

	jr jr_000_1e00

;@ def ClearShadowOAMFrom6()
;@ path: gfx/objects
;@ Clears shadow OAM entries 6-29 (the first 6 sprites stay).
;@ sig: 6dfb7d51
ClearShadowOAMFrom6::
;> fill(wShadowOAM + 0x18, 0, 0x60)            # (shares ClearShadowOAM's loop)
	ld hl, wShadowOAM + $18
	ld b, $60
	jr jr_000_1e45

;@ def ClearShadowOAM()
;@ path: gfx/objects
;@ Clears all 40 entries of the shadow OAM.
;@ sig: 13ff8572
ClearShadowOAM::
;> fill(wShadowOAM, 0, 0xA0)
	ld hl, wShadowOAM
	ld b, $a0

jr_000_1e45:
	xor a

jr_000_1e46:
	ld [hli], a
	dec b
	jr nz, jr_000_1e46

;> return
	ret


DrawDemoGarbage::
	db $21, $c2, $99, $11, $70, $1e, $0e, $04, $06, $0a, $e5, $1a, $77, $e5, $7c, $c6
	db $30, $67, $1a, $77, $e1, $2c, $13, $05, $20, $f1, $e1, $d5, $11, $20, $00, $19
	db $d1, $0d, $20, $e4, $c9

DemoGarbage::
	db $85, $2f, $82, $86, $83, $2f, $2f, $80, $82, $85, $2f
	db $82, $84, $82, $83, $2f, $83, $2f, $87, $2f, $2f, $85, $2f, $83, $2f, $86, $82
	db $80, $81, $2f, $83, $2f, $86, $83, $2f, $85, $2f, $85, $2f, $2f

;@ def HandlePause()
;@ path: game/play
;@ Start pauses and resumes. One player: sprites off and the background
;@ switched to BG map 1, a copy of the screen without the bottle's contents,
;@ so nothing can be studied while paused. In a link game only the master
;@ pauses (see HandlePauseLink); the game stands still while paused.
;@ reads: hDemoMode, hJoyPressed, hTwoPlayer, hSerialRole, hPaused
;@ writes: hPaused, wSoundPause
;@ test: skip may leave its caller
;@ sig: 11c9ed05
HandlePause::
;> if hDemoMode:
;>     return
	ldh a, [hDemoMode]
	and a
	ret nz

;> if not hJoyPressed & BTN_START:
;>     return HandlePauseLink()
	ldh a, [hJoyPressed]
	bit 3, a
	jp z, HandlePauseLink

;> if not hTwoPlayer:
	ldh a, [hTwoPlayer]
	and a
	jr nz, jr_000_1ec8

;>     hPaused ^= 1
	ld hl, $ff40
	ldh a, [hPaused]
	xor $01
	ldh [hPaused], a
;>     if hPaused:
	jr z, jr_000_1ebe

;>         rLCDC = (rLCDC & 0xFD) | 0x08           # sprites off, BG map 1
	ld a, [hl]
	res 1, [hl]
	set 3, [hl]
;>         wSoundPause = 1
;>@res     else:
;>@res2         rLCDC = (rLCDC & 0xF7) | 0x02
;>@res3         wSoundPause = 2
;>@ret     return
;=@ret
	ld a, $01
	ld [wSoundPause], a
	ret


jr_000_1ebe:
;=@res2
	res 3, [hl]
	set 1, [hl]
;=@res3
	ld a, $02
	ld [wSoundPause], a
	ret


jr_000_1ec8:
;> if hSerialRole != SERIAL_MASTER:                # only the master pauses a link game
;>     return
	ldh a, [hSerialRole]
	cp $30
	ret nz

;> hPaused ^= 1
	ldh a, [hPaused]
	xor $01
	ldh [hPaused], a
;> if not hPaused:
;>     return ResumeVersus()
	jr z, ResumeVersus

;> PauseVersus()
;> hSerialTx = 0x90                                # (as in HandlePauseLink) the slave pauses too
;> QueueBottleRedraw()
;> pop_return_address()                            # the game stands still
	call PauseVersus
	jr jr_000_1f0b

jr_000_1eda:
;=@HandlePauseLink.slave
	ldh a, [hPaused]
	and a
	jr nz, jr_000_1f18

;=@HandlePauseLink.slave2
	ldh a, [hSerialRx]
	cp $90
	ret nz

;=@HandlePauseLink.slave3
	call PauseVersus
	jr jr_000_1f18

;@ def PauseVersus()
;@ path: game/play
;@ Pauses a link game: sound paused, PAUSE written over the panel title.
;@ writes: hPaused, wSoundPause
;@ test: skip waits for the LCD
;@ sig: b4ac6b9d
PauseVersus::
;> hPaused = 1
	ld a, $01
	ldh [hPaused], a
;> wSoundPause = 1
	ld [wSoundPause], a
;> WriteTilesUntilFD(TextPause, 0x984C)            # falls through
	ld hl, $984c
	ld de, $0da8

;@ def WriteTilesUntilFD(src: de, dest: hl)
;@ path: gfx/tilemaps
;@ Writes tiles to the BG map, one per HBlank, until a $FD.
;@ test: skip waits for the LCD
;@ sig: 45676236
WriteTilesUntilFD::
;> while mem[src] != 0xFD:
	ld a, [de]
	cp $fd
	ret z

;>     WriteTileA(mem[src], dest)
	call WriteTileA
;>     src += 1
;>     dest += 1
	inc de
	inc hl
	jr WriteTilesUntilFD

;@ def HandlePauseLink()
;@ path: game/play
;@ The link side of pausing, every frame without a Start press. While the
;@ master is paused it keeps sending $90 and the game stands still (this
;@ leaves the caller). The slave pauses on $90 and resumes once neither $90
;@ nor $E0 arrives.
;@ reads: hTwoPlayer, hSerialRole, hPaused, hSerialRx
;@ writes: hSerialTx
;@ test: skip may leave its caller
;@ sig: 8508b02b
HandlePauseLink::
;> if not hTwoPlayer:
;>     return
	ldh a, [hTwoPlayer]
	and a
	ret z

;> if hSerialRole == SERIAL_MASTER:
	ldh a, [hSerialRole]
	cp $30
	jr nz, jr_000_1eda

jr_000_1f0b:
;>     if not hPaused:
;>         return
	ldh a, [hPaused]
	and a
	ret z

;>     hSerialTx = 0x90                            # tell the slave
	ld a, $90
	ldh [hSerialTx], a
;>     QueueBottleRedraw()
	call QueueBottleRedraw
;>     pop_return_address()                        # the game stands still
;>     return
;>@slave if not hPaused:                              # the slave
;>@slave2     if hSerialRx != 0x90:
;>@slave2b         return
;>@slave3     PauseVersus()
	pop hl
	ret


jr_000_1f18:
;> hSerialTx = 0
	xor a
	ldh [hSerialTx], a
;> if hSerialRx in (0x90, 0xE0):                   # still paused
;>@still     QueueBottleRedraw()
;>@still2     pop_return_address()
;>@still3     return
;> return ResumeVersus()                           # falls through
	ldh a, [hSerialRx]
	cp $90
	jr z, jr_000_1f37

	cp $e0
	jr z, jr_000_1f37

;@ def ResumeVersus()
;@ path: game/play
;@ Resumes a link game: sound back on, Dr.MARIO written back.
;@ writes: wSoundPause, hPaused
;@ test: skip waits for the LCD
;@ sig: 2dcb6a77
ResumeVersus::
;> wSoundPause = 2
	ld a, $02
	ld [wSoundPause], a
;> hPaused = 0
	xor a
	ldh [hPaused], a
;> WriteTilesUntilFD(TextDrMario, 0x984C)
	ld hl, $984c
	ld de, $1f4e
	call WriteTilesUntilFD
	ret


;=@HandlePauseLink.still
jr_000_1f37:
	call QueueBottleRedraw
;=@HandlePauseLink.still2
	pop hl
	ret


DrawPauseText::
	db $21, $ee, $98, $0e, $05, $11, $a8, $0d, $1a, $cd, $56, $1f, $13, $2c, $0d, $20
	db $f7, $c9

;@ asset: rows tiles=LoadGameTiles
;@ Dr.MARIO, written back when the link game resumes (HandlePauseLink).
TextDrMario::
	db $0d, $2f, $16, $0a, $1b, $12, $18, $fd

;@ def WriteTileA(tile: a, dest: hl)
;@ path: gfx/tilemaps
;@ Writes one tile to the BG map in an HBlank, interrupts off.
;@ test: skip waits for the LCD
;@ sig: fbfebfc7
WriteTileA::
;> disable_interrupts()
	di
	ld b, a

;> wait_hblank()
jr_000_1f58:
	ldh a, [rSTAT]
	and $03
	jr nz, jr_000_1f58

;> mem[dest] = tile
	ld [hl], b
;> enable_interrupts()
	ei
	ret


;@ def CheckCapsuleCollision() -> a
;@ path: game/play
;@ Does either half of the capsule (shadow OAM entries 4 and 5) overlap the
;@ walls or a filled bottle cell?
;@ writes: hBlocked
;@ test: for k in range(2): mem[0xC010 + 4 * k] = 0x18 + 8 * rand(0, 17); mem[0xC011 + 4 * k] = rng.choice([0x18 + 8 * rand(0, 7), 0x10, 0x58])
;@ test: for k in range(0x100): mem[0xC800 + k] = rng.choice([0xFF, 0xFF, 0xE0])
;@ sig: 0b423600
CheckCapsuleCollision::
;> return CheckSpriteCells(0xC010, 2)              # falls through
	ld b, $02
	ld hl, wShadowOAM + $10

;@ def CheckSpriteCells(oam: hl, count: b) -> a
;@ path: game/play
;@ Checks count shadow OAM entries against the bottle: blocked (1) if one is
;@ below the bottom, outside the walls, or on a cell that is not empty.
;@ writes: hBlocked
;@ test: count = rand(1, 2); oam = 0xC010
;@ test: for k in range(2): mem[0xC010 + 4 * k] = 0x18 + 8 * rand(0, 17); mem[0xC011 + 4 * k] = rng.choice([0x18 + 8 * rand(0, 7), 0x10, 0x58])
;@ test: for k in range(0x100): mem[0xC800 + k] = rng.choice([0xFF, 0xFF, 0xE0])
;@ sig: 4863146d
CheckSpriteCells::
;> for i in range(count):
;>     y = mem[oam + 4 * i]
;>     if y >= 0x98:                               # below the bottle
;>         hBlocked = 1
;>         return 1
	ld a, [hli]
	cp $98
	jr nc, jr_000_1f90

;>     cell = (y - 0x18) & 0xFF                    # row * 8
	sub $18
	ld e, a
;>     x = mem[oam + 4 * i + 1]
;>     if x < 0x11 or x >= 0x58:                   # outside the walls
;>         hBlocked = 1
;>         return 1
	ld a, [hli]
	cp $11
	jr c, jr_000_1f90

	cp $58
	jr nc, jr_000_1f90

;>     while x != 0x18:                            # + column
;>         x = (x - 8) & 0xFF
;>         cell = (cell + 1) & 0xFF
jr_000_1f77:
	cp $18
	jr z, jr_000_1f80

	sub $08
	inc e
	jr jr_000_1f77

;>     if mem[0xC800 + cell] != 0xFF:
;>         hBlocked = 1
;>         return 1
jr_000_1f80:
	ld d, $c8
	ld a, [de]
	cp $ff
	jr nz, jr_000_1f90

	inc l
	inc l
	dec b
	jr nz, CheckSpriteCells

;> hBlocked = 0
;> return 0
	xor a
	ldh [hBlocked], a
	ret


jr_000_1f90:
	ld a, $01
	ldh [hBlocked], a
	ret


;@ def LockCapsule()
;@ path: game/play
;@ Turns the landed capsule into background: each half's tile goes into the BG
;@ map (not in the hidden top row; on the bottle's shoulders row a $Bx tile
;@ becomes $Cx) and into the bottle array, then the capsule object is hidden.
;@ reads: hCapsuleState
;@ writes: hCoordY, hCoordX, hCapsuleState, wNoiseSFXRequest
;@ test: skip waits for the LCD
;@ sig: cedbdbf7
LockCapsule::
;> if hCapsuleState != 1:
;>     return
	ldh a, [hCapsuleState]
	cp $01
	ret nz

;> for i in range(2):                              # the two halves (shadow OAM entries 4 and 5)
;>     hCoordY = mem[0xC010 + 4 * i]
;>     hCoordX = mem[0xC011 + 4 * i]
;>     tile_ptr = 0xC012 + 4 * i
	ld hl, wShadowOAM + $10
	ld b, $02

jr_000_1f9f:
	ld a, [hli]
	ldh [hCoordY], a
	ld a, [hli]
	ldh [hCoordX], a
;>     vram = CoordsToBGMapAddr()
	push hl
	push bc
	call CoordsToBGMapAddr
	push hl
	pop de
	pop bc
	pop hl
;>     if vram >> 8 == 0x98 and vram & 0xF0 == 0x20:          # the hidden top row: not drawn
;>         continue
;>     if (vram >> 8 == 0x98 and vram & 0xF0 == 0x40 and vram & 0xFF not in (0x45, 0x46)
;>             and mem[tile_ptr] & 0xF0 == 0xB0):
;>         mem[tile_ptr] += 0x10
	ld a, d
	cp $98
	jr nz, jr_000_1fd2

	ld a, e
	and $f0
	cp $20
	jr z, jr_000_1fdc

	cp $40
	jr nz, jr_000_1fd2

	ld a, e
	cp $45
	jr z, jr_000_1fd2

	cp $46
	jr z, jr_000_1fd2

	ld a, [hl]
	and $f0
	cp $b0
	jr nz, jr_000_1fd2

	ld a, [hl]
	add $10
	ld [hl], a

jr_000_1fd2:
;>     disable_interrupts()
;>     wait_hblank()
;>     mem[vram] = mem[tile_ptr]
;>     enable_interrupts()
	di

jr_000_1fd3:
	ldh a, [rSTAT]
	and $03
	jr nz, jr_000_1fd3

	ld a, [hl]
	ld [de], a
	ei

jr_000_1fdc:
	inc l
	inc l
	dec b
	jr nz, jr_000_1f9f

;> for i in range(2):                              # and into the bottle array
;>     CheckSpriteCells(0xC010 + 4 * i, 1)         # leaves de at the half's cell
;>     cell = (mem[0xC010 + 4 * i] - 0x18 + (mem[0xC011 + 4 * i] - 0x18) // 8) & 0xFF
;>     if cell & 0xF8:                             # not the top row
;>         mem[0xC800 + cell] = mem[0xC012 + 4 * i]
	ld b, $01
	ld hl, wShadowOAM + $10
	call CheckSpriteCells
	ld hl, wShadowOAM + $12
	ld a, e
	and $f8
	jr z, jr_000_1ff3

	ld a, [hl]
	ld [de], a

jr_000_1ff3:
	ld b, $01
	ld hl, wShadowOAM + $14
	call CheckSpriteCells
	ld hl, wShadowOAM + $16
	ld a, e
	and $f8
	jr z, jr_000_2005

	ld a, [hl]
	ld [de], a

jr_000_2005:
;> mem[wObjects] = 0x80                              # hide the capsule
	ld hl, wObjects
	ld [hl], $80
;> DrawObject0()
	call DrawObject0
;> hCapsuleState = 2
	ld a, $02
	ldh [hCapsuleState], a
;> wNoiseSFXRequest = 1                            # landing thud
	ld a, $01
	ld [wNoiseSFXRequest], a
	ret


;@ def DrawTwoObjects()
;@ path: gfx/objects
;@ Draws objects 0 and 1 of wObjects into the shadow OAM from entry 4 on.
;@ writes: hOAMPtrHi, hOAMPtrLo, hObjCount
;@ test: for i in range(2): mem[0xC200 + 16 * i] = rng.choice([0, 0x80, 1])
;@ test: for i in range(2): mem[0xC203 + 16 * i] = rand(0, 0x20)
;@ test: hObjHidden = 0
;@ sig: 2a815ca5
DrawTwoObjects::
;> hObjCount = 2
	ld a, $02
	ldh [hObjCount], a
;> hOAMPtrLo = 0x10                            # shadow OAM entry 4
	ld a, $10
	ldh [hOAMPtrLo], a
;> hOAMPtrHi = 0xC0
	ld a, $c0
	ldh [hOAMPtrHi], a
;> DrawObjects(wObjects)
	ld hl, wObjects
	call DrawObjects
;> return
	ret


;@ def DrawObject0()
;@ path: gfx/objects
;@ Draws object 0, the falling capsule, into shadow OAM entries 4 and 5.
;@ writes: hObjCount, hOAMPtrLo, hOAMPtrHi
;@ test: mem[0xC200] = rng.choice([0, 0x80]); mem[0xC201] = rand(0x10, 0x90); mem[0xC202] = rand(0x10, 0x90); mem[0xC203] = rand(0, 0x17)
;@ test: for k in range(4, 16): mem[0xC200 + k] = 0
;@ test: hObjHidden = 0
;@ sig: c00781c7
DrawObject0::
;> hObjCount = 1
	ld a, $01
	ldh [hObjCount], a
;> hOAMPtrLo = 0x10
;> hOAMPtrHi = 0xC0
	ld a, $10
	ldh [hOAMPtrLo], a
	ld a, $c0
	ldh [hOAMPtrHi], a
;> DrawObjects(wObjects)
	ld hl, wObjects
	call DrawObjects
	ret


;@ def DrawNextCapsule()
;@ path: game/capsules
;@ Draws the next capsule (object 1, at $C210) into shadow OAM entry 6.
;@ writes: hObjCount, hOAMPtrLo, hOAMPtrHi
;@ test: mem[0xC210] = 0; mem[0xC211] = rand(0x10, 0x90); mem[0xC212] = rand(0x10, 0x90); mem[0xC213] = rand(0, 0x17)
;@ test: for k in range(4, 16): mem[0xC210 + k] = 0
;@ sig: f0889d6a
DrawNextCapsule::
;> hObjCount = 1
	ld a, $01
	ldh [hObjCount], a
;> hOAMPtrLo = 0x18
;> hOAMPtrHi = 0xC0
	ld a, $18
	ldh [hOAMPtrLo], a
	ld a, $c0
	ldh [hOAMPtrHi], a
;> DrawObjects(0xC210)
	ld hl, wNextCapsule
	call DrawObjects
	ret


DrawWallColumn::
	db $06, $20, $3e, $8e, $11, $20, $00, $77, $19, $05, $20, $fb, $c9

;@ def TimerHandler()
;@ path: system/interrupts
;@ The timer interrupt runs the sound engine. During the demo, requested sound
;@ effects are dropped (unless $D054 lets one through, as the title's beeps do).
;@ reads: hDemoMode, $D054, wDemoSFXOK
;@ writes: wSFXRequest, wNoiseSFXRequest, $D054, wDemoSFXOK
;@ test: skip runs the sound engine from an interrupt
;@ sig: faad8bca
TimerHandler::
;> enable_interrupts()
	ei
;>@c if not wDemoSFXOK and hDemoMode:
;>@q     wSFXRequest = 0
;>@q2     wNoiseSFXRequest = 0
;>@go wDemoSFXOK = 0
;>@go2 UpdateSound()
;>@go3 return                                      # registers restored, reti
;=@c
	push af
	ld a, [wDemoSFXOK]
	and a
	jr nz, jr_000_206a

	ldh a, [hDemoMode]
	and a
	jr nz, jr_000_2079

;=@go
jr_000_206a:
	xor a
	ld [wDemoSFXOK], a
	push bc
	push de
	push hl
;=@go2
	call UpdateSound
	pop hl
	pop de
	pop bc
;=@go3
	pop af
	reti


;=@q
jr_000_2079:
	xor a
	ld [wSFXRequest], a
;=@q2
	ld [wNoiseSFXRequest], a
	jr jr_000_206a

;@ def LCDCHandler()
;@ path: system/interrupts
;@ The STAT interrupt is not used.
;@ sig: 2d0d85fd
LCDCHandler::
;> return                                          # reti
	reti


ObjCapsuleTemplate::
	db $00, $20, $30, $00, $00, $00, $00, $ff

ObjNextTemplate::
	db $00, $3b, $6a, $00, $00, $00, $00, $ff
ObjUnusedTemplate::
	db $00, $14, $30, $00, $00, $00, $00, $ff

ObjNextDemoTemplate::
	db $00, $3b, $6a, $10, $00, $00, $00, $ff

;@ def ClearBGMap0()
;@ path: gfx/tilemaps
;@ Fills BG map 0 with tile $FF.
;@ sig: 47f05215
ClearBGMap0::
;> fill(vBGMap0, 0xFF, 0x400)                  # from the end, downwards
	ld hl, $9bff
	ld bc, $0400

jr_000_20a9:
	ld a, $ff
	ld [hld], a
	dec bc
	ld a, b
	or c
	jr nz, jr_000_20a9

;> return
	ret


;@ def CopyBytes(src: hl, dest: de, count: bc)
;@ path: lib/memory
;@ Copies `count` bytes from src to dest, front to back.
;@ A count of 0 copies 64 KiB.
;@ clobbers: a, bc, de, hl
;@ test: count = rand(1, 0x100)
;@ test: src = rand(0x0000, 0xDE00)
;@ test: dest = rand_ram(count)
;@ sig: 994589e5
CopyBytes::
;>@loop for i in range(count or 0x10000):
;>     mem[dest + i] = mem[src + i]
	ld a, [hli]
	ld [de], a
	inc de
;=@loop
	dec bc
	ld a, b
	or c
	jr nz, CopyBytes

;> return
	ret


;@ def LoadGameTiles()
;@ path: gfx/tiles
;@ Copies the game's tile graphics ($17FF bytes from $3D9E) into VRAM.
;@ sig: 3969451e
LoadGameTiles::
;> CopyBytes(0x3D9E, vTiles0, 0x17FF)
	ld hl, $3d9e
	ld de, $8000
	ld bc, $17ff
	call CopyBytes
;> return
	ret


;@ def UnusedState1C()
;@ path: game/end
;@ Game state $1C does nothing.
;@ sig: 30ba9599
UnusedState1C::
;> return
	ret


;@ def LoadScreen(src: de) -> de
;@ path: gfx/tilemaps
;@ A full screen (20x18 tiles) from src into BG map 0.
;@ test: src = rand(0x0000, 0x7000)
;@ sig: 381aeeb3
LoadScreen::
;> return LoadScreenAt(src, vBGMap0)            # falls through
	ld hl, $9800

;@ def LoadScreenAt(src: de, dest: hl) -> de
;@ path: gfx/tilemaps
;@ A full screen (20x18 tiles) from src into the BG map at dest.
;@ test: src = rand(0x0000, 0x7000)
;@ test: dest = rng.choice([0x9800, 0x9C00])
;@ sig: e43ac431
LoadScreenAt::
;> return CopyTilemapRows(src, dest, 18)        # falls through
	ld b, $12

;@ def CopyTilemapRows(src: de, dest: hl, rows: b) -> de
;@ path: gfx/tilemaps
;@ Copies `rows` rows of 20 tiles from src into the BG map at dest. BG map
;@ rows are 32 tiles apart. Returns the end of the source data.
;@ clobbers: a, bc, hl
;@ test: rows = rand(1, 18)
;@ test: src = rand(0x0000, 0x7000)
;@ test: dest = rand(0x8000, 0xDA00)
;@ sig: 10e6fe2f
CopyTilemapRows::
;>@rows for _ in range(rows):
	push hl
;>@col     for col in range(20):
	ld c, $14

;>         mem[dest + col] = mem[src]
.copyRow
	ld a, [de]
	ld [hli], a
;>         src += 1
	inc de
;=@col
	dec c
	jr nz, .copyRow

;>     dest += 32                                   # next BG map row
	pop hl
	push de
	ld de, $0020
	add hl, de
	pop de
;=@rows
	dec b
	jr nz, CopyTilemapRows

;> return src
	ret


;@ def LoadBGMap1Panel(src: de) -> de
;@ path: gfx/tilemaps
;@ Copies 24 rows of 9 tiles from src to the left of BG map 1.
;@ test: src = rand(0x0000, 0x7000)
;@ sig: 28b5318f
LoadBGMap1Panel::
;> dest = vBGMap1
	ld hl, $9c00
;>@rows for _ in range(24):
	ld b, $18

jr_000_20e7:
	push hl
;>@cols     for i in range(9):
	ld c, $09

;>         mem[dest + i] = mem[src]
;>         src += 1
jr_000_20ea:
	ld a, [de]
	ld [hli], a
	inc de
;=@cols
	dec c
	jr nz, jr_000_20ea

;>     dest += 32                          # next BG map row
	pop hl
	push de
	ld de, $0020
	add hl, de
	pop de
;=@rows
	dec b
	jr nz, jr_000_20e7

;> return src
	ret



;@ def RoundOver()
;@ path: versus/results
;@ Game state $12: a link round is over. Plays the round jingle (song 4),
;@ or song 6 once a side has three wins; the loser's panel virus laughs, the
;@ winner's Dr. Mario cheers. When the master presses Start it sends $E8 and
;@ both sides clear up for the next round (state $15).
;@ reads: hRoundResult, hSerialRole, hSerialRx, hJoyPressed, hTimer2, hRedrawRow, $D042, wJinglePlayed
;@ writes: hDangerLevel, wMusicRequest, hSerialTx, rLCDC, hRedrawRow, hGameState, $D042, $D04B, wJinglePlayed, wShowResults
;@ test: skip calls helpers not translated yet
;@ sig: 48770567
RoundOver::
;> hDangerLevel = 0
	ld de, wMusicRequest
	xor a
	ldh [hDangerLevel], a
;> if not wJinglePlayed:                             # once
	ld a, [wJinglePlayed]
	and a
	jr nz, jr_000_211f

;>     wMusicRequest = 4
	ld a, $04
	ld [de], a
;>     if wWins1 == 3 or wWins2 == 3:    # the match is decided
	ld hl, wWins1
	ld a, [hli]
	cp $03
	jr z, jr_000_2117

	ld a, [hl]
	cp $03
	jr nz, jr_000_211a

jr_000_2117:
;>         wMusicRequest = 6
	ld a, $06
	ld [de], a

jr_000_211a:
;>     wJinglePlayed = 1
	ld a, $01
	ld [wJinglePlayed], a

jr_000_211f:
;> UpdateBottle()
	call UpdateBottle
;> if hRedrawRow:
;>     return
	ldh a, [hRedrawRow]
	and a
	ret nz

;> if hRoundResult == 0xFD:
;>     LaughPanelVirus()                           # this side lost
	ldh a, [hRoundResult]
	cp $fd
	jr nz, jr_000_2131

	call LaughPanelVirus
	jr jr_000_2134

;> else:
;>     CheerMario()
jr_000_2131:
	call CheerMario

jr_000_2134:
;> if hSerialRole != SERIAL_MASTER:
	ldh a, [hSerialRole]
	cp $30
	jr z, jr_000_2141

;>     if hSerialRx != 0xE8:                       # wait for the master
;>         return
;>@m else:
;>@m2     if hJoyPressed != BTN_START or hTimer2:
;>@m3         return
;>@m4     hSerialTx = 0xE8
;=@m
	ldh a, [hSerialRx]
	cp $e8
	jr z, jr_000_214e

	ret


jr_000_2141:
;=@m2
	ldh a, [hJoyPressed]
	cp $08
	ret nz

	ldh a, [hTimer2]
;=@m3
	and a
	ret nz

;=@m4
	ld a, $e8
	ldh [hSerialTx], a

jr_000_214e:
;> rLCDC = 0x83                                    # window off
	ld a, $83
	ldh [rLCDC], a
;> HideWinCrowns()
	call HideWinCrowns
;> wShowResults = 0
	xor a
	ld [wShowResults], a
;> MarioFrontBG()
	call MarioFrontBG
;> InitSound()
	call InitSound
;> ClearShadowOAMFrom6()
	call ClearShadowOAMFrom6
;> ClearBottleRows()
	call ClearBottleRows
;> hRedrawRow = 0x10
	ld a, $10
	ldh [hRedrawRow], a
;> hGameState = 0x15                               # NextRound
	ld a, $15
	ldh [hGameState], a
;> wJinglePlayed = 0
	xor a
	ld [wJinglePlayed], a
	ret


;@ def MarioFrontBG()
;@ path: versus/results
;@ Puts Dr. Mario's 10 sprites (shadow OAM entry 8 on) in front of the background again.
;@ sig: 0fe3310b
MarioFrontBG::
;> for i in range(10):
;>     mem[0xC023 + 4 * i] &= 0x7F
	ld hl, wShadowOAM + $23
	ld de, $0004
	ld b, $0a

jr_000_217a:
	res 7, [hl]
	add hl, de
	dec b
	jr nz, jr_000_217a

	ret


;@ def CheerMario()
;@ path: versus/results
;@ The round's winner: every 16 frames Dr. Mario switches between the
;@ throwing pose and an arms-up frame (three tiles from CheerTiles).
;@ reads: hFrameCount
;@ test: hFrameCount = rng.choice([0, 16, 5]); mem[0xD03F] = rand(0, 1)
;@ sig: bc9656d9
CheerMario::
;> if hFrameCount & 0x0F:
;>     return
	ldh a, [hFrameCount]
	and $0f
	ret nz

;> wCheerFrame ^= 1
;> if wCheerFrame:
	ld hl, wShadowOAM + $22
	ld de, $0004
	ld bc, wCheerFrame
	ld a, [bc]
	xor $01
	ld [bc], a
	jr z, jr_000_21a2

;>     DrawMarioThrowSprite()
;>@up else:
;>@up2     i = 0
;>@up3     while mem[CheerTiles + i] != 0xFD:
;>@up4         mem[0xC022 + 4 * i] = mem[CheerTiles + i]
;>@up5         i += 1
	call DrawMarioThrowSprite
	ret


;=@up3
jr_000_2199:
	ld a, [bc]
	cp $fd
	ret z

	ld [hl], a
	add hl, de
	inc bc
	jr jr_000_2199

;=@up2
jr_000_21a2:
	ld bc, $21ab
	jr jr_000_2199

	db $ff, $1c, $1d, $fd

CheerTiles::
	db $3c, $2e, $2f, $fd

;@ def NextRound()
;@ path: versus/results
;@ Game state $15: after the bottle is redrawn, the next round (state $09),
;@ or, if a side has three wins, back to the options screen (state $14)
;@ with the wins cleared.
;@ writes: hCapsuleState, hToppedOut, hGameState
;@ reads: $D000, $D001, hRedrawRow, wWins1, wWins2
;@ test: skip calls helpers not translated yet
;@ sig: b9a94e22
NextRound::
;> hCapsuleState = 0
;> hToppedOut = 0
	xor a
	ldh [hCapsuleState], a
	ldh [hToppedOut], a
;> UpdateBottle()
	call UpdateBottle
;> if hRedrawRow:
;>     return
	ldh a, [hRedrawRow]
	and a
	ret nz

;> state = 0x14                                    # OptionsInit2P
;> if wWins1 >= 3 or wWins2 >= 3:        # the match is over
;>@over     wWins1 = 0
;>@over2     wWins2 = 0
;>@over3     ClearShadowOAM()
;> else:
;>     state = 0x09                                # LevelInit
	ld b, $14
	ld a, [wWins1]
	cp $03
	jp nc, Jump_000_21d1

	ld a, [wWins2]
	cp $03
	jp nc, Jump_000_21d1

	ld b, $09
	jr jr_000_21dc

;=@over
Jump_000_21d1:
	ld hl, wWins1
	xor a
	ld [hli], a
	ld [hl], a
	push bc
;=@over3
	call ClearShadowOAM
	pop bc

;> hGameState = state
jr_000_21dc:
	ld a, b
	ldh [hGameState], a
;> ClearShadowOAMFrom6()
	call ClearShadowOAMFrom6
	ret


;@ def LoadOptionsScreen()
;@ path: screens/options
;@ With the LCD off, loads the options tiles and tilemap, writes the number of
;@ players into the map and copies the initial sprites into the shadow OAM.
;@ reads: hTwoPlayer
;@ writes: $9844, $FFE4, hDemoMode
;@ test: skip switches the LCD off
;@ sig: 6b50f87c
LoadOptionsScreen::
;> DisableLCD()
	call DisableLCD
;> hDemoMode = 0
	xor a
	ldh [hDemoMode], a
;> CopyBytes(0x4D9E, vTiles0, 0x300)               # 48 tiles
	ld de, $8000
	ld hl, $4d9e
	ld bc, $0300
	call CopyBytes
;> LoadScreen(0x5ABE)
	ld de, $5abe
	call LoadScreen
;> mem[0x9844] = hTwoPlayer + 1                    # digit tile: 1 or 2 players
	ldh a, [hTwoPlayer]
	inc a
	ld [$9844], a
;> CopyUntilFF(0x05E7, wShadowOAM)                 # the options sprites
	ld hl, wShadowOAM
	ld de, $05e7
	rst $18
	ret


;@ def ShowOptionsScreen()
;@ path: screens/options
;@ Draws the three choices, switches the LCD on, clears the link bytes and
;@ highlights the virus level box.
;@ writes: hSerialTx, hSerialRx
;@ test: skip waits for the LCD
;@ sig: bbc4c343
ShowOptionsScreen::
;> DrawVirusLevel()
	call DrawVirusLevel
;> DrawSpeed()
	call DrawSpeed
;> DrawMusicType()
	call DrawMusicType
;> rLCDC = 0x83
	ld a, $83
	ldh [rLCDC], a
;> hSerialTx = 0
	xor a
	ldh [hSerialTx], a
;> hSerialRx = 0
	ldh [hSerialRx], a
;> FrameVirusLevel()                               # falls through

;@ def FrameVirusLevel()
;@ path: screens/options
;@ reads: wCurrentSong
;@ writes: wMusicRequest
;@ Draws the highlighted frame around the virus level box (tiles $93-$9A) and
;@ makes sure the options music (song 3) is playing.
;@ test: skip waits for the LCD
;@ sig: 6228bca2
FrameVirusLevel::
;> DrawColumn3VRAM(0x9863, 0x93, 3, 2)             # left edge
	ld hl, $9863
	ld a, $93
	ld bc, $0302
	call DrawColumn3VRAM
;> DrawColumn3VRAM(0x986F, 0x95, 2, 3)             # right edge
	ld hl, $986f
	ld a, $95
	ld bc, $0203
	call DrawColumn3VRAM
;> FillRowVRAM(0x9864, 0x94, 11)                   # top edge
	ld hl, $9864
	ld a, $94
	ld b, $0b
	call FillRowVRAM
;> FillRowVRAM(0x98A4, 0x99, 11)                   # bottom edge
	ld hl, $98a4
	ld a, $99
	ld b, $0b
	call FillRowVRAM
;> if wCurrentSong != 3:
;>     wMusicRequest = 3
	ld hl, wCurrentSong
	ld a, $03
	cp [hl]
	ret z

	ld [wMusicRequest], a
	ret


;@ def DisableLCD()
;@ path: system/lcd
;@ Switches the LCD off safely: waits for line $91 (inside VBlank) with the
;@ VBlank interrupt masked, then clears LCDC bit 7.
;@ writes: hSavedIE
;@ reads: hSavedIE
;@ test: skip waits for the LCD
;@ sig: cd7f764e
DisableLCD::
;> hSavedIE = rIE
	ldh a, [rIE]
	ldh [hSavedIE], a
;> rIE = hSavedIE & 0xFE                        # no VBlank interrupt meanwhile
	res 0, a
	ldh [rIE], a

;> wait_ly(0x91)
jr_000_2258:
	ldh a, [rLY]
	cp $91
	jr nz, jr_000_2258

;> rLCDC &= 0x7F                               # LCD off
	ldh a, [rLCDC]
	and $7f
	ldh [rLCDC], a
;> rIF = 0
	xor a
	ldh [rIF], a
;> rIE = hSavedIE
	ldh a, [hSavedIE]
	ldh [rIE], a
;> return
	ret


;@ def DrawClearText()
;@ path: game/end
;@ 1 player: CLEAR in the middle of the bottle.
;@ reads: hTwoPlayer
;@ test: hTwoPlayer = rng.choice([0, 1])
;@ sig: 91526757
DrawClearText::
;> if hTwoPlayer:
;>     return
	ldh a, [hTwoPlayer]
	and a
	ret nz

;> CopyRowsUntilFD(TextClear, 0xC859)
	ld hl, wBottle + $59
	ld de, $1104
	call CopyRowsUntilFD
	ret


;@ def DrawMissText()
;@ path: game/end
;@ 1 player: MISS in the bottle.
;@ reads: hTwoPlayer
;@ test: hTwoPlayer = rng.choice([0, 1])
;@ sig: eaea9bf8
DrawMissText::
;> if hTwoPlayer:
;>     return
	ldh a, [hTwoPlayer]
	and a
	ret nz

;> CopyRowsUntilFD(TextMiss, 0xC85A)
	ld hl, wBottle + $5A
	ld de, $10ff
	call CopyRowsUntilFD
	ret


;@ def DrawYouWinText()
;@ path: versus/results
;@ 2 players: YOU / WIN! in the bottle.
;@ reads: hTwoPlayer
;@ test: hTwoPlayer = rng.choice([0, 1])
;@ sig: aa20b150
DrawYouWinText::
;> if not hTwoPlayer:
;>     return
	ldh a, [hTwoPlayer]
	and a
	ret z

;> CopyRowsUntilFD(TextYouWin, 0xC848)
	ld hl, wBottle + $48
	ld de, $110a
	call CopyRowsUntilFD
	ret


;@ def DrawYouLostText()
;@ path: versus/results
;@ 2 players: YOU / LOST in the bottle.
;@ reads: hTwoPlayer
;@ test: hTwoPlayer = rng.choice([0, 1])
;@ sig: c58283ce
DrawYouLostText::
;> if not hTwoPlayer:
;>     return
	ldh a, [hTwoPlayer]
	and a
	ret z

;> CopyRowsUntilFD(TextYouLost, 0xC830)
	ld hl, wBottle + $30
	ld de, $1113
	call CopyRowsUntilFD
	ret


;@ def DrawDrawText()
;@ path: versus/results
;@ 2 players: DRAW in the bottle, two rows higher if this side topped out.
;@ reads: $FFF4, hRoundResult
;@ test: mem[0xFFF4] = rng.choice([0, 0xFD])
;@ sig: 999dcd5d
DrawDrawText::
;> dest = 0xC832 if hRoundResult == 0xFD else 0xC84A
	ld hl, wBottle + $4A
	ldh a, [hRoundResult]
	cp $fd
	jr nz, jr_000_22b0

	ld hl, wBottle + $32

jr_000_22b0:
;> CopyRowsUntilFD(TextDraw, dest)
	ld de, $1134
	call CopyRowsUntilFD
	ret


;@ def ClearBottleFromRow5()
;@ path: game/end
;@ Blanks the bottle from row 5 down (tile $FE) to make room for a message.
;@ sig: 2d1ae7d7
ClearBottleFromRow5::
;> FillBytes(0xC828, 0xFE, 0x58)
	ld hl, wBottle + $28
	ld b, $58
	ld a, $fe
	call FillBytes
	ret


;@ def ClearBottleFromRow8()
;@ path: game/end
;@ Blanks the bottle from row 8 down.
;@ sig: bb1b71fa
ClearBottleFromRow8::
;> FillBytes(0xC840, 0xFE, 0x40)
	ld hl, wBottle + $40
	ld b, $40
	ld a, $fe
	call FillBytes
	ret


;@ def ClearBottleFromRow10()
;@ path: game/end
;@ Blanks the bottle from row 10 down.
;@ sig: 70dd2039
ClearBottleFromRow10::
;> FillBytes(0xC850, 0xFE, 0x30)
	ld hl, wBottle + $50
	ld b, $30
	ld a, $fe
	call FillBytes
	ret


;@ def DrawPushStart()
;@ path: game/end
;@ PUSH / START! at the bottom of the bottle; a link slave gets PLEASE / WAIT
;@ instead, since the master decides when to go on.
;@ reads: hTwoPlayer, hSerialRole
;@ test: hTwoPlayer = rng.choice([0, 1]); hSerialRole = rng.choice([SERIAL_MASTER, SERIAL_SLAVE])
;@ sig: 3beec7ef
DrawPushStart::
;> if hTwoPlayer:
	ldh a, [hTwoPlayer]
	and a
	jr z, jr_000_2309

;>     if hSerialRole != SERIAL_SLAVE:
	ldh a, [hSerialRole]
	cp $60
	jr z, jr_000_22f6

;>         CopyRowsUntilFD(TextPush, 0xC872)
	ld hl, wBottle + $72
	ld de, $111c
	call CopyRowsUntilFD
;>         CopyRowsUntilFD(TextStart, 0xC879)
	ld hl, wBottle + $79
	ld de, $1121
	call CopyRowsUntilFD
	ret


;>     else:
;>         CopyRowsUntilFD(TextPlease, 0xC871)
jr_000_22f6:
	ld hl, wBottle + $71
	ld de, $1128
	call CopyRowsUntilFD
;>         CopyRowsUntilFD(TextWait, 0xC87A)
	ld hl, wBottle + $7A
	ld de, $112f
	call CopyRowsUntilFD
	ret


;> else:
;>     CopyRowsUntilFD(TextPush, 0xC869)
jr_000_2309:
	ld hl, wBottle + $69
	ld de, $111c
	call CopyRowsUntilFD
;>     CopyRowsUntilFD(TextStart, 0xC872)
	ld hl, wBottle + $72
	ld de, $1121
	call CopyRowsUntilFD
	ret


;@ def ReadJoypad()
;@ path: system/input
;@ Reads all eight buttons into hJoyHeld and works out which of them were
;@ pressed since the last call (hJoyPressed).
;@ reads: hJoyHeld
;@ writes: hJoyHeld, hJoyPressed
;@ clobbers: a, b, c
;@ sig: a0c59ef9
ReadJoypad::
;> rP1 = 0x20                                  # select the d-pad
	ld a, $20
	ldh [rP1], a
;> pins = rP1                                  # read 4 times to let the lines settle
	ldh a, [rP1]
	ldh a, [rP1]
	ldh a, [rP1]
	ldh a, [rP1]
;> dpad = (~pins & 0x0F) << 4
	cpl
	and $0f
	swap a
	ld b, a
;> rP1 = 0x10                                  # select A/B/Select/Start
	ld a, $10
	ldh [rP1], a
;> pins = rP1                                  # read 10 times
	ldh a, [rP1]
	ldh a, [rP1]
	ldh a, [rP1]
	ldh a, [rP1]
	ldh a, [rP1]
	ldh a, [rP1]
	ldh a, [rP1]
	ldh a, [rP1]
	ldh a, [rP1]
	ldh a, [rP1]
;> buttons = ~pins & 0x0F
	cpl
	and $0f
;> held = dpad | buttons
	or b
	ld c, a
;> hJoyPressed = held & ~hJoyHeld              # down now, but not last time
	ldh a, [hJoyHeld]
	xor c
	and c
	ldh [hJoyPressed], a
;> hJoyHeld = held
	ld a, c
	ldh [hJoyHeld], a
;> rP1 = 0x30                                  # deselect both groups
	ld a, $30
	ldh [rP1], a
;> return
	ret


;@ def CoordsToBGMapAddr() -> hl
;@ path: gfx/tilemaps
;@ The BG map 0 address under a sprite position (hCoordY, hCoordX in OAM
;@ space), also kept in hBGMapAddr.
;@ reads: hCoordY, hCoordX
;@ writes: hBGMapAddr
;@ test: hCoordY = rand(0x10, 0xA0); hCoordX = rand(0x08, 0xA8)
;@ sig: 5d7cd530
CoordsToBGMapAddr::
;> row = ((hCoordY - 0x10) & 0xFF) >> 3
	ldh a, [hCoordY]
	sub $10
	srl a
	srl a
	srl a
;> addr = 0x9800 + 32 * row
	ld de, $0000
	ld e, a
	ld hl, $9800
	ld b, $20

jr_000_236c:
	add hl, de
	dec b
	jr nz, jr_000_236c

;> addr += ((hCoordX - 8) & 0xFF) >> 3
	ldh a, [hCoordX]
	sub $08
	srl a
	srl a
	srl a
	ld de, $0000
	ld e, a
	add hl, de
;> hBGMapAddr = addr                              # ($FFB4 low byte, $FFB5 high byte)
;> return addr
	ld a, h
	ldh [hBGMapAddr + 1], a
	ld a, l
	ldh [hBGMapAddr], a
	ret


OAMDMARoutine::
	db $3e, $c0, $e0, $46, $3e, $28, $3d, $20, $fd, $c9

;@ def DrawObjects(obj: hl)
;@ path: gfx/objects
;@ The metasprite engine. Draws hObjCount objects (16 bytes each, starting at
;@ `obj`) into the shadow OAM at hOAMPtrHi:hOAMPtrLo, moving that pointer on.
;@ An object's sprite id picks a sprite from SpriteTable: a list of tiles
;@ placed on a grid of (y, x) offsets, where $FE leaves a cell empty, $FD
;@ mirrors the next tile and $FF ends the list.
;@ reads: hObjCount, hOAMPtrHi, hOAMPtrLo, hObjHidden
;@ writes: hObjState, hObjY, hObjX, hObjSprite, hObjAttrBits, hObjFlip, hObjAttr, hSpriteYOff, hSpriteXOff, hTileX, hTileY, hTileAttr, hObjHidden, hObjPtrHi, hObjPtrLo, hObjCount, hOAMPtrHi, hOAMPtrLo
;@ test: obj = 0xC200
;@ test: hObjCount = rand(1, 4)
;@ test: hOAMPtrHi = 0xC0
;@ test: hOAMPtrLo = 0
;@ test: hObjHidden = 0
;@ test: for i in range(4): mem[0xC200 + 16 * i] = rng.choice([0, 0, 0x80, 1])
;@ test: for i in range(4): mem[0xC203 + 16 * i] = rand(0, 0x5D)
;@ sig: c3a6560a
DrawObjects::
;>@obj while True:
;>     hObjPtrHi = hi(obj)
	ld a, h
	ldh [hObjPtrHi], a
;>     hObjPtrLo = lo(obj)
	ld a, l
	ldh [hObjPtrLo], a
;>     if mem[obj] in (0x00, 0x80):                  # any other state: not drawn
	ld a, [hl]
	and a
	jr z, .draw

	cp $80
	jr z, .hidden

;=@ptr
.next
	ldh a, [hObjPtrHi]
	ld h, a
	ldh a, [hObjPtrLo]
	ld l, a
;=@add16
	ld de, $0010
	add hl, de
;=@count
	ldh a, [hObjCount]
	dec a
	ldh [hObjCount], a
;=@done
	ret z

;=@obj
	jr DrawObjects

;=@end0
.endOfSprite
	xor a
	ldh [hObjHidden], a
;=@endbrk
	jr .next

;>         if mem[obj] == 0x80: hObjHidden = 0x80     # hidden: its tiles get Y = $FF
.hidden
	ldh [hObjHidden], a

;>@copy         for k in range(7):                        # hObjState ... hObjAttr
.draw
	ld b, $07
	ld de, hObjState

;>             mem[addr(hObjState) + k] = mem[obj + k]
.copy
	ld a, [hli]
	ld [de], a
	inc de
;=@copy
	dec b
	jr nz, .copy

;>         entry = SpriteTable + 2 * hObjSprite
	ldh a, [hObjSprite]
	ld hl, SpriteTable
	rlca
	ld e, a
	ld d, $00
	add hl, de
;>         header = mem16[entry]
	ld e, [hl]
	inc hl
	ld d, [hl]
;>         tiles = mem16[header]
	ld a, [de]
	ld l, a
	inc de
	ld a, [de]
	ld h, a
;>         hSpriteYOff = mem[header + 2]
	inc de
	ld a, [de]
	ldh [hSpriteYOff], a
;>         hSpriteXOff = mem[header + 3]
	inc de
	ld a, [de]
	ldh [hSpriteXOff], a
;>         offsets = mem16[tiles]                    # a (y, x) pair per grid cell
;>         p = tiles + 1
	ld e, [hl]
	inc hl
	ld d, [hl]

;>@tile         while True:
;>             p += 1
.nextTile
	inc hl
;>             hTileAttr = hObjAttr
	ldh a, [hObjAttr]
	ldh [hTileAttr], a
;>             tile = mem[p]
	ld a, [hl]
;>             if tile == 0xFF:
	cp $ff
	jr z, .endOfSprite

;>@end0                 hObjHidden = 0
;>@endbrk                 break
;>             if tile == 0xFD:                      # mirror the next tile
	cp $fd
	jr nz, .notMirrored

;>                 hTileAttr = hObjAttr ^ 0x20
	ldh a, [hObjAttr]
	xor $20
	ldh [hTileAttr], a
;>                 p += 1
	inc hl
;>                 tile = mem[p]
	ld a, [hl]
;>@elif             elif tile == 0xFE:                    # empty cell
;>@skip                 offsets += 2
;>@cont                 continue
;=@elif
	jr .emit

;=@skip
.skipCell
	inc de
	inc de
;=@cont
	jr .nextTile

;=@elif
.notMirrored
	cp $fe
	jr z, .skipCell

;>             hObjSprite = tile
.emit
	ldh [hObjSprite], a
;>             cell_y = mem[offsets]
	ldh a, [hObjY]
	ld b, a
	ld a, [de]
	ld c, a
;>             if not hObjFlip & 0x40:
	ldh a, [hObjFlip]
	bit 6, a
	jr nz, .flipY

;>                 s = hSpriteYOff + hObjY
	ldh a, [hSpriteYOff]
	add b
;>                 y = s + cell_y + (s > 0xFF)      # adc: the first carry counts too
	adc c
;>             else:                                 # flipped vertically
	jr .storeY

;>                 d = hObjY - hSpriteYOff
.flipY
	ld a, b
	push af
	ldh a, [hSpriteYOff]
	ld b, a
	pop af
	sub b
;>                 d2 = u8(d) - cell_y - (d < 0)
	sbc c
;>                 y = d2 - 8 - (d2 < 0)
	sbc $08

;>             hTileY = y
.storeY
	ldh [hTileY], a
;>@cellx             cell_x = mem[offsets + 1]
	ldh a, [hObjX]
	ld b, a
	inc de
	ld a, [de]
;>             offsets += 2
	inc de
;=@cellx
	ld c, a
;>             if not hObjFlip & 0x20:
	ldh a, [hObjFlip]
	bit 5, a
	jr nz, .flipX

;>                 s = hSpriteXOff + hObjX
	ldh a, [hSpriteXOff]
	add b
;>                 x = s + cell_x + (s > 0xFF)
	adc c
;>             else:                                 # flipped horizontally
	jr .storeX

;>                 d = hObjX - hSpriteXOff
.flipX
	ld a, b
	push af
	ldh a, [hSpriteXOff]
	ld b, a
	pop af
	sub b
;>                 d2 = u8(d) - cell_x - (d < 0)
	sbc c
;>                 x = d2 - 8 - (d2 < 0)
	sbc $08

;>             hTileX = x
.storeX
	ldh [hTileX], a
;>             oam = hOAMPtrHi << 8 | hOAMPtrLo
	push hl
	ldh a, [hOAMPtrHi]
	ld h, a
	ldh a, [hOAMPtrLo]
	ld l, a
;>             if hObjHidden:
	ldh a, [hObjHidden]
	and a
	jr z, .visible

;>                 oam_y = 0xFF
	ld a, $ff
;>             else:
	jr .writeY

;>                 oam_y = hTileY
.visible
	ldh a, [hTileY]

;>             mem[oam] = oam_y
.writeY
	ld [hli], a
;>             mem[oam + 1] = hTileX
	ldh a, [hTileX]
	ld [hli], a
;>             mem[oam + 2] = hObjSprite
	ldh a, [hObjSprite]
	ld [hli], a
;>             attr = hTileAttr | hObjFlip
	ldh a, [hTileAttr]
	ld b, a
	ldh a, [hObjFlip]
	or b
	ld b, a
;>             mem[oam + 3] = attr | hObjAttrBits
	ldh a, [hObjAttrBits]
	or b
	ld [hli], a
;>             hOAMPtrHi = hi(oam + 4)
	ld a, h
	ldh [hOAMPtrHi], a
;>             hOAMPtrLo = lo(oam + 4)
	ld a, l
	ldh [hOAMPtrLo], a
;=@tile
	pop hl
	jp .nextTile

;>@ptr     obj = hObjPtrHi << 8 | hObjPtrLo
;>@add16     obj += 16
;>@count     hObjCount -= 1
;>@done     if hObjCount == 0: return


;@ asset: sprites count=$18 tiles=LoadGameTiles
;@ The 24 capsule sprites the object engine draws: every pair of the three
;@ colours (checkered, dark, light), lying (even ids) and standing (odd ids).
SpriteTable::
	db $9b, $24, $9f, $24, $a3, $24, $a7, $24, $ab, $24, $af, $24, $b3, $24, $b7, $24
	db $bb, $24, $bf, $24, $c3, $24, $c7, $24, $cb, $24, $cf, $24, $d3, $24, $d7, $24
	db $db, $24, $df, $24, $e3, $24, $e7, $24, $eb, $24, $ef, $24, $f3, $24, $f7, $24
	db $fb, $24, $ff, $00, $00, $25, $f7, $00, $05, $25, $ff, $00, $0a, $25, $f7, $00
	db $0f, $25, $ff, $00, $14, $25, $f7, $00, $19, $25, $ff, $00, $1e, $25, $f7, $00
	db $23, $25, $ff, $00, $28, $25, $f7, $00, $2d, $25, $ff, $00, $32, $25, $f7, $00
	db $37, $25, $ff, $00, $3c, $25, $f7, $00, $41, $25, $ff, $00, $46, $25, $f7, $00
	db $4b, $25, $ff, $00, $50, $25, $f7, $00, $55, $25, $ff, $00, $5a, $25, $f7, $00
	db $5f, $25, $ff, $00, $64, $25, $f7, $00, $69, $25, $ff, $00, $6e, $25, $f7, $00
	db $73, $25, $80, $90, $ff, $77, $25, $a0, $b0, $ff, $73, $25, $80, $90, $ff, $77
	db $25, $a0, $b0, $ff, $73, $25, $80, $91, $ff, $77, $25, $a0, $b1, $ff, $73, $25
	db $81, $90, $ff, $77, $25, $a1, $b0, $ff, $73, $25, $80, $92, $ff, $77, $25, $a0
	db $b2, $ff, $73, $25, $82, $90, $ff, $77, $25, $a2, $b0, $ff, $73, $25, $81, $91
	db $ff, $77, $25, $a1, $b1, $ff, $73, $25, $81, $91, $ff, $77, $25, $a1, $b1, $ff
	db $73, $25, $81, $92, $ff, $77, $25, $a1, $b2, $ff, $73, $25, $82, $91, $ff, $77
	db $25, $a2, $b1, $ff, $73, $25, $82, $92, $ff, $77, $25, $a2, $b2, $ff, $73, $25
	db $82, $92, $ff, $77, $25, $a2, $b2, $ff, $00, $00, $00, $08, $00, $00, $08, $00

;@ def DrawBCD7(src: de, dest: hl)
;@ path: gfx/numbers
;@ Draws a 7-digit BCD number (4 bytes, src = the most significant one,
;@ going down) at dest if hDrawBCDFlag is set: leading zeros are blank
;@ (tile $FE; the top digit's place is skipped), the last digit always
;@ shows. Clears the flag.
;@ writes: hDrawBCDFlag
;@ reads: hDrawBCDFlag
;@ test: hDrawBCDFlag = rng.choice([0, 1, 1])
;@ test: base = rand_ram(4); fill_bcd(base, 4); src = base + 3
;@ test: dest = rand_ram(8)
;@ sig: dbe16460
DrawBCD7::
;> if not hDrawBCDFlag: return
	ldh a, [hDrawBCDFlag]
	and a
	ret z

;> top = mem[src] & 0x0F                        # the 7th digit: low nibble of the top byte
;> src = (src & 0xFF00) | lo(src - 1)
	ld a, [de]
	dec e
	and $0f
;> if top:
	jr z, jr_000_258c

;>     mem[dest] = top
;>     dest += 1
;>@one     printed = 1
	ld [hli], a
	ld c, $03
	ld a, $01
	jr jr_000_2590

;> else:
;>     dest += 1                                # nothing drawn there
;>     printed = 0
jr_000_258c:
	inc l
	ld c, $03
	xor a

;> hDrawBCDFlag = printed
jr_000_2590:
	ldh [hDrawBCDFlag], a

;>@pair for c in (3, 2, 1):
;>     b = mem[src]
;>     high = b >> 4
jr_000_2592:
	ld a, [de]
	ld b, a
	swap a
	and $0f
;>     if high:
;>@hset         hDrawBCDFlag = 1
;>         tile = high
	jr nz, jr_000_25c2

;>     else:
;>         tile = 0 if hDrawBCDFlag else 0xFE    # blank while only zeros so far
	ldh a, [hDrawBCDFlag]
	and a
	ld a, $00
	jr nz, jr_000_25a3

	ld a, $fe

;>     mem[dest] = tile
;>     dest += 1
jr_000_25a3:
	ld [hli], a
;>     low = b & 0x0F
	ld a, b
	and $0f
;>     if low:
;>@lset         hDrawBCDFlag = 1
;>         tile = low
	jr nz, jr_000_25ca

;>     elif hDrawBCDFlag or c == 1:              # the last digit always shows
;>         tile = 0
	ldh a, [hDrawBCDFlag]
	and a
	ld a, $00
	jr nz, jr_000_25b9

	ld a, $01
	cp c
	ld a, $00
	jr z, jr_000_25b9

;>     else:
;>         tile = 0xFE
	ld a, $fe

;>     mem[dest] = tile
;>     dest += 1
jr_000_25b9:
	ld [hli], a
;>     src = (src & 0xFF00) | lo(src - 1)
	dec e
;=@pair
	dec c
	jr nz, jr_000_2592

;> hDrawBCDFlag = 0
	xor a
	ldh [hDrawBCDFlag], a
;> return
	ret


;=@hset
jr_000_25c2:
	push af
	ld a, $01
	ldh [hDrawBCDFlag], a
	pop af
	jr jr_000_25a3

;=@lset
jr_000_25ca:
	push af
	ld a, $01
	ldh [hDrawBCDFlag], a
	pop af
	jr jr_000_25b9

;@ def InitGameScreen()
;@ path: game/setup
;@ Puts the fixed parts of a game on screen and resets the game state: the
;@ speed written down the side, Dr. Mario and the magnifier viruses (1P) or
;@ the win markers (2P), an empty bottle, and lots of zeroed variables.
;@ reads: hSpeed, hTwoPlayer
;@ writes: hClearStep, hVirusCount, hVirusCount2P, hDemoTimer, $FF9D, $FF9F, $FFC8, $FFC9, $FFCA, $FFCE, $FFD3, $FFD4, $FFD8, $FFD9, $FFDB, $FFDC, $FFDD, $FFDE, $FFE5, $FFE6, $FFE7, $FFE8, $FFEF, $FFF3, $FFF4, $FFF5, $FFF6, $FFF7, $FFF8, $FFF9, $FFFA, $FFFB, $FFFC, hVirusColours, hViruses0, hViruses1, hViruses2, hVirusesPlaced, hVirusesPlacedBCD, hCutscenePhase, hCapsuleCount, hCombo, hDanger, hDangerLevel, hDropWait, hFoundRun, hGarbage, hHalvesMoved, hRedrawRow, hRunColours, hSendGarbage, hVBlankJob, hVirusColoursHit, hDanceTimer1, hDanceTimer2, hDanceTimer3, hMagnifierVirus1, hMagnifierVirus2, hMagnifierVirus3, hRoundResult, hVirusAnim, hGarbageArrived, hUnusedF6, hVirusThresholds, hVirusesLeft2P, hVirusesLeft2PBCD
;@ test: hSpeed = rand(2, 4); hTwoPlayer = rng.choice([0, 1])
;@ test: mem[0xD000] = rand(0, 3); mem[0xD001] = rand(0, 3)
;@ sig: 0388780d
InitGameScreen::
;> src = {4: SpeedLabelTiles, 3: SpeedLabelTiles + 3}.get(hSpeed, SpeedLabelTiles + 6)   # LOW / MED / HI
	ld hl, $98b2
	ld de, $2729
	ld b, $03
	ldh a, [hSpeed]
	cp $04
	jr z, jr_000_25ea

	ld de, $272c
	cp $03
	jr z, jr_000_25ea

	ld de, $272f

;> for i in range(3):                              # written downwards
;>     mem[0x98B2 + 32 * i] = mem[src + i]
jr_000_25ea:
	ld a, [de]
	ld [hl], a
	push de
	ld de, $0020
	add hl, de
	pop de
	inc de
	dec b
	jr nz, jr_000_25ea

;> DrawMarioSprite1P()
	call DrawMarioSprite1P
;> if not hTwoPlayer:
	ldh a, [hTwoPlayer]
	and a
	jr nz, jr_000_2609

;>     DrawMagnifierVirus1()
	call DrawMagnifierVirus1
;>     DrawMagnifierVirus2()
	call DrawMagnifierVirus2
;>     DrawMagnifierVirus3()
	call DrawMagnifierVirus3
	jr jr_000_2615

;> else:
;>     DrawWins1(0xD000)
jr_000_2609:
	ld hl, wWins1
	call DrawWins1
;>     DrawWins2(0xD001)
	ld hl, wWins2
	call DrawWins2
;> FillBytes(wBottle, 0xFF, 0x80)                  # empty bottle
jr_000_2615:
	ld hl, wBottle
	ld b, $80
	ld a, $ff
	call FillBytes
;> for addr in (0xFF9D, 0xFF9C, 0xFF9F, 0xFFC6, 0xFFC7, 0xFFC8, 0xFFC9, 0xFFCA, 0xFFCE, 0xFFD1, 0xFFD2,
;>              0xFFD3, 0xFFD4, 0xFFD5, 0xFFD6, 0xFFD7, 0xFFD8, 0xFFD9):
;>     mem[addr] = 0
	xor a
	ldh [hVBlankJob], a
	ldh [hClearStep], a
	ldh [hFoundRun], a
	ldh [hVirusCount], a
	ldh [hVirusCount2P], a
	ldh [hVirusThresholds], a
	ldh [hVirusThresholds + 1], a
	ldh [hVirusThresholds + 2], a
	ldh [hDanger], a
	ldh [hVirusesPlaced], a
	ldh [hVirusesPlacedBCD], a
	ldh [hVirusesLeft2P], a
	ldh [hVirusesLeft2PBCD], a
	ldh [hViruses0], a
	ldh [hViruses1], a
	ldh [hViruses2], a
	ldh [hRunColours], a
	ldh [hGarbage], a
;> hVirusColours = 0x80
	ld a, $80
	ldh [hVirusColours], a
;> for addr in (0xFFDB, 0xFFDC, 0xFFDD, 0xFFDE, 0xFFE5, 0xFFE6, 0xFFE7, 0xFFE8, 0xFFEF, 0xFFF0,
;>              0xFFF3, 0xFFF4, 0xFFF5, 0xFFF6, 0xFFF7, 0xFFF8, 0xFFF9, 0xFFFA, 0xFFFB, 0xFFFC):
;>     mem[addr] = 0
	xor a
	ldh [hVirusColoursHit], a
	ldh [hGarbageArrived], a
	ldh [hSendGarbage], a
	ldh [hDangerLevel], a
	ldh [hDanceTimer1], a
	ldh [hDanceTimer2], a
	ldh [hDanceTimer3], a
	ldh [hCombo], a
	ldh [hRedrawRow], a
	ldh [hDemoTimer], a
	ldh [hCapsuleCount], a
	ldh [hRoundResult], a
	ldh [hHalvesMoved], a
	ldh [hUnusedF6], a
	ldh [hDropWait], a
	ldh [hVirusAnim], a
	ldh [hCutscenePhase], a
	ldh [hMagnifierVirus1], a
	ldh [hMagnifierVirus2], a
	ldh [hMagnifierVirus3], a
;> FillBytes(0xD002, 0, 0x63)
	ld hl, wVirusCell
	xor a
	ld b, $63
	call FillBytes
;> for k, v in enumerate((3, 0, 0, 0x98, 0x7F)):
;>     mem[0xD065 + k] = v
	ld a, $03
	ld [hli], a
	xor a
	ld [hli], a
	ld [hli], a
	ld a, $98
	ld [hli], a
	ld a, $7f
	ld [hli], a
	ret


;@ def FillBytes(dest: hl, value: a, count: b) -> hl
;@ path: lib/memory
;@ test: dest = rand_ram(256); value = rand(0, 255); count = rand(1, 255)
;@ sig: 2801e90e
FillBytes::
;> for i in range(count):
;>     mem[dest + i] = value
;> return dest + count
	ld [hli], a
	dec b
	jr nz, FillBytes

	ret


;@ def DrawMarioSprite1P()
;@ path: gfx/objects
;@ Puts MarioSprite1P into shadow OAM entries 8-17.
;@ sig: 6b3677ba
DrawMarioSprite1P::
;> CopyUntilFD(MarioSprite1P, 0xC020)
	ld hl, wShadowOAM + $20
	ld de, $26a0
	call CopyUntilFD
	ret


;@ def DrawMagnifierVirus1()
;@ path: gfx/objects
;@ Puts MagnifierVirus1 into shadow OAM entries 18-21.
;@ sig: a3760a94
DrawMagnifierVirus1::
;> CopyUntilFD(MagnifierVirus1, 0xC048)
	ld hl, wShadowOAM + $48
	ld de, $26c9
	call CopyUntilFD
	ret


;@ asset: oam tiles=LoadGameTiles|LoadGameTiles+CopyBytes(hl=Tiles_559E,de=$8800,bc=$520)
;@ Dr. Mario standing beside the bottle in a 1-player game (DrawMarioSprite1P).
MarioSprite1P::
	db $35, $74, $ff, $10, $3d, $74, $04, $10, $35, $7c, $02, $10, $3d, $7c, $05, $10
	db $2d, $7c, $00, $10, $45, $7c, $07, $10, $2d, $84, $01, $10, $35, $84, $03, $10
	db $3d, $84, $06, $10, $45, $84, $08, $10, $fd

;@ asset: oam tiles=LoadGameTiles|LoadGameTiles+CopyBytes(hl=Tiles_559E,de=$8800,bc=$520)
;@ One of the three viruses dancing in the magnifying glass (DrawMagnifierVirus1).
MagnifierVirus1::
	db $8d, $6b, $20, $10, $8d, $73, $21
	db $10, $95, $6b, $30, $10, $95, $73, $31, $10, $fd

;@ def DrawMagnifierVirus2()
;@ path: gfx/objects
;@ Puts MagnifierVirus2 (MagnifierVirus2Alt in a 2-player game) into shadow
;@ OAM entries 22-25.
;@ reads: hTwoPlayer
;@ test: hTwoPlayer = rng.choice([0, 1])
;@ sig: 861c98d4
DrawMagnifierVirus2::
;> CopyUntilFD(MagnifierVirus2Alt if hTwoPlayer else MagnifierVirus2, 0xC058)
	ld hl, wShadowOAM + $58
	ld de, $26ec
	ldh a, [hTwoPlayer]
	and a
	jr z, jr_000_26e8

	ld de, $26fd

jr_000_26e8:
	call CopyUntilFD
	ret


;@ asset: oam tiles=LoadGameTiles
;@ The second virus dancing in the magnifying glass (DrawMagnifierVirus2).
MagnifierVirus2::
	db $8d, $7b, $40, $10, $8d, $83, $41, $10, $95, $7b, $50, $10, $95, $83, $51, $10
	db $fd

;@ asset: oam tiles=LoadGameTiles
;@ DrawMagnifierVirus2's choice for a 2-player game; it is only called in 1-player games, so this layout is never shown.
MagnifierVirus2Alt::
	db $75, $38, $40, $10, $75, $40, $41, $10, $7d, $38, $50, $10, $7d, $40, $51
	db $10, $fd

;@ def DrawMagnifierVirus3()
;@ path: gfx/objects
;@ Puts MagnifierVirus3 into shadow OAM entries 26-29.
;@ sig: c5856e0d
DrawMagnifierVirus3::
;> CopyUntilFD(MagnifierVirus3, 0xC068)
	ld hl, wShadowOAM + $68
	ld de, $2718
	call CopyUntilFD
	ret


;@ asset: oam tiles=LoadGameTiles|LoadGameTiles+CopyBytes(hl=Tiles_559E,de=$8800,bc=$520)
;@ The third magnifier virus (DrawMagnifierVirus3).
MagnifierVirus3::
	db $8d, $8b, $60, $10, $8d, $93, $61, $10, $95, $8b, $70, $10, $95, $93, $71, $10
	db $fd

SpeedLabelTiles::
	db $15, $18, $20, $16, $0e, $0d, $11, $12, $fe

;@ def DrawWins1(wins: hl)
;@ path: versus/setup
;@ Shows the left player's wins (the count at `wins`) as markers from
;@ WinMarkers1 in shadow OAM entries 32-34.
;@ test: wins = rand_ram(1); mem[wins] = rand(0, 3)
;@ sig: 08ec9fb9
DrawWins1::
;> for n in range(mem[wins], 0, -1):
;>     for k in range(4):
;>         mem[0xC07C + 4 * n + k] = mem[WinMarkers1 - 4 + 4 * n + k]
	ld a, [hl]
	and a
	ret z

	ld c, a

jr_000_2736:
	ld b, c
	ld hl, wShadowOAM + $7C
	ld de, $0004

jr_000_273d:
	add hl, de
	dec b
	jr nz, jr_000_273d

	push hl
	ld hl, $2778
	ld b, c

jr_000_2746:
	add hl, de
	dec b
	jr nz, jr_000_2746

	pop de
	ld b, $04

jr_000_274d:
	ld a, [hli]
	ld [de], a
	inc de
	dec b
	jr nz, jr_000_274d

	dec c
	jr nz, jr_000_2736

	ret


;@ def DrawWins2(wins: hl)
;@ path: versus/setup
;@ The right player's wins, from WinMarkers2 into shadow OAM entries 35-37.
;@ test: wins = rand_ram(1); mem[wins] = rand(0, 3)
;@ sig: bcacc235
DrawWins2::
;> for n in range(mem[wins], 0, -1):
;>     for k in range(4):
;>         mem[0xC088 + 4 * n + k] = mem[WinMarkers2 - 4 + 4 * n + k]
	ld a, [hl]
	and a
	ret z

	ld c, a

jr_000_275b:
	ld b, c
	ld hl, wShadowOAM + $88
	ld de, $0004

jr_000_2762:
	add hl, de
	dec b
	jr nz, jr_000_2762

	push hl
	ld hl, $2784
	ld b, c

jr_000_276b:
	add hl, de
	dec b
	jr nz, jr_000_276b

	pop de
	ld b, $04

jr_000_2772:
	ld a, [hli]
	ld [de], a
	inc de
	dec b
	jr nz, jr_000_2772

	dec c
	jr nz, jr_000_275b

	ret


;@ asset: oam length=12 tiles=LoadGameTiles
;@ Up to three win markers for the left player in a versus match (DrawWins1).
WinMarkers1::
	db $60, $68, $2c, $00, $60, $70, $2c, $00, $60, $78, $2c, $00

;@ asset: oam length=12 tiles=LoadGameTiles
;@ The right player's win markers (DrawWins2).
WinMarkers2::
	db $60, $88, $2c, $00
	db $60, $90, $2c, $00, $60, $98, $2c, $00

;@ def CopyUntilFD(src: de, dest: hl) -> (hl, de)
;@ path: lib/memory
;@ Copies bytes from src to dest up to (not including) a $FD - the
;@ terminator of this game's text and tile strings.
;@ test: src = rand_ram(32); mem[src + rand(0, 31)] = 0xFD
;@ test: dest = rand_ram(32)
;@ sig: e9578238
CopyUntilFD::
;>@loop while mem[src] != 0xFD:
	ld a, [de]
	cp $fd
;>@done     # (ret z: return dest, src)
	ret z

;>     mem[dest] = mem[src]
;>     dest += 1
	ld [hli], a
;>     src += 1
	inc de
;=@loop
	jr CopyUntilFD
;> return dest, src


;@ def UpdateBottle()
;@ path: game/lines
;@ Every frame of play: once a capsule has been locked, runs the next step of
;@ the clearing (RunClearStep), otherwise QueueBottleRedraw. In a link game it also
;@ shows both virus counts as sprites, and starts the danger music once the
;@ other side is close to winning.
;@ reads: hToppedOut, hTwoPlayer, wInPlay, hCapsuleState, hDanger, hVirusLevel2P, hVirusesPlacedBCD, $FFD4, hDangerLevel, hVirusesLeft2PBCD
;@ writes: hDanger, $DF8B, wDangerMusic
;@ test: skip calls helpers not translated yet
;@ sig: fc7ab378
UpdateBottle::
;> if not hToppedOut:
	ldh a, [hToppedOut]
	and a
	jr nz, jr_000_27b3

;>     if hTwoPlayer and wInPlay:
;>@vs1         if hCapsuleState == 2 and not hDanger and hVirusLevel2P >= 5 and hDangerLevel:
;>@vs2             wDangerMusic = 1                         # danger music
;>@vs3             hDanger = 1
;>@vs4         hVirusesLeft2PBCD = ToBCD(0xFFD3)                 # the other side's viruses, in BCD
;>@vs5         DrawVirusCount2P(hVirusesPlacedBCD, 0xC052, 4)
;>@vs6         DrawVirusCount2P(hVirusesLeft2PBCD, 0xC05A, 4)
	ldh a, [hTwoPlayer]
	and a
	jr z, jr_000_27ac

	ld a, [wInPlay]
	and a
	jr nz, jr_000_27b7

;>@cs     if hCapsuleState == 2:
;>@runclear         return RunClearStep()
;=@cs
jr_000_27ac:
	ldh a, [hCapsuleState]
	cp $02
	jp z, Jump_000_282a

;> QueueBottleRedraw()
jr_000_27b3:
	call QueueBottleRedraw
	ret


;=@vs1
jr_000_27b7:
	ld hl, hVirusesLeft2P
	ldh a, [hCapsuleState]
	cp $02
	jr nz, jr_000_27d7

	ldh a, [hDanger]
	and a
	jr nz, jr_000_27d7

	ldh a, [hVirusLevel2P]
	cp $05
	jr c, jr_000_27d7

	ldh a, [hDangerLevel]
	and a
	jr z, jr_000_27d7

;=@vs2
	ld a, $01
	ld [wDangerMusic], a
;=@vs3
	ldh [hDanger], a

;=@vs4
jr_000_27d7:
	call ToBCD
	inc l
	ld [hl], a
;=@vs5
	ld de, $0004
	ld hl, wShadowOAM + $52
	ldh a, [hVirusesPlacedBCD]
	call DrawVirusCount2P
;=@vs6
	ldh a, [hVirusesLeft2PBCD]
	call DrawVirusCount2P
	jr jr_000_27ac

;@ def DrawVirusCount2P(count: a, dest: hl, step: de) -> hl
;@ path: versus/play
;@ Shows a BCD count as two tall digits made of sprites: writes the top and
;@ bottom tile of each digit into the OAM tile bytes at dest (step bytes apart).
;@ test: count = rand_bcd(1); dest = 0xC052; step = 4
;@ sig: c046c87f
DrawVirusCount2P::
;> dest = DigitSpriteTile(count >> 4, dest, step)
	ld b, a
	swap a
	and $0f
	call DigitSpriteTile
;> return DigitSpriteTile(count & 0x0F, dest, step)
	ld a, b
	and $0f
	call DigitSpriteTile
	ret


;@ def DigitSpriteTile(digit: a, dest: hl, step: de) -> hl
;@ path: versus/play
;@ The tiles of a tall digit: 0-3 start at $4C, 4-7 at $6C, 8-9 at $68.
;@ test: digit = rand(0, 9); dest = 0xC052 + 4 * rand(0, 10); step = 4
;@ sig: ad5607fb
DigitSpriteTile::
;>@d8c if digit >= 8:
;>@d8     return PutDigitSprite(digit - 8, 0x68, dest, step)
;>@d4 elif digit >= 4:
;>@d4b     return PutDigitSprite(digit - 4, 0x6C, dest, step)
;>@d0 else:
;>@d0b     return PutDigitSprite(digit, 0x4C, dest, step)
;=@d8c
	cp $08
	jr nc, jr_000_280b

;=@d4
	cp $04
	jr nc, jr_000_2813

;=@d0b
	ld c, $4c
	call PutDigitSprite
	ret


;=@d8
jr_000_280b:
	ld c, $68
	sub $08
	call PutDigitSprite
	ret


;=@d4b
jr_000_2813:
	ld c, $6c
	sub $04
	call PutDigitSprite
	ret


;@ def PutDigitSprite(n: a, base: c, dest: hl, step: de) -> hl
;@ path: versus/play
;@ Writes tile base + n and the tile below it (base + n + $10) step bytes apart.
;@ test: n = rand(0, 3); base = rng.choice([0x4C, 0x68, 0x6C]); dest = 0xC052 + 4 * rand(0, 10); step = 4
;@ sig: 7dbbc01a
PutDigitSprite::
;> tile = base + n
	and a
	jr z, jr_000_2822

	inc c
	dec a
	jr PutDigitSprite

jr_000_2822:
;> mem[dest] = tile
;> mem[dest + step] = (tile + 0x10) & 0xFF
;> return dest + 2 * step
	ld [hl], c
	add hl, de
	ld a, c
	add $10
	ld [hl], a
	add hl, de
	ret


;=@UpdateBottle.runclear
Jump_000_282a:
	call RunClearStep
	ret


;@ def RunClearStep()
;@ path: game/lines
;@ Runs step hClearStep of the clearing: 0 rows, 1 columns, 2-7 the clear
;@ animation, letting halves fall, and the hand-over to the next capsule.
;@ reads: hClearStep
;@ test: skip jumps through a table
;@ sig: a7c4903d
RunClearStep::
;> goto((FindRowRuns, FindColumnRuns, ShowPops, RemovePops, DropHalves, WaitThenDropHalves, DropGarbage, WaitAfterGarbage)[hClearStep])
	ldh a, [hClearStep]
	rst $28

JumpTable_2831::
	dw FindRowRuns
	dw FindColumnRuns
	dw ShowPops
	dw RemovePops
	dw DropHalves
	dw WaitThenDropHalves
	dw DropGarbage
	dw WaitAfterGarbage

;@ def FindRowRuns()
;@ path: game/lines
;@ Clearing step 0: finds every run of four or more of a colour in the rows
;@ and clears it. In a link game it first sets the "bottle nearly full"
;@ warning ($DF8A) if anything is in the bottle's neck (columns 3-4 of rows 1-3).
;@ reads: hTwoPlayer
;@ writes: hClearStep
;@ test: hTwoPlayer = rng.choice([0, 0, 1]); hSpeed = rand(2, 4); hCombo = rand(0, 5); mem[0xDF8A] = rand(0, 1)
;@ test: for k in range(0x80): mem[0xC800 + k] = rng.choice([0xFF, 0xFF, 0xE0, 0xE1, 0xE2, 0x30, 0x31, 0x32, 0x41, 0x42])
;@ test: hVirusesPlaced = 40; hVirusesPlacedBCD = 0x40; hViruses0 = 15; hViruses1 = 15; hViruses2 = 10; fill_bcd(0xC0A0, 4); hRunColours = 0
;@ sig: cfb65f66
FindRowRuns::
;> if hTwoPlayer:
	ldh a, [hTwoPlayer]
	and a
	jr z, jr_000_2879

;>     neck = (0xC80B, 0xC80C, 0xC813, 0xC814, 0xC81B, 0xC81C)
;>     if all(mem[a] == 0xFF for a in neck):
	ld de, wNearlyFull
	ld hl, wBottle + $0B
	ld a, [hli]
	cp $ff
	jr nz, jr_000_2872

	ld a, [hl]
	cp $ff
	jr nz, jr_000_2872

	ld l, $13
	ld a, [hli]
	cp $ff
	jr nz, jr_000_2872

	ld a, [hl]
	cp $ff
	jr nz, jr_000_2872

	ld l, $1b
	ld a, [hli]
	cp $ff
	jr nz, jr_000_2872

	ld a, [hl]
	cp $ff
	jr nz, jr_000_2872

;>         wNearlyFull = 0
	xor a
	ld [de], a
	jr jr_000_2879

jr_000_2872:
;>     elif not wNearlyFull:
	ld a, [de]
	and a
	jr nz, jr_000_2879

;>         wNearlyFull = 1
	ld a, $01
	ld [de], a

jr_000_2879:
;> for row in range(1, 16):
;>     if row & 1:
;>         FindRunsInRowB(0xC800 + 8 * row)
;>     else:
;>         FindRunsInRowA(0xC800 + 8 * row)
	ld hl, wBottle + $08
	call FindRunsInRowB
	ld l, $10
	call FindRunsInRowA
	ld l, $18
	call FindRunsInRowB
	ld l, $20
	call FindRunsInRowA
	ld l, $28
	call FindRunsInRowB
	ld l, $30
	call FindRunsInRowA
	ld l, $38
	call FindRunsInRowB
	ld l, $40
	call FindRunsInRowA
	ld l, $48
	call FindRunsInRowB
	ld l, $50
	call FindRunsInRowA
	ld l, $58
	call FindRunsInRowB
	ld l, $60
	call FindRunsInRowA
	ld l, $68
	call FindRunsInRowB
	ld l, $70
	call FindRunsInRowA
	ld l, $78
	call FindRunsInRowB
;> hClearStep = 1
	ld a, $01
	ldh [hClearStep], a
	ret


jr_000_28ca:
;=@FindRunsInRowA.skip
	inc l

;@ def FindRunsInRowA(cell: hl)
;@ path: game/lines
;@ Scans a row that starts at an address ending in 0 (the even rows) for runs
;@ of four or more cells of one colour (the low nibble of the tile) and
;@ clears them. A run has to start in columns 0-4.
;@ test: cell = 0xC800 + 0x10 * rand(1, 7)
;@ test: for k in range(0x80): mem[0xC800 + k] = rng.choice([0xFF, 0xE0, 0xE1, 0xE2, 0x30, 0x31, 0x32, 0x41, 0x42, 0x40])
;@ test: hTwoPlayer = rng.choice([0, 1]); hSpeed = rand(2, 4); hCombo = rand(0, 5); hRunColours = rng.choice([0, 0x05, 0x40])
;@ test: hVirusesPlaced = 40; hVirusesPlacedBCD = 0x40; hViruses0 = 15; hViruses1 = 15; hViruses2 = 10; fill_bcd(0xC0A0, 4)
;@ sig: 60f3de43
FindRunsInRowA::
;> while (cell & 0x0F) < 5:
	ld a, l
	and $0f
	cp $05
	ret nc

;>     if mem[cell] == 0xFF:
;>@skip         cell += 1
;>         continue
	ld a, [hl]
	cp $ff
	jr z, jr_000_28ca

;>     colour = mem[cell] & 0x0F
;>     run = 0
	and $0f
	ld b, a
	ld c, $00

jr_000_28db:
;>     while True:
;>         run += 1
;>         cell += 1
	inc c
	inc l
;>         if cell & 0x0F == 8 or mem[cell] & 0x0F != colour:
;>             break
	ld a, l
	and $0f
	cp $08
	jr z, jr_000_28ea

	ld a, [hl]
	and $0f
	cp b
	jr z, jr_000_28db

jr_000_28ea:
;>     if run >= 4:
	ld a, c
	cp $04
	jr c, FindRunsInRowA

;>         last = ClearRowRun(cell, run)
	call ClearRowRun
;>         RecordRunColour(last)
	push hl
	call RecordRunColour
	pop hl
	jr FindRunsInRowA

;@ def ClearRowRun(end: hl, length: c) -> a
;@ path: game/lines
;@ Clears the `length` cells of a row run that ends just before `end`.
;@ Returns the last cleared cell's new value.
;@ writes: hFoundRun
;@ test: length = rand(4, 8); end = 0xC800 + 8 * rand(1, 14) + rand(0, 8 - length) + length; mem[0xD00F] = 0
;@ test: for k in range(0x80): mem[0xC800 + k] = rng.choice([0xE0, 0xE1, 0xE2, 0x30, 0x31])
;@ test: hTwoPlayer = rng.choice([0, 1]); hSpeed = rand(2, 4); hCombo = rand(0, 5); hVirusColoursHit = rand(0, 255)
;@ test: hVirusesPlaced = 40; hVirusesPlacedBCD = 0x40; hViruses0 = 15; hViruses1 = 15; hViruses2 = 10; fill_bcd(0xC0A0, 4)
;@ sig: 035a33d6
ClearRowRun::
;> hFoundRun = 1
	ld a, $01
	ldh [hFoundRun], a
;> cell = (end & 0xFF00) | ((end - length) & 0xFF)
	ld a, l
	sub c
	ld l, a

jr_000_2900:
;> for _ in range(length):
;>     value = ClearCellInRow(cell)
;>     cell += 1
;> return value
	call ClearCellInRow
	dec c
	jr nz, jr_000_2900

	ret


;@ def ClearCellInRow(cell: hl) -> a
;@ path: game/lines
;@ Clears one cell of a run. A capsule half keeps only its colour (low
;@ nibble: the "popping" tiles); a virus becomes $F0-$F2, is counted off (per
;@ colour too in 1-player games, noting which colours were hit for the
;@ magnifier) and scores.
;@ reads: hTwoPlayer, hVirusColoursHit
;@ writes: hViruses0, hViruses1, hViruses2, hVirusColoursHit, hVirusesPlaced, hVirusesPlacedBCD
;@ test: cell = rand_ram(1); mem[cell] = rng.choice([0xE0, 0xE1, 0xE2, 0x30, 0x41, 0x52]); mem[0xD00F] = 0
;@ test: hTwoPlayer = rng.choice([0, 1]); hSpeed = rand(2, 4); hCombo = rand(0, 5); hVirusColoursHit = rand(0, 255)
;@ test: hVirusesPlaced = 40; hVirusesPlacedBCD = 0x40; hViruses0 = 15; hViruses1 = 15; hViruses2 = 10; fill_bcd(0xC0A0, 4)
;@ sig: 877484ba
ClearCellInRow::
;> v = mem[cell]
;> if v not in (0xE0, 0xE1, 0xE2):                 # a capsule half
	ld a, [hl]
	cp $e0
	jr c, jr_000_2916

	jr z, jr_000_291b

	cp $e1
	jr z, jr_000_294c

	cp $e2
	jr z, jr_000_2968

jr_000_2916:
;>     mem[cell] = v & 0x0F
;>     return mem[cell]
	ld a, $0f
	and [hl]
	ld [hli], a
	ret


;>@v0 if not hTwoPlayer:
;>@v1     n = v - 0xE0                                # colour 0, 1, 2
;>@v2     if n == 0: hViruses0 -= 1
;>@v3     elif n == 1: hViruses1 -= 1
;>@v4     else: hViruses2 -= 1
;>@v5     first, again = 4 >> n, 0x80 >> n            # bits 2/1/0, then 7/6/5
;>@v6     hVirusColoursHit |= again if hVirusColoursHit & first else first
;>@v7 hVirusesPlaced -= 1
;>@v8 hVirusesPlacedBCD = to_bcd((bcd_to_int(hVirusesPlacedBCD) - 1) % 100)
;>@v9 wVirusChanges += 1
;>@v10 mem[cell] = 0xF0 | v
;>@v11 ScoreVirus()
;>@v12 return mem[cell]
;=@v0
jr_000_291b:
	push hl
	ldh a, [hTwoPlayer]
	and a
	jr nz, jr_000_2935

;=@v2
	ld hl, hViruses0
	dec [hl]
;=@v6
	ldh a, [hVirusColoursHit]
	bit 2, a
	jr z, jr_000_2931

	set 7, a
	ldh [hVirusColoursHit], a
	jr jr_000_2935

jr_000_2931:
	set 2, a
	ldh [hVirusColoursHit], a

jr_000_2935:
;=@v7
	ld hl, hVirusesPlaced
	dec [hl]
;=@v8
	inc l
	ld a, [hl]
	sub $01
	daa
	ld [hl], a
;=@v9
	ld hl, wVirusChanges
	inc [hl]
	pop hl
;=@v10
	ld a, $f0
	or [hl]
	ld [hli], a
;=@v11
	call ScoreVirus
;=@v12
	ret


;=@v0
jr_000_294c:
	push hl
	ldh a, [hTwoPlayer]
	and a
	jr nz, jr_000_2935

;=@v3
	ld hl, hViruses1
	dec [hl]
;=@v6
	ldh a, [hVirusColoursHit]
	bit 1, a
	jr z, jr_000_2962

	set 6, a
	ldh [hVirusColoursHit], a
	jr jr_000_2935

jr_000_2962:
	set 1, a
	ldh [hVirusColoursHit], a
	jr jr_000_2935

;=@v0
jr_000_2968:
	push hl
	ldh a, [hTwoPlayer]
	and a
	jr nz, jr_000_2935

;=@v4
	ld hl, hViruses2
	dec [hl]
;=@v6
	ldh a, [hVirusColoursHit]
	bit 0, a
	jr z, jr_000_297e

	set 5, a
	ldh [hVirusColoursHit], a
	jr jr_000_2935

jr_000_297e:
	set 0, a
	ldh [hVirusColoursHit], a
	jr jr_000_2935

;@ def ScoreVirus()
;@ path: game/score
;@ 1 player: scores a cleared virus, 100 x 1 / 2 / 3 (LOW / MED / HI),
;@ doubled for every earlier virus of this chain (up to 5 times).
;@ reads: hTwoPlayer, hSpeed
;@ writes: hCombo
;@ test: hTwoPlayer = rng.choice([0, 0, 1]); hSpeed = rand(2, 4); hCombo = rand(0, 5); fill_bcd(0xC0A0, 4)
;@ sig: e3f46df9
ScoreVirus::
;> if hTwoPlayer:
;>     return
	push af
	ldh a, [hTwoPlayer]
	and a
	jr nz, jr_000_29b1

;> base = {2: 3, 3: 2}.get(hSpeed, 1)
	push bc
	push de
	push hl
	ld e, $00
	ldh a, [hSpeed]
	cp $02
	jr z, jr_000_29b3

	cp $03
	jr z, jr_000_29b7

	ld d, $01

jr_000_299b:
;> AddScoreBCD(ComboPoints(base) << 8, wScore)      # hundreds
	call ComboPoints
	ld hl, wScore
	call AddScoreBCD
;> hCombo = min(hCombo + 1, 5)
	ld hl, hCombo
	inc [hl]
	ld a, [hl]
	cp $06
	jr c, jr_000_29ae

	dec [hl]

jr_000_29ae:
	pop hl
	pop de
	pop bc

jr_000_29b1:
	pop af
	ret


jr_000_29b3:
	ld d, $03
	jr jr_000_299b

jr_000_29b7:
	ld d, $02
	jr jr_000_299b

;@ def ComboPoints(base: d) -> d
;@ path: game/score
;@ base doubled hCombo times, in BCD (1, 2, 4, 8, 16, 32 / 3, 6, 12, 24, 48, 96).
;@ reads: hCombo
;@ test: base = rand(1, 3); hCombo = rand(0, 5)
;@ sig: e3557070
ComboPoints::
;> points = base
;> for _ in range(hCombo):
;>     points = to_bcd(2 * bcd_to_int(points))
;> return points
	ldh a, [hCombo]
	and a
	ret z

	ld b, a
	ld a, d

jr_000_29c1:
	add d
	daa
	ld d, a
	dec b
	jr nz, jr_000_29c1

	ret


;@ def RecordRunColour(colour: a)
;@ path: game/lines
;@ Remembers the colour of a cleared run in hRunColours (up to four runs a turn).
;@ test: colour = rng.choice([0xF0, 0xF1, 0x02, 0x31]); hRunColours = rng.choice([0, 0x01, 0x06, 0x1B, 0x6E])
;@ sig: 2b79e629
RecordRunColour::
;> b = (colour & 0x0F) + 1
	and $0f
	ld b, a
	inc b
	ld hl, hRunColours
;> if hRunColours & 0xC0:                          # four runs recorded already
;>     return
	ld a, [hl]
	and $c0
	ret nz

;> hRunColours = ((hRunColours << 2) | b) & 0xFF
	sla [hl]
	sla [hl]
	ld a, [hl]
	or b
	ld [hl], a
	ret


jr_000_29db:
;=@FindRunsInRowB.skip
	inc l

;@ def FindRunsInRowB(cell: hl)
;@ path: game/lines
;@ The same for a row that starts at an address ending in 8 (the odd rows):
;@ a run has to start in columns 0-4 (low nibble 8-12).
;@ test: cell = 0xC808 + 0x10 * rand(0, 7)
;@ test: for k in range(0x80): mem[0xC800 + k] = rng.choice([0xFF, 0xE0, 0xE1, 0xE2, 0x30, 0x31, 0x32, 0x41, 0x42, 0x40])
;@ test: hTwoPlayer = rng.choice([0, 1]); hSpeed = rand(2, 4); hCombo = rand(0, 5); hRunColours = rng.choice([0, 0x05, 0x40])
;@ test: hVirusesPlaced = 40; hVirusesPlacedBCD = 0x40; hViruses0 = 15; hViruses1 = 15; hViruses2 = 10; fill_bcd(0xC0A0, 4)
;@ sig: f57a9c45
FindRunsInRowB::
;> while cell & 0x0F and (cell & 0x0F) < 0x0D:
	ld a, l
	and $0f
	ret z

	cp $0d
	ret nc

;>     if mem[cell] == 0xFF:
;>@skip         cell += 1
;>         continue
	ld a, [hl]
	cp $ff
	jr z, jr_000_29db

;>     colour = mem[cell] & 0x0F
;>     run = 0
	and $0f
	ld b, a
	ld c, $00

jr_000_29ed:
;>     while True:
;>         run += 1
;>         cell += 1
	inc c
	inc l
;>         if cell & 0x0F == 0 or mem[cell] & 0x0F != colour:
;>             break
	ld a, l
	and $0f
	jr z, jr_000_29fa

	ld a, [hl]
	and $0f
	cp b
	jr z, jr_000_29ed

jr_000_29fa:
;>     if run >= 4:
	ld a, c
	cp $04
	jr c, FindRunsInRowB

;>         last = ClearRowRun(cell, run)
	call ClearRowRun
;>         RecordRunColour(last)
	push hl
	call RecordRunColour
	pop hl
	jr FindRunsInRowB

;@ def FindColumnRuns()
;@ path: game/lines
;@ Clearing step 1: the same for the columns. If anything was cleared (rows
;@ or columns) step 2 shows it; otherwise the chain is over: its combo ends,
;@ two or more runs give a sound (1P) or garbage for the other side (2P), and
;@ step 6 follows. Every 10 capsules the drop speed goes up.
;@ reads: hFoundRun, hRunColours, hTwoPlayer
;@ writes: hFoundRun, hClearStep, hCombo, hRunColours, hSendGarbage, hCapsuleCount, wSFXRequest
;@ test: skip calls helpers not translated yet
;@ sig: 5a499939
FindColumnRuns::
;> for column in range(8):
;>     FindRunsInColumn(0xC808 + column, 8)
	ld de, $0008
	ld hl, wBottle + $08
	call FindRunsInColumn
	ld l, $09
	call FindRunsInColumn
	ld l, $0a
	call FindRunsInColumn
	ld l, $0b
	call FindRunsInColumn
	ld l, $0c
	call FindRunsInColumn
	ld l, $0d
	call FindRunsInColumn
	ld l, $0e
	call FindRunsInColumn
	ld l, $0f
	call FindRunsInColumn
;> if hFoundRun:
;>@found     hFoundRun = 0
;>@found2     hClearStep = 2
;>@found3     return
	ld hl, hFoundRun
	ld a, [hl]
	and a
	jr nz, jr_000_2a66

;> hCombo = 0
	xor a
	ldh [hCombo], a
;> if hRunColours & 0xFC:                          # two or more runs this turn
	ldh a, [hRunColours]
	and $fc
	jr z, jr_000_2a51

	ld b, a
;>     if hTwoPlayer:
	ldh a, [hTwoPlayer]
	and a
	jr z, jr_000_2a6d

;>         hSendGarbage = 1
;>@sfx     else:
;>@sfx2         wSFXRequest = 0x0D if hRunColours & 0xC0 else 0x0B if hRunColours & 0xF0 else 0x08
;>@sfx3         hRunColours = 0
;>@none else:
;>@none2     hRunColours = 0
	ld a, $01
	ldh [hSendGarbage], a
	jr jr_000_2a54

;=@none
jr_000_2a51:
;=@none2
	xor a
	ldh [hRunColours], a

jr_000_2a54:
;> hClearStep = 6
	ld a, $06
	ldh [hClearStep], a
;> hCapsuleCount += 1
;> if hCapsuleCount == 10:
	ld hl, hCapsuleCount
	inc [hl]
	ld a, [hl]
	cp $0a
	ret nz

;>     hCapsuleCount = 0
	xor a
	ld [hl], a
;>     SpeedUp()                                 # faster
	call SpeedUp
	ret


;=@found
jr_000_2a66:
	xor a
	ld [hl], a
;=@found2
	ld a, $02
	ldh [hClearStep], a
;=@found3
	ret


;=@sfx
jr_000_2a6d:
;=@sfx2
	ld c, $08
	ld a, b
	and $f0
	jr nz, jr_000_2a7a

jr_000_2a74:
	ld a, c
	ld [wSFXRequest], a
	jr jr_000_2a51

jr_000_2a7a:
	ld c, $0b
	and $c0
	jr z, jr_000_2a74

	ld c, $0d
	jr jr_000_2a74

jr_000_2a84:
;=@FindRunsInColumn.skip
	add hl, de

;@ def FindRunsInColumn(cell: hl, step: de)
;@ path: game/lines
;@ Scans a column (cells 8 bytes apart) for runs of four or more and clears
;@ them; a run has to start in rows 1-12.
;@ test: cell = 0xC808 + rand(0, 7); step = 8
;@ test: for k in range(0x80): mem[0xC800 + k] = rng.choice([0xFF, 0xE0, 0xE1, 0xE2, 0x30, 0x31, 0x32, 0x41, 0x42, 0x40])
;@ test: hTwoPlayer = rng.choice([0, 1]); hSpeed = rand(2, 4); hCombo = rand(0, 5); hRunColours = rng.choice([0, 0x05, 0x40])
;@ test: hVirusesPlaced = 40; hVirusesPlacedBCD = 0x40; hViruses0 = 15; hViruses1 = 15; hViruses2 = 10; fill_bcd(0xC0A0, 4)
;@ sig: 1c864fd3
FindRunsInColumn::
;> while (cell & 0xFF) < 0x68:
	ld a, l
	cp $68
	ret nc

;>     if mem[cell] == 0xFF:
;>@skip         cell += step
;>         continue
	ld a, [hl]
	cp $ff
	jr z, jr_000_2a84

;>     colour = mem[cell] & 0x0F
;>     run = 0
	and $0f
	ld b, a
	ld c, $00

jr_000_2a93:
;>     while True:
;>         run += 1
;>         cell += step
	inc c
	add hl, de
;>         if cell & 0xFF >= 0x80 or mem[cell] & 0x0F != colour:
;>             break
	ld a, l
	cp $80
	jr nc, jr_000_2aa0

	ld a, [hl]
	and $0f
	cp b
	jr z, jr_000_2a93

jr_000_2aa0:
;>     if run >= 4:
	ld a, c
	cp $04
	jr c, FindRunsInColumn

;>         last = ClearColumnRun(cell, run, step)
	call ClearColumnRun
;>         RecordRunColour(last)
	push hl
	call RecordRunColour
	pop hl
	jr FindRunsInColumn

;@ def ClearColumnRun(end: hl, length: c, step: de) -> a
;@ path: game/lines
;@ Clears the `length` cells of a column run that ends just above `end`.
;@ writes: hFoundRun
;@ test: length = rand(4, 6); step = 8; end = 0xC800 + 8 * rand(length + 1, 15) + rand(0, 7)
;@ test: for k in range(0x80): mem[0xC800 + k] = rng.choice([0xE0, 0xE1, 0xE2, 0x30, 0x31])
;@ test: hTwoPlayer = rng.choice([0, 1]); hSpeed = rand(2, 4); hCombo = rand(0, 5); hVirusColoursHit = rand(0, 255)
;@ test: hVirusesPlaced = 40; hVirusesPlacedBCD = 0x40; hViruses0 = 15; hViruses1 = 15; hViruses2 = 10; fill_bcd(0xC0A0, 4)
;@ sig: fb1efafc
ClearColumnRun::
;> hFoundRun = 1
	ld a, $01
	ldh [hFoundRun], a
;> cell = (end & 0xFF00) | ((end - 8 * length) & 0xFF)
	ld b, e
	ld a, l

jr_000_2ab5:
	sub c
	dec b
	jr nz, jr_000_2ab5

	ld l, a

jr_000_2aba:
;> for _ in range(length):
;>     value = ClearCellInColumn(cell, step)
;>     cell += step
;> return value
	call ClearCellInColumn
	dec c
	jr nz, jr_000_2aba

	ret


;@ def ClearCellInColumn(cell: hl, step: de) -> a
;@ path: game/lines
;@ ClearCellInRow for columns (without counting $D00F; it sets $D041 for a virus).
;@ reads: hTwoPlayer, hVirusColoursHit
;@ writes: hViruses0, hViruses1, hViruses2, hVirusColoursHit, hVirusesPlaced, hVirusesPlacedBCD, $D041, wColumnVirus
;@ test: cell = rand_ram(9); step = 8; mem[cell] = rng.choice([0xE0, 0xE1, 0xE2, 0x30, 0x41, 0x52]); mem[0xD041] = 0
;@ test: hTwoPlayer = rng.choice([0, 1]); hSpeed = rand(2, 4); hCombo = rand(0, 5); hVirusColoursHit = rand(0, 255)
;@ test: hVirusesPlaced = 40; hVirusesPlacedBCD = 0x40; hViruses0 = 15; hViruses1 = 15; hViruses2 = 10; fill_bcd(0xC0A0, 4)
;@ sig: 600324e7
ClearCellInColumn::
;> v = mem[cell]
;> if v not in (0xE0, 0xE1, 0xE2):
	ld a, [hl]
	cp $e0
	jr c, jr_000_2ad0

	jr z, jr_000_2ad6

	cp $e1
	jr z, jr_000_2b0b

	cp $e2
	jr z, jr_000_2b27

jr_000_2ad0:
;>     mem[cell] = v & 0x0F
;>     return mem[cell]
	ld a, $0f
	and [hl]
	ld [hl], a
	add hl, de
	ret


jr_000_2ad6:
;>@v0 if not hTwoPlayer:
;>@v1     n = v - 0xE0
;>@v2     if n == 0: hViruses0 -= 1
;>@v3     elif n == 1: hViruses1 -= 1
;>@v4     else: hViruses2 -= 1
;>@v5     first, again = 4 >> n, 0x80 >> n
;>@v6     hVirusColoursHit |= again if hVirusColoursHit & first else first
;>@v7 hVirusesPlaced -= 1
;>@v8 hVirusesPlacedBCD = to_bcd((bcd_to_int(hVirusesPlacedBCD) - 1) % 100)
;>@v10 mem[cell] = 0xF0 | v
;>@v11 ScoreVirus()
;>@v11b wColumnVirus = 1
;>@v12 return mem[cell]
;=@v0
	push hl
	ldh a, [hTwoPlayer]
	and a
	jr nz, jr_000_2af0

;=@v2
	ld hl, hViruses0
	dec [hl]
;=@v6
	ldh a, [hVirusColoursHit]
	bit 2, a
	jr z, jr_000_2aec

	set 7, a
	ldh [hVirusColoursHit], a
	jr jr_000_2af0

jr_000_2aec:
	set 2, a
	ldh [hVirusColoursHit], a

jr_000_2af0:
;=@v7
	ld hl, hVirusesPlaced
	dec [hl]
;=@v8
	inc l
	ld a, [hl]
	sub $01
	daa
	ld [hl], a
	pop hl
;=@v10
	ld a, $f0
	or [hl]
	ld [hl], a
	push af
	add hl, de
;=@v11
	call ScoreVirus
;=@v11b
	ld a, $01
	ld [wColumnVirus], a
;=@v12
	pop af
	ret


jr_000_2b0b:
;=@v0
	push hl
	ldh a, [hTwoPlayer]
	and a
	jr nz, jr_000_2af0

;=@v3
	ld hl, hViruses1
	dec [hl]
;=@v6
	ldh a, [hVirusColoursHit]
	bit 1, a
	jr z, jr_000_2b21

	set 6, a
	ldh [hVirusColoursHit], a
	jr jr_000_2af0

jr_000_2b21:
	set 1, a
	ldh [hVirusColoursHit], a
	jr jr_000_2af0

jr_000_2b27:
;=@v0
	push hl
	ldh a, [hTwoPlayer]
	and a
	jr nz, jr_000_2af0

;=@v4
	ld hl, hViruses2
	dec [hl]
;=@v6
	ldh a, [hVirusColoursHit]
	bit 0, a
	jr z, jr_000_2b3d

	set 5, a
	ldh [hVirusColoursHit], a
	jr jr_000_2af0

jr_000_2b3d:
	set 0, a
	ldh [hVirusColoursHit], a
	jr jr_000_2af0



;@ def ShowPops()
;@ path: game/lines
;@ Clearing step 2: cleared capsule halves become "pop" tiles ($Dx), halves
;@ whose partner was cleared become lone halves, the clear sound plays (6 if
;@ a virus went in a column run, else 5) and the bottle is redrawn.
;@ writes: wSFXRequest, hRedrawRow, hClearStep
;@ test: for k in range(0x88): mem[0xC800 + k] = rng.choice([0xFF, 0x00, 0x01, 0x80, 0x91, 0xA2, 0xB0, 0xC1, 0xE0, 0xF2])
;@ test: mem[0xD041] = rng.choice([0, 1])
;@ sig: e5f1fd29
ShowPops::
;> PopClearedHalves(wBottle, 0x80)
	ld hl, wBottle
	ld b, $80
	ld c, b
	push hl
	call PopClearedHalves
	pop hl
;> SplitBrokenCapsules(wBottle, 0x80)
	call SplitBrokenCapsules
;> sfx = 5
;> if wColumnVirus:
	ld b, $05
	ld hl, wColumnVirus
	ld a, [hl]
	and a
	jr z, jr_000_2b5d

;>     wColumnVirus = 0
;>     sfx = 6
	xor a
	ld [hl], a
	inc b

jr_000_2b5d:
;> wSFXRequest = sfx
	ld a, b
	ld [wSFXRequest], a
;> hRedrawRow = 0x10
	ld a, $10
	ldh [hRedrawRow], a
;> hClearStep = 3
	ld a, $03
	ldh [hClearStep], a
	ret


;@ def PopClearedHalves(cell: hl, count: c)
;@ path: game/lines
;@ Turns every cleared capsule half (a tile below $10: just its colour) into a
;@ pop tile ($D0 + colour).
;@ test: cell = 0xC800; count = rand(1, 0x80)
;@ test: for k in range(0x80): mem[0xC800 + k] = rng.choice([0xFF, 0x00, 0x01, 0x02, 0x80, 0xE1])
;@ sig: 53cf202a
PopClearedHalves::
;> for i in range(count):
;>     if mem[cell + i] & 0xF0 == 0:
;>         PopCell(cell + i + 1)
	ld a, [hli]
	and $f0
	call z, PopCell
	dec c
	jr nz, PopClearedHalves

	ret


;@ def PopCell(next: hl)
;@ path: game/lines
;@ Adds $D0 to the cell before `next` (a cleared half becomes a pop tile).
;@ test: next = rand_ram(2) + 1; mem[(next & 0xFF00) | ((next - 1) & 0xFF)] = rand(0, 2)
;@ sig: d7b7513b
PopCell::
;> cell = (next & 0xFF00) | ((next - 1) & 0xFF)
;> mem[cell] = (mem[cell] + 0xD0) & 0xFF
	dec l
	ld a, [hl]
	add $d0
	ld [hli], a
	ret


;@ def SplitBrokenCapsules(cell: hl, count: b)
;@ path: game/lines
;@ A capsule half's tile says where its partner is: $8x left half, $9x right,
;@ $Ax top, $Bx bottom. A half whose partner is no longer there becomes a
;@ lone half, $Cx (same colour).
;@ test: cell = 0xC800; count = 0x80
;@ test: for k in range(0x88): mem[0xC800 + k] = rng.choice([0xFF, 0x80, 0x91, 0xA2, 0xB0, 0xC1, 0xD0, 0xE0])
;@ sig: 9d0ee000
SplitBrokenCapsules::
;> for i in range(count):
;>     at = cell + i
;>     kind = mem[at] & 0xF0
;>@k8     if kind == 0x80:
;>@k8b         if mem[at + 1] & 0xF0 != 0x90:
;>@k8c             mem[at] += 0x40
;>@k9     elif kind == 0x90:
;>@k9b         if mem[(at & 0xFF00) | ((at - 1) & 0xFF)] & 0xF0 != 0x80:   # (wraps within the page)
;>@k9c             mem[at] += 0x30
;>@ka     elif kind == 0xA0:
;>@kab         if mem[(at & 0xFF00) | ((at + 8) & 0xFF)] & 0xF0 != 0xB0:
;>@kac             mem[at] += 0x20
;>@kb     elif kind == 0xB0:
;>@kbb         if mem[(at & 0xFF00) | ((at - 8) & 0xFF)] & 0xF0 != 0xA0:
;>@kbc             mem[at] += 0x10
	ld a, [hli]
	and $f0
;=@k8
	cp $80
	jr z, jr_000_2b91

;=@k9
	cp $90
	jr z, jr_000_2b9f

;=@ka
	cp $a0
	jr z, jr_000_2bb1

;=@kb
	cp $b0
	jr z, jr_000_2bc5

jr_000_2b8d:
	dec b
	jr nz, SplitBrokenCapsules

	ret


jr_000_2b91:
;=@k8b
	ld a, [hl]
	and $f0
	cp $90
	jr z, jr_000_2b8d

;=@k8c
	dec l
	ld a, [hl]
	add $40
	ld [hli], a
	jr jr_000_2b8d

;=@k9b
jr_000_2b9f:
	push hl
	dec l
	dec l
	ld a, [hl]
	pop hl
	and $f0
	cp $80
	jr z, jr_000_2b8d

;=@k9c
	dec l
	ld a, [hl]
	add $30
	ld [hli], a
	jr jr_000_2b8d

;=@kab
jr_000_2bb1:
	push hl
	ld a, l
	add $07
	ld l, a
	ld a, [hl]
	pop hl
	and $f0
	cp $b0
	jr z, jr_000_2b8d

;=@kac
	dec l
	ld a, [hl]
	add $20
	ld [hli], a
	jr jr_000_2b8d

;=@kbb
jr_000_2bc5:
	push hl
	ld a, l
	sub $09
	ld l, a
	ld a, [hl]
	pop hl
	and $f0
	cp $a0
	jr z, jr_000_2b8d

;=@kbc
	dec l
	ld a, [hl]
	add $10
	ld [hli], a
	jr jr_000_2b8d

;@ def RemovePops()
;@ path: game/lines
;@ Clearing step 3: once the bottle has been redrawn, checks for the end of
;@ the level: no viruses left means a cleared level (1P) or a won round
;@ (2P, telling the other side). Otherwise the pops and destroyed viruses are
;@ emptied and step 5 lets the halves above fall.
;@ reads: hRedrawRow, hVirusesPlaced, hTwoPlayer, hVirusLevel2P, $FFD3, hVirusesLeft2P
;@ writes: hSerialTx, hClearStep, hGameState, hLevelCleared, hDangerLevel, hRedrawRow, $D00E, $FFF4, hRoundResult, wGarbageHeaderSent
;@ test: hRedrawRow = rng.choice([0, 0, 3]); hVirusesPlaced = rng.choice([0, 7, 30]); hTwoPlayer = rng.choice([0, 1]); hVirusLevel2P = rand(0, 20)
;@ test: mem[0xFFD3] = rand(0, 84); mem[0xFFC8] = rand(10, 21); mem[0xFFC9] = rand(5, 10); mem[0xFFCA] = rand(2, 5)
;@ test: for k in range(0x80): mem[0xC800 + k] = rng.choice([0xFF, 0xD0, 0xF1, 0xC2, 0xE0])
;@ sig: 765fe3b7
RemovePops::
;> QueueBottleRedraw()
	call QueueBottleRedraw
;> if hRedrawRow:                                  # still redrawing
;>     return
	ld a, [hl]
	and a
	ret nz

;> if hVirusesPlaced == 0:                         # no viruses left
	ldh a, [hVirusesPlaced]
	and a
	jr nz, jr_000_2bfa

;>     if hTwoPlayer:
	ldh a, [hTwoPlayer]
	and a
	jr z, jr_000_2c31

;>         hSerialTx = 0xF8                        # tell the other side: I won
;>         hRoundResult = 0xF8
	ld a, $f8
	ldh [hSerialTx], a
	ldh [hRoundResult], a
;>         wGarbageHeaderSent = 0
;>         hClearStep = 0
	xor a
	ld [wGarbageHeaderSent], a
	ldh [hClearStep], a
;>         hGameState = 0x17
;>         return
;>@win1     hClearStep = 0
;>@win2     hLevelCleared = 1
;>@win3     return
	ld a, $17
	ldh [hGameState], a
	ret


jr_000_2bfa:
;> if hVirusLevel2P >= 5:
	ldh a, [hVirusLevel2P]
	cp $05
	jr c, jr_000_2c1e

;>     left = hVirusesLeft2P
;>     hDangerLevel = 3 if left <= mem[hVirusThresholds + 2] else 2 if left <= mem[hVirusThresholds + 1] else 1 if left <= mem[hVirusThresholds] else 0
	ldh a, [hVirusesLeft2P]
	ld b, $03
	ld hl, hVirusThresholds + 2
	cp [hl]
	jr z, jr_000_2c1b

	jr c, jr_000_2c1b

	dec b
	dec hl
	cp [hl]
	jr z, jr_000_2c1b

	jr c, jr_000_2c1b

	dec b
	dec hl
	cp [hl]
	jr z, jr_000_2c1b

	jr c, jr_000_2c1b

	dec b

jr_000_2c1b:
	ld a, b
	ldh [hDangerLevel], a

jr_000_2c1e:
;> EmptyPoppedCells(wBottle, 0x80, 0xFF)
	ld hl, wBottle
	ld b, $80
	ld c, $ff
	call EmptyPoppedCells
;> hClearStep = 5
	ld a, $05
	ldh [hClearStep], a
;> hRedrawRow = 0x10
	ld a, $10
	ldh [hRedrawRow], a
	ret


;=@win1
jr_000_2c31:
	xor a
	ldh [hClearStep], a
;=@win2
	inc a
	ldh [hLevelCleared], a
;=@win3
	ret


;@ def EmptyPoppedCells(cell: hl, count: b, blank: c)
;@ path: game/lines
;@ Empties (sets to `blank`) every pop tile ($Dx) and destroyed virus ($Fx).
;@ test: cell = 0xC800; count = rand(1, 0x80); blank = 0xFF
;@ test: for k in range(0x80): mem[0xC800 + k] = rng.choice([0xFF, 0xD0, 0xD2, 0xF1, 0xC2, 0xE0, 0x80])
;@ sig: 7228381d
EmptyPoppedCells::
;> for i in range(count):
;>     if mem[cell + i] & 0xF0 in (0xD0, 0xF0):
;>         EmptyCell(cell + i + 1, blank)
	ld a, [hli]
	and $f0
	cp $d0
	call z, EmptyCell
	cp $f0
	call z, EmptyCell
	dec b
	jr nz, EmptyPoppedCells

	ret


;@ def EmptyCell(next: hl, blank: c)
;@ path: game/lines
;@ test: next = rand_ram(2) + 1; blank = rand(0, 255)
;@ sig: 445ea480
EmptyCell::
;> mem[(next & 0xFF00) | ((next - 1) & 0xFF)] = blank
	dec l
	ld a, $ff
	ld [hl], c
	inc l
	ret


;@ def QueueBottleRedraw() -> hl
;@ path: game/lines
;@ While rows remain to be redrawn, asks the VBlank handler to copy bottle row
;@ hRedrawRow - 1 to the screen (BG map from $9842 on). For row 0 the
;@ address loop runs 256 times and points outside VRAM, so the hidden top
;@ row is never drawn.
;@ reads: hRedrawRow
;@ writes: hVBlankJob, $D023, $D024, $D026, wRedrawCell, wRedrawVRAM
;@ test: hRedrawRow = rand(0, 16)
;@ sig: 804edbac
QueueBottleRedraw::
;> if not hRedrawRow:
;>     return 0xFFEF
	ld hl, hRedrawRow
	ld a, [hl]
	and a
	ret z

;> hVBlankJob = 0
	xor a
	ldh [hVBlankJob], a
;> n = hRedrawRow - 1
;> addr = (0x9822 + 32 * (n or 256)) & 0xFFFF
	ld a, [hl]
	dec a
	ld c, a
	ld hl, $9822
	ld de, $0020

jr_000_2c61:
	add hl, de
	dec a
	jr nz, jr_000_2c61

;> mem[wRedrawVRAM] = addr >> 8
;> mem[wRedrawVRAM + 1] = addr & 0xFF
	ld a, h
	ld [wRedrawVRAM], a
	ld a, l
	ld [wRedrawVRAM + 1], a
;> wRedrawCell = (8 * n) & 0xFF                    # the row's first cell in the bottle
	xor a
	ld b, $08

jr_000_2c70:
	add b
	dec c
	jr nz, jr_000_2c70

	ld [wRedrawCell], a
;> hVBlankJob = 2
	ld a, $02
	ldh [hVBlankJob], a
;> return 0xFFEF                                   # hRedrawRow
	ld hl, hRedrawRow
	ret




;@ def DropHalves()
;@ path: game/lines
;@ Clearing step 4: everything that has room below falls one row (scanning
;@ bottom up, so a whole stack falls in one pass), then the bottle is
;@ redrawn and the next pass runs. When nothing moves any more, step 0 looks
;@ for new runs: that is how chain reactions happen.
;@ reads: hDropWait, hHalvesMoved, hRedrawRow
;@ writes: hHalvesMoved, hDropWait, hRedrawRow, hClearStep, wSFXRequest
;@ test: hDropWait = rng.choice([0, 0, 1]); hRedrawRow = rng.choice([0, 0, 2]); hHalvesMoved = 0
;@ test: for k in range(0x80): mem[0xC800 + k] = rng.choice([0xFF, 0xFF, 0xFF, 0xE0, 0xC1, 0x80, 0x91, 0xA2, 0xB0])
;@ sig: c76fee0f
DropHalves::
;> if not hDropWait:
	ld b, $78
	ld c, $ff
	ldh a, [hDropWait]
	and a
	jr nz, jr_000_2ca5

;>     cell = 0xC87F                               # the bottom right cell
;>     for _ in range(0x78):                       # up to row 1
	ld hl, wBottle + $7F

jr_000_2c8b:
;>         if mem[cell] == 0xFF:
;>             cell = DropIntoCell(cell, 0xFF)
	ld a, [hl]
	cp c
	call z, DropIntoCell
;>         cell = (cell & 0xFF00) | ((cell - 1) & 0xFF)
	dec l
	dec b
	jr nz, jr_000_2c8b

;>     if not hHalvesMoved:                        # nothing fell: look for new runs
;>@done         hClearStep = 0
;>@doneret         return
	ld hl, hHalvesMoved
	ld a, [hl]
	and a
	jr z, jr_000_2cb0

;>     hHalvesMoved = 0
	xor a
	ld [hl], a
;>     hDropWait = 1
	ld a, $01
	ldh [hDropWait], a
;>     hRedrawRow = 0x10
	ld a, $10
	ldh [hRedrawRow], a

jr_000_2ca5:
;> QueueBottleRedraw()
	call QueueBottleRedraw
;> if hRedrawRow:
;>     return
	ldh a, [hRedrawRow]
	and a
	ret nz

;> hDropWait = 0
	xor a
	ldh [hDropWait], a
	ret


jr_000_2cb0:
;=@done
	xor a
	ldh [hClearStep], a
;=@doneret
	ret


;@ def DropIntoCell(cell: hl, blank: c) -> hl
;@ path: game/lines
;@ Lets the piece above an empty cell fall into it. Viruses stay, left halves
;@ only move with their right half, and a right half moves only if the cell
;@ beside the empty one is empty too (both halves fall). After a right half
;@ it returns the cell to its left, so the caller's scan skips that cell.
;@ writes: wSFXRequest, hHalvesMoved
;@ test: cell = 0xC800 + rand(0x10, 0x7F); blank = 0xFF; hHalvesMoved = 0
;@ test: for k in range(0x80): mem[0xC800 + k] = rng.choice([0xFF, 0xFF, 0xE0, 0xC1, 0x80, 0x91, 0x92, 0xA2, 0xB0, 0xD1])
;@ sig: 415f3d6f
DropIntoCell::
;> above = (cell & 0xFF00) | ((cell - 8) & 0xFF)
;> v = mem[above]
;> if v == 0xFF or v < 0x83 or v & 0xF0 == 0xE0:    # empty, a left half, or a virus
	push hl
	ld a, l
	sub $08
	ld l, a
	ld a, [hl]
	cp $ff
	jr z, jr_000_2cda

	cp $83
	jr c, jr_000_2cda

	and $f0
	cp $e0
	jr z, jr_000_2cda

;>@skipret     return cell
;>@right if v & 0xF0 == 0x90:                         # a right half: the pair falls together
;>@r1     left = (cell & 0xFF00) | ((cell - 1) & 0xFF)
;>@r2     if mem[left] != 0xFF:
;>@r3         return left
;>@r4     above_left = (left & 0xFF00) | ((left - 8) & 0xFF)
;>@r5     mem[left], mem[above_left] = mem[above_left], blank
;>@r6     mem[cell], mem[above] = mem[above], blank
;>@r7     hHalvesMoved = 1
;>@r8     return left
;=@right
	cp $90
	jr z, jr_000_2ce1

;> wSFXRequest = 4
	ld a, $04
	ld [wSFXRequest], a
;> mem[cell], mem[above] = mem[above], blank
	ld a, [hl]
	ld [hl], c
	pop hl
	ld [hl], a
;> hHalvesMoved = 1
	ld a, $01
	ldh [hHalvesMoved], a
;> return cell
	ret


;=@skipret
jr_000_2cda:
	pop hl
	ret


	db $e1, $3e, $ff, $77, $c9

jr_000_2ce1:
;=@r1
	pop hl
	dec l
;=@r2
	ld a, [hl]
	cp $ff
;=@r3
	ret nz

;=@r4
	push hl
	ld a, l
	sub $08
	ld l, a
;=@r5
	ld d, [hl]
	ld [hl], c
;=@r6
	inc l
	ld e, [hl]
	ld [hl], c
;=@r5
	pop hl
	ld [hl], d
;=@r6
	inc l
	ld [hl], e
;=@r8
	dec l
;=@r7
	ld a, $01
	ldh [hHalvesMoved], a
;=@r8
	ret


;@ def WaitThenDropHalves()
;@ path: game/lines
;@ Clearing step 5: waits for the bottle redraw, then step 4.
;@ writes: hClearStep
;@ test: hRedrawRow = rng.choice([0, 0, 4])
;@ sig: 272d73e5
WaitThenDropHalves::
;> QueueBottleRedraw()
	call QueueBottleRedraw
;> if hRedrawRow:
;>     return
	ld a, [hl]
	and a
	ret nz

;> hClearStep = 4
	ld a, $04
	ldh [hClearStep], a
	ret


;@ def DropGarbage()
;@ path: versus/play
;@ Clearing step 6, the turn is over. In a link game, two or more runs sent
;@ by the other side arrive here as lone halves in the top row (their colours
;@ from hGarbage, the columns from GarbageColumns, picked at random); then
;@ step 7. Otherwise the next capsule is thrown (state $0A).
;@ reads: hGarbage, rDIV
;@ writes: hGarbage, hClearStep, hRedrawRow, hCapsuleState, hGameState
;@ test: hGarbage = rng.choice([0, 0x01, 0x06, 0x1B, 0x6E, 0x9B]); rDIV = rand(0, 255)
;@ test: for k in range(0x88): mem[0xC800 + k] = rng.choice([0xFF, 0xFF, 0xE0, 0x80, 0x91, 0xA2, 0xB0])
;@ sig: 7e63c8bf
DropGarbage::
;> g = hGarbage
;> if g & 0xFC == 0:                               # fewer than two runs: nothing arrives
	ld hl, hGarbage
	ld d, $c8
	ld a, [hl]
	and $fc
	jr z, jr_000_2d3c

;>@done     hGarbage = 0
;>@done2     hCapsuleState = 0
;>@done3     hClearStep = 0
;>@done4     hGameState = 0x0A
;>@done5     return
;>@two if g & 0xF0 == 0:                              # two halves
;>@two2     cols = (0x2E1A, 0x2E1C, 0x2E1E, 0x2E20)[rDIV & 3]
;>@two3     AlignGarbageColours(0xFFD9)
;>@two4     cols = PlaceGarbageHalf(0xFFD9, cols, 0xC8)
;>@two5     PlaceGarbageHalf(0xFFD9, cols, 0xC8)
;>@three elif g & 0xC0 == 0:                          # three
;>@three2     cols = (0x2E0E, 0x2E11, 0x2E14, 0x2E17)[rDIV & 3]
;>@three3     AlignGarbageColours(0xFFD9)
;>@three4     for _ in range(3):
;>@three5         cols = PlaceGarbageHalf(0xFFD9, cols, 0xC8)
;> else:                                           # four
;=@two
	and $f0
	jr z, jr_000_2d48

;=@three
	and $c0
	jr z, jr_000_2d73

;>     cols = 0x2E0A if rDIV & 1 else 0x2E06
	ld bc, $2e06
	ldh a, [rDIV]
	and $01
	jr z, jr_000_2d24

	ld bc, $2e0a

jr_000_2d24:
;>     for _ in range(4):
;>         cols = PlaceGarbageHalf(0xFFD9, cols, 0xC8)
	call PlaceGarbageHalf
	call PlaceGarbageHalf
	call PlaceGarbageHalf
	call PlaceGarbageHalf

jr_000_2d30:
;> hGarbage = 0
	xor a
	ldh [hGarbage], a
;> hClearStep = 7
	ld a, $07
	ldh [hClearStep], a
;> hRedrawRow = 3                                  # redraw the top rows
	ld a, $03
	ldh [hRedrawRow], a
	ret


;=@done
jr_000_2d3c:
	xor a
	ldh [hGarbage], a
;=@done2
	ldh [hCapsuleState], a
;=@done3
	ldh [hClearStep], a
;=@done4
	ld a, $0a
	ldh [hGameState], a
;=@done5
	ret


;=@two2
jr_000_2d48:
	ldh a, [rDIV]
	and $03
	jr z, jr_000_2d5b

	cp $01
	jr z, jr_000_2d60

	cp $02
	jr z, jr_000_2d65

	ld bc, $2e20
	jr jr_000_2d68

jr_000_2d5b:
	ld bc, $2e1a
	jr jr_000_2d68

jr_000_2d60:
	ld bc, $2e1c
	jr jr_000_2d68

jr_000_2d65:
	ld bc, $2e1e

jr_000_2d68:
;=@two3
	call AlignGarbageColours
;=@two4
	call PlaceGarbageHalf
;=@two5
	call PlaceGarbageHalf
	jr jr_000_2d30

;=@three2
jr_000_2d73:
	ldh a, [rDIV]
	and $03
	jr z, jr_000_2d86

	cp $01
	jr z, jr_000_2d8b

	cp $02
	jr z, jr_000_2d90

	ld bc, $2e17
	jr jr_000_2d93

jr_000_2d86:
	ld bc, $2e0e
	jr jr_000_2d93

jr_000_2d8b:
	ld bc, $2e11
	jr jr_000_2d93

jr_000_2d90:
	ld bc, $2e14

jr_000_2d93:
;=@three3
	call AlignGarbageColours
;=@three5
	call PlaceGarbageHalf
	call PlaceGarbageHalf
	call PlaceGarbageHalf
	jr jr_000_2d30

;@ def AlignGarbageColours(colours: hl)
;@ path: versus/play
;@ Shifts the colour list up until its top two bits hold a colour.
;@ test: colours = rand_ram(1); mem[colours] = rng.choice([0x06, 0x1B, 0x07, 0x2D, 0x9B])
;@ sig: cec7d0f9
AlignGarbageColours::
;> e = mem[colours]
	ld a, [hl]
	ld e, a

jr_000_2da3:
;> while not e & 0xC0:
;>     e = (e << 2) & 0xFF
	ld a, e
	and $c0
	jr nz, jr_000_2dae

	sla e
	sla e
	jr jr_000_2da3

jr_000_2dae:
;> mem[colours] = e
	ld [hl], e
	ret


;@ def PlaceGarbageHalf(colours: hl, cols: bc, page: d) -> bc
;@ path: versus/play
;@ Drops one garbage half into the top row at the column listed at `cols`:
;@ takes the next colour from the list (rotating it two bits), writes a lone
;@ half ($C0 + colour - 1) and splits any capsule beside or below it.
;@ test: colours = rand_ram(1); mem[colours] = rng.choice([0x5B, 0x9C, 0x6F]); cols = 0x2E06 + rand(0, 27); page = 0xC8
;@ test: for k in range(0x88): mem[0xC800 + k] = rng.choice([0xFF, 0xE0, 0x80, 0x91, 0xA2, 0xB0])
;@ sig: bf913c4f
PlaceGarbageHalf::
;> cell = page << 8 | mem[cols]                     # page = $C8: the bottle
	ld a, [bc]
	ld e, a
;> mem[colours] = ((mem[colours] << 2) | (mem[colours] >> 6)) & 0xFF
	rlc [hl]
	rlc [hl]
;> mem[cell] = (0xC0 + (mem[colours] & 3) - 1) & 0xFF
	ld a, [hl]
	and $03
	dec a
	add $c0
	ld [de], a
;> SplitLowerNeighbour(SplitLeftNeighbour(SplitRightNeighbour(cell)))
	push af
	push bc
	push de
	push hl
	call SplitRightNeighbour
	call SplitLeftNeighbour
	call SplitLowerNeighbour
;> return cols + 1
	pop hl
	pop de
	pop bc
	pop af
	inc bc
	ret


;@ def SplitRightNeighbour(cell: de) -> de
;@ path: versus/play
;@ Moves to the cell on the right (unless past the row end, $10): a right
;@ half there becomes a lone half.
;@ test: cell = 0xC808 + rand(0, 7); mem[(cell + 1) & 0xFFFF] = rng.choice([0xFF, 0x91, 0x92, 0xA0])
;@ sig: 55343832
SplitRightNeighbour::
;> cell = (cell & 0xFF00) | ((cell + 1) & 0xFF)
	inc e
;> if cell & 0xFF == 0x10:
;>     return cell
	ld a, e
	cp $10
	ret z

;> if mem[cell] & 0xF0 == 0x90:
	ld a, [de]
	and $f0
	cp $90
	ret nz

;>     mem[cell] = 0xC0 + (mem[cell] & 0x0F)
	ld a, [de]
	and $0f
	add $c0
	ld [de], a
;> return cell
	ret


;@ def SplitLeftNeighbour(cell: de) -> de
;@ path: versus/play
;@ From the cell right of the garbage half, moves to the one on its left
;@ (unless before the row start, $07): a left half there becomes lone.
;@ test: cell = 0xC809 + rand(0, 7); mem[(cell & 0xFF00) | ((cell - 2) & 0xFF)] = rng.choice([0xFF, 0x80, 0x81, 0xB0])
;@ sig: 50bff1e0
SplitLeftNeighbour::
;> cell = (cell & 0xFF00) | ((cell - 2) & 0xFF)
	dec e
	dec e
;> if cell & 0xFF == 0x07:
;>     return cell
	ld a, e
	cp $07
	ret z

;> if mem[cell] & 0xF0 == 0x80:
	ld a, [de]
	and $f0
	cp $80
	ret nz

;>     mem[cell] = 0xC0 + (mem[cell] & 0x0F)
	ld a, [de]
	and $0f
	add $c0
	ld [de], a
;> return cell
	ret


;@ def SplitLowerNeighbour(cell: de) -> de
;@ path: versus/play
;@ From the cell left of the garbage half, moves to the one below it: a
;@ bottom half there becomes lone.
;@ test: cell = 0xC807 + rand(0, 7); mem[(cell & 0xFF00) | ((cell + 9) & 0xFF)] = rng.choice([0xFF, 0xB0, 0xB2, 0xA1])
;@ sig: 0775f250
SplitLowerNeighbour::
;> cell = (cell & 0xFF00) | ((cell + 9) & 0xFF)
	ld a, $09
	add e
	ld e, a
;> if mem[cell] & 0xF0 == 0xB0:
	ld a, [de]
	and $f0
	cp $b0
	ret nz

;>     mem[cell] = 0xC0 + (mem[cell] & 0x0F)
	ld a, [de]
	and $0f
	add $c0
	ld [de], a
;> return cell
	ret


GarbageColumns::
	db $08, $0a, $0c, $0e, $09, $0b, $0d, $0f, $08, $0a, $0c, $09, $0b, $0d, $0a, $0c
	db $0e, $0b, $0d, $0f, $08, $0c, $09, $0d, $0a, $0e, $0b, $0f

;@ def WaitAfterGarbage()
;@ path: versus/play
;@ Clearing step 7: waits for the redraw, then lets the garbage fall (step 4).
;@ writes: hClearStep
;@ test: hRedrawRow = rng.choice([0, 0, 2])
;@ sig: 272d73e5
WaitAfterGarbage::
;> QueueBottleRedraw()
	call QueueBottleRedraw
;> if hRedrawRow:
;>     return
	ld a, [hl]
	and a
	ret nz

;> hClearStep = 4
	ld a, $04
	ldh [hClearStep], a
	ret



;@ def VBlankDraw()
;@ path: system/vblank
;@ The game's drawing in VBlank. Runs the queued job (hVBlankJob), then
;@ animates tiles: in a level the bottle viruses (one tile of VirusAnimTiles
;@ on three frames out of eight), in a cutscene the underwater tiles (every 8
;@ frames, a four-step cycle). Last it writes the 1-player virus count, or a
;@ finished link round's results panel.
;@ reads: hVBlankJob, hCutscenePhase, hFrameCount, wInPlay, hTwoPlayer, hVirusesPlacedBCD, $D00D, $D04B, wShowResults, wVirusAnim
;@ writes: hVBlankJob, hVirusAnim
;@ test: skip runs a job through a jump table
;@ sig: 00a693dc
VBlankDraw::
;> if hVBlankJob:
;>     RunVBlankJob(0xFF9D)
	ld hl, hVBlankJob
	ld a, [hl]
	and a
	call nz, RunVBlankJob
;> hVBlankJob = 0
	xor a
	ldh [hVBlankJob], a
;> if hCutscenePhase == 0:
	ldh a, [hCutscenePhase]
	and a
	jr nz, jr_000_2e70

;>     if wVirusAnim and hFrameCount & 7 < 3:     # in a level: wiggle the viruses
	ld a, [wVirusAnim]
	and a
	jp z, Jump_000_2ed2

	ldh a, [hFrameCount]
	and $07
	cp $03
	jp nc, Jump_000_2ed2

;>         hVirusAnim = (hVirusAnim + 0x10) % 0x60
	ld de, hVirusAnim
	ld a, [de]
	add $10
	cp $60
	jr nz, jr_000_2e58

	xor a

jr_000_2e58:
	ld [de], a
;>         dest = 0x8E00 | (hVirusAnim if hVirusAnim < 0x30 else (hVirusAnim + 0x10) & 0x3F)
	ld c, a
	ld b, $00
	ld hl, $4b9e
	add hl, bc
	ld d, $8e
	cp $30
	jr c, jr_000_2e6a

	add $10
	and $3f

jr_000_2e6a:
;>         CopyTile16(VirusAnimTiles + hVirusAnim, dest)
;>@uw elif hFrameCount & 7 == 0:                      # a cutscene: the underwater tiles
;>@uw2     step = wUnderwaterStep
;>@uw3     if step == 0:
;>@uw4         wUnderwaterStep += 1
;>@uw5         for k in range(3):
;>@uw6             CopyTile16(0x566E + 0x10 * k, 0x88D0 + 0x10 * k)
;>@uw7         SwapUnderwaterTilesA()
;>@uw8     elif step == 1:
;>@uw9         wUnderwaterStep += 1
;>@uw10         SwapUnderwaterTilesB()
;>@uw11     elif step == 2:
;>@uw12         wUnderwaterStep += 1
;>@uw13         for k in range(3):
;>@uw14             CopyTile16(0x5A5E + 0x10 * k, 0x88D0 + 0x10 * k)
;>@uw15         SwapUnderwaterTilesA()
;>@uw16     else:
;>@uw17         wUnderwaterStep = 0
;>@uw18         SwapUnderwaterTilesB()
	ld e, a
	call CopyTile16
	jr jr_000_2ed2

;=@uw
jr_000_2e70:
	ldh a, [hFrameCount]
	and $07
	jr nz, jr_000_2ed2

;=@uw2
	ld hl, wUnderwaterStep
	ld a, [hl]
	and a
	jr z, jr_000_2e8c

;=@uw8
	cp $01
	jr z, jr_000_2ead

;=@uw11
	cp $02
	jr z, jr_000_2eb3

;=@uw17
	xor a
	ld [hl], a
;=@uw18
	call SwapUnderwaterTilesB
	jr jr_000_2ed2

;=@uw4
jr_000_2e8c:
	inc [hl]
;=@uw6
	ld hl, $566e
	ld de, $88d0
	call CopyTile16
	ld hl, $567e
	ld de, $88e0
	call CopyTile16
	ld hl, $568e
	ld de, $88f0
	call CopyTile16
;=@uw7
	call SwapUnderwaterTilesA
	jr jr_000_2ed2

;=@uw9
jr_000_2ead:
	inc [hl]
;=@uw10
	call SwapUnderwaterTilesB
	jr jr_000_2ed2

;=@uw12
jr_000_2eb3:
	inc [hl]
;=@uw14
	ld hl, $5a5e
	ld de, $88d0
	call CopyTile16
	ld hl, $5a6e
	ld de, $88e0
	call CopyTile16
	ld hl, $5a7e
	ld de, $88f0
	call CopyTile16
;=@uw15
	call SwapUnderwaterTilesA

;> if wInPlay and not hTwoPlayer:                  # the virus count on the side panel
Jump_000_2ed2:
jr_000_2ed2:
	ld a, [wInPlay]
	and a
	jr z, jr_000_2eef

	ldh a, [hTwoPlayer]
	and a
	jr nz, jr_000_2eef

;>     mem[0x99B1] = hVirusesPlacedBCD >> 4
	ld hl, hVirusesPlacedBCD
	ld a, [hl]
	ld b, a
	and $f0
	swap a
	ld hl, $99b1
	ld [hli], a
;>     mem[0x99B2] = hVirusesPlacedBCD & 0x0F
;>@ret     return
;>@res if wShowResults:                                # a link round is over: its results
;>@res2     DrawLevels2P()
;>@res3     DrawSpeeds2P()
;>@res4     DrawVirusCounts2P()
	ld a, b
	and $0f
	ld [hl], a
;=@ret
	ret


;=@res
jr_000_2eef:
	ld a, [wShowResults]
	and a
	ret z

;=@res2
	call DrawLevels2P
;=@res3
	call DrawSpeeds2P
;=@res4
	call DrawVirusCounts2P
	ret


;@ def SwapUnderwaterTilesA()
;@ path: cutscenes
;@ Copies the two tiles from Tiles_559E to $8800 and $8810 in their usual order.
;@ sig: 39deaea7
SwapUnderwaterTilesA::
;> CopyTile16(Tiles_559E, 0x8800)
	ld hl, $559e
	ld de, $8800
	call CopyTile16
;> CopyTile16(Tiles_559E + 0x10, 0x8810)
	ld hl, $55ae
	ld de, $8810
	call CopyTile16
	ret


;@ def SwapUnderwaterTilesB()
;@ path: cutscenes
;@ ... and swapped: the two tiles alternate, which makes them move.
;@ sig: 640a8a5d
SwapUnderwaterTilesB::
;> CopyTile16(Tiles_559E + 0x10, 0x8800)
	ld hl, $55ae
	ld de, $8800
	call CopyTile16
;> CopyTile16(Tiles_559E, 0x8810)
	ld hl, $559e
	ld de, $8810
	call CopyTile16
	ret


;@ def CopyTile16(src: hl, dest: de) -> (hl, de)
;@ path: system/vblank
;@ Copies one tile (16 bytes).
;@ test: src = rand(0x4000, 0x5000); dest = rand_ram(16)
;@ sig: e843b1ee
CopyTile16::
;> for i in range(16):
;>     mem[dest + i] = mem[src + i]
;> return src + 16, dest + 16
	ld b, $10

jr_000_2f26:
	ld a, [hli]
	ld [de], a
	inc de
	dec b
	jr nz, jr_000_2f26

	ret


;@ def RunVBlankJob(job: hl)
;@ path: system/vblank
;@ test: skip jumps through a table
;@ sig: c0d0b96e
RunVBlankJob::
;> goto((NoVBlankJob, DrawNewVirus, DrawBottleRow, TypeLetter)[mem[job]])
	ld a, [hl]
	rst $28

JumpTable_2F2F::
	dw NoVBlankJob
	dw DrawNewVirus
	dw DrawBottleRow
	dw TypeLetter

;@ def NoVBlankJob()
;@ path: system/vblank
;@ sig: 30ba9599
NoVBlankJob::
;> return
	ret


;@ def DrawNewVirus()
;@ path: system/vblank
;@ Job 1: puts the virus just placed (tile in $D035) at its BG map address
;@ ($D036/$D037, from BottleCellToVRAM).
;@ writes: $D00C, wNewVirusPending
;@ reads: $D00C, $D035, wNewVirusPending, wNewVirusTile
;@ test: mem[0xD00C] = rng.choice([0, 1]); mem[0xD036] = 0xC1; mem[0xD037] = rand(0, 255); mem[0xD035] = rand(0xE0, 0xE2)
;@ sig: 9b89b85d
DrawNewVirus::
;> if not wNewVirusPending:
;>     return
	ld a, [wNewVirusPending]
	and a
	ret z

;> vram = mem[wNewVirusVRAM] << 8 | mem[wNewVirusVRAM + 1]
	ld hl, wNewVirusVRAM
	ld a, [hli]
	ld d, a
	ld a, [hl]
	ld e, a
;> mem[vram] = wNewVirusTile                         # (written twice)
	ld a, [wNewVirusTile]
	ld [de], a
	ld [de], a
;> wNewVirusPending = 0
	xor a
	ld [wNewVirusPending], a
	ret


;@ def DrawBottleRow()
;@ path: system/vblank
;@ Job 2: copies one bottle row (8 cells from $C800 + [$D026]) to the BG map
;@ address in $D023/$D024 and counts hRedrawRow down; at 1 it stops (row 0,
;@ hidden, is never drawn).
;@ reads: hRedrawRow
;@ writes: hRedrawRow
;@ test: mem[0xD023] = 0xC1; mem[0xD024] = rand(0, 0xE0); mem[0xD026] = 8 * rand(0, 15); hRedrawRow = rand(1, 16)
;@ sig: 79de91a9
DrawBottleRow::
;> vram = mem[wRedrawVRAM] << 8 | mem[wRedrawVRAM + 1]
;> cells = 0xC800 | wRedrawCell
	ld hl, wRedrawVRAM
	ld a, [hli]
	ld b, a
	ld a, [hli]
	ld c, a
	ld d, $c8
	inc hl
	ld e, [hl]
	push bc
	pop hl
;> for i in range(8):
;>     mem[vram + i] = mem[(cells & 0xFF00) | ((cells + i) & 0xFF)]
	ld b, $08

jr_000_2f5d:
	ld a, [de]
	ld [hli], a
	inc e
	dec b
	jr nz, jr_000_2f5d

;> hRedrawRow -= 1
;> if hRedrawRow == 1:
	ld hl, hRedrawRow
	dec [hl]
	ld a, [hl]
	dec a
	ret nz

;>     hRedrawRow = 0
	ld [hl], a
	ret


;@ def TypeLetter()
;@ path: system/vblank
;@ Job 3: types the next letter of the ending text ($C500 + [$D009]) at the
;@ BG map address in $D068/$D069, with a click unless it is a blank.
;@ writes: wSFXRequest
;@ reads: $D009, wEndingLetter
;@ test: mem[0xD068] = 0xC1; mem[0xD069] = rand(0, 255); mem[0xD009] = rand(0, 0x3B)
;@ test: for k in range(0x40): mem[0xC500 + k] = rng.choice([0xFF, rand(0, 0x30)])
;@ sig: 4682bf0a
TypeLetter::
;> vram = mem[wTextVRAM] << 8 | mem[wTextVRAM + 1]
	ld hl, wTextVRAM
	ld a, [hli]
	ld d, a
	ld e, [hl]
;> letter = mem[0xC500 + wEndingLetter]
	ld a, [wEndingLetter]
	ld l, a
	ld h, $c5
	ld a, [hl]
;> mem[vram] = letter
	ld [de], a
;> if letter != 0xFF:
	cp $ff
	ret z

;>     wSFXRequest = 1
	ld a, $01
	ld [wSFXRequest], a
	ret


;@ def DrawLevels2P()
;@ path: versus/results
;@ The round results panel (BG map 1): both virus levels.
;@ reads: hVirusLevelBCD, hVirusLevel2PBCD
;@ test: hVirusLevelBCD = rand_bcd(1); hVirusLevel2PBCD = rand_bcd(1)
;@ sig: bb014978
DrawLevels2P::
;> DrawTwoBCD(hVirusLevelBCD, hVirusLevel2PBCD, 0x9CA1)
	ld hl, $9ca1
	ldh a, [hVirusLevelBCD]
	ld b, a
	ldh a, [hVirusLevel2PBCD]
	ld c, a
	call DrawTwoBCD
	ret


;@ def DrawSpeeds2P()
;@ path: versus/results
;@ Both speeds, as HI / MED / LOW.
;@ reads: hSpeed, hSpeed2P
;@ test: hSpeed = rand(2, 4); hSpeed2P = rand(2, 4)
;@ sig: d473dd3f
DrawSpeeds2P::
;> DrawSpeedName(hSpeed, 0x9CE1)
	ld hl, $9ce1
	ldh a, [hSpeed]
	call DrawSpeedName
;> DrawSpeedName(hSpeed2P, 0x9CE5)
	ld hl, $9ce5
	ldh a, [hSpeed2P]
	call DrawSpeedName
	ret


;@ def DrawVirusCounts2P()
;@ path: versus/results
;@ Both sides' viruses left.
;@ reads: hVirusesPlacedBCD, $FFD4, hVirusesLeft2PBCD
;@ test: hVirusesPlacedBCD = rand_bcd(1); mem[0xFFD4] = rand_bcd(1)
;@ sig: 69797e54
DrawVirusCounts2P::
;> DrawTwoBCD(hVirusesPlacedBCD, hVirusesLeft2PBCD, 0x9D21)
	ld hl, $9d21
	ldh a, [hVirusesPlacedBCD]
	ld b, a
	ldh a, [hVirusesLeft2PBCD]
	ld c, a
	call DrawTwoBCD
	ret


;@ def DrawTwoBCD(left: b, right: c, dest: hl)
;@ path: versus/results
;@ Writes two BCD bytes as digits: left at dest, right four tiles further.
;@ test: left = rand_bcd(1); right = rand_bcd(1); dest = 0xC100 + rand(0, 0x80)
;@ sig: 960a3c3b
DrawTwoBCD::
;> mem[dest] = left >> 4
;> mem[dest + 1] = left & 0x0F
	ld a, b
	swap a
	and $0f
	ld [hli], a
	ld a, b
	and $0f
	ld [hli], a
	inc l
	inc l
	inc l
;> mem[dest + 5] = right >> 4
;> mem[dest + 6] = right & 0x0F
	ld a, c
	swap a
	and $0f
	ld [hli], a
	ld a, c
	and $0f
	ld [hl], a
	ret


;@ def PlaceViruses()
;@ path: game/viruses
;@ Game state $03: fills the bottle with viruses, one per frame. The demo
;@ loads a fixed bottle instead; a link slave playing the same level as the
;@ master waits for the master's bottle (state $19).
;@ reads: hDemoMode, hSerialRole, hVirusLevel, hVirusLevel2P
;@ writes: $D00D, $D021, wLevelStartWait, wVirusAnim
;@ test: skip the 2-player branches loop back into each other
;@ sig: 36d6c18c
PlaceViruses::
;> wLevelStartWait = 1
;> wVirusAnim = 1
	ld a, $01
	ld [wLevelStartWait], a
	ld [wVirusAnim], a
;> if hDemoMode:
;>     return PlaceVirusesDemo()
	ldh a, [hDemoMode]
	and a
	jr nz, PlaceVirusesDemo

;> if hSerialRole == SERIAL_SLAVE and hVirusLevel == hVirusLevel2P:
;>     return SlaveCopyVirusCount()
	ldh a, [hSerialRole]
	cp $60
	jr nz, jr_000_2fe1

	ldh a, [hVirusLevel]
	ld b, a
	ldh a, [hVirusLevel2P]
	cp b
	jr z, SlaveCopyVirusCount

;> PlaceVirusesCheck()                             # falls through

;@ def PlaceVirusesCheck()
;@ path: game/viruses
;@ Places another virus until there are enough. When both link players play
;@ the same level, the master then hands the bottle over (state $19).
;@ reads: hVirusCount, hVirusesPlaced, hTwoPlayer, hVirusLevel, hVirusLevel2P
;@ test: skip PlaceOneVirus loops back here
;@ sig: 526563cc
PlaceVirusesCheck::
jr_000_2fe1:
;> if hVirusCount != hVirusesPlaced:
;>     return PlaceOneVirus()
	ldh a, [hVirusCount]
	ld hl, hVirusesPlaced
	cp [hl]
	jr nz, PlaceOneVirus

;> if hTwoPlayer and hVirusLevel == hVirusLevel2P:
;>     return VersusSameLevelWait()
	ldh a, [hTwoPlayer]
	and a
	jr z, jr_000_2ff6

	ldh a, [hVirusLevel]
	ld b, a
	ldh a, [hVirusLevel2P]
	cp b
	jr z, VersusSameLevelWait

;> PlaceVirusesDone()                              # falls through

;@ def PlaceVirusesDone()
;@ path: game/viruses
;@ The bottle is ready: start the level's music and play (state $0A).
;@ writes: hGameState, $C4F1, wInPlay
;@ test: hDemoMode = rng.choice([0, 1]); hMusicType = rand(0, 2)
;@ sig: 9e579572
PlaceVirusesDone::
jr_000_2ff6:
;> StartLevelMusic()
	call StartLevelMusic
;> hGameState = 0x0A
	ld a, $0a
	ldh [hGameState], a
;> wInPlay = 0
	xor a
	ld [wInPlay], a
	ret


;@ def StartLevelMusic()
;@ path: game/setup
;@ Requests the chosen music: FEVER (1), CHILL (2), or song 7 (silence) for
;@ OFF and in the demo.
;@ reads: hDemoMode, hMusicType
;@ writes: wMusicRequest
;@ test: hDemoMode = rng.choice([0, 0, 1]); hMusicType = rand(0, 2)
;@ sig: f2c0109b
StartLevelMusic::
;> if hDemoMode or hMusicType == 2:
	ldh a, [hDemoMode]
	and a
	jr nz, jr_000_3013

	ld b, $01
	ldh a, [hMusicType]
	and a
	jr z, jr_000_3019

	inc b
	cp $01
	jr z, jr_000_3019

;>     wMusicRequest = 7
jr_000_3013:
	ld a, $07
	ld [wMusicRequest], a
	ret


;> else:
;>     wMusicRequest = hMusicType + 1
jr_000_3019:
	ld a, b
	ld [wMusicRequest], a
	ret


;@ def PlaceVirusesDemo()
;@ path: screens/demo
;@ The demo's bottle: points the demo player at DemoInputs, loads DemoBottle
;@ and sets the counts to match it (15 + 16 + 13 viruses).
;@ reads: hVirusCount
;@ writes: hCapsuleListPos, hVirusesPlaced, hVirusesPlacedBCD, hViruses0, hViruses1, hViruses2
;@ test: hVirusCount = 44; hMusicType = rand(0, 2); hDemoMode = 1
;@ sig: 6a5b164e
PlaceVirusesDemo::
;> mem[wDemoPtr] = DemoInputs >> 8                   # demo input pointer, big-endian
;> mem[wDemoPtr + 1] = DemoInputs & 0xFF
	ld de, $5e00
	ld hl, wDemoPtr
	ld a, d
	ld [hli], a
	ld [hl], e
;> hCapsuleListPos = 1
	ld a, $01
	ldh [hCapsuleListPos], a
;> LoadDemoBottle()
	call LoadDemoBottle
;> hVirusesPlaced = hVirusCount
	ldh a, [hVirusCount]
	ld hl, hVirusesPlaced
	ld [hl], a
;> hVirusesPlacedBCD = ToBCD(0xFFD1)               # hVirusesPlaced
	call ToBCD
	ldh [hVirusesPlacedBCD], a
;> hViruses0 = 15
	ld a, $0f
	ldh [hViruses0], a
;> hViruses1 = 16
	inc a
	ldh [hViruses1], a
;> hViruses2 = 13
	ld a, $0d
	ldh [hViruses2], a
;> PlaceVirusesDone()
	jr jr_000_2ff6

;@ def VersusSameLevelWait()
;@ path: versus/setup
;@ Switches to state $19, where the link players share one bottle layout.
;@ writes: hGameState
;@ sig: f91d81f6
VersusSameLevelWait::
;> hGameState = 0x19
	ld a, $19
	ldh [hGameState], a
	ret


;@ def SlaveCopyVirusCount()
;@ path: versus/setup
;@ The slave will get the master's bottle: it only sets the count.
;@ reads: hVirusCount
;@ writes: hVirusesPlaced, hVirusesPlacedBCD
;@ test: hVirusCount = 4 * rand(1, 21)
;@ sig: f027493c
SlaveCopyVirusCount::
;> hVirusesPlaced = hVirusCount
	ldh a, [hVirusCount]
	ld hl, hVirusesPlaced
	ld [hl], a
;> hVirusesPlacedBCD = ToBCD(0xFFD1)
	call ToBCD
	ldh [hVirusesPlacedBCD], a
;> VersusSameLevelWait()
	jr VersusSameLevelWait

;@ def PlaceOneVirus()
;@ path: game/viruses
;@ Picks a random cell, low in the bottle on easy levels and higher up on
;@ hard ones (VirusRowMasks / VirusColMasks by level), and scans forward from
;@ it for a cell TryPlaceVirus accepts. The new virus is drawn in the next
;@ VBlank; with both link players on the same level all of them are placed
;@ at once.
;@ reads: hSerialRole, hVirusLevel, hVirusLevel2P, hTwoPlayer, hVirusColours, $D00C, $D03A, wLinkHold, wNewVirusPending
;@ writes: hVirusColours, $D004, $D00C, $D035, $D03A, $FF9D, hVBlankJob, wLinkHold, wNewVirusPending, wNewVirusTile, wScanSteps
;@ test: hTwoPlayer = 0; hSerialRole = 0; hVirusLevel = rand(0, 20); rDIV = rand(0, 255)
;@ test: mem[0xD00C] = rng.choice([0, 0, 1]); mem[0xD010] = 0; mem[0xD007] = 0; mem[0xD004] = 0; mem[0xD03A] = 1
;@ test: for k in range(0x80): mem[0xC800 + k] = rng.choice([0xFF, 0xFF, 0xFF, 0xE0, 0xE1, 0xE2])
;@ test: for k in range(0x80, 0x100): mem[0xC800 + k] = 0xFF
;@ test: hVirusColours = rng.choice([0x80, 0x40, 0x20]); hVirusesPlaced = rand(0, 80); hVirusesPlacedBCD = to_bcd(hVirusesPlaced)
;@ sig: 7b29aae0
PlaceOneVirus::
;> if wLinkHold == 0 and hSerialRole == SERIAL_MASTER and hVirusLevel == hVirusLevel2P:
;>     wLinkHold = 1
	ld a, [wLinkHold]
	and a
	jr nz, jr_000_3071

	ldh a, [hSerialRole]
	cp $30
	jr nz, jr_000_3071

	ldh a, [hVirusLevel]
	ld b, a
	ldh a, [hVirusLevel2P]
	cp b
	jr nz, jr_000_3071

	ld a, $01
	ld [wLinkHold], a

jr_000_3071:
;> if wNewVirusPending:                                 # the last one is not on screen yet
;>     return
	ld a, [wNewVirusPending]
	and a
	ret nz

;> div = rDIV
;> offset = ((((div << 4) | (div >> 4)) & mem[VirusRowMasks + hVirusLevel]) + (div & mem[VirusColMasks + hVirusLevel])) & 0xFF
;> cell = wBottle + ((0x7F - offset) & 0xFF)
	ld hl, $311b
	ldh a, [hVirusLevel]
	ld e, a
	ld d, $00
	add hl, de
	ld b, [hl]
	ld hl, $3134
	add hl, de
	ld c, [hl]
	ldh a, [rDIV]
	ld d, a
	swap a
	and b
	ld e, a
	ld a, d
	and c
	add e
	ld e, a
	ld a, $7f
	sub e
	ld e, a
	ld d, $00
	ld hl, wBottle
	add hl, de

jr_000_309a:
;> while True:
;>     TryPlaceVirus(cell)
	call TryPlaceVirus
;>     hVirusColours &= 0xF0
	ld hl, hVirusColours
	ld a, [hl]
	and $f0
	ld [hl], a
;>     if wVirusPlaced:
;>         break
	ld hl, wVirusPlaced
	ld a, [hl]
	and a
	jr nz, jr_000_30c2

;>     cell += 1
;>     if cell & 0xFF < 0x80:
	inc de
	ld a, e
	cp $80
	jr nc, jr_000_30bd

;>         wScanSteps += 1
	ld hl, wScanSteps
	inc [hl]
;>         if cell & 0xFF != 0x10:
	cp $10
	jr z, jr_000_30bd

;>             continue
	push de
	pop hl
	jr jr_000_309a

;>     wScanSteps = 0                             # nothing here: try again next frame
jr_000_30bd:
	xor a
	ld [wScanSteps], a
;>     return
	ret


jr_000_30c2:
;> wVirusPlaced = 0
	xor a
	ld [hl], a
;> wScanSteps = 0
	ld [wScanSteps], a
;> wNewVirusTile = mem[cell]
	ld a, [de]
	ld [wNewVirusTile], a
;> if hTwoPlayer and hVirusLevel == hVirusLevel2P:
;>     return PlaceVirusesCheck()                  # all of them in this frame
	ldh a, [hTwoPlayer]
	and a
	jr z, jr_000_30d9

	ldh a, [hVirusLevel]
	ld b, a
	ldh a, [hVirusLevel2P]
	cp b
	jp z, PlaceVirusesCheck

jr_000_30d9:
;> BottleCellToVRAM()
	call BottleCellToVRAM
;> hVBlankJob = 1
;> wNewVirusPending = 1                                 # the VBlank handler draws it
	ld a, $01
	ldh [hVBlankJob], a
	ld [wNewVirusPending], a
	ret


	db $11, $0a, $31, $26, $c8, $1a, $fe, $fc, $28, $07, $6f, $13, $1a, $77, $13, $18
	db $f4

;=@LoadDemoBottle.tail
jr_000_30f5:
	ld a, $10
	ldh [hRedrawRow], a
	ret


;@ def LoadDemoBottle()
;@ path: screens/demo
;@ Copies DemoBottle into wBottle. (The bytes after it, $310A, are a list of
;@ (cell, virus) pairs ending in $FC for an unused routine at $30E3 that
;@ places them.)
;@ writes: $FFEF, hRedrawRow
;@ test: mem[0xFFEF] = 0
;@ sig: 3211d4da
LoadDemoBottle::
;> CopyBytes(DemoBottle, wBottle, 0x80)
	ld de, $5f80
	ld hl, wBottle
	ld b, $80

jr_000_3102:
	ld a, [de]
	ld [hli], a
	inc de
	dec b
	jr nz, jr_000_3102

;>@tail hRedrawRow = 0x10
	jr jr_000_30f5

	db $46, $e1, $49, $e0, $4e, $e1, $54, $e2, $5d, $e2, $64, $e0, $79, $e0, $7b, $e1
	db $fc

VirusRowMasks::
	db $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f
	db $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f

VirusColMasks::
	db $0f, $0f, $0f, $0f, $0f, $0f
	db $0f, $0f, $0f, $0f, $0f, $0f, $0f, $0f, $0f, $17, $17, $1f, $1f, $27, $27, $27
	db $2f, $2f, $2f

;@ def TryPlaceVirus(cell: hl)
;@ path: game/viruses
;@ Tries to put a virus into an empty bottle cell. A colour is ruled out when
;@ the cell two steps left, right, up or down already holds a virus of that
;@ colour; if all three are ruled out the cell stays empty. Otherwise the
;@ colours are tried in a rotating order (0-1-2, then 1-2-0, then 2-0-1) so
;@ the bottle gets a mix.
;@ reads: hVirusColours
;@ writes: hVirusColours
;@ test: cell = 0xC800 + rand(0x10, 0x7F)
;@ test: for k in range(0x80): mem[0xC800 + k] = rng.choice([0xFF, 0xFF, 0xE0, 0xE1, 0xE2])
;@ test: for k in range(0x80, 0x100): mem[0xC800 + k] = 0xFF
;@ test: hVirusColours = rng.choice([0x80, 0x40, 0x20, 0]); mem[0xD007] = 0; mem[0xD010] = 0
;@ test: hVirusesPlaced = rand(0, 80); hVirusesPlacedBCD = to_bcd(hVirusesPlaced)
;@ sig: 0caa3a0a
TryPlaceVirus::
;> if mem[cell] != 0xFF:
;>     return
	push hl
	push hl
	pop de
	pop bc
	ld a, [bc]
	cp $ff
	ret nz

;> CheckRight2(cell)
	push bc
	call CheckRight2
	pop bc
;> CheckLeft2(cell)
	push bc
	call CheckLeft2
	pop bc
;> CheckUp2(cell)
	push bc
	call CheckUp2
	pop bc
;> CheckDown2(cell)
	call CheckDown2
;> if hVirusColours & 7 == 7:                      # every colour would line up
;>     return
	ldh a, [hVirusColours]
	and $07
	cp $07
	ret z

;> mem[wVirusCell] = cell >> 8                         # remembered for BottleCellToVRAM
;> mem[wVirusCell + 1] = cell & 0xFF
	ld hl, wVirusCell
	ld a, d
	ld [hli], a
	ld [hl], e
;> wVirusPlaced += 1                                # placed
	ld hl, wVirusPlaced
	inc [hl]
;> if hVirusColours & 0x40:
;>     order = (1, 2, 0)
	ld hl, wColourPlaced
	ldh a, [hVirusColours]
	bit 6, a
	jr nz, jr_000_31af

;>@o2 elif hVirusColours & 0x20:
;>@o2b     order = (2, 0, 1)
;>@o0 else:
;>@o0b     order = (0, 1, 2)
;>@try for colour in order:
;>@call     (PlaceVirus0, PlaceVirus1, PlaceVirus2)[colour](cell, 0xD007)
;>@stop     if wColourPlaced:                             # it took that colour
;>@brk         break
;=@o2
	bit 5, a
	jr nz, jr_000_31c2

;=@call
	call PlaceVirus0
;=@stop
	ld a, [hl]
	and a
	jr nz, jr_000_3196

;=@call
	call PlaceVirus1
;=@stop
	ld a, [hl]
	and a
	jr nz, jr_000_3196

;=@call
	call PlaceVirus2

jr_000_3196:
;> wColourPlaced = 0
	xor a
	ld [hl], a
;> if hVirusColours & 0x20:                        # next time start with the next colour
;>     hVirusColours = 0x80
;> elif hVirusColours & 0x40:
;>     hVirusColours = 0x20
;> else:
;>     hVirusColours = 0x40
	ld hl, hVirusColours
	bit 5, [hl]
	jr nz, jr_000_31a7

	bit 6, [hl]
	jr nz, jr_000_31ab

	ld a, $40
	ld [hl], a
	ret


jr_000_31a7:
	ld a, $80
	ld [hl], a
	ret


jr_000_31ab:
	ld a, $20
	ld [hl], a
	ret


jr_000_31af:
;=@call
	call PlaceVirus1
;=@stop
	ld a, [hl]
	and a
	jr nz, jr_000_3196

;=@call
	call PlaceVirus2
;=@stop
	ld a, [hl]
	and a
	jr nz, jr_000_3196

;=@call
	call PlaceVirus0
;=@brk
	jr jr_000_3196

jr_000_31c2:
;=@call
	call PlaceVirus2
;=@stop
	ld a, [hl]
	and a
	jr nz, jr_000_3196

;=@call
	call PlaceVirus0
;=@stop
	ld a, [hl]
	and a
	jr nz, jr_000_3196

;=@call
	call PlaceVirus1
;=@brk
	jr jr_000_3196

;@ def CheckRight2(cell: bc)
;@ path: game/viruses
;@ Rules out the colour of a virus two cells to the right (if inside the bottle).
;@ reads: hVirusColours
;@ writes: hVirusColours
;@ test: cell = 0xC800 + rand(0, 0x7F); hVirusColours = rand(0, 255) & 0xE0
;@ test: for k in range(0x100): mem[0xC800 + k] = rng.choice([0xFF, 0xE0, 0xE1, 0xE2])
;@ sig: e52f2899
CheckRight2::
;> if cell & 7 >= 6:
;>     return
	ld a, c
	and $07
	cp $06
	ret nc

;> MarkNeighbourColour(cell + 2)
	inc c
	inc c
	call MarkNeighbourColour
	ret


;@ def CheckLeft2(cell: bc)
;@ path: game/viruses
;@ Rules out the colour of a virus two cells to the left (if inside the bottle).
;@ reads: hVirusColours
;@ writes: hVirusColours
;@ test: cell = 0xC800 + rand(0, 0x7F); hVirusColours = rand(0, 255) & 0xE0
;@ test: for k in range(0x100): mem[0xC800 + k] = rng.choice([0xFF, 0xE0, 0xE1, 0xE2])
;@ sig: a4b69211
CheckLeft2::
;> if cell & 7 < 2:
;>     return
	ld a, c
	and $07
	cp $02
	ret c

;> MarkNeighbourColour(cell - 2)
	dec c
	dec c
	call MarkNeighbourColour
	ret


;@ def CheckUp2(cell: bc)
;@ path: game/viruses
;@ Rules out the colour of a virus two rows up. There is no check for the top:
;@ from the first two rows it looks at $C8F0-$C8FF, past the end of the bottle.
;@ reads: hVirusColours
;@ writes: hVirusColours
;@ test: cell = 0xC800 + rand(0, 0x7F); hVirusColours = rand(0, 255) & 0xE0
;@ test: for k in range(0x100): mem[0xC800 + k] = rng.choice([0xFF, 0xE0, 0xE1, 0xE2])
;@ sig: 4cb4b610
CheckUp2::
;> MarkNeighbourColour((cell & 0xFF00) | ((cell - 0x10) & 0xFF))
	ld a, c
	sub $10
	ld c, a
	call MarkNeighbourColour
	ret


;@ def CheckDown2(cell: bc)
;@ path: game/viruses
;@ Rules out the colour of a virus two rows down (if inside the bottle).
;@ reads: hVirusColours
;@ writes: hVirusColours
;@ test: cell = 0xC800 + rand(0, 0x7F); hVirusColours = rand(0, 255) & 0xE0
;@ test: for k in range(0x100): mem[0xC800 + k] = rng.choice([0xFF, 0xE0, 0xE1, 0xE2])
;@ sig: eb84ab75
CheckDown2::
;> if cell & 0xFF >= 0x70:
;>     return
	ld a, c
	cp $70
	ret nc

;> MarkNeighbourColour(cell + 0x10)
	add $10
	ld c, a
	call MarkNeighbourColour
	ret


;@ def MarkNeighbourColour(cell: bc)
;@ path: game/viruses
;@ If the cell holds a virus, rules its colour out (tiles $E0/$E1/$E2 set
;@ bits 2/1/0 of hVirusColours).
;@ reads: hVirusColours
;@ writes: hVirusColours
;@ test: cell = rand_ram(1); mem[cell] = rng.choice([0xFF, 0xE0, 0xE1, 0xE2, rand(0, 255)]); hVirusColours = rand(0, 255)
;@ sig: 955e3e51
MarkNeighbourColour::
;>@v v = mem[cell]
;>@c0 if v == 0xE0:
;>@b0     hVirusColours |= 4
;>@c1 elif v == 0xE1:
;>@b1     hVirusColours |= 2
;>@c2 elif v == 0xE2:
;>@b2     hVirusColours |= 1
;=@v
	ld hl, hVirusColours
	ld a, [bc]
;=@c0
	cp $e0
	jr z, jr_000_3211

;=@c1
	cp $e1
	jr z, jr_000_3214

;=@c2
	cp $e2
	jr z, jr_000_3217

	ret


;=@b0
jr_000_3211:
	set 2, [hl]
	ret


;=@b1
jr_000_3214:
	set 1, [hl]
	ret


;=@b2
jr_000_3217:
	set 0, [hl]
	ret


;@ def PlaceVirus0(cell: de, placed: hl)
;@ path: game/viruses
;@ Puts a colour 0 virus (tile $E0) into the cell unless that colour is ruled
;@ out, and counts it.
;@ reads: hVirusColours
;@ writes: hViruses0
;@ test: cell = 0xC800 + rand(0x10, 0x7F); placed = 0xD007; mem[0xD007] = 0
;@ test: hVirusColours = rng.choice([0, 4, 3, 7]); hVirusesPlaced = rand(0, 80); hVirusesPlacedBCD = to_bcd(hVirusesPlaced)
;@ sig: 4c5840c6
PlaceVirus0::
;> if hVirusColours & 4:
;>     return
	ldh a, [hVirusColours]
	bit 2, a
	ret nz

;> mem[placed] += 1
	inc [hl]
;> mem[cell] = 0xE0
	ld a, $e0
	ld [de], a
;> hViruses0 += 1
	push hl
	ld hl, hViruses0
	inc [hl]

;> CountPlacedVirus()                              # falls through

;@ def CountPlacedVirus()
;@ path: game/viruses
;@ The tail of PlaceVirus0/1/2: counts the virus (binary and BCD).
;@ writes: hVirusesPlaced, hVirusesPlacedBCD
;@ test: skip pops the hl its callers pushed
;@ sig: 33c30cdd
CountPlacedVirus::
;> hVirusesPlaced += 1
	ld hl, hVirusesPlaced
	inc [hl]
;> hVirusesPlacedBCD = to_bcd((bcd_to_int(hVirusesPlacedBCD) + 1) % 100)
	inc l
	ld a, [hl]
	add $01
	daa
	ld [hl], a
;> wVirusChanges += 1
	ld hl, wVirusChanges
	inc [hl]
	pop hl
	ret


;@ def PlaceVirus1(cell: de, placed: hl)
;@ path: game/viruses
;@ Puts a colour 1 virus (tile $E1) into the cell unless that colour is ruled out.
;@ reads: hVirusColours
;@ writes: hViruses1
;@ test: cell = 0xC800 + rand(0x10, 0x7F); placed = 0xD007; mem[0xD007] = 0
;@ test: hVirusColours = rng.choice([0, 2, 5, 7]); hVirusesPlaced = rand(0, 80); hVirusesPlacedBCD = to_bcd(hVirusesPlaced)
;@ sig: 366b0efa
PlaceVirus1::
;> if hVirusColours & 2:
;>     return
	ldh a, [hVirusColours]
	bit 1, a
	ret nz

;> mem[placed] += 1
	inc [hl]
;> mem[cell] = 0xE1
	ld a, $e1
	ld [de], a
;> hViruses1 += 1
	push hl
	ld hl, hViruses1
	inc [hl]
;> CountPlacedVirus()
	jr CountPlacedVirus

;@ def PlaceVirus2(cell: de, placed: hl)
;@ path: game/viruses
;@ Puts a colour 2 virus (tile $E2) into the cell unless that colour is ruled out.
;@ reads: hVirusColours
;@ writes: hViruses2
;@ test: cell = 0xC800 + rand(0x10, 0x7F); placed = 0xD007; mem[0xD007] = 0
;@ test: hVirusColours = rng.choice([0, 1, 6, 7]); hVirusesPlaced = rand(0, 80); hVirusesPlacedBCD = to_bcd(hVirusesPlaced)
;@ sig: 4e5cf84e
PlaceVirus2::
;> if hVirusColours & 1:
;>     return
	ldh a, [hVirusColours]
	bit 0, a
	ret nz

;> mem[placed] += 1
	inc [hl]
;> mem[cell] = 0xE2
	ld a, $e2
	ld [de], a
;> hViruses2 += 1
	push hl
	ld hl, hViruses2
	inc [hl]
;> CountPlacedVirus()
	jr CountPlacedVirus


;@ def ShareBottle()
;@ path: versus/setup
;@ Game state $19: both link players chose the same virus level, so they get
;@ the same bottle: the master sends its 128 cells, the slave stores them,
;@ and both count the viruses per colour. Handshakes: $E0 / $C0 from the
;@ master until the slave answers $D0 (the slave starts over on a $C0), and
;@ $C1 / $D1 at the end. Then the level starts (PlaceVirusesDone).
;@ reads: hSerialRole, hSerialDone, hSerialRx
;@ writes: hSerialTx, hSerialRx, hSerialDone, hViruses0, hViruses1, hViruses2, hRedrawRow, $D03A, wLinkHold
;@ test: skip talks to the link cable
;@ sig: 1cf4ef40
ShareBottle::
;> ShortDelay()
;> ShortDelay()
	rst $08
	rst $08
;> rIF = 0
	xor a
	ldh [rIF], a
;> rIE = 0x08                                      # serial only
	ld a, $08
	ldh [rIE], a
;> wLinkHold = 0
;> rSB = 0
;> hSerialTx = 0
;> hSerialRx = 0
;> hViruses0 = 0
;> hViruses1 = 0
;> hViruses2 = 0
	xor a
	ld [wLinkHold], a
	ldh [rSB], a
	ldh [hSerialTx], a
	ldh [hSerialRx], a
	ldh [hViruses0], a
	ldh [hViruses1], a
	ldh [hViruses2], a
;> if hSerialRole != SERIAL_SLAVE:                 # the master sends
	ldh a, [hSerialRole]
	cp $60
	jp z, Jump_000_32f1

;>     for hello in (0xE0, 0xC0):                  # each until the slave answers $D0
;>         while True:
;>             ShortDelay()
;>             ShortDelay()
;>             rSB = hello
;>             rSC = 0x81
;>             hSerialRx = 0
;>             hSerialDone = 0
;>             while not hSerialDone:
;>                 pass
;>             if hSerialRx == 0xD0:
;>                 break
jr_000_3278:
	rst $08
	rst $08
	ld a, $e0
	ldh [rSB], a
	ld a, $81
	ldh [rSC], a
	xor a
	ldh [hSerialRx], a
	ldh [hSerialDone], a

jr_000_3287:
	ldh a, [hSerialDone]
	and a
	jr z, jr_000_3287

	ldh a, [hSerialRx]
	cp $d0
	jr nz, jr_000_3278

jr_000_3292:
	rst $08
	rst $08
	ld a, $c0
	ldh [rSB], a
	ld a, $81
	ldh [rSC], a
	xor a
	ldh [hSerialRx], a
	ldh [hSerialDone], a

jr_000_32a1:
	ldh a, [hSerialDone]
	and a
	jr z, jr_000_32a1

	ldh a, [hSerialRx]
	cp $d0
	jr nz, jr_000_3292

;>     for k in range(0x80):
	ld hl, wBottle
	ld b, $80

jr_000_32b1:
;>         ShortDelay()
;>         cell = mem[wBottle + k]
;>         rSB = cell
	rst $08
	ld a, [hli]
	ldh [rSB], a
;>         CountVirus(cell)
	call CountVirus
;>         rSC = 0x81
	ld a, $81
	ldh [rSC], a
;>         hSerialRx = 0
;>         hSerialDone = 0
	xor a
	ldh [hSerialRx], a
	ldh [hSerialDone], a

;>         while not hSerialDone:
;>             pass
jr_000_32c1:
	ldh a, [hSerialDone]
	and a
	jr z, jr_000_32c1

	dec b
	jr nz, jr_000_32b1

;>     while True:                                 # goodbye
;>         ShortDelay()
;>         ShortDelay()
jr_000_32c9:
	rst $08
	rst $08
;>         rSB = 0xC1
	ld a, $c1
	ldh [rSB], a
;>         rSC = 0x81
	ld a, $81
	ldh [rSC], a
;>         hSerialRx = 0
;>         hSerialDone = 0
	xor a
	ldh [hSerialRx], a
	ldh [hSerialDone], a

;>         while not hSerialDone:
;>             pass
jr_000_32d8:
	ldh a, [hSerialDone]
	and a
	jr z, jr_000_32d8

;>         if hSerialRx == 0xD1:
;>             break
;>@sl else:                                           # the slave receives
;>@sl2     while True:
;>@sl3         ShortDelay()
;>@sl4         rSB = 0xD0
;>@sl5         hSerialTx = 0xD0
;>@sl6         rSC = 0x80
;>@sl7         hSerialRx = 0
;>@sl8         hSerialDone = 0
;>@sl9         while not hSerialDone:
;>@sl10             pass
;>@sl11         if hSerialRx == 0xC0:
;>@sl12             break
;>@rx     k = 0
;>@rx2     rSB = 0xC0
;>@rx2b     hSerialRx = 0xC0
;>@rx3     while k < 0x80:
;>@rx4         rSC = 0x80
;>@rx5         hSerialRx = 0
;>@rx6         hSerialDone = 0
;>@rx7         while not hSerialDone:
;>@rx8             pass
;>@rx9         if hSerialRx == 0xC0:                   # the master is still saying hello: start over
;>@rx10             k = 0
;>@rx11             rSB = 0xC0
;>@rx11b             hSerialRx = 0xC0
;>@rx12             continue
;>@rx13         mem[wBottle + k] = hSerialRx
;>@rx14         CountVirus(hSerialRx)
;>@rx15         k += 1
;>@bye     while True:
;>@bye2         rSB = 0xD1
;>@bye3         hSerialTx = 0xD1
;>@bye4         rSC = 0x80
;>@bye5         hSerialRx = 0
;>@bye6         hSerialDone = 0
;>@bye7         while not hSerialDone:
;>@bye8             pass
;>@bye9         if hSerialRx == 0xC1:
;>@bye10             break
	ldh a, [hSerialRx]
	cp $d1
	jr nz, jr_000_32c9

jr_000_32e3:
;> hRedrawRow = 0x10
	ld a, $10
	ldh [hRedrawRow], a
;> rIF = 0
	xor a
	ldh [rIF], a
;> rIE = 0x0D
	ld a, $0d
	ldh [rIE], a
;> return PlaceVirusesDone()
	jp PlaceVirusesDone


Jump_000_32f1:
jr_000_32f1:
;=@sl3
	rst $08
;=@sl4
	ld a, $d0
	ldh [rSB], a
	ldh [hSerialTx], a
;=@sl6
	ld a, $80
	ldh [rSC], a
;=@sl7
	xor a
	ldh [hSerialRx], a
	ldh [hSerialDone], a

;=@sl9
jr_000_3301:
	ldh a, [hSerialDone]
	and a
	jr z, jr_000_3301

;=@sl11
	ldh a, [hSerialRx]
	cp $c0
	jr nz, jr_000_32f1

;=@rx
	ld b, $80
	ld hl, wBottle

jr_000_3311:
;=@rx2
	ldh [rSB], a
	ldh [hSerialRx], a

jr_000_3315:
;=@rx4
	ld a, $80
	ldh [rSC], a
;=@rx5
	xor a
	ldh [hSerialRx], a
	ldh [hSerialDone], a

;=@rx7
jr_000_331e:
	ldh a, [hSerialDone]
	and a
	jr z, jr_000_331e

;=@rx9
	ldh a, [hSerialRx]
	cp $c0
	jr z, jr_000_3311

;=@rx13
	ld [hli], a
;=@rx14
	call CountVirus
;=@rx15
	dec b
	jr nz, jr_000_3315

jr_000_3330:
;=@bye2
	ld a, $d1
	ldh [rSB], a
	ldh [hSerialTx], a
;=@bye4
	ld a, $80
	ldh [rSC], a
;=@bye5
	xor a
	ldh [hSerialRx], a
	ldh [hSerialDone], a

;=@bye7
jr_000_333f:
	ldh a, [hSerialDone]
	and a
	jr z, jr_000_333f

;=@bye9
	ldh a, [hSerialRx]
	cp $c1
	jr nz, jr_000_3330

	jr jr_000_32e3

;@ def CountVirus(cell: a)
;@ path: versus/setup
;@ Counts a virus cell into hViruses0/1/2 (keeps a and hl).
;@ reads: hViruses0, hViruses1, hViruses2
;@ writes: hViruses0, hViruses1, hViruses2
;@ test: cell = rng.choice([0xE0, 0xE1, 0xE2, 0xFF, 0x80]); hViruses0 = rand(0, 40); hViruses1 = rand(0, 40); hViruses2 = rand(0, 40)
;@ sig: abb1fe10
CountVirus::
;> if cell == 0xE1:
;>@c1b     hViruses1 += 1
	push hl
	cp $e1
	jr z, jr_000_3362

;>@c2 elif cell == 0xE2:
;>@c2b     hViruses2 += 1
;>@c0 elif cell == 0xE0:
;>@c0b     hViruses0 += 1
;=@c2
	cp $e2
	jr z, jr_000_3369

;=@c0
	cp $e0
	jr z, jr_000_335b

	pop hl
	ret


;=@c0b
jr_000_335b:
	ld hl, hViruses0
	inc [hl]
	jp Jump_000_336d


jr_000_3362:
;=@c1b
	ld hl, hViruses1
	inc [hl]
	jp Jump_000_336d


jr_000_3369:
;=@c2b
	ld hl, hViruses2
	inc [hl]

Jump_000_336d:
	pop hl
	ret



;@ def ThrowCapsule()
;@ path: game/play
;@ Game state $0A: Dr. Mario throws the next capsule into the bottle. The
;@ first throw of a level waits $50 frames. Every few frames (3 on LOW, 2
;@ otherwise) the throw moves on a step: wind up, throw, the capsule spinning
;@ along ThrowPath, and at step 13 it becomes the falling capsule (state $04).
;@ reads: wInPlay, hPaused, hRedrawRow, hSpeed, $D021, wLevelStartWait
;@ writes: wInPlay, hGameState, $D013, $D021, wLevelStartWait, wThrowPathPos
;@ test: skip calls helpers not translated yet
;@ sig: f63669d6
ThrowCapsule::
;> if wInPlay:
	ld a, [wInPlay]
	and a
	jr z, jr_000_337c

;>     HandlePause()
	call HandlePause
;>     if hPaused:
;>         return
	ldh a, [hPaused]
	and a
	ret nz

jr_000_337c:
;> DemoCheckStart()
	call DemoCheckStart
;> UpdateBottle()
	call UpdateBottle
;> if hRedrawRow:
;>     return
	ldh a, [hRedrawRow]
	and a
	ret nz

;> UpdateMagnifier()
	call UpdateMagnifier
;> BlinkMagnifierDanger()
	call BlinkMagnifierDanger
;> if wLevelStartWait:                                 # a new level: wait first
	ld a, [wLevelStartWait]
	and a
	jr z, jr_000_33a3

;>     wLevelStartTimer += 1
;>     if wLevelStartTimer != 0x50:
;>         return
	ld hl, wLevelStartTimer
	inc [hl]
	ld a, [hl]
	cp $50
	ret nz

;>     wLevelStartTimer = 0
;>     wLevelStartWait = 0
;>     wInPlay = 1
	xor a
	ld [hl], a
	ld [wLevelStartWait], a
	inc a
	ld [wInPlay], a

jr_000_33a3:
;> rate = hSpeed if hSpeed == 2 else hSpeed - 1
	ld hl, hSpeed
	ld a, [hl]
	ld b, a
	cp $02
	jr z, jr_000_33ad

	dec b

jr_000_33ad:
;> wThrowTimer += 1
;> if wThrowTimer != rate:
;>     return
	ld de, wThrowTimer
	ld a, [de]
	inc a
	ld [de], a
	cp b
	ret nz

;> wThrowTimer = 0
	xor a
	ld [de], a
;> wThrowStep += 1                                # the throw's step
;> step = wThrowStep
;> if step == 1:                                   # wind up
;>@s1     for i, t in enumerate((0x09, 0x0B, 0x0A, 0x0C)): mem[0xC022 + 4 * i] = t
;>@s2 elif step == 2:                                 # throw
;>@s2b     for i, t in enumerate((0x0D, 0xFF, 0x0E, 0x0F, 0x00)): mem[0xC022 + 4 * i] = t
;>@s13 elif step == 13:                               # done: back to standing
;>@s13b     wThrowStep = 0
;>@s13c     wThrowPathPos = 0
;>@s13d     for i, t in enumerate((0xFF, 0x04, 0x02, 0x05, 0x00)): mem[0xC022 + 4 * i] = t
;>@s13e     NextCapsule()
;>@s13f     hGameState = 0x04                           # Play
;>@s13g     return
	ld bc, wThrowStep
	ld de, $0004
	ld hl, wShadowOAM + $22
	ld a, [bc]
	inc a
	ld [bc], a
	cp $01
	jr z, jr_000_33d6

;=@s2
	cp $02
	jr z, jr_000_33e7

;=@s13
	cp $0d
	jr z, jr_000_33fb

jr_000_33cf:
;> FollowThrowPath(4)
	call FollowThrowPath
;> DrawTwoObjects()
	call DrawTwoObjects
	ret


jr_000_33d6:
;=@s1
	ld a, $09
	ld [hl], a
	add hl, de
	ld a, $0b
	ld [hl], a
	add hl, de
	ld a, $0a
	ld [hl], a
	add hl, de
	ld a, $0c
	ld [hl], a
	jr jr_000_33cf

jr_000_33e7:
;=@s2b
	ld a, $0d
	ld [hl], a
	add hl, de
	ld a, $ff
	ld [hl], a
	add hl, de
	ld a, $0e
	ld [hl], a
	add hl, de
	ld a, $0f
	ld [hl], a
	add hl, de
	xor a
	ld [hl], a
	jr jr_000_33cf

jr_000_33fb:
;=@s13b
	xor a
	ld [bc], a
;=@s13c
	ld [wThrowPathPos], a
;=@s13d
	ld a, $ff
	ld [hl], a
	add hl, de
	ld a, $04
	ld [hl], a
	add hl, de
	ld a, $02
	ld [hl], a
	add hl, de
	ld a, $05
	ld [hl], a
	add hl, de
	xor a
	ld [hl], a
;=@s13e
	call NextCapsule
;=@s13f
	ld a, $04
	ldh [hGameState], a
;=@s13g
	ret


;@ def FollowThrowPath(step: e)
;@ path: game/play
;@ Moves the thrown capsule (object 1) to the next point of ThrowPath and spins it.
;@ writes: $D013, wThrowPathPos
;@ reads: $D013, wThrowPathPos
;@ test: mem[0xD013] = 2 * rand(0, 10); step = 4; mem[0xC213] = rand(0, 0x17)
;@ sig: 2b5c159c
FollowThrowPath::
;> at = 0x3444 + wThrowPathPos                       # ThrowPath, after its first point
;> wThrowPathPos += 2
	push hl
	ld hl, $3444
	ld a, [wThrowPathPos]
	ld c, a
	add $02
	ld [wThrowPathPos], a
	ld b, $00
	add hl, bc
	push hl
	pop bc
;> mem[wObjects + 17] = mem[at]                           # y
;> mem[wObjects + 18] = mem[at + 1]                       # x
	ld hl, wNextCapsule + 1
	ld a, [bc]
	ld [hli], a
	inc bc
	ld a, [bc]
	ld [hli], a
;> SpinCapsule(0xC213, step)
	call SpinCapsule
	pop hl
	ret


;@ def SpinCapsule(sprite: hl, step: e)
;@ path: game/play
;@ Turns a capsule a quarter turn backwards: the sprite id's low two bits
;@ count down, wrapping within its group of four.
;@ test: sprite = rand_ram(1); mem[sprite] = rand(1, 0x17); step = 4
;@ sig: c5c940d8
SpinCapsule::
;> mem[sprite] -= 1
	dec [hl]
;> if mem[sprite] & 3 == 3:
	ld a, [hl]
	and $03
	cp $03
	ret nz

;>     mem[sprite] += step
	ld a, [hl]
	add e
	ld [hl], a
	ret


	db $2e, $66, $20, $5a, $1e, $58, $17, $51, $1a, $50, $16, $47, $1a, $46, $17, $3f
	db $1c, $3f, $1a, $35, $20, $34, $20, $30

;@ def ResetMagnifierVirus1()
;@ path: game/magnifier
;@ Its colour was hit again: stops the animation and redraws virus 1.
;@ writes: hVirusColoursHit, $D015, $D019, $D01C, wDanceStep1, wHurtStep1, wWobble1
;@ sig: 7ba9460c
ResetMagnifierVirus1::
;> wDanceStep1 = 0                                 # dance step
;> wHurtStep1 = 0                                 # hurt step
;> wWobble1 = 0                                 # wobble side
	xor a
	ld [wDanceStep1], a
	ld [wHurtStep1], a
	ld [wWobble1], a
;> hVirusColoursHit &= 0x7F
	ld hl, hVirusColoursHit
	res 7, [hl]
;> DrawMagnifierVirus1()
	call DrawMagnifierVirus1
	ret


;@ def ResetMagnifierVirus2()
;@ path: game/magnifier
;@ writes: hVirusColoursHit, $D017, $D01A, $D01D, wDanceStep2, wHurtStep2, wWobble2
;@ sig: e2886ed9
ResetMagnifierVirus2::
;> wDanceStep2 = 0
;> wHurtStep2 = 0
;> wWobble2 = 0
	xor a
	ld [wDanceStep2], a
	ld [wHurtStep2], a
	ld [wWobble2], a
;> hVirusColoursHit &= 0xBF
	ld hl, hVirusColoursHit
	res 6, [hl]
;> DrawMagnifierVirus2()
	call DrawMagnifierVirus2
	ret


;@ def ResetMagnifierVirus3()
;@ path: game/magnifier
;@ writes: hVirusColoursHit, $D018, $D01B, $D01E, wDanceStep3, wHurtStep3, wWobble3
;@ sig: 5aeed7f9
ResetMagnifierVirus3::
;> wDanceStep3 = 0
;> wHurtStep3 = 0
;> wWobble3 = 0
	xor a
	ld [wDanceStep3], a
	ld [wHurtStep3], a
	ld [wWobble3], a
;> hVirusColoursHit &= 0xDF
	ld hl, hVirusColoursHit
	res 5, [hl]
;> DrawMagnifierVirus3()
	call DrawMagnifierVirus3
	ret



;@ def UpdateMagnifier()
;@ path: game/magnifier
;@ 1 player, every frame: the three viruses in the magnifying glass. A virus
;@ whose colour was hit again is reset first. Then each one, unless gone,
;@ either goes on vanishing (which ends this frame's update), gets hurt
;@ (its colour was hit) or dances to the music.
;@ reads: hTwoPlayer, hVirusColoursHit, hMagnifierVirus1, hMagnifierVirus2, hMagnifierVirus3
;@ test: skip calls helpers not translated yet
;@ sig: f8204b35
UpdateMagnifier::
;> if hTwoPlayer:
;>     return
	ldh a, [hTwoPlayer]
	and a
	ret nz

;> if hVirusColoursHit & 0x80:
;>     ResetMagnifierVirus1()
	ldh a, [hVirusColoursHit]
	bit 7, a
	call nz, ResetMagnifierVirus1
;> if hVirusColoursHit & 0x40:
;>     ResetMagnifierVirus2()
	ldh a, [hVirusColoursHit]
	bit 6, a
	call nz, ResetMagnifierVirus2
;> if hVirusColoursHit & 0x20:
;>     ResetMagnifierVirus3()
	ldh a, [hVirusColoursHit]
	bit 5, a
	call nz, ResetMagnifierVirus3
;> if hMagnifierVirus1 != 3:                       # not gone
	ld hl, hMagnifierVirus1
	ld a, [hl]
	cp $03
	jr z, jr_000_34ce

;>     if hMagnifierVirus1 == 1:
;>         return VanishWait1()
	cp $01
	jp z, VanishWait1

;>     if hMagnifierVirus1 == 2:
;>         return RemoveMagnifierVirus1()
	cp $02
	jp z, RemoveMagnifierVirus1

;>     if hVirusColoursHit & 0x04:
;>@hurt1         HurtMagnifierVirus1()
;>     else:
	ldh a, [hVirusColoursHit]
	bit 2, a
	jr nz, jr_000_34cb

;>         DanceMagnifierVirus1()
	call DanceMagnifierVirus1
	jr jr_000_34ce

jr_000_34cb:
;=@hurt1
	call HurtMagnifierVirus1

jr_000_34ce:
;> if hMagnifierVirus2 != 3:
	ld hl, hMagnifierVirus2
	ld a, [hl]
	cp $03
	jr z, jr_000_34ee

;>     if hMagnifierVirus2 == 1:
;>         return VanishWait2()
	cp $01
	jp z, VanishWait2

;>     if hMagnifierVirus2 == 2:
;>         return RemoveMagnifierVirus2()
	cp $02
	jp z, RemoveMagnifierVirus2

;>     if hVirusColoursHit & 0x02:
;>@hurt2         HurtMagnifierVirus2()
;>     else:
	ldh a, [hVirusColoursHit]
	bit 1, a
	jr nz, jr_000_34eb

;>         DanceMagnifierVirus2()
	call DanceMagnifierVirus2
	jr jr_000_34ee

jr_000_34eb:
;=@hurt2
	call HurtMagnifierVirus2

jr_000_34ee:
;> if hMagnifierVirus3 == 3:
;>     return
	ld hl, hMagnifierVirus3
	ld a, [hl]
	cp $03
	ret z

;> if hMagnifierVirus3 == 1:
;>     return VanishWait3()
	cp $01
	jp z, VanishWait3

;> if hMagnifierVirus3 == 2:
;>     return RemoveMagnifierVirus3()
	cp $02
	jp z, RemoveMagnifierVirus3

;> if hVirusColoursHit & 0x01:
;>@hurt3     HurtMagnifierVirus3()
;> else:
	ldh a, [hVirusColoursHit]
	bit 0, a
	jr nz, jr_000_3509

;>     DanceMagnifierVirus3()
	call DanceMagnifierVirus3
	ret


jr_000_3509:
;=@hurt3
	call HurtMagnifierVirus3
	ret


;@ def DanceMagnifierVirus1()
;@ path: game/magnifier
;@ Once a beat of the music (wSongBeat frames) virus 1 changes pose: its four
;@ tiles go +2, -2, +4, -4 in turn.
;@ reads: wSongBeat, hDanceTimer1
;@ writes: hDanceTimer1, $D015, wDanceStep1
;@ test: wSongBeat = rand(5, 20); hDanceTimer1 = rand(0, 25); mem[0xD015] = rand(0, 3)
;@ test: for i in range(4): mem[0xC04A + 4 * i] = rand(0x40, 0x60)
;@ sig: 0f8690ab
DanceMagnifierVirus1::
;> if hDanceTimer1 < wSongBeat:
;>     return
	ld a, [wSongBeat]
	ld b, a
	ld hl, hDanceTimer1
	ld a, [hl]
	cp b
	ret c

;> hDanceTimer1 = 0
	xor a
	ld [hl], a
;> wDanceStep1 += 1
;> step = wDanceStep1
	ld hl, wDanceStep1
	inc [hl]
	ld a, [hl]
;> change = {1: 2, 2: -2, 3: 4}.get(step, -4)
	ld hl, wShadowOAM + $4A
	ld de, $0004
	ld b, e
	cp $01
	jr z, jr_000_353e

	cp $02
	jr z, jr_000_3548

	cp $03
	jr z, jr_000_354c

;> if step not in (1, 2, 3):
;>     wDanceStep1 = 0
	xor a
	ld [wDanceStep1], a

jr_000_3535:
;> for i in range(4):                              # the tile bytes of shadow OAM entries 18-21
;>     mem[0xC04A + 4 * i] = (mem[0xC04A + 4 * i] + change) & 0xFF
	ld c, e

jr_000_3536:
	ld a, [hl]
	sub c
	ld [hl], a
	add hl, de
	dec b
	jr nz, jr_000_3536

	ret


jr_000_353e:
	ld c, $02

jr_000_3540:
	ld a, [hl]
	add c
	ld [hl], a
	add hl, de
	dec b
	jr nz, jr_000_3540

	ret


jr_000_3548:
	ld c, $02
	jr jr_000_3536

jr_000_354c:
	ld c, e
	jr jr_000_3540

;@ def DanceMagnifierVirus2()
;@ path: game/magnifier
;@ The same for virus 2 (shadow OAM entries 22-25), using DanceMagnifierVirus1's loops.
;@ reads: wSongBeat, hDanceTimer2
;@ writes: hDanceTimer2, $D017, wDanceStep2
;@ test: wSongBeat = rand(5, 20); hDanceTimer2 = rand(0, 25); mem[0xD017] = rand(0, 3)
;@ test: for i in range(4): mem[0xC05A + 4 * i] = rand(0x40, 0x60)
;@ sig: 5a896129
DanceMagnifierVirus2::
;> if hDanceTimer2 < wSongBeat:
;>     return
	ld a, [wSongBeat]
	ld b, a
	ld hl, hDanceTimer2
	ld a, [hl]
	cp b
	ret c

;> hDanceTimer2 = 0
	xor a
	ld [hl], a
;> wDanceStep2 += 1
;> step = wDanceStep2
	ld hl, wDanceStep2
	inc [hl]
	ld a, [hl]
;> change = {1: 2, 2: -2, 3: 4}.get(step, -4)
	ld hl, wShadowOAM + $5A
	ld de, $0004
	ld b, e
	cp $01
	jr z, jr_000_353e

	cp $02
	jr z, jr_000_3548

	cp $03
	jr z, jr_000_354c

;> if step not in (1, 2, 3):
;>     wDanceStep2 = 0
;> for i in range(4):
;>     mem[0xC05A + 4 * i] = (mem[0xC05A + 4 * i] + change) & 0xFF
	xor a
	ld [wDanceStep2], a
	jr jr_000_3535

;@ def DanceMagnifierVirus3()
;@ path: game/magnifier
;@ The same for virus 3 (shadow OAM entries 26-29).
;@ reads: wSongBeat, hDanceTimer3
;@ writes: hDanceTimer3, $D018, wDanceStep3
;@ test: wSongBeat = rand(5, 20); hDanceTimer3 = rand(0, 25); mem[0xD018] = rand(0, 3)
;@ test: for i in range(4): mem[0xC06A + 4 * i] = rand(0x40, 0x60)
;@ sig: 7bb7fcec
DanceMagnifierVirus3::
;> if hDanceTimer3 < wSongBeat:
;>     return
	ld a, [wSongBeat]
	ld b, a
	ld hl, hDanceTimer3
	ld a, [hl]
	cp b
	ret c

;> hDanceTimer3 = 0
	xor a
	ld [hl], a
;> wDanceStep3 += 1
;> step = wDanceStep3
	ld hl, wDanceStep3
	inc [hl]
	ld a, [hl]
;> change = {1: 2, 2: -2, 3: 4}.get(step, -4)
	ld hl, wShadowOAM + $6A
	ld de, $0004
	ld b, e
	cp $01
	jr z, jr_000_353e

	cp $02
	jr z, jr_000_3548

	cp $03
	jr z, jr_000_354c

;> if step not in (1, 2, 3):
;>     wDanceStep3 = 0
;> for i in range(4):
;>     mem[0xC06A + 4 * i] = (mem[0xC06A + 4 * i] + change) & 0xFF
	xor a
	ld [wDanceStep3], a
	jr jr_000_3535


;@ def HurtMagnifierVirus1()
;@ path: game/magnifier
;@ Virus 1's colour lost a virus: every other frame it hops up, makes a hurt
;@ face, lands and wobbles for a while. Then it goes back to normal, or, if
;@ no virus of its colour is left, starts vanishing.
;@ reads: hFrameCount, hViruses0
;@ writes: hVirusColoursHit, hMagnifierVirus1, $D015, $D019, $D01C, wDanceStep1, wHurtStep1, wWobble1
;@ test: hFrameCount = rand(0, 255); mem[0xD01C] = rng.choice([rand(0, 8), rand(8, 0x1F), 0x1F]); mem[0xD019] = rand(0, 1); hViruses0 = rand(0, 2)
;@ test: for i in range(4): mem[0xC048 + 4 * i] = rand(0x40, 0x60); mem[0xC04A + 4 * i] = rand(0x40, 0x60)
;@ sig: ee16cbd3
HurtMagnifierVirus1::
;> if hFrameCount & 1:
;>     return
	ldh a, [hFrameCount]
	and $01
	ret nz

;> wHurtStep1 += 1
;> step = wHurtStep1
	ld hl, wHurtStep1
	inc [hl]
	ld a, [hl]
;> if step < 4:                                    # hop up
;>@up     for i in range(4):
;>@up2         mem[0xC048 + 4 * i] -= 2
;>@face elif step == 4:                               # hurt face
;>@face2     t = ((mem[wShadowOAM + 74] & 0xF0) + 6) & 0xFF
;>@face3     for i, d in enumerate((0, 1, 0x10, 0x11)):
;>@face4         mem[0xC04A + 4 * i] = (t + d) & 0xFF
;>@down elif step < 8:                                # land
;>@down2     for i in range(4):
;>@down3         mem[0xC048 + 4 * i] += 2
;>@wob elif step < 0x20:                              # wobble, a move every 4 frames
;>@wob2     if hFrameCount & 3:
;>@wob3         wHurtStep1 -= 1
;>@wob4         return
;>@wob5     wWobble1 ^= 1
;>@wob6     d = 2 if wWobble1 else -2
;>@wob7     for i in range(4):
;>@wob8         mem[0xC04A + 4 * i] = (mem[0xC04A + 4 * i] + d) & 0xFF
;> else:                                           # done
	ld hl, wShadowOAM + $48
	ld de, $0004
	ld b, e
	cp $04
	jr c, jr_000_35da

;=@face
	jr z, jr_000_35e3

;=@down
	cp $08
	jr c, jr_000_35f6

;=@wob
	cp $20
	jr c, jr_000_35ff

;>     wDanceStep1 = 0
;>     wHurtStep1 = 0
;>     wWobble1 = 0
	xor a
	ld [wDanceStep1], a
	ld [wHurtStep1], a
	ld [wWobble1], a
;>     hVirusColoursHit &= ~0x04 & 0xFF
	ld hl, hVirusColoursHit
	res 2, [hl]
;>     if hViruses0:
	ldh a, [hViruses0]
	and a
	jr z, jr_000_3618

;>         DrawMagnifierVirus1()
	call DrawMagnifierVirus1
	ret


;=@up
Jump_000_35da:
jr_000_35da:
;=@up2
	ld a, [hl]
	sub $02
	ld [hl], a
	add hl, de
	dec b
	jr nz, jr_000_35da

	ret


;=@face2
Jump_000_35e3:
jr_000_35e3:
;=@face3
	inc l
	inc l
	ld a, [hl]
	and $f0
	add $06
	ld [hl], a
	add hl, de
	inc a
	ld [hl], a
	add hl, de
	add $0f
	ld [hl], a
	add hl, de
	inc a
	ld [hl], a
	ret


;=@down2
Jump_000_35f6:
jr_000_35f6:
;=@down3
	ld a, [hl]
	add $02
	ld [hl], a
	add hl, de
	dec b
	jr nz, jr_000_35f6

	ret


;=@wob2
jr_000_35ff:
	ldh a, [hFrameCount]
	and $03
	jr z, jr_000_360a

;=@wob3
	ld hl, wHurtStep1
	dec [hl]
;=@wob4
	ret


;=@wob5
jr_000_360a:
	ld hl, wWobble1
	ld a, [hl]
	xor $01
	ld [hl], a
;=@wob6
	ld hl, wShadowOAM + $4A
	jr z, jr_000_35da

	jr jr_000_35f6

;>     else:
;>         VanishFrame(0xC04A)
jr_000_3618:
	ld hl, wShadowOAM + $4A
	call VanishFrame
;>         hMagnifierVirus1 = 1
	ld a, $01
	ldh [hMagnifierVirus1], a
	ret


;@ def VanishWait1()
;@ path: game/magnifier
;@ Virus 1 shows its vanishing frame for 3 updates.
;@ writes: hMagnifierVirus1
;@ test: mem[0xD027] = rand(0, 2)
;@ sig: a7a466a8
VanishWait1::
;> wVanishTimer1 += 1
;> if wVanishTimer1 != 3:
;>     return
	ld hl, wVanishTimer1
	inc [hl]
	ld a, [hl]
	cp $03
	ret nz

;> wVanishTimer1 = 0
	xor a
	ld [hl], a
;> hMagnifierVirus1 = 2
	ld a, $02
	ldh [hMagnifierVirus1], a
	ret


;@ def RemoveMagnifierVirus1(state: hl)
;@ path: game/magnifier
;@ Virus 1 is gone (state 3): its sprites are cleared.
;@ test: state = 0xFFFA
;@ sig: 0721b23d
RemoveMagnifierVirus1::
;> mem[state] = 3
	ld a, $03
	ld [hl], a
;> ClearBytes16(0xC048)
	ld hl, wShadowOAM + $48
	call ClearBytes16
;> BlankTiles4(0xC04A)
	ld hl, wShadowOAM + $4A
	call BlankTiles4
	ret


;@ def HurtMagnifierVirus2()
;@ path: game/magnifier
;@ The same for virus 2, using HurtMagnifierVirus1's hop and face code; its
;@ wobble mirrors the sprite left and right (X flip) instead.
;@ reads: hFrameCount, hViruses1
;@ writes: hVirusColoursHit, hMagnifierVirus2, $D017, $D01A, $D01D, wDanceStep2, wHurtStep2, wWobble2
;@ test: hFrameCount = rand(0, 255); mem[0xD01D] = rng.choice([rand(0, 8), rand(8, 0x1F), 0x1F]); mem[0xD01A] = rand(0, 1); hViruses1 = rand(0, 2)
;@ test: for i in range(4): mem[0xC058 + 4 * i] = rand(0x40, 0x60); mem[0xC05A + 4 * i] = rand(0x40, 0x60); mem[0xC05B + 4 * i] = rng.choice([0, 0x20])
;@ sig: f5bf8040
HurtMagnifierVirus2::
;> if hFrameCount & 1:
;>     return
	ldh a, [hFrameCount]
	and $01
	ret nz

;> wHurtStep2 += 1
;> step = wHurtStep2
	ld hl, wHurtStep2
	inc [hl]
	ld a, [hl]
;> if step < 4:
;>     for i in range(4):
;>         mem[0xC058 + 4 * i] -= 2
	ld hl, wShadowOAM + $58
	ld de, $0004
	ld b, e
	cp $04
	jp c, Jump_000_35da

;> elif step == 4:
;>     t = ((mem[wShadowOAM + 90] & 0xF0) + 6) & 0xFF
;>     for i, d in enumerate((0, 1, 0x10, 0x11)):
;>         mem[0xC05A + 4 * i] = (t + d) & 0xFF
	jp z, Jump_000_35e3

;> elif step < 8:
;>     for i in range(4):
;>         mem[0xC058 + 4 * i] += 2
	cp $08
	jp c, Jump_000_35f6

;> elif step < 0x20:
;>@wob2     if hFrameCount & 3:
;>@wob3         wHurtStep2 -= 1
;>@wob4         return
;>@wob5     wWobble2 ^= 1
;>@wob6     on = wWobble2
;>@wob7     for p in range(2):                          # two pairs of sprites
;>@wob8         a, b = 0xC05A + 8 * p, 0xC05E + 8 * p
;>@wob9         if on:                                  # mirrored (X flip)
;>@wob10             mem[a] += 1; mem[a + 1] |= 0x20; mem[b] -= 1; mem[b + 1] |= 0x20
;>@wob11         else:
;>@wob12             mem[a] -= 1; mem[a + 1] &= 0xDF; mem[b] += 1; mem[b + 1] &= 0xDF
;> else:
	cp $20
	jr c, jr_000_367c

;>     wDanceStep2 = 0
;>     wHurtStep2 = 0
;>     wWobble2 = 0
	xor a
	ld [wDanceStep2], a
	ld [wHurtStep2], a
	ld [wWobble2], a
;>     hVirusColoursHit &= ~0x02 & 0xFF
	ld hl, hVirusColoursHit
	res 1, [hl]
;>     if hViruses1:
	ldh a, [hViruses1]
	and a
	jr z, jr_000_36bb

;>         DrawMagnifierVirus2()
	call DrawMagnifierVirus2
	ret


jr_000_367c:
;=@wob2
	ldh a, [hFrameCount]
	and $03
	jr z, jr_000_3687

;=@wob3
	ld hl, wHurtStep2
	dec [hl]
;=@wob4
	ret


jr_000_3687:
;=@wob5
	ld hl, wWobble2
	ld a, [hl]
	xor $01
	ld [hl], a
;=@wob6
	ld hl, wShadowOAM + $5A
	jr z, jr_000_36a7

;=@wob10
Jump_000_3693:
	ld b, $02

jr_000_3695:
	ld a, [hl]
	inc a
	ld [hli], a
	set 5, [hl]
	dec l
	add hl, de
	ld a, [hl]
	dec a
	ld [hli], a
	set 5, [hl]
	dec l
	add hl, de
	dec b
	jr nz, jr_000_3695

	ret


;=@wob12
Jump_000_36a7:
jr_000_36a7:
	ld b, $02

jr_000_36a9:
	ld a, [hl]
	dec a
	ld [hli], a
	res 5, [hl]
	dec l
	add hl, de
	ld a, [hl]
	inc a
	ld [hli], a
	res 5, [hl]
	dec l
	add hl, de
	dec b
	jr nz, jr_000_36a9

	ret


;>     else:
;>         VanishFrame(0xC05A)
jr_000_36bb:
	ld hl, wShadowOAM + $5A
	call VanishFrame
;>         hMagnifierVirus2 = 1
	ld a, $01
	ldh [hMagnifierVirus2], a
	ret


;@ def VanishWait2()
;@ path: game/magnifier
;@ writes: hMagnifierVirus2
;@ test: mem[0xD028] = rand(0, 2)
;@ sig: e82be31f
VanishWait2::
;> wVanishTimer2 += 1
;> if wVanishTimer2 != 3:
;>     return
	ld hl, wVanishTimer2
	inc [hl]
	ld a, [hl]
	cp $03
	ret nz

;> wVanishTimer2 = 0
	xor a
	ld [hl], a
;> hMagnifierVirus2 = 2
	ld a, $02
	ldh [hMagnifierVirus2], a
	ret


;@ def RemoveMagnifierVirus2(state: hl)
;@ path: game/magnifier
;@ test: state = 0xFFFB
;@ sig: 08ef5d5a
RemoveMagnifierVirus2::
;> mem[state] = 3
	ld a, $03
	ld [hl], a
;> ClearBytes16(0xC058)
	ld hl, wShadowOAM + $58
	call ClearBytes16
;> BlankTiles4(0xC05A)
	ld hl, wShadowOAM + $5A
	call BlankTiles4
	ret


;@ def HurtMagnifierVirus3()
;@ path: game/magnifier
;@ The same for virus 3, with HurtMagnifierVirus2's mirrored wobble.
;@ reads: hFrameCount, hViruses2
;@ writes: hVirusColoursHit, hMagnifierVirus3, $D018, $D01B, $D01E, wDanceStep3, wHurtStep3, wWobble3
;@ test: hFrameCount = rand(0, 255); mem[0xD01E] = rng.choice([rand(0, 8), rand(8, 0x1F), 0x1F]); mem[0xD01B] = rand(0, 1); hViruses2 = rand(0, 2)
;@ test: for i in range(4): mem[0xC068 + 4 * i] = rand(0x40, 0x60); mem[0xC06A + 4 * i] = rand(0x40, 0x60); mem[0xC06B + 4 * i] = rng.choice([0, 0x20])
;@ sig: 96636e6f
HurtMagnifierVirus3::
;> if hFrameCount & 1:
;>     return
	ldh a, [hFrameCount]
	and $01
	ret nz

;> wHurtStep3 += 1
;> step = wHurtStep3
	ld hl, wHurtStep3
	inc [hl]
	ld a, [hl]
;> if step < 4:
;>     for i in range(4):
;>         mem[0xC068 + 4 * i] -= 2
	ld hl, wShadowOAM + $68
	ld de, $0004
	ld b, e
	cp $04
	jp c, Jump_000_35da

;> elif step == 4:
;>     t = ((mem[wShadowOAM + 106] & 0xF0) + 6) & 0xFF
;>     for i, d in enumerate((0, 1, 0x10, 0x11)):
;>         mem[0xC06A + 4 * i] = (t + d) & 0xFF
	jp z, Jump_000_35e3

;> elif step < 8:
;>     for i in range(4):
;>         mem[0xC068 + 4 * i] += 2
	cp $08
	jp c, Jump_000_35f6

;> elif step < 0x20:
;>@wob2     if hFrameCount & 3:
;>@wob3         wHurtStep3 -= 1
;>@wob4         return
;>@wob5     wWobble3 ^= 1
;>@wob6     on = wWobble3
;>@wob7     for p in range(2):                          # two pairs of sprites
;>@wob8         a, b = 0xC06A + 8 * p, 0xC06E + 8 * p
;>@wob9         if on:                                  # mirrored (X flip)
;>@wob10             mem[a] += 1; mem[a + 1] |= 0x20; mem[b] -= 1; mem[b + 1] |= 0x20
;>@wob11         else:
;>@wob12             mem[a] -= 1; mem[a + 1] &= 0xDF; mem[b] += 1; mem[b + 1] &= 0xDF
;> else:
	cp $20
	jr c, jr_000_371f

;>     wDanceStep3 = 0
;>     wHurtStep3 = 0
;>     wWobble3 = 0
	xor a
	ld [wDanceStep3], a
	ld [wHurtStep3], a
	ld [wWobble3], a
;>     hVirusColoursHit &= ~0x01 & 0xFF
	ld hl, hVirusColoursHit
	res 0, [hl]
;>     if hViruses2:
	ldh a, [hViruses2]
	and a
	jr z, jr_000_373a

;>         DrawMagnifierVirus3()
	call DrawMagnifierVirus3
	ret


jr_000_371f:
;=@wob2
	ldh a, [hFrameCount]
	and $03
	jr z, jr_000_372a

;=@wob3
	ld hl, wHurtStep3
	dec [hl]
;=@wob4
	ret


jr_000_372a:
;=@wob5
	ld hl, wWobble3
	ld a, [hl]
	xor $01
	ld [hl], a
;=@wob6
	ld hl, wShadowOAM + $6A
	jp z, Jump_000_36a7

	jp Jump_000_3693


;>     else:
;>         VanishFrame(0xC06A)
jr_000_373a:
	ld hl, wShadowOAM + $6A
	call VanishFrame
;>         hMagnifierVirus3 = 1
	ld a, $01
	ldh [hMagnifierVirus3], a
	ret


;@ def VanishWait3()
;@ path: game/magnifier
;@ writes: hMagnifierVirus3
;@ test: mem[0xD029] = rand(0, 2)
;@ sig: 3a6594ae
VanishWait3::
;> wVanishTimer3 += 1
;> if wVanishTimer3 != 3:
;>     return
	ld hl, wVanishTimer3
	inc [hl]
	ld a, [hl]
	cp $03
	ret nz

;> wVanishTimer3 = 0
	xor a
	ld [hl], a
;> hMagnifierVirus3 = 2
	ld a, $02
	ldh [hMagnifierVirus3], a
	ret


;@ def RemoveMagnifierVirus3(state: hl)
;@ path: game/magnifier
;@ test: state = 0xFFFC
;@ sig: 18bc6cf3
RemoveMagnifierVirus3::
;> mem[state] = 3
	ld a, $03
	ld [hl], a
;> ClearBytes16(0xC068)
	ld hl, wShadowOAM + $68
	call ClearBytes16
;> BlankTiles4(0xC06A)
	ld hl, wShadowOAM + $6A
	call BlankTiles4
	ret


;@ def VanishFrame(tiles: hl)
;@ path: game/magnifier
;@ The last colour of a virus is gone: its four tiles become the vanishing
;@ frame ($48, $49, $58, $59) and sound $0C plays.
;@ writes: wSFXRequest
;@ test: tiles = 0xC04A + 0x10 * rand(0, 2)
;@ sig: 8ef2334a
VanishFrame::
;> for i, t in enumerate((0x48, 0x49, 0x58, 0x59)):
;>     mem[tiles + 4 * i] = t
	ld de, $0004
	ld a, $48
	ld [hl], a
	add hl, de
	inc a
	ld [hl], a
	add hl, de
	add $0f
	ld [hl], a
	add hl, de
	inc a
	ld [hl], a
;> wSFXRequest = 0x0C
	ld a, $0c
	ld [wSFXRequest], a
	ret


;@ def ClearBytes16(dest: hl) -> hl
;@ path: lib/memory
;@ test: dest = rand_ram(16)
;@ sig: c2faf708
ClearBytes16::
;> for i in range(16):
;>     mem[dest + i] = 0
;> return dest + 16
	ld b, $10
	xor a

jr_000_377d:
	ld [hli], a
	dec b
	jr nz, jr_000_377d

	ret


;@ def BlankTiles4(tiles: hl)
;@ path: game/magnifier
;@ Sets the tile bytes of four shadow OAM entries to $FF (blank).
;@ test: tiles = 0xC04A + 0x10 * rand(0, 2)
;@ sig: d86b1cf9
BlankTiles4::
;> for i in range(4):
;>     mem[tiles + 4 * i] = 0xFF
	ld de, $0004
	ld b, e
	ld a, $ff

jr_000_3788:
	ld [hl], a
	add hl, de
	dec b
	jr nz, jr_000_3788

	ret


;@ def DrawMarioLost()
;@ path: game/magnifier
;@ 1 player, after a full bottle: Dr. Mario's sprites (shadow OAM entry 8 on)
;@ show the losing pose from MarioLostTiles.
;@ reads: hTwoPlayer
;@ test: hTwoPlayer = rng.choice([0, 1])
;@ sig: eaba883c
DrawMarioLost::
;> if hTwoPlayer:
;>     return
	ldh a, [hTwoPlayer]
	and a
	ret nz

;> mem[wShadowOAM + 32] = 0x3D                              # y and x of the first sprite
;> mem[wShadowOAM + 33] = 0x8C
	ld hl, wShadowOAM + $20
	ld a, $3d
	ld [hli], a
	ld a, $8c
	ld [hli], a
;> for i in range(10):
;>     mem[0xC022 + 4 * i] = mem[MarioLostTiles + i]
	ld de, $37aa
	ld b, $0a

jr_000_37a0:
	ld a, [de]
	ld [hli], a
	inc l
	inc l
	inc l
	inc de
	dec b
	jr nz, jr_000_37a0

	ret


MarioLostTiles::
	db $17, $14, $12, $15, $10, $18, $11, $13, $16, $19

;@ def LaughMagnifierViruses()
;@ path: game/magnifier
;@ After a full bottle the viruses that are left laugh: every 8 frames they
;@ switch between their normal tiles and the laughing ones (+$0A).
;@ reads: hFrameCount, hViruses0, hViruses1, hViruses2
;@ test: hFrameCount = rng.choice([0, 8, 3]); mem[0xD01F] = rand(0, 1); hViruses0 = rand(0, 2); hViruses1 = rand(0, 2); hViruses2 = rand(0, 2)
;@ sig: 34394e57
LaughMagnifierViruses::
;> if hFrameCount & 7:
;>     return
	ldh a, [hFrameCount]
	and $07
	ret nz

;> wLaughFrame ^= 1
;> if wLaughFrame:                                 # normal
	ld hl, wLaughFrame
	ld a, [hl]
	xor $01
	ld [hl], a
	jr z, jr_000_37da

;>     if hViruses0: DrawMagnifierVirus1()
	ldh a, [hViruses0]
	and a
	jr z, jr_000_37ca

	call DrawMagnifierVirus1

jr_000_37ca:
;>     if hViruses1: DrawMagnifierVirus2()
	ldh a, [hViruses1]
	and a
	jr z, jr_000_37d2

	call DrawMagnifierVirus2

jr_000_37d2:
;>     if hViruses2: DrawMagnifierVirus3()
;>@laugh else:                                        # laughing
;>@laugh0     if hViruses0: AddToTiles4(0xC04A)
;>@laugh1     if hViruses1: AddToTiles4(0xC05A)
;>@laugh2     if hViruses2: AddToTiles4(0xC06A)
	ldh a, [hViruses2]
	and a
	ret z

	call DrawMagnifierVirus3
	ret


;=@laugh0
jr_000_37da:
	ldh a, [hViruses0]
	and a
	jr z, jr_000_37e5

	ld hl, wShadowOAM + $4A
	call AddToTiles4

jr_000_37e5:
;=@laugh1
	ldh a, [hViruses1]
	and a
	jr z, jr_000_37f0

	ld hl, wShadowOAM + $5A
	call AddToTiles4

jr_000_37f0:
;=@laugh2
	ldh a, [hViruses2]
	and a
	ret z

	ld hl, wShadowOAM + $6A
	call AddToTiles4
	ret


;@ def AddToTiles4(tiles: hl)
;@ path: game/magnifier
;@ Adds $0A to the tile bytes of four shadow OAM entries (the laughing frame).
;@ test: tiles = 0xC04A + 0x10 * rand(0, 2)
;@ sig: d74742c5
AddToTiles4::
;> for i in range(4):
;>     mem[tiles + 4 * i] = (mem[tiles + 4 * i] + 0x0A) & 0xFF
	ld bc, $040a
	ld de, $0004

jr_000_3801:
	ld a, [hl]
	add c
	ld [hl], a
	add hl, de
	dec b
	jr nz, jr_000_3801

	ret


;@ def BottleCellToVRAM()
;@ path: game/viruses
;@ Works out the BG map address of the bottle cell in $D002/$D003 (rows 2-15
;@ are on screen) and stores it in $D036/$D037 for the VBlank handler.
;@ writes: $D036, $D037, wNewVirusVRAM
;@ test: mem[0xD002] = 0xC8; mem[0xD003] = rand(0, 255)
;@ sig: aabfa02a
BottleCellToVRAM::
;> e = mem[wVirusCell + 1]                                 # cell offset in the bottle
	ld hl, wVirusCell
	ld a, [hli]
	ld d, a
	ld a, [hl]
	ld e, a
;> row = min(max(e >> 3, 2), 15)
	cp $78
	jr nc, jr_000_384f

	cp $70
	jr nc, jr_000_3862

	cp $68
	jr nc, jr_000_3869

	cp $60
	jr nc, jr_000_3870

	cp $58
	jr nc, jr_000_3877

	cp $50
	jr nc, jr_000_387e

	cp $48
	jr nc, jr_000_3885

	cp $40
	jr nc, jr_000_388c

	cp $38
	jr nc, jr_000_3893

	cp $30
	jr nc, jr_000_389a

	cp $28
	jr nc, jr_000_38a1

	cp $20
	jr nc, jr_000_38a8

	cp $18
	jr nc, jr_000_38af

	jr jr_000_38b6

	db $fe, $10, $30, $6c, $fe, $08, $30, $6f, $c9

;=@vram
jr_000_384f:
;>@vram addr = (0x9862 + 32 * (row - 2) + ((e - 8 * row) & 0xFF)) & 0xFFFF   # column 2 of BG row row + 1
	ld b, $78
	ld hl, $9a02

;=@vram
jr_000_3854:
	sub b
	ld e, a
	ld d, $00
	add hl, de
;> mem[wNewVirusVRAM] = addr >> 8
;> mem[wNewVirusVRAM + 1] = addr & 0xFF
	ld a, h
	ld [wNewVirusVRAM], a
	ld a, l
	ld [wNewVirusVRAM + 1], a
	ret


;=@vram
jr_000_3862:
	ld b, $70
	ld hl, $99e2
	jr jr_000_3854

;=@vram
jr_000_3869:
	ld b, $68
	ld hl, $99c2
	jr jr_000_3854

;=@vram
jr_000_3870:
	ld b, $60
	ld hl, $99a2
	jr jr_000_3854

;=@vram
jr_000_3877:
	ld b, $58
	ld hl, $9982
	jr jr_000_3854

;=@vram
jr_000_387e:
	ld b, $50
	ld hl, $9962
	jr jr_000_3854

;=@vram
jr_000_3885:
	ld b, $48
	ld hl, $9942
	jr jr_000_3854

;=@vram
jr_000_388c:
	ld b, $40
	ld hl, $9922
	jr jr_000_3854

;=@vram
jr_000_3893:
	ld b, $38
	ld hl, $9902
	jr jr_000_3854

;=@vram
jr_000_389a:
	ld b, $30
	ld hl, $98e2
	jr jr_000_3854

;=@vram
jr_000_38a1:
	ld b, $28
	ld hl, $98c2
	jr jr_000_3854

;=@vram
jr_000_38a8:
	ld b, $20
	ld hl, $98a2
	jr jr_000_3854

;=@vram
jr_000_38af:
	ld b, $18
	ld hl, $9882
	jr jr_000_3854

;=@vram
jr_000_38b6:
	ld b, $10
	ld hl, $9862
	jr jr_000_3854

	db $06, $08, $21, $42, $98, $18, $90

;@ asset: tilemap width=20 height=18 tiles=LoadGameTiles
;@ The 1-player game screen (GameInit).
GameScreen1P::
	db $3f, $3f, $3f, $38, $39, $4f, $4f, $3c, $3d
	db $3f, $3f, $56, $57, $57, $57, $57, $57, $57, $57, $58, $3f, $30, $31, $31, $3a
	db $4e, $4e, $3b, $31, $31, $32, $59, $fe, $1c, $0c, $18, $1b, $0e, $fe, $5a, $3f
	db $33, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $34, $59, $fe, $fe, $fe, $fe, $fe
	db $fe, $fe, $5a, $3f, $33, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $34, $5b, $5c
	db $5c, $5c, $5c, $5c, $5c, $5c, $5d, $3f, $33, $ff, $ff, $ff, $ff, $ff, $ff, $ff
	db $ff, $34, $3f, $48, $4c, $4c, $4c, $49, $3f, $66, $3f, $3f, $33, $ff, $ff, $ff
	db $ff, $ff, $ff, $ff, $ff, $34, $3f, $fe, $fe, $fe, $fe, $fe, $3f, $fe, $3f, $3f
	db $33, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $34, $3f, $fe, $fe, $fe, $fe, $fe
	db $3f, $fe, $3f, $3f, $33, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $34, $3f, $4a
	db $4d, $4d, $4d, $4b, $3f, $fe, $3f, $3f, $33, $ff, $ff, $ff, $ff, $ff, $ff, $ff
	db $ff, $34, $3f, $3f, $50, $51, $51, $51, $52, $67, $3f, $3f, $33, $ff, $ff, $ff
	db $ff, $ff, $ff, $ff, $ff, $34, $40, $41, $53, $54, $54, $54, $55, $41, $42, $3f
	db $33, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $34, $43, $fe, $15, $0e, $1f, $0e
	db $15, $fe, $44, $3f, $33, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $34, $43, $fe
	db $fe, $fe, $fe, $fe, $fe, $fe, $44, $3f, $33, $ff, $ff, $ff, $ff, $ff, $ff, $ff
	db $ff, $34, $43, $fe, $1f, $12, $1b, $1e, $1c, $fe, $44, $3f, $33, $ff, $ff, $ff
	db $ff, $ff, $ff, $ff, $ff, $34, $43, $fe, $fe, $fe, $fe, $fe, $fe, $fe, $44, $3f
	db $33, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $34, $45, $46, $46, $46, $46, $46
	db $46, $46, $47, $3f, $33, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $34, $3f, $48
	db $4c, $4c, $4c, $4c, $4c, $49, $3f, $3f, $33, $ff, $ff, $ff, $ff, $ff, $ff, $ff
	db $ff, $34, $3f, $fe, $fe, $fe, $fe, $fe, $fe, $fe, $3f, $3f, $35, $36, $36, $36
	db $36, $36, $36, $36, $36, $37, $3f, $4a, $4d, $4d, $4d, $4d, $4d, $4b, $3f

;@ asset: tilemap width=20 height=18 tiles=LoadGameTiles
;@ The 2-player game screen; in 1-player games it goes into BG map 1.
GameScreen2P::
	db $3f
	db $3f, $3f, $38, $39, $4f, $4f, $3c, $3d, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f
	db $3f, $3f, $3f, $3f, $30, $31, $31, $3a, $4e, $4e, $3b, $31, $31, $32, $56, $57
	db $57, $57, $57, $57, $57, $57, $58, $3f, $33, $ff, $ff, $ff, $ff, $ff, $ff, $ff
	db $ff, $34, $59, $0d, $2f, $16, $0a, $1b, $12, $18, $5a, $3f, $33, $ff, $ff, $ff
	db $ff, $ff, $ff, $ff, $ff, $34, $5b, $5c, $5c, $5c, $5c, $5c, $5c, $5c, $5d, $3f
	db $33, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $34, $3f, $48, $4c, $4c, $4c, $49
	db $3f, $66, $3f, $3f, $33, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $34, $3f, $fe
	db $fe, $fe, $fe, $fe, $3f, $fe, $3f, $3f, $33, $ff, $ff, $ff, $ff, $ff, $ff, $ff
	db $ff, $34, $3f, $fe, $fe, $fe, $fe, $fe, $3f, $fe, $3f, $3f, $33, $ff, $ff, $ff
	db $ff, $ff, $ff, $ff, $ff, $34, $3f, $4a, $4d, $4d, $4d, $4b, $3f, $fe, $3f, $3f
	db $33, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $34, $3f, $3f, $3f, $3f, $3f, $3f
	db $3f, $67, $3f, $3f, $33, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $34, $56, $57
	db $57, $57, $68, $57, $57, $57, $58, $3f, $33, $ff, $ff, $ff, $ff, $ff, $ff, $ff
	db $ff, $34, $59, $fe, $fe, $fe, $6a, $fe, $fe, $fe, $5a, $3f, $33, $ff, $ff, $ff
	db $ff, $ff, $ff, $ff, $ff, $34, $5b, $5c, $5c, $5c, $69, $5c, $5c, $5c, $5d, $3f
	db $33, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $34, $56, $57, $57, $58, $3f, $60
	db $61, $62, $3f, $3f, $33, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $34, $59, $fe
	db $fe, $5a, $3f, $70, $71, $72, $3f, $3f, $33, $ff, $ff, $ff, $ff, $ff, $ff, $ff
	db $ff, $34, $59, $fe, $fe, $5a, $3f, $73, $fe, $74, $3f, $3f, $33, $ff, $ff, $ff
	db $ff, $ff, $ff, $ff, $ff, $34, $5b, $5c, $5c, $5d, $3f, $63, $64, $65, $3f, $3f
	db $33, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $34, $3f, $22, $18, $1e, $3f, $0c
	db $18, $16, $3f, $3f, $35, $36, $36, $36, $36, $36, $36, $36, $36, $37, $3f, $3f
	db $3f, $3f, $3f, $3f, $3f, $3f, $3f

;@ asset: tilemap width=20 height=18 tiles=LoadGameTiles+CopyBytes(hl=Tiles_559E,de=$8800,bc=$520)
;@ The underwater screen, with its own tiles over $8800 (LoadUnderwaterScreen).
UnderwaterScreen::
	db $fe, $fe, $fe, $fe, $fe, $fe, $fe, $fe, $fe
	db $fe, $fe, $fe, $fe, $fe, $fe, $fe, $fe, $fe, $fe, $fe, $fe, $fe, $fe, $fe, $fe
	db $fe, $fe, $fe, $fe, $fe, $fe, $fe, $fe, $fe, $fe, $fe, $fe, $fe, $fe, $fe, $80
	db $81, $80, $81, $80, $81, $80, $81, $80, $81, $80, $81, $80, $81, $80, $81, $80
	db $81, $80, $81, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
	db $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
	db $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
	db $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
	db $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
	db $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
	db $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
	db $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
	db $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
	db $8d, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
	db $ff, $ff, $ff, $ff, $8e, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
	db $ff, $ff, $ff, $ff, $ff, $8d, $ff, $8f, $8d, $ff, $ff, $8d, $ff, $ff, $8d, $ff
	db $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $8e, $ff, $8f, $8e, $ff, $ff, $8e
	db $ff, $ff, $8e, $ff, $ff, $ff, $ff, $ff, $ff, $8f, $8f, $ff, $ff, $8d, $ff, $8f
	db $8d, $ff, $ff, $8d, $ff, $ff, $8d, $ff, $ff, $ff, $ff, $ff, $ff, $8f, $8f, $ff
	db $ff, $8e, $ff, $cf, $8e, $8a, $8a, $82, $8a, $86, $84, $8a, $8a, $8b, $8a, $8b
	db $8a, $cf, $cf, $8a, $8a, $8d, $8a, $8b, $82, $86, $87, $8b, $8c, $88, $89, $83
	db $8b, $8b, $8c, $8b, $8c, $86, $87, $8b, $8c, $82, $8b, $8c, $8c, $88, $89, $8c
	db $8c, $8b, $8c, $8c, $8c, $8b, $8c, $8c, $8c, $88, $89, $8c, $8b, $8b, $8c

;@ asset: tilemap width=9 height=18 tiles=LoadGameTiles
;@ The 2-player side panel, 9x18 tiles, shown through the window. LoadBGMap1Panel copies 24 rows, so the last 6 come from the start of GameTiles (off screen).
VersusPanel::
	db $3f
	db $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $56, $57, $57, $57, $68, $57, $57, $57
	db $58, $59, $22, $18, $1e, $6a, $0c, $18, $16, $5a, $6d, $6b, $6b, $6b, $6c, $6b
	db $6b, $6b, $6e, $59, $fe, $15, $0e, $1f, $0e, $15, $fe, $5a, $59, $fe, $fe, $fe
	db $fe, $fe, $fe, $fe, $5a, $59, $fe, $1c, $19, $0e, $0e, $0d, $fe, $5a, $59, $fe
	db $fe, $fe, $fe, $fe, $fe, $fe, $5a, $59, $fe, $1f, $12, $1b, $1e, $1c, $fe, $5a
	db $59, $fe, $fe, $fe, $fe, $fe, $fe, $fe, $5a, $5b, $5c, $5c, $5c, $5c, $5c, $5c
	db $5c, $5d, $3f, $56, $57, $57, $68, $57, $57, $58, $3f, $3f, $59, $fe, $fe, $6a
	db $fe, $fe, $5a, $3f, $3f, $59, $fe, $fe, $6a, $fe, $fe, $5a, $3f, $3f, $59, $fe
	db $fe, $6a, $fe, $fe, $5a, $3f, $3f, $59, $fe, $fe, $6a, $fe, $fe, $5a, $3f, $3f
	db $59, $fe, $fe, $6a, $fe, $fe, $5a, $3f, $3f, $5b, $5c, $5c, $69, $5c, $5c, $5d
	db $3f

;@ asset: tiles bpp=2 length=$17FF
;@ All tile graphics, copied to $8000 by LoadGameTiles.
GameTiles::
	db $00, $00, $00, $00, $00, $00, $00, $00, $30, $30, $4f, $4f, $a7, $87, $cc
	db $cc, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $e0, $e0, $f0, $f0, $08
	db $08, $7f, $7f, $49, $41, $5c, $54, $5c, $54, $7f, $40, $ff, $83, $ff, $87, $7f
	db $7f, $f8, $f8, $fc, $3c, $fe, $32, $fe, $6a, $fe, $0a, $fe, $12, $fe, $ce, $fc
	db $8c, $00, $00, $00, $00, $07, $07, $1e, $1a, $3e, $22, $3e, $3e, $03, $03, $00
	db $00, $3f, $2c, $5f, $50, $8f, $8f, $2a, $2a, $47, $47, $44, $44, $f4, $f4, $44
	db $44, $f8, $18, $e4, $64, $82, $82, $82, $82, $11, $11, $11, $11, $f1, $f1, $3f
	db $3f, $24, $24, $22, $22, $1f, $1f, $09, $09, $1d, $1d, $23, $3f, $41, $7f, $7f
	db $7f, $3f, $21, $1f, $11, $fe, $fe, $08, $08, $38, $38, $c4, $fc, $02, $fe, $fe
	db $fe, $00, $00, $00, $00, $1a, $1a, $3f, $25, $3f, $21, $3f, $23, $1c, $14, $08
	db $08, $7f, $7f, $49, $41, $5c, $54, $5c, $54, $7f, $40, $ff, $83, $ff, $87, $7f
	db $7f, $04, $04, $03, $03, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
	db $00, $3f, $2c, $1f, $10, $8f, $8f, $6a, $6a, $47, $47, $44, $44, $74, $74, $44
	db $44, $00, $00, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01
	db $01, $ff, $ff, $c9, $41, $dc, $54, $dc, $d4, $7f, $40, $ff, $83, $ff, $87, $7f
	db $7f, $bf, $ac, $9f, $90, $4f, $4f, $6a, $6a, $47, $47, $44, $44, $74, $74, $44
	db $44, $00, $00, $00, $00, $00, $00, $00, $00, $03, $03, $0f, $0f, $1e, $1e, $23
	db $23, $00, $00, $00, $00, $00, $00, $00, $00, $c0, $c0, $30, $30, $18, $58, $34
	db $34, $3f, $3f, $79, $68, $f3, $a2, $f3, $b2, $ff, $80, $ff, $a8, $7f, $5c, $7f
	db $4f, $fc, $fc, $3e, $2e, $9f, $89, $9f, $99, $ff, $01, $ff, $25, $fe, $72, $fe
	db $e2, $02, $02, $0f, $0d, $1f, $11, $1e, $1e, $04, $04, $02, $02, $01, $01, $00
	db $00, $3f, $20, $5f, $58, $af, $af, $2b, $2b, $45, $45, $43, $43, $dd, $dd, $41
	db $41, $fc, $04, $fa, $3a, $e1, $e1, $a2, $a2, $41, $41, $81, $81, $79, $79, $03
	db $03, $40, $40, $f8, $b8, $fc, $84, $78, $78, $20, $20, $c0, $c0, $00, $00, $00
	db $00, $41, $41, $21, $21, $1f, $1f, $08, $08, $1c, $1c, $23, $3f, $40, $7f, $7f
	db $7f, $02, $02, $04, $04, $f8, $f8, $88, $88, $b8, $b8, $c4, $fc, $82, $fe, $fe
	db $fe, $3f, $3f, $79, $68, $f3, $a2, $f3, $b2, $ff, $80, $ff, $a8, $ff, $dc, $6f
	db $5f, $fc, $fc, $3e, $2e, $9f, $89, $9f, $99, $ff, $01, $ff, $25, $fe, $72, $e6
	db $fa, $03, $03, $07, $04, $07, $04, $07, $04, $03, $03, $01, $01, $00, $00, $00
	db $00, $e0, $df, $f0, $6e, $dc, $53, $8f, $8c, $27, $27, $45, $45, $c2, $c2, $5d
	db $5d, $07, $fb, $0f, $76, $3b, $ca, $f1, $31, $c4, $c4, $42, $42, $83, $83, $3a
	db $3a, $c0, $c0, $e0, $20, $e0, $20, $e0, $60, $a0, $a0, $40, $40, $80, $80, $00
	db $00, $00, $00, $00, $00, $38, $38, $7e, $7e, $e7, $f7, $81, $a1, $02, $42, $00
	db $40, $00, $00, $00, $00, $38, $38, $fc, $fc, $ce, $de, $02, $0a, $80, $84, $00
	db $04, $3c, $3c, $7e, $7e, $8e, $8e, $23, $37, $41, $61, $02, $42, $00, $40, $01
	db $6a, $00, $00, $38, $38, $7c, $7c, $ce, $de, $02, $0a, $80, $84, $00, $04, $00
	db $ac, $00, $00, $38, $38, $7c, $7c, $e7, $f7, $81, $a1, $02, $42, $00, $40, $01
	db $6a, $78, $78, $fc, $fc, $e2, $e2, $88, $d8, $04, $0c, $80, $84, $00, $04, $00
	db $ac, $00, $00, $00, $00, $00, $00, $1a, $1a, $30, $30, $2c, $2c, $1f, $1f, $df
	db $df, $00, $00, $00, $00, $e0, $e0, $b0, $90, $08, $18, $64, $6c, $fc, $f4, $f4
	db $f8, $00, $00, $00, $00, $0e, $0e, $1a, $12, $20, $30, $4c, $6c, $7f, $5f, $5f
	db $7f, $00, $00, $00, $00, $00, $00, $b8, $98, $0c, $1c, $64, $6c, $f0, $f0, $f6
	db $f6, $00, $00, $00, $00, $3e, $3e, $73, $73, $65, $65, $c0, $c0, $41, $4a, $5f
	db $af, $00, $00, $00, $00, $f8, $f8, $9c, $9c, $4c, $4c, $06, $06, $04, $a4, $d0
	db $ea, $00, $00, $18, $18, $5a, $5a, $7e, $7e, $66, $66, $00, $66, $7e, $7e, $00
	db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
	db $00, $02, $02, $02, $02, $01, $01, $00, $00, $00, $00, $00, $00, $00, $00, $00
	db $00, $20, $3f, $30, $2e, $1c, $13, $cf, $cc, $27, $27, $45, $45, $42, $42, $5d
	db $5d, $01, $6a, $3f, $7f, $04, $54, $07, $2f, $00, $15, $00, $2a, $50, $70, $f0
	db $f0, $00, $ac, $f8, $fc, $40, $54, $c0, $e8, $00, $50, $00, $a8, $14, $1c, $1e
	db $1e, $3f, $7f, $04, $54, $07, $2f, $00, $15, $00, $2a, $00, $20, $50, $50, $f0
	db $f0, $f8, $fc, $42, $52, $c6, $ee, $02, $5a, $06, $b6, $00, $00, $00, $00, $00
	db $00, $3f, $7f, $84, $94, $c7, $ef, $80, $b5, $c0, $da, $00, $00, $00, $00, $00
	db $00, $f8, $fc, $40, $54, $c0, $e8, $00, $50, $00, $a8, $00, $08, $14, $14, $1e
	db $1e, $c7, $d7, $e5, $ea, $6a, $65, $05, $0a, $0a, $15, $05, $02, $00, $00, $00
	db $00, $c8, $d0, $56, $a6, $a6, $56, $4e, $ae, $ac, $4c, $40, $80, $00, $00, $00
	db $00, $27, $17, $d1, $ca, $ca, $d5, $e5, $ea, $6a, $65, $05, $02, $00, $00, $00
	db $00, $c6, $d6, $4e, $ae, $ac, $4c, $50, $a0, $a0, $50, $40, $80, $00, $00, $00
	db $00, $0c, $dc, $1f, $bf, $1f, $5f, $0f, $6f, $07, $37, $00, $2a, $50, $75, $f0
	db $f0, $60, $76, $f0, $fa, $f0, $f4, $e0, $ec, $c0, $d8, $10, $b8, $14, $5c, $1e
	db $1e, $00, $00, $00, $00, $00, $00, $07, $07, $0f, $08, $0f, $08, $0f, $0d, $06
	db $06, $f3, $13, $e0, $60, $88, $88, $84, $84, $03, $03, $02, $02, $e2, $e2, $02
	db $02, $80, $80, $60, $60, $10, $10, $30, $30, $78, $48, $f8, $88, $f0, $90, $60
	db $60, $04, $04, $04, $04, $fc, $fc, $08, $08, $38, $38, $c4, $fc, $02, $fe, $fe
	db $fe, $00, $00, $20, $20, $32, $32, $3f, $3f, $dc, $dc, $d0, $d0, $32, $32, $79
	db $79, $00, $00, $04, $04, $4c, $4c, $fc, $fc, $3b, $3b, $0b, $0b, $4c, $4c, $9e
	db $9e, $00, $00, $d0, $d5, $df, $df, $70, $70, $20, $20, $49, $49, $66, $66, $7f
	db $7f, $10, $10, $30, $30, $f0, $f0, $f8, $f8, $38, $38, $3b, $3b, $7b, $7b, $fc
	db $fc, $08, $08, $0c, $0c, $0f, $0f, $1f, $1f, $1c, $1c, $dc, $dc, $de, $de, $3f
	db $3f, $00, $00, $0b, $ab, $fb, $fb, $0e, $0e, $04, $04, $92, $92, $66, $66, $fe
	db $fe, $00, $00, $00, $00, $00, $00, $0a, $0a, $10, $10, $db, $db, $bc, $bc, $31
	db $31, $00, $00, $00, $00, $00, $00, $4c, $4c, $14, $14, $d8, $d8, $3c, $3c, $8c
	db $8c, $01, $01, $01, $01, $21, $21, $10, $10, $08, $08, $00, $00, $00, $00, $e0
	db $e0, $00, $00, $00, $00, $08, $08, $10, $10, $20, $20, $00, $00, $00, $00, $0e
	db $0e, $00, $00, $00, $00, $20, $20, $37, $37, $3c, $3c, $d2, $d2, $f9, $f9, $7f
	db $7f, $00, $00, $00, $00, $04, $04, $ec, $ec, $3c, $3c, $4b, $4b, $9f, $9f, $fe
	db $fe, $ff, $00, $ff, $3c, $ff, $7e, $ff, $66, $ff, $66, $ff, $66, $ff, $66, $ff
	db $66, $ff, $00, $ff, $18, $ff, $38, $ff, $38, $ff, $18, $ff, $18, $ff, $18, $ff
	db $18, $ff, $00, $ff, $3c, $ff, $7e, $ff, $66, $ff, $06, $ff, $06, $ff, $06, $ff
	db $0e, $ff, $00, $ff, $3c, $ff, $7e, $ff, $66, $ff, $06, $ff, $06, $ff, $1c, $ff
	db $1c, $7f, $7f, $7f, $7f, $60, $66, $3f, $3f, $7f, $7f, $4f, $4f, $60, $60, $e0
	db $e0, $fe, $fe, $fe, $fe, $06, $06, $fc, $fc, $fe, $fe, $f2, $f2, $06, $06, $07
	db $07, $40, $4c, $60, $6c, $20, $20, $30, $30, $18, $18, $2f, $2f, $60, $60, $e0
	db $e0, $0c, $0c, $0c, $0c, $1c, $1c, $38, $38, $f6, $f6, $c7, $c7, $00, $00, $00
	db $00, $30, $31, $38, $39, $38, $38, $1c, $1c, $6f, $6f, $e3, $e3, $00, $00, $00
	db $00, $02, $82, $06, $86, $04, $04, $0c, $0c, $18, $18, $f4, $f4, $06, $06, $07
	db $07, $27, $27, $37, $37, $df, $df, $ef, $ef, $6f, $6f, $07, $07, $00, $00, $00
	db $00, $e4, $e4, $e4, $e4, $fc, $fc, $f8, $f8, $fb, $fb, $e7, $e7, $06, $06, $00
	db $00, $00, $00, $00, $00, $08, $08, $11, $11, $21, $21, $01, $01, $01, $01, $00
	db $00, $00, $00, $00, $00, $20, $20, $10, $10, $08, $08, $00, $00, $00, $00, $00
	db $00, $60, $66, $40, $46, $40, $40, $21, $20, $63, $60, $59, $58, $6f, $6f, $e0
	db $e0, $06, $06, $02, $02, $02, $02, $84, $04, $c6, $06, $9a, $1a, $f6, $f6, $07
	db $07, $ff, $66, $ff, $66, $ff, $66, $ff, $66, $ff, $66, $ff, $7e, $ff, $3c, $ff
	db $00, $ff, $18, $ff, $18, $ff, $18, $ff, $18, $ff, $18, $ff, $3c, $ff, $3c, $ff
	db $00, $ff, $1c, $ff, $38, $ff, $30, $ff, $60, $ff, $60, $ff, $7e, $ff, $7e, $ff
	db $00, $ff, $06, $ff, $06, $ff, $06, $ff, $06, $ff, $66, $ff, $7e, $ff, $3c, $ff
	db $00, $62, $62, $75, $57, $38, $28, $10, $10, $17, $17, $dd, $dd, $e3, $a3, $44
	db $44, $46, $46, $ae, $ea, $1c, $14, $08, $08, $e8, $e8, $bb, $bb, $c7, $c5, $22
	db $22, $00, $00, $00, $00, $62, $62, $75, $57, $38, $28, $10, $10, $17, $17, $3d
	db $3d, $00, $00, $00, $00, $46, $46, $ae, $ea, $1c, $14, $08, $08, $e8, $e8, $bc
	db $bc, $c7, $c5, $e8, $a8, $70, $50, $37, $37, $dd, $dd, $f3, $b3, $64, $64, $20
	db $20, $e3, $a3, $17, $15, $0e, $0a, $ec, $ec, $bb, $bb, $cf, $cd, $26, $26, $04
	db $04, $00, $00, $00, $00, $03, $03, $0c, $6c, $13, $73, $1f, $1f, $10, $10, $20
	db $20, $00, $00, $00, $00, $c0, $c0, $30, $30, $c8, $c8, $f8, $f8, $0c, $0f, $04
	db $07, $ff, $00, $ff, $3c, $ff, $7e, $ff, $66, $ff, $66, $ff, $66, $ff, $3c, $ff
	db $3c, $ff, $00, $ff, $3c, $ff, $7e, $ff, $66, $ff, $66, $ff, $66, $ff, $7e, $ff
	db $3e, $c2, $c2, $ef, $af, $70, $50, $27, $27, $2d, $2d, $44, $44, $80, $80, $9f
	db $9f, $43, $43, $f7, $f5, $0e, $0a, $e4, $e4, $b4, $b4, $22, $22, $01, $01, $f9
	db $f9, $ff, $00, $ff, $1c, $ff, $3c, $ff, $3c, $ff, $6c, $ff, $6c, $ff, $6c, $ff
	db $6c, $ff, $00, $ff, $7e, $ff, $7e, $ff, $60, $ff, $60, $ff, $60, $ff, $7c, $ff
	db $7e, $ff, $00, $ff, $3c, $ff, $7e, $ff, $66, $ff, $60, $ff, $60, $ff, $7c, $ff
	db $7e, $ff, $00, $ff, $7e, $ff, $7e, $ff, $66, $ff, $06, $ff, $06, $ff, $06, $ff
	db $0c, $40, $40, $5f, $5f, $20, $e0, $10, $d0, $0f, $0f, $1c, $14, $3e, $22, $3e
	db $3e, $02, $02, $fa, $fa, $04, $07, $08, $0b, $f0, $f0, $38, $28, $7c, $44, $7c
	db $7c, $43, $43, $80, $80, $b8, $b8, $47, $47, $30, $f0, $1f, $df, $2e, $32, $3e
	db $3e, $c2, $c2, $01, $01, $1d, $1d, $e2, $e2, $0c, $0f, $f8, $fb, $7c, $44, $7c
	db $7c, $2f, $ef, $10, $d0, $10, $10, $0c, $0c, $1f, $17, $1c, $14, $3e, $22, $3e
	db $3e, $f4, $f7, $08, $0b, $08, $08, $30, $30, $f8, $e8, $38, $28, $7c, $44, $7c
	db $7c, $4f, $4f, $58, $58, $64, $64, $24, $24, $38, $38, $18, $18, $07, $07, $00
	db $00, $fa, $fa, $06, $06, $09, $09, $09, $09, $06, $06, $18, $18, $e0, $e0, $00
	db $00, $ff, $66, $ff, $66, $ff, $66, $ff, $66, $ff, $66, $ff, $7e, $ff, $3c, $ff
	db $00, $ff, $06, $ff, $06, $ff, $06, $ff, $06, $ff, $66, $ff, $7e, $ff, $3c, $ff
	db $00, $a4, $a4, $bc, $bc, $4f, $4f, $30, $f0, $0f, $cf, $1c, $14, $3e, $22, $3e
	db $3e, $95, $95, $9d, $9d, $f2, $f2, $0c, $0f, $f0, $f3, $38, $28, $7c, $44, $7c
	db $7c, $ff, $6c, $ff, $6c, $ff, $7e, $ff, $7e, $ff, $0c, $ff, $0c, $ff, $0c, $ff
	db $00, $ff, $06, $ff, $06, $ff, $06, $ff, $06, $ff, $66, $ff, $7e, $ff, $3c, $ff
	db $00, $ff, $66, $ff, $66, $ff, $66, $ff, $66, $ff, $66, $ff, $7e, $ff, $3c, $ff
	db $00, $ff, $18, $ff, $18, $ff, $18, $ff, $18, $ff, $18, $ff, $18, $ff, $18, $ff
	db $00, $7f, $7f, $eb, $d5, $d5, $ab, $ab, $d5, $d5, $ab, $eb, $d5, $7f, $7f, $00
	db $00, $7f, $7f, $ff, $c1, $ff, $bf, $ff, $ff, $ff, $ff, $ff, $ff, $7f, $7f, $00
	db $00, $7f, $7f, $ff, $c1, $ff, $81, $ff, $81, $ff, $81, $ff, $c1, $7f, $7f, $00
	db $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $fe, $00, $f8
	db $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $00, $00, $00
	db $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $7f, $00, $1f
	db $00, $f0, $00, $e3, $00, $e7, $00, $e7, $00, $e7, $00, $e7, $00, $e3, $00, $f0
	db $00, $0f, $00, $c7, $00, $e7, $00, $e7, $00, $e7, $00, $e7, $00, $c7, $00, $0f
	db $00, $f8, $00, $fe, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff
	db $00, $00, $00, $00, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff
	db $00, $1f, $00, $7f, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff
	db $00, $11, $11, $3b, $2a, $3f, $24, $3a, $2f, $3f, $2a, $3f, $3f, $36, $29, $3f
	db $3f, $00, $18, $18, $18, $00, $18, $18, $18, $00, $18, $18, $18, $00, $18, $18
	db $18, $00, $00, $18, $18, $38, $38, $18, $18, $18, $18, $18, $18, $3c, $3c, $00
	db $00, $00, $00, $7c, $7c, $66, $66, $66, $66, $7c, $7c, $60, $60, $60, $60, $00
	db $00, $ff, $38, $c7, $7c, $c7, $7c, $c7, $7c, $ff, $44, $ff, $44, $ff, $44, $ff
	db $38, $fc, $fc, $ae, $56, $56, $aa, $aa, $56, $56, $aa, $ae, $56, $fc, $fc, $00
	db $00, $fc, $fc, $fe, $06, $fe, $fa, $fe, $fe, $fe, $fe, $fe, $fe, $fc, $fc, $00
	db $00, $fc, $fc, $fe, $06, $fe, $02, $fe, $02, $fe, $02, $fe, $06, $fc, $fc, $00
	db $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $03, $fe, $0f, $f8
	db $1e, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $ff, $00, $ff, $00
	db $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $c0, $7f, $f0, $1f
	db $78, $f0, $18, $e3, $30, $e7, $30, $e7, $30, $e7, $30, $e7, $30, $e3, $30, $f0
	db $18, $0f, $18, $c7, $0c, $e7, $0c, $e7, $0c, $e7, $0c, $e7, $0c, $c7, $0c, $0f
	db $18, $f8, $1e, $fe, $0f, $ff, $03, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff
	db $00, $00, $00, $00, $ff, $ff, $ff, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff
	db $00, $1f, $78, $7f, $f0, $ff, $c0, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff
	db $00, $00, $00, $6c, $6c, $fe, $fa, $fe, $fe, $fe, $fe, $7c, $7c, $38, $38, $10
	db $10, $00, $00, $00, $00, $ff, $ff, $3f, $3f, $0f, $0f, $03, $03, $00, $00, $00
	db $00, $00, $00, $3c, $3c, $4e, $4e, $0e, $0e, $3c, $3c, $70, $70, $7e, $7e, $00
	db $00, $00, $00, $7c, $7c, $66, $66, $66, $66, $7c, $7c, $60, $60, $60, $60, $00
	db $00, $00, $00, $80, $80, $40, $40, $20, $20, $e0, $e0, $e0, $20, $e0, $20, $c0
	db $c0, $7c, $7c, $ee, $d6, $d6, $aa, $aa, $d6, $d6, $aa, $aa, $d6, $d6, $aa, $fe
	db $fe, $7c, $7c, $fe, $f6, $fe, $fa, $fe, $fa, $fe, $fa, $fe, $fa, $fe, $fa, $fe
	db $fe, $7c, $7c, $fe, $c6, $fe, $82, $fe, $82, $fe, $82, $fe, $82, $fe, $82, $fe
	db $fe, $00, $ff, $00, $ff, $00, $ff, $0f, $ff, $10, $f0, $25, $e0, $28, $e0, $28
	db $e0, $00, $ff, $00, $ff, $00, $ff, $f0, $ff, $0e, $0f, $e1, $01, $00, $00, $00
	db $00, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $80, $ff, $40, $7f, $20
	db $3f, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00
	db $ff, $00, $ff, $00, $ff, $00, $ff, $1f, $ff, $20, $e0, $44, $c0, $48, $c0, $48
	db $c0, $00, $ff, $00, $ff, $00, $ff, $80, $ff, $40, $7f, $40, $7f, $21, $3f, $21
	db $3f, $00, $ff, $00, $ff, $00, $ff, $7e, $ff, $81, $81, $98, $80, $20, $00, $20
	db $00, $00, $ff, $00, $ff, $00, $ff, $0f, $ff, $10, $f0, $a5, $e0, $a8, $e0, $a8
	db $e0, $00, $ff, $00, $ff, $00, $ff, $ff, $ff, $00, $00, $fe, $00, $00, $00, $00
	db $00, $00, $ff, $00, $ff, $00, $ff, $c1, $ff, $22, $3e, $14, $1c, $15, $1c, $15
	db $1c, $00, $ff, $00, $ff, $00, $ff, $ff, $ff, $00, $00, $bf, $00, $00, $00, $00
	db $00, $00, $ff, $00, $ff, $00, $ff, $c0, $ff, $30, $3f, $08, $0f, $04, $07, $02
	db $03, $00, $ff, $00, $ff, $00, $ff, $3f, $ff, $40, $c0, $90, $80, $a0, $80, $a0
	db $80, $d6, $aa, $aa, $d6, $d6, $aa, $aa, $d6, $d6, $aa, $ee, $d6, $7c, $7c, $00
	db $00, $fe, $fa, $fe, $fa, $fe, $fa, $fe, $fa, $fe, $fa, $fe, $f6, $7c, $7c, $00
	db $00, $fe, $82, $fe, $82, $fe, $82, $fe, $82, $fe, $82, $fe, $c6, $7c, $7c, $00
	db $00, $20, $e0, $20, $e0, $20, $e0, $10, $f0, $08, $f8, $08, $f8, $0a, $f8, $0a
	db $f8, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $18, $18, $14, $1c, $15
	db $1c, $20, $3f, $10, $1f, $10, $1f, $08, $0f, $08, $0f, $08, $0f, $0b, $0f, $0c
	db $0c, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $80, $ff, $5c
	db $7f, $40, $c0, $20, $e0, $10, $f0, $10, $f0, $10, $f0, $14, $f0, $14, $f0, $14
	db $f0, $12, $1e, $12, $1e, $0c, $0c, $0c, $0c, $00, $00, $00, $00, $00, $00, $40
	db $40, $40, $00, $01, $01, $02, $03, $02, $03, $02, $03, $22, $03, $22, $03, $a2
	db $83, $a0, $e0, $10, $f0, $08, $f8, $08, $f8, $08, $f8, $12, $f0, $12, $f0, $14
	db $f0, $00, $00, $00, $00, $30, $30, $30, $30, $30, $30, $48, $78, $48, $78, $78
	db $78, $14, $1c, $22, $3e, $41, $7f, $41, $7f, $41, $7f, $21, $3f, $21, $3f, $21
	db $3f, $00, $00, $00, $00, $07, $07, $04, $07, $04, $07, $04, $07, $44, $07, $45
	db $07, $02, $03, $01, $01, $01, $01, $81, $81, $81, $81, $81, $81, $81, $81, $81
	db $81, $80, $80, $40, $c0, $20, $e0, $20, $e0, $20, $e0, $20, $e0, $28, $e0, $28
	db $e0, $7c, $7c, $ee, $d6, $d6, $aa, $aa, $d6, $d6, $aa, $ee, $d6, $7c, $7c, $00
	db $00, $7c, $7c, $fe, $c6, $fe, $be, $fe, $fe, $fe, $fe, $fe, $fe, $7c, $7c, $00
	db $00, $7c, $7c, $fe, $c6, $fe, $82, $fe, $82, $fe, $82, $fe, $c6, $7c, $7c, $00
	db $00, $0a, $f8, $0a, $f8, $0a, $f8, $0a, $f8, $0a, $f8, $12, $f0, $24, $e0, $24
	db $e0, $15, $1c, $15, $1c, $15, $1c, $19, $18, $02, $00, $00, $00, $00, $00, $00
	db $00, $08, $08, $08, $08, $0a, $08, $0a, $08, $0a, $08, $0a, $08, $1a, $18, $1a
	db $18, $22, $23, $11, $01, $01, $01, $01, $01, $22, $23, $3c, $3f, $20, $3f, $20
	db $3f, $14, $f0, $14, $f0, $14, $f0, $14, $f0, $14, $f0, $14, $f0, $10, $f0, $14
	db $f0, $61, $61, $61, $61, $52, $73, $52, $73, $4c, $7f, $40, $7f, $40, $7f, $40
	db $7f, $a2, $83, $a2, $83, $a2, $83, $a2, $83, $a2, $83, $a2, $83, $82, $83, $a2
	db $83, $24, $e0, $28, $e0, $28, $e0, $48, $c0, $50, $c0, $50, $c0, $81, $81, $a1
	db $81, $0c, $00, $00, $00, $00, $00, $00, $00, $fc, $fc, $84, $fc, $02, $fe, $02
	db $fe, $11, $1f, $11, $1f, $11, $1f, $09, $0f, $09, $0f, $09, $0f, $05, $07, $85
	db $07, $41, $00, $40, $00, $40, $00, $40, $00, $47, $07, $44, $07, $04, $07, $44
	db $07, $82, $03, $04, $07, $04, $07, $02, $03, $02, $03, $81, $81, $81, $81, $40
	db $c0, $28, $e0, $28, $e0, $28, $e0, $28, $e0, $28, $e0, $28, $e0, $20, $e0, $d0
	db $c0, $00, $54, $00, $82, $00, $00, $00, $82, $00, $00, $00, $82, $00, $54, $00
	db $00, $54, $54, $82, $82, $00, $00, $82, $82, $00, $00, $82, $82, $54, $54, $00
	db $00, $54, $00, $82, $00, $00, $00, $82, $00, $00, $00, $82, $00, $54, $00, $00
	db $00, $20, $e0, $20, $e0, $20, $e0, $20, $e0, $10, $f0, $0f, $ff, $00, $ff, $00
	db $ff, $00, $00, $00, $00, $00, $00, $01, $01, $0e, $0f, $f0, $ff, $00, $ff, $00
	db $ff, $2a, $38, $2a, $38, $48, $78, $88, $f8, $04, $fc, $03, $ff, $00, $ff, $00
	db $ff, $20, $3f, $26, $3f, $2d, $39, $29, $39, $46, $7f, $80, $ff, $00, $ff, $00
	db $ff, $28, $e0, $48, $c0, $40, $c0, $40, $c0, $20, $e0, $1f, $ff, $00, $ff, $00
	db $ff, $21, $3f, $12, $1e, $12, $1e, $12, $1e, $21, $3f, $c0, $ff, $00, $ff, $00
	db $ff, $41, $01, $40, $00, $00, $00, $00, $00, $00, $00, $ff, $ff, $00, $ff, $00
	db $ff, $40, $00, $40, $00, $00, $00, $00, $00, $00, $00, $ff, $ff, $00, $ff, $00
	db $ff, $85, $fc, $49, $78, $48, $78, $48, $78, $84, $fc, $03, $ff, $00, $ff, $00
	db $ff, $02, $02, $00, $00, $00, $00, $00, $00, $00, $00, $ff, $ff, $00, $ff, $00
	db $ff, $82, $03, $81, $01, $01, $01, $01, $01, $02, $03, $fc, $ff, $00, $ff, $00
	db $ff, $40, $c0, $20, $e0, $20, $e0, $10, $f0, $10, $f0, $0f, $ff, $00, $ff, $00
	db $ff, $a0, $80, $20, $00, $00, $00, $00, $00, $00, $00, $ff, $ff, $00, $ff, $00
	db $ff

;@ asset: tiles bpp=2 length=$60
;@ Six tiles: two frames of the three bottle viruses. VBlankDraw copies one of
;@ them to $8E00-$8E2F (tiles $E0-$E2) on three frames out of eight, so the viruses wiggle.
VirusAnimTiles::
	db $00, $00, $28, $28, $7c, $7c, $fe, $d6, $fe, $aa, $fe, $d6, $7c, $7c, $00
	db $00, $44, $44, $7c, $7c, $fe, $fe, $fe, $fe, $fe, $74, $fe, $8a, $7c, $7c, $00
	db $00, $54, $54, $7c, $6c, $fe, $82, $fe, $82, $fe, $82, $fe, $82, $54, $54, $00
	db $00, $ee, $ee, $7c, $7c, $fe, $d6, $fe, $aa, $fe, $d6, $fe, $aa, $7c, $7c, $00
	db $00, $28, $28, $7c, $7c, $fe, $fe, $fe, $fe, $fe, $fe, $7c, $7c, $00, $00, $00
	db $00, $00, $00, $92, $92, $7c, $6c, $7c, $44, $7c, $44, $7c, $44, $28, $28, $00
	db $00, $00, $ff, $00, $ff, $00, $ff, $80, $ff, $41, $7f, $22, $3e, $24, $3c, $29
	db $38, $00, $ff, $00, $ff, $00, $ff, $7e, $ff, $81, $81, $00, $00, $00, $00, $00
	db $00, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $80, $ff, $40, $7f, $20, $3f, $10
	db $1f, $a0, $e0, $a0, $e0, $a0, $e0, $a0, $e0, $a0, $e0, $a0, $e0, $50, $70, $50
	db $70, $42, $7e, $42, $7e, $42, $7e, $24, $3c, $24, $3c, $19, $18, $02, $00, $00
	db $00, $04, $07, $04, $07, $84, $07, $84, $07, $04, $07, $04, $07, $08, $0f, $08
	db $0f, $00, $ff, $00, $ff, $00, $02, $dc, $de, $10, $de, $10, $de, $10, $de, $10
	db $de, $00, $ff, $00, $ff, $00, $73, $88, $ab, $d8, $db, $a8, $fb, $88, $fb, $88
	db $fb, $ff, $f8, $ff, $f0, $ff, $e0, $ff, $c1, $ff, $83, $ff, $07, $ff, $0f, $ff
	db $1f, $ff, $1f, $ff, $0f, $ff, $07, $ff, $83, $ff, $c1, $ff, $e0, $ff, $f0, $ff
	db $f8, $00, $82, $00, $54, $00, $38, $00, $7c, $00, $38, $00, $54, $00, $82, $00
	db $00, $82, $82, $54, $54, $38, $38, $7c, $7c, $38, $38, $54, $54, $82, $82, $00
	db $00, $82, $00, $54, $00, $38, $00, $7c, $00, $38, $00, $54, $00, $82, $00, $00
	db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
	db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
	db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
	db $00, $2a, $38, $52, $70, $94, $f0, $a4, $e0, $a8, $e0, $a8, $e0, $a0, $e0, $a0
	db $e0, $00, $00, $00, $00, $00, $00, $00, $00, $18, $18, $24, $3c, $24, $3c, $42
	db $7e, $10, $1f, $08, $0f, $08, $0f, $04, $07, $04, $07, $04, $07, $04, $07, $04
	db $07, $28, $38, $28, $38, $24, $3c, $22, $3e, $41, $7f, $80, $ff, $00, $ff, $00
	db $ff, $00, $00, $00, $00, $00, $00, $00, $00, $81, $81, $7e, $ff, $00, $ff, $00
	db $ff, $10, $1f, $10, $1f, $20, $3f, $40, $7f, $80, $ff, $00, $ff, $00, $ff, $00
	db $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
	db $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00
	db $ff, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff
	db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
	db $00, $ff, $00, $ff, $3c, $ff, $66, $ff, $66, $ff, $66, $ff, $66, $ff, $3c, $ff
	db $00, $ff, $00, $ff, $18, $ff, $38, $ff, $18, $ff, $18, $ff, $18, $ff, $3c, $ff
	db $00, $ff, $00, $ff, $3c, $ff, $4e, $ff, $0e, $ff, $3c, $ff, $70, $ff, $7e, $ff
	db $00, $ff, $00, $ff, $7c, $ff, $0e, $ff, $3c, $ff, $0e, $ff, $0e, $ff, $7c, $ff
	db $00, $ff, $00, $ff, $3c, $ff, $6c, $ff, $4c, $ff, $4e, $ff, $7e, $ff, $0c, $ff
	db $00, $ff, $00, $ff, $7c, $ff, $60, $ff, $7c, $ff, $0e, $ff, $4e, $ff, $3c, $ff
	db $00, $ff, $00, $ff, $3c, $ff, $60, $ff, $7c, $ff, $66, $ff, $66, $ff, $3c, $ff
	db $00, $ff, $00, $ff, $7e, $ff, $06, $ff, $0c, $ff, $18, $ff, $38, $ff, $38, $ff
	db $00, $ff, $00, $ff, $3c, $ff, $4e, $ff, $3c, $ff, $4e, $ff, $4e, $ff, $3c, $ff
	db $00, $ff, $00, $ff, $3c, $ff, $4e, $ff, $4e, $ff, $3e, $ff, $0e, $ff, $3c, $ff
	db $00, $ff, $00, $ff, $3c, $ff, $4e, $ff, $4e, $ff, $7e, $ff, $4e, $ff, $4e, $ff
	db $00, $ff, $00, $ff, $7c, $ff, $66, $ff, $7c, $ff, $66, $ff, $66, $ff, $7c, $ff
	db $00, $ff, $00, $ff, $3c, $ff, $66, $ff, $60, $ff, $60, $ff, $66, $ff, $3c, $ff
	db $00, $ff, $00, $ff, $7c, $ff, $4e, $ff, $4e, $ff, $4e, $ff, $4e, $ff, $7c, $ff
	db $00, $ff, $00, $ff, $7e, $ff, $60, $ff, $7c, $ff, $60, $ff, $60, $ff, $7e, $ff
	db $00, $ff, $00, $ff, $7e, $ff, $60, $ff, $60, $ff, $7c, $ff, $60, $ff, $60, $ff
	db $00, $ff, $00, $ff, $3c, $ff, $66, $ff, $60, $ff, $6e, $ff, $66, $ff, $3e, $ff
	db $00, $ff, $00, $ff, $46, $ff, $46, $ff, $7e, $ff, $46, $ff, $46, $ff, $46, $ff
	db $00, $ff, $00, $ff, $3c, $ff, $18, $ff, $18, $ff, $18, $ff, $18, $ff, $3c, $ff
	db $00, $ff, $00, $ff, $07, $ff, $06, $ff, $06, $ff, $07, $ff, $06, $ff, $06, $ff
	db $00, $ff, $00, $ff, $c3, $ff, $64, $ff, $64, $ff, $c7, $ff, $04, $ff, $04, $ff
	db $00, $ff, $00, $ff, $60, $ff, $60, $ff, $60, $ff, $60, $ff, $60, $ff, $7e, $ff
	db $00, $ff, $00, $ff, $46, $ff, $6e, $ff, $7e, $ff, $56, $ff, $46, $ff, $46, $ff
	db $00, $ff, $00, $ff, $46, $ff, $66, $ff, $76, $ff, $5e, $ff, $4e, $ff, $46, $ff
	db $00, $ff, $00, $ff, $3c, $ff, $66, $ff, $66, $ff, $66, $ff, $66, $ff, $3c, $ff
	db $00, $ff, $00, $ff, $7c, $ff, $66, $ff, $66, $ff, $7c, $ff, $60, $ff, $60, $ff
	db $00, $ff, $00, $ff, $c4, $ff, $e4, $ff, $e4, $ff, $e4, $ff, $e4, $ff, $e3, $ff
	db $00, $ff, $00, $ff, $7c, $ff, $66, $ff, $66, $ff, $7c, $ff, $68, $ff, $66, $ff
	db $00, $ff, $00, $ff, $3c, $ff, $60, $ff, $3c, $ff, $0e, $ff, $4e, $ff, $3c, $ff
	db $00, $ff, $00, $ff, $7e, $ff, $18, $ff, $18, $ff, $18, $ff, $18, $ff, $18, $ff
	db $00, $ff, $00, $ff, $46, $ff, $46, $ff, $46, $ff, $46, $ff, $4e, $ff, $3c, $ff
	db $00, $ff, $00, $ff, $46, $ff, $46, $ff, $46, $ff, $46, $ff, $2c, $ff, $18, $ff
	db $00, $ff, $00, $ff, $46, $ff, $46, $ff, $56, $ff, $7e, $ff, $6e, $ff, $46, $ff
	db $00, $ff, $00, $ff, $63, $ff, $66, $ff, $63, $ff, $60, $ff, $e4, $ff, $c3, $ff
	db $00, $ff, $00, $ff, $66, $ff, $66, $ff, $3c, $ff, $18, $ff, $18, $ff, $18, $ff
	db $00, $ff, $00, $ff, $c7, $ff, $06, $ff, $c7, $ff, $e6, $ff, $e6, $ff, $c7, $ff
	db $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $30, $ff, $30, $ff
	db $00, $ff, $00, $ff, $06, $ff, $0e, $ff, $1c, $ff, $18, $ff, $60, $ff, $60, $ff
	db $00, $ff, $00, $ff, $00, $ff, $00, $ff, $3c, $ff, $3c, $ff, $00, $ff, $00, $ff
	db $00, $00, $00, $00, $fe, $00, $7c, $00, $7c, $00, $38, $00, $38, $00, $10, $00
	db $10, $ff, $00, $ff, $e6, $ff, $d6, $ff, $d6, $ff, $ce, $ff, $ce, $ff, $c6, $ff
	db $00, $ff, $00, $ff, $c0, $ff, $db, $ff, $1d, $ff, $d9, $ff, $d9, $ff, $d9, $ff
	db $00, $ff, $00, $ff, $30, $ff, $7b, $ff, $b6, $ff, $b7, $ff, $b6, $ff, $b3, $ff
	db $00, $ff, $00, $ff, $00, $ff, $cd, $ff, $6e, $ff, $ec, $ff, $0c, $ff, $ec, $ff
	db $00, $ff, $00, $ff, $01, $ff, $8f, $ff, $d9, $ff, $d9, $ff, $d9, $ff, $cf, $ff
	db $00, $ff, $00, $ff, $80, $ff, $9e, $ff, $b3, $ff, $b3, $ff, $b3, $ff, $9e, $ff
	db $00, $ff, $00, $ff, $38, $ff, $44, $ff, $ba, $ff, $a2, $ff, $ba, $ff, $44, $ff
	db $38, $ff, $00, $ff, $00, $ff, $60, $ff, $78, $ff, $60, $ff, $60, $ff, $64, $ff
	db $00, $00, $0f, $07, $0f, $18, $1f, $20, $38, $47, $e0, $4e, $e0, $9c, $c1, $99
	db $c3, $00, $0f, $ff, $ff, $00, $ff, $00, $00, $ff, $00, $00, $00, $00, $ff, $ff
	db $ff, $00, $0f, $c0, $cf, $30, $ff, $08, $3f, $c4, $0c, $e4, $0c, $72, $06, $32
	db $86, $92, $c6, $92, $c6, $92, $c6, $92, $c6, $92, $c6, $92, $c6, $92, $c6, $92
	db $c6, $92, $c7, $92, $c7, $92, $c7, $92, $c7, $92, $c6, $92, $c6, $92, $c6, $92
	db $c6, $99, $c3, $9c, $c1, $4e, $60, $47, $60, $20, $f8, $18, $ff, $07, $f7, $00
	db $f0, $ff, $ff, $00, $ff, $00, $00, $ff, $00, $00, $00, $00, $ff, $ff, $ff, $00
	db $f0, $32, $87, $72, $07, $e6, $0f, $c4, $0f, $08, $38, $30, $f0, $c0, $f0, $00
	db $f0, $01, $0f, $02, $0f, $04, $0e, $04, $0e, $04, $f6, $02, $f3, $01, $f1, $00
	db $f0, $c0, $c0, $30, $ff, $0f, $78, $c4, $1c, $64, $0f, $32, $86, $92, $c6, $92
	db $c6, $92, $c6, $92, $c6, $92, $c6, $32, $87, $e3, $06, $04, $0c, $08, $ff, $f0
	db $f0, $49, $63, $49, $63, $49, $63, $4c, $e1, $c7, $60, $20, $30, $10, $ff, $0f
	db $0f, $03, $03, $0c, $ff, $f0, $1e, $23, $38, $26, $f0, $4c, $61, $49, $63, $49
	db $63, $80, $8f, $40, $cf, $20, $6f, $20, $6f, $20, $70, $60, $f0, $c0, $f0, $00
	db $f0, $ff, $c3, $ff, $81, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff
	db $ff, $00, $0f, $00, $0f, $00, $0f, $00, $0f, $00, $f0, $00, $f0, $00, $f0, $00
	db $f0, $00, $0f, $7f, $7f, $40, $55, $40, $6a, $40, $d7, $43, $ec, $43, $d4, $43
	db $ec, $00, $0f, $ff, $ff, $00, $55, $00, $aa, $00, $ff, $ff, $00, $ff, $00, $ff
	db $00, $00, $0f, $fe, $ff, $02, $57, $02, $ab, $02, $f6, $c2, $2a, $c2, $36, $c2
	db $2a, $c3, $d4, $c3, $ec, $c3, $d4, $c3, $ec, $43, $d4, $43, $ec, $43, $d4, $43
	db $ec, $c2, $37, $c2, $2b, $c2, $37, $c2, $2b, $c2, $36, $c2, $2a, $c2, $36, $c2
	db $2a, $40, $57, $40, $6a, $40, $55, $7f, $7f, $40, $c0, $7f, $ff, $00, $f0, $00
	db $f0, $00, $ff, $00, $aa, $00, $55, $ff, $ff, $00, $00, $ff, $ff, $00, $f0, $00
	db $f0, $02, $f7, $02, $ab, $02, $57, $fe, $ff, $02, $02, $fe, $fe, $00, $f0, $00
	db $f0, $00, $0f, $00, $0f, $1f, $00, $7f, $00, $7f, $80, $ff, $00, $ff, $00, $ff
	db $00, $00, $0f, $00, $0f, $f8, $07, $fe, $01, $fe, $00, $ff, $00, $ff, $00, $ff
	db $00, $ff, $00, $ff, $00, $ff, $00, $7f, $00, $7f, $80, $1f, $e0, $00, $f0, $00
	db $f0, $ff, $00, $ff, $00, $ff, $00, $fe, $01, $fe, $00, $f8, $00, $00, $f0, $00
	db $f0, $00, $0f, $00, $0f, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff
	db $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $00, $f0, $00
	db $f0, $00, $00, $00, $00, $00, $00, $00, $ff, $ff, $00, $00, $00, $00, $ff, $00
	db $00, $00, $00, $00, $ff, $ff, $00, $00, $00, $00, $ff, $00, $00, $00, $00, $00
	db $00, $00, $0f, $00, $0f, $00, $0f, $00, $0f, $00, $f0, $03, $f3, $0c, $fc, $1d
	db $f5, $00, $0f, $00, $0f, $00, $0f, $00, $0f, $0f, $ff, $ff, $ff, $00, $00, $00
	db $00, $00, $0f, $00, $0f, $00, $0f, $00, $0f, $00, $f0, $e0, $f0, $30, $30, $b8
	db $a8, $14, $14, $f7, $f7, $14, $55, $17, $b7, $16, $f6, $f3, $12, $fe, $0e, $ff
	db $03, $00, $00, $ff, $ff, $00, $55, $ff, $ff, $00, $00, $ff, $00, $00, $00, $ff
	db $ff, $28, $2f, $ef, $ef, $28, $6a, $e8, $ed, $68, $6f, $cf, $48, $7f, $70, $ff
	db $c0, $00, $0f, $00, $0f, $0f, $0f, $10, $1f, $27, $f8, $2c, $f3, $28, $f7, $29
	db $f7, $00, $0f, $00, $0f, $ff, $ff, $00, $ff, $ff, $00, $00, $ff, $00, $ff, $ff
	db $ff, $00, $0f, $00, $0f, $f0, $ff, $08, $ff, $e4, $1c, $34, $cc, $14, $ec, $94
	db $ec, $29, $37, $29, $37, $29, $37, $29, $37, $29, $f7, $29, $f7, $29, $f7, $29
	db $f7, $94, $ef, $94, $ef, $94, $ef, $94, $ef, $94, $ec, $94, $ec, $94, $ec, $94
	db $ec, $29, $37, $28, $37, $2c, $33, $27, $38, $10, $ff, $0f, $ff, $00, $f0, $00
	db $f0, $ff, $ff, $00, $ff, $00, $ff, $ff, $00, $00, $ff, $ff, $ff, $00, $f0, $00
	db $f0, $94, $ef, $14, $ef, $34, $cf, $e4, $1f, $08, $f8, $f0, $f0, $00, $f0, $00
	db $f0, $ff, $00, $ff, $e0, $ff, $00, $ff, $c0, $ff, $00, $ff, $00, $ff, $e0, $ff
	db $00, $e7, $34, $e7, $2c, $e7, $34, $e7, $2c, $e7, $34, $e7, $2c, $e7, $34, $e7
	db $2c, $01, $0f, $02, $0e, $02, $0e, $02, $0e, $01, $f1, $1f, $ff, $60, $e0, $5f
	db $c0, $ff, $ff, $00, $00, $ff, $00, $ff, $00, $7e, $00, $7e, $00, $ff, $00, $ff
	db $00, $80, $8f, $40, $4f, $40, $4f, $40, $4f, $80, $f0, $f8, $f8, $06, $06, $fa
	db $02, $bf, $80, $bf, $80, $bf, $80, $5f, $40, $60, $e0, $1f, $ff, $00, $f0, $00
	db $f0, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $00, $00, $ff, $ff, $00, $f0, $00
	db $f0, $fd, $01, $fd, $01, $fd, $01, $fa, $03, $06, $06, $f8, $f8, $00, $f0, $00
	db $f0, $00, $0f, $00, $0f, $3c, $03, $7e, $01, $ff, $00, $ff, $00, $ff, $00, $ff
	db $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $7e, $80, $3c, $c0, $00, $f0, $00
	db $f0, $00, $0f, $00, $0f, $ff, $ff, $00, $ff, $ff, $00, $00, $ff, $00, $ff, $d3
	db $e7, $d3, $e7, $00, $ff, $00, $ff, $ff, $00, $00, $ff, $ff, $ff, $00, $f0, $00
	db $f0, $db, $24, $db, $24, $db, $24, $db, $24, $db, $24, $db, $24, $db, $24, $db
	db $24, $ff, $00, $ff, $00, $00, $ff, $ff, $00, $00, $ff, $ff, $00, $ff, $00, $ff
	db $00, $db, $24, $db, $24, $18, $e7, $ff, $00, $00, $ff, $ff, $00, $ff, $00, $ff
	db $00, $29, $37, $29, $37, $28, $37, $29, $36, $28, $f7, $28, $f7, $29, $f7, $29
	db $f7, $94, $ef, $94, $ef, $14, $ef, $94, $6f, $14, $ec, $14, $ec, $94, $ec, $94
	db $ec, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
	db $00, $bf, $80, $bf, $80, $bf, $80, $bf, $80, $bf, $80, $bf, $80, $bf, $80, $bf
	db $80, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff
	db $00, $fd, $01, $fd, $01, $fd, $01, $fd, $01, $fd, $01, $fd, $01, $fd, $01, $fd
	db $01, $bf, $80, $bf, $80, $bf, $80, $bf, $80, $bf, $80, $bf, $80, $bf, $80, $bf
	db $80, $fd, $01, $fd, $01, $fd, $01, $fd, $01, $fd, $01, $fd, $01, $fd, $01, $fd
	db $01, $ff, $00, $ff, $00, $ff, $00, $ff, $01, $ff, $01, $ff, $01, $ff, $01, $ff
	db $01, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $11, $ff, $11, $ff
	db $ff, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $10, $ff, $11, $ff, $11, $ff
	db $ff, $ff, $00, $ff, $00, $ff, $00, $ff, $01, $ff, $01, $ff, $11, $ff, $11, $ff
	db $ff, $ff, $01, $ff, $01, $ff, $01, $ff, $01, $ff, $01, $ff, $00, $ff, $00, $ff
	db $00, $ff, $ff, $ff, $11, $ff, $11, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff
	db $00, $ff, $ff, $ff, $11, $ff, $11, $ff, $10, $ff, $10, $ff, $00, $ff, $00, $ff
	db $00, $ff, $ff, $ff, $11, $ff, $11, $ff, $01, $ff, $01, $ff, $00, $ff, $00, $ff
	db $00, $00, $0f, $00, $0f, $00, $0f, $c3, $0c, $c3, $30, $e7, $10, $e7, $10, $e7
	db $10, $e7, $08, $e7, $08, $e7, $08, $e7, $08, $e7, $10, $e7, $10, $e7, $10, $e7
	db $10, $e7, $08, $e7, $08, $e7, $08, $c3, $0c, $c3, $30, $00, $f0, $00, $f0, $00
	db $f0

;@ asset: tiles bpp=2 length=$520
;@ Tiles copied over $8800 by LoadUnderwaterScreen.
Tiles_559E::
	db $ff, $00, $ff, $00, $ff, $00, $e7, $00, $81, $00, $00, $00, $00, $00, $00
	db $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $e7, $00, $00, $00, $00, $00, $00
	db $00, $a9, $08, $5a, $08, $b3, $18, $52, $18, $c9, $08, $a6, $00, $75, $00, $9b
	db $00, $00, $c0, $04, $e0, $00, $70, $05, $70, $d0, $d8, $e8, $e0, $02, $00, $90
	db $00, $08, $08, $28, $0c, $89, $18, $2c, $08, $1a, $c0, $08, $70, $05, $f8, $00
	db $14, $c8, $38, $30, $f0, $f8, $f8, $fc, $34, $fc, $54, $f8, $38, $f0, $f0, $00
	db $00, $4a, $00, $25, $00, $ba, $00, $ed, $00, $78, $03, $d0, $07, $20, $0f, $90
	db $09, $52, $00, $2d, $00, $da, $00, $a5, $00, $19, $e0, $0e, $70, $03, $f8, $02
	db $14, $40, $39, $40, $7b, $40, $7f, $80, $fc, $80, $fd, $70, $7f, $bf, $1f, $0d
	db $00, $00, $fc, $03, $be, $02, $9e, $07, $b7, $de, $de, $ff, $ff, $fc, $bc, $14
	db $00, $a4, $00, $52, $00, $25, $00, $da, $00, $57, $00, $ad, $00, $d2, $00, $6d
	db $00, $b7, $00, $6a, $00, $b5, $00, $5a, $00, $e5, $00, $5b, $00, $ef, $00, $7a
	db $00, $d7, $00, $7f, $00, $fd, $00, $bf, $00, $f7, $00, $bd, $00, $ff, $00, $ff
	db $00, $08, $08, $10, $18, $10, $18, $10, $18, $10, $18, $08, $08, $04, $0c, $04
	db $0c, $04, $0c, $04, $0c, $08, $18, $10, $30, $10, $30, $10, $30, $10, $10, $08
	db $18, $00, $08, $00, $08, $00, $04, $00, $04, $00, $04, $00, $04, $00, $08, $00
	db $08, $00, $00, $00, $00, $18, $18, $3c, $24, $3c, $24, $18, $18, $00, $00, $00
	db $00, $60, $20, $c0, $40, $d0, $40, $d8, $48, $f8, $58, $be, $78, $46, $32, $30
	db $11, $1f, $1f, $6d, $6f, $b9, $bf, $b2, $bf, $5c, $5f, $57, $57, $00, $00, $00
	db $00, $1f, $1f, $0d, $0f, $39, $3f, $52, $5f, $5c, $5f, $27, $27, $28, $28, $08
	db $08, $00, $00, $07, $07, $1f, $18, $3f, $20, $7f, $43, $7d, $46, $fb, $8c, $fb
	db $8d, $00, $00, $e0, $e0, $f0, $10, $f8, $08, $fc, $84, $fc, $44, $f4, $4c, $f4
	db $8c, $fb, $8c, $fc, $87, $bf, $c3, $7f, $41, $5f, $61, $27, $39, $18, $1f, $07
	db $07, $c8, $38, $3f, $ff, $ff, $f8, $ff, $33, $ff, $50, $ff, $31, $fe, $fe, $00
	db $00, $00, $00, $1f, $1f, $3c, $23, $5c, $6b, $5c, $62, $80, $ff, $60, $5f, $f8
	db $87, $30, $30, $70, $50, $e0, $e0, $36, $f6, $09, $7f, $01, $ad, $01, $ff, $71
	db $8d, $77, $48, $67, $58, $77, $48, $3f, $20, $3f, $20, $1f, $10, $0f, $0c, $03
	db $03, $fe, $06, $f8, $08, $b8, $48, $f8, $08, $f0, $10, $fc, $1c, $e4, $64, $98
	db $98, $73, $4c, $79, $46, $7f, $40, $3f, $20, $3f, $20, $1f, $10, $0f, $0c, $03
	db $03, $00, $00, $1f, $03, $7f, $6a, $1e, $63, $00, $1f, $00, $00, $00, $00, $00
	db $00, $f0, $10, $fc, $3c, $ff, $ff, $03, $ff, $00, $ff, $28, $00, $10, $00, $00
	db $00, $00, $00, $4c, $0c, $d8, $d8, $f0, $f0, $18, $f8, $8c, $0c, $00, $00, $00
	db $00, $00, $00, $00, $00, $00, $00, $00, $00, $06, $06, $1f, $19, $7e, $62, $fc
	db $8c, $00, $00, $fc, $fc, $ff, $7f, $e3, $3f, $f0, $1f, $f8, $88, $7c, $64, $1c
	db $1c, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $07, $07, $1f, $18, $3f
	db $20, $00, $00, $00, $00, $00, $00, $00, $00, $ff, $ff, $ff, $13, $ff, $08, $ff
	db $c4, $00, $00, $00, $00, $00, $00, $03, $03, $fc, $ff, $31, $ce, $c4, $fb, $c9
	db $76, $0f, $0f, $3e, $32, $7e, $4e, $ff, $93, $7f, $c4, $3f, $fb, $0e, $ff, $a0
	db $df, $00, $00, $00, $00, $01, $01, $02, $03, $82, $83, $e5, $e7, $38, $ff, $ba
	db $fd, $3c, $3c, $fe, $c2, $fc, $04, $f8, $18, $f8, $88, $f0, $f0, $8e, $8e, $f1
	db $ff, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $f0, $c0, $f8, $00, $fc
	db $94, $0f, $08, $07, $04, $03, $03, $00, $00, $00, $00, $00, $00, $00, $00, $00
	db $00, $ff, $c9, $ff, $09, $ff, $13, $ff, $e7, $7f, $7f, $03, $03, $00, $00, $00
	db $00, $1d, $ff, $8c, $ff, $df, $f7, $7f, $f0, $ff, $c1, $ff, $e0, $1f, $18, $0f
	db $0f, $89, $ff, $52, $ff, $c3, $ff, $bd, $ff, $ff, $ff, $ef, $ff, $ff, $71, $cf
	db $cf, $4c, $ff, $52, $ff, $3a, $ff, $fc, $ff, $fc, $ff, $f2, $f3, $01, $01, $00
	db $00, $30, $ff, $fb, $ff, $7f, $fe, $43, $c3, $70, $b0, $fc, $cc, $fe, $82, $7e
	db $7e, $7e, $c0, $fc, $80, $f8, $10, $f0, $00, $c0, $c0, $00, $00, $00, $00, $00
	db $00, $3f, $21, $3f, $31, $0f, $08, $0f, $0c, $03, $02, $03, $03, $03, $03, $07
	db $05, $0f, $09, $1f, $12, $3f, $24, $3f, $38, $07, $07, $00, $00, $00, $00, $00
	db $00, $3f, $21, $3f, $31, $3f, $28, $3f, $2c, $3f, $26, $1f, $13, $1f, $19, $0f
	db $0f, $ff, $64, $ff, $e5, $ff, $c4, $ff, $0c, $ff, $1f, $ff, $18, $ff, $10, $ff
	db $e1, $e2, $3f, $e4, $3f, $e2, $bd, $e0, $bf, $e0, $3f, $e0, $7f, $d8, $ff, $9a
	db $ff, $4d, $fb, $40, $bf, $08, $f7, $42, $ff, $00, $ff, $04, $ff, $50, $ff, $02
	db $ff, $48, $bf, $01, $ff, $aa, $77, $02, $ff, $20, $df, $00, $ff, $84, $ff, $10
	db $ff, $d4, $eb, $64, $ff, $32, $fd, $1f, $ff, $88, $f7, $a1, $ff, $0f, $ff, $de
	db $ff, $7c, $e0, $3e, $e6, $1e, $f8, $ff, $e0, $3f, $f0, $bf, $f0, $ff, $f1, $3e
	db $ee, $3c, $3c, $fe, $c2, $fc, $04, $f8, $18, $f8, $88, $f0, $f0, $83, $83, $ff
	db $fe, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $c0
	db $00, $e4, $df, $64, $ff, $36, $fb, $1f, $ff, $90, $ef, $a1, $ff, $0f, $ff, $d5
	db $ff, $e0, $40, $f0, $80, $f0, $80, $f0, $e0, $f0, $90, $f0, $c0, $f0, $c0, $f0
	db $90, $3b, $ff, $ff, $fe, $7f, $fc, $4f, $ce, $74, $b4, $fc, $cc, $fe, $82, $7e
	db $7e, $f0, $e0, $e0, $00, $e0, $80, $80, $00, $00, $00, $00, $00, $00, $00, $00
	db $00, $ff, $ff, $3f, $3f, $3f, $28, $1f, $14, $0f, $0e, $03, $03, $00, $00, $00
	db $00, $00, $00, $28, $28, $7c, $7c, $fe, $d6, $fe, $aa, $fe, $d6, $7c, $7c, $00
	db $00, $28, $28, $7c, $7c, $fe, $fe, $fe, $fe, $fe, $fe, $fe, $fe, $7c, $7c, $00
	db $00, $92, $92, $7c, $6c, $fe, $82, $fe, $c6, $fe, $82, $fe, $82, $7c, $7c, $00
	db $00, $ee, $ee, $7c, $7c, $fe, $fe, $fe, $d6, $fe, $aa, $fe, $d6, $7c, $7c, $00
	db $00, $00, $00, $28, $28, $7c, $7c, $fe, $fe, $fe, $fe, $fe, $fe, $7c, $7c, $00
	db $00, $00, $00, $92, $92, $7c, $6c, $7c, $44, $fe, $82, $fe, $82, $7c, $7c, $00
	db $00, $00, $00, $20, $00, $78, $29, $ff, $df, $78, $79, $00, $10, $00, $00, $00
	db $00, $00, $00, $20, $00, $78, $2a, $fe, $de, $78, $7a, $00, $10, $00, $00, $00
	db $00, $04, $04, $38, $08, $30, $20, $3a, $08, $fe, $fc, $3a, $38, $10, $10, $08
	db $08, $04, $04, $38, $08, $30, $20, $3c, $08, $fc, $f8, $3c, $38, $10, $10, $08
	db $08, $00, $00, $03, $03, $0c, $0f, $10, $1f, $29, $36, $20, $3f, $ff, $ff, $ff
	db $aa, $00, $00, $03, $03, $0c, $0f, $10, $1f, $29, $36, $20, $3f, $ff, $ff, $ff
	db $55, $08, $18, $04, $0c, $04, $0c, $04, $0c, $08, $18, $08, $38, $10, $30, $10
	db $30, $10, $30, $10, $10, $08, $18, $08, $18, $08, $18, $08, $18, $10, $10, $10
	db $10, $00, $04, $00, $04, $00, $08, $00, $08, $00, $08, $00, $08, $00, $04, $00
	db $04, $24, $08, $42, $10, $06, $10, $a9, $08, $08, $08, $66, $00, $98, $00, $a5
	db $00, $00, $00, $00, $38, $08, $34, $00, $0e, $00, $00, $00, $00, $00, $00, $00
	db $3c, $20, $50, $00, $60, $00, $00, $00, $02, $00, $0c, $08, $14, $00, $18, $00
	db $00

;@ asset: tilemap width=20 height=18 tiles=LoadGameTiles+CopyBytes(hl=$4D9E,de=$8000,bc=$300)
;@ The options screen (LoadOptionsScreen).
OptionsTilemap::
	db $3f, $56, $57, $57, $57, $57, $57, $57, $57, $57, $57, $57, $57, $57, $57
	db $57, $57, $57, $58, $3f, $3f, $59, $fe, $fe, $fe, $fe, $fe, $fe, $fe, $fe, $fe
	db $fe, $fe, $fe, $fe, $fe, $fe, $fe, $5a, $3f, $3f, $59, $fe, $fe, $fe, $fe, $19
	db $15, $0a, $22, $0e, $1b, $fe, $10, $0a, $16, $0e, $fe, $5a, $3f, $3f, $59, $fe
	db $83, $84, $84, $84, $84, $84, $84, $84, $84, $84, $84, $84, $85, $fe, $fe, $5a
	db $3f, $3f, $59, $fe, $86, $1f, $12, $1b, $1e, $1c, $fe, $15, $0e, $1f, $0e, $15
	db $87, $fe, $fe, $5a, $3f, $3f, $59, $fe, $88, $89, $89, $89, $89, $89, $89, $89
	db $89, $89, $89, $89, $8a, $fe, $fe, $5a, $3f, $3f, $59, $fe, $fe, $fe, $75, $76
	db $76, $77, $76, $78, $76, $76, $77, $76, $78, $fe, $fe, $5a, $3f, $3f, $59, $fe
	db $fe, $fe, $79, $7a, $7a, $7b, $7a, $7c, $7a, $7a, $7b, $7a, $7c, $fe, $fe, $5a
	db $3f, $3f, $59, $fe, $83, $84, $84, $84, $84, $84, $85, $fe, $fe, $fe, $fe, $fe
	db $fe, $fe, $fe, $5a, $3f, $3f, $59, $fe, $86, $1c, $19, $0e, $0e, $0d, $87, $fe
	db $fe, $fe, $fe, $fe, $fe, $fe, $fe, $5a, $3f, $3f, $59, $fe, $88, $89, $89, $89
	db $89, $89, $8a, $fe, $fe, $fe, $fe, $fe, $fe, $fe, $fe, $5a, $3f, $3f, $59, $fe
	db $fe, $fe, $fe, $15, $18, $20, $fe, $16, $0e, $0d, $fe, $11, $12, $fe, $fe, $5a
	db $3f, $3f, $59, $fe, $83, $84, $84, $84, $84, $84, $85, $fe, $fe, $fe, $fe, $fe
	db $fe, $fe, $fe, $5a, $3f, $3f, $59, $fe, $86, $16, $1e, $1c, $12, $0c, $87, $fe
	db $fe, $fe, $fe, $fe, $fe, $fe, $fe, $5a, $3f, $3f, $59, $fe, $88, $89, $89, $89
	db $89, $89, $8a, $fe, $fe, $fe, $fe, $fe, $fe, $fe, $fe, $5a, $3f, $3f, $59, $fe
	db $0f, $0e, $1f, $0e, $1b, $fe, $0c, $11, $12, $15, $15, $fe, $18, $0f, $0f, $5a
	db $3f, $3f, $59, $fe, $fe, $fe, $fe, $fe, $fe, $fe, $fe, $fe, $fe, $fe, $fe, $fe
	db $fe, $fe, $fe, $5a, $3f, $3f, $5b, $5c, $5c, $5c, $5c, $5c, $5c, $5c, $5c, $5c
	db $5c, $5c, $5c, $5c, $5c, $5c, $5c, $5d, $3f

;@ asset: tilemap width=20 height=18 tiles=LoadGameTiles
;@ The title screen (TitleInit).
TitleTilemap::
	db $3f, $3f, $3f, $3f, $3f, $3f, $3f
	db $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f
	db $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f
	db $3f, $3f, $56, $57, $57, $57, $57, $57, $57, $57, $57, $57, $57, $57, $57, $57
	db $57, $57, $57, $58, $3f, $3f, $59, $fd, $fd, $fd, $fd, $fd, $fd, $fd, $fd, $fd
	db $fd, $fd, $fd, $fd, $fd, $ec, $ed, $5a, $3f, $3f, $59, $a3, $a4, $a5, $a6, $a7
	db $a8, $a9, $aa, $ab, $ac, $ad, $ae, $af, $e6, $e7, $e8, $5a, $3f, $3f, $59, $b3
	db $b4, $b5, $b6, $b7, $b8, $b9, $ba, $bb, $bc, $bd, $be, $bf, $f6, $f7, $f8, $5a
	db $3f, $3f, $59, $c3, $c4, $c5, $c6, $c7, $c8, $c9, $ca, $cb, $cc, $cd, $ce, $cf
	db $e9, $ea, $eb, $5a, $3f, $3f, $59, $d3, $d4, $d5, $d6, $d7, $d8, $d9, $da, $db
	db $dc, $dd, $de, $df, $f9, $fa, $fb, $5a, $3f, $3f, $59, $fd, $fd, $fd, $fd, $fd
	db $fd, $fd, $fd, $fd, $fd, $fd, $fd, $fd, $fd, $fd, $fd, $5a, $3f, $3f, $5b, $5c
	db $5c, $5c, $5c, $5c, $5c, $5c, $5c, $5c, $5c, $5c, $5c, $5c, $5c, $5c, $5c, $5d
	db $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f
	db $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f
	db $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $fe, $01, $fe, $19
	db $15, $0a, $22, $0e, $1b, $fe, $10, $0a, $16, $0e, $3f, $3f, $3f, $3f, $3f, $3f
	db $fe, $02, $fe, $19, $15, $0a, $22, $0e, $1b, $fe, $10, $0a, $16, $0e, $3f, $3f
	db $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f
	db $3f, $3f, $3f, $3f, $3f, $3f, $3f, $fe, $2e, $fe, $01, $09, $09, $00, $fe, $fe
	db $28, $29, $2a, $2b, $2c, $2d, $fe, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f
	db $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f
	db $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f
	db $3f

;@ asset: tilemap width=20 height=5 tiles=LoadGameTiles
;@ Five more rows in the title map's format right after it: "2 PLAYER GAME" and
;@ "(c) 1990 Nintendo" again, then unused bytes. Nothing loads them.
TitleExtraRows::
	db $3f, $3f, $3f, $3f, $3f, $fe, $02, $fe, $19, $15, $0a, $22, $0e, $1b, $fe
	db $10, $0a, $16, $0e, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f
	db $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $fe, $2e, $fe
	db $01, $09, $09, $00, $fe, $fe, $28, $29, $2a, $2b, $2c, $2d, $fe, $3f, $3f, $3f
	db $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f
	db $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f
	db $3f, $3f, $3f, $3f, $3f, $3f, $3f, $00, $00, $00, $00, $00, $00, $00, $00, $00
	db $00, $00, $00

DemoInputs::
	db $00, $48, $20, $06, $00, $04, $20, $06, $00, $08, $02, $08, $00
	db $04, $02, $0a, $00, $1c, $20, $05, $00, $03, $20, $05, $00, $00, $02, $07, $00
	db $04, $02, $09, $00, $0f, $80, $05, $00, $14, $02, $05, $00, $05, $02, $06, $00
	db $00, $80, $0e, $00, $0a, $10, $06, $00, $42, $80, $05, $00, $1b, $10, $08, $00
	db $0f, $80, $10, $00, $54, $20, $06, $00, $02, $20, $06, $00, $20, $80, $08, $00
	db $3b, $20, $03, $22, $01, $02, $07, $00, $06, $20, $05, $00, $07, $80, $13, $00
	db $57, $10, $06, $00, $03, $10, $04, $00, $03, $10, $05, $00, $04, $02, $07, $00
	db $05, $02, $07, $00, $03, $80, $08, $00, $07, $02, $0a, $00, $03, $80, $0f, $00
	db $28, $02, $09, $10, $05, $00, $04, $10, $05, $00, $11, $80, $05, $00, $24, $10
	db $08, $00, $42, $02, $09, $00, $01, $10, $05, $00, $05, $10, $04, $00, $05, $10
	db $04, $00, $0f, $80, $08, $00, $0c, $10, $05, $00, $03, $10, $07, $00, $30, $20
	db $03, $00, $04, $20, $03, $00, $2c, $80, $0f, $00, $37, $20, $07, $00, $13, $80
	db $0e, $00, $16, $20, $05, $00, $2a, $80, $0a, $00, $40, $02, $05, $00, $11, $01
	db $08, $00, $01, $80, $0f, $00, $52, $20, $05, $00, $04, $20, $05, $00, $01, $20
	db $0d, $00, $01, $02, $08, $00, $04, $02, $08, $00, $03, $80, $08, $10, $07, $12
	db $08, $10, $15, $00, $08, $80, $0d, $00, $36, $02, $06, $00, $05, $02, $08, $00
	db $06, $80, $0b, $00, $1e, $20, $05, $00, $06, $20, $04, $00, $22, $02, $03, $12
	db $04, $10, $00, $00, $27, $02, $0a, $00, $2f, $20, $04, $00, $06, $02, $09, $00
	db $57, $01, $0c, $00, $41, $20, $05, $00, $06, $20, $08, $00, $02, $20, $07, $22
	db $01, $02, $05, $00, $03, $02, $09, $00, $15, $20, $00, $00, $0a, $20, $04, $00
	db $07, $20, $03, $00, $0f, $80, $0d, $00, $91, $80, $0c, $00, $31, $02, $08, $00
	db $00, $20, $04, $00, $06, $20, $05, $00, $07, $20, $04, $00, $0f, $80, $0e, $00
	db $07, $20, $04, $00, $0b, $02, $07, $00, $04, $02, $07, $80, $15, $00, $50, $02
	db $02, $12, $03, $02, $00, $fc, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
	db $00, $00, $00

;@ asset: tilemap width=8 height=16 tiles=LoadGameTiles
;@ The bottle the title demo starts with: 8 columns x 16 rows of cells, each
;@ a BG tile number ($FF = empty), copied into wBottle by LoadDemoBottle.
DemoBottle::
	db $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
	db $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
	db $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
	db $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $e1, $ff, $ff, $e1, $e1, $e0
	db $e0, $ff, $ff, $e1, $e0, $e0, $e2, $e1, $e0, $e2, $ff, $e0, $e0, $e2, $ff, $ff
	db $ff, $e0, $e2, $e2, $e2, $e1, $e0, $ff, $e1, $ff, $e2, $e1, $e1, $ff, $e2, $ff
	db $e0, $e2, $ff, $ff, $ff, $ff, $e1, $ff, $e2, $e1, $e0, $ff, $e2, $ff, $e1, $e1
	db $ff, $e0, $e0, $ff, $e1, $ff, $e0, $e1, $e1, $e2, $ff, $ff, $ff, $ff, $ff, $e0
	db $e2, $ff, $ff

SquareSFXStarts::
	db $01, $61, $2a, $61, $85, $60, $b8, $63, $44, $63, $f9, $62, $c1
	db $60, $37, $62, $71, $61, $9a, $60, $5f, $62, $86, $63, $11, $62, $db, $60

SquareSFXUpdates::
	db $11
	db $61, $3a, $61, $4e, $61, $4e, $61, $50, $63, $05, $63, $4e, $61, $85, $62, $80
	db $61, $a7, $60, $85, $62, $92, $63, $85, $62, $e3, $60

NoiseSFXStarts::
	db $fe, $63, $d7, $63, $c8
	db $63

NoiseSFXUpdates::
	db $06, $64, $df, $63, $b8, $66

SongTable::
	db $a8, $6c, $b3, $6c, $be, $6c, $c9, $6c, $d4
	db $6c, $df, $6c, $ea, $6c, $f5, $6c, $00, $6d, $0b, $6d, $fa, $e1, $df, $18, $06
	db $fa, $e1, $df, $fe, $0c, $c8, $fe, $08, $c8, $fe, $0a, $c8, $fe, $0b, $c8, $fe
	db $0d, $c8, $c9, $fa, $e1, $df, $fe, $04, $c8, $fa, $e1, $df, $fe, $05, $c8, $fe
	db $06, $c8, $c9, $48, $bc, $90, $27, $c7, $cd, $5d, $60, $c8, $cd, $70, $60, $c8
	db $3e, $02, $21, $80, $60, $c3, $7f, $64, $00, $2e, $e0, $f0, $c5, $21, $af, $df
	db $cb, $be, $3e, $08, $21, $95, $60, $c3, $7f, $64, $cd, $ed, $64, $a7, $c0, $21
	db $e4, $df, $34, $7e, $fe, $09, $ca, $53, $61, $21, $95, $60, $c3, $b8, $64, $00
	db $bd, $91, $89, $c7, $cd, $5d, $60, $c8, $cd, $76, $60, $c8, $3e, $01, $21, $bc
	db $60, $c3, $7f, $64, $3d, $80, $f0, $10, $c5, $3e, $80, $f0, $e0, $c5, $3e, $05
	db $21, $d1, $60, $c3, $7f, $64, $cd, $ed, $64, $a7, $c0, $21, $e4, $df, $34, $7e
	db $fe, $02, $28, $62, $21, $d6, $60, $c3, $b8, $64, $00, $f5, $d0, $70, $c7, $00
	db $f5, $20, $70, $c7, $cd, $5d, $60, $c8, $cd, $70, $60, $c8, $3e, $05, $21, $f7
	db $60, $c3, $7f, $64, $cd, $ed, $64, $a7, $c0, $21, $e4, $df, $34, $7e, $fe, $02
	db $28, $34, $21, $fc, $60, $c3, $b8, $64, $00, $b8, $80, $63, $c7, $cd, $5d, $60
	db $c8, $cd, $70, $60, $c8, $3e, $04, $21, $25, $61, $c3, $7f, $64, $cd, $ed, $64
	db $a7, $c0, $21, $e4, $df, $7e, $fe, $01, $28, $0c, $34, $21, $25, $61, $c3, $b8
	db $64, $cd, $ed, $64, $a7, $c0

StopSquareSFX::
	db $af, $ea, $e1, $df, $e0, $10, $3e, $08, $e0, $12
	db $3e, $80, $e0, $14, $21, $9f, $df, $cb, $be, $c9, $00, $80, $91, $ac, $87, $00
	db $80, $91, $9d, $87, $cd, $58, $60, $c8, $21, $af, $df, $cb, $be, $21, $67, $61
	db $c3, $7f, $64, $21, $e4, $df, $34, $7e, $fe, $04, $28, $11, $fe, $0b, $28, $13
	db $fe, $0f, $28, $09, $fe, $30, $ca, $97, $61, $c9, $c3, $53, $61, $21, $6c, $61
	db $c3, $b8, $64, $21, $67, $61, $c3, $b8, $64, $00, $b0, $f0, $ac, $c7, $ac, $ac
	db $00, $b6, $ac, $00, $a2, $00, $9d, $00, $00, $00, $83, $00, $00, $ff, $b0, $f0
	db $ad, $c7, $ad, $ad, $00, $b7, $ad, $00, $a3, $00, $9e, $00, $00, $00, $84, $00
	db $00, $ff, $00, $80, $f0, $97, $c7, $8a, $4f, $00, $a7, $00, $a7, $00, $ff, $80
	db $f0, $98, $c7, $8b, $50, $00, $73, $00, $73, $00, $ff, $00, $80, $f0, $9d, $c7
	db $80, $f0, $9e, $c7, $83, $9d, $83, $9d, $83, $9d, $83, $9d, $83, $9d, $83, $9d
	db $83, $9d, $83, $ff, $84, $9e, $84, $9e, $84, $9e, $84, $9e, $84, $9e, $84, $9e
	db $84, $9e, $84, $ff, $21, $af, $df, $cb, $fe, $21, $ed, $61, $cd, $bf, $64, $3e
	db $04, $21, $e8, $61, $cd, $7f, $64, $3e, $f1, $ea, $e6, $df, $3e, $61, $ea, $e7
	db $df, $3e, $01, $ea, $ee, $df, $3e, $62, $18, $24, $21, $af, $df, $cb, $fe, $21
	db $bb, $61, $cd, $bf, $64, $3e, $04, $21, $a6, $61, $cd, $7f, $64, $3e, $ab, $ea
	db $e6, $df, $3e, $61, $ea, $e7, $df, $3e, $bf, $ea, $ee, $df, $3e, $61, $ea, $ef
	db $df, $c9, $21, $af, $df, $cb, $fe, $21, $dc, $61, $cd, $bf, $64, $3e, $06, $21
	db $cf, $61, $cd, $7f, $64, $3e, $d4, $ea, $e6, $df, $3e, $61, $ea, $e7, $df, $3e
	db $e0, $ea, $ee, $df, $3e, $61, $18, $d6, $cd, $ed, $64, $a7, $c0, $21, $e4, $df
	db $4e, $34, $06, $00, $fa, $e6, $df, $6f, $fa, $e7, $df, $67, $09, $7e, $fe, $ff
	db $ca, $cb, $62, $57, $fa, $ee, $df, $6f, $fa, $ef, $df, $67, $09, $7e, $5f, $0e
	db $08, $fe, $00, $28, $02, $0e, $f2, $7a, $e0, $13, $79, $e0, $12, $fa, $aa, $61
	db $e0, $14, $7b, $e0, $18, $79, $e0, $17, $fa, $d2, $61, $e0, $19, $c9, $fa, $e1
	db $df, $fe, $0d, $28, $06, $cd, $71, $64, $c3, $53, $61, $3e, $0a, $ea, $e8, $df
	db $18, $f3, $34, $80, $e7, $80, $c6

SFX6Envelopes::
	db $97, $87, $87, $77, $67, $57, $47, $37, $20
	db $10, $00

SFX6Frequencies::
	db $88, $90, $98, $a0, $a8, $b0, $b8, $c0, $c8, $d0, $cd, $5d, $60, $c8
	db $3e, $05, $21, $df, $62, $c3, $7f, $64

;@ def UpdateSFX6(slot: de)
;@ path: sound/sfx/square
;@ Every 6 frames the next envelope/frequency pair - a rising, fading sweep.
;@ test: slot = 0xDFE2
;@ test: mem[0xDFE3] = 6; mem[0xDFE2] = rng.choice([5, 1]); mem[0xDFE4] = rand(0, 10)
;@ sig: 949f45da
UpdateSFX6::
;> if SFXTick(slot): return
	call SFXTick
	and a
	ret nz

;> step = mem[addr(wSFXPlaying) + 3]
	ld hl, wSFXPlaying + 3
	ld c, [hl]
;> mem[addr(wSFXPlaying) + 3] = step + 1
	inc [hl]
;> envelope = mem[SFX6Envelopes + step]
	ld b, $00
	ld hl, SFX6Envelopes
	add hl, bc
	ld a, [hl]
;> if envelope == 0:
;>     return StopSquareSFX()                       # (jumps straight to it)
	and a
	jp z, StopSquareSFX

;> freq_lo = mem[SFX6Frequencies + step]
	ld e, a
	ld hl, SFX6Frequencies
	add hl, bc
	ld a, [hl]
;> SetSquare1Note(envelope, freq_lo, 0x86)          # (falls through into it)
	ld d, a
	ld b, $86

SetSquare1Note::
	db $0e, $12, $7b, $e2, $0c, $7a, $e2, $0c, $78, $e2
	db $c9, $2e, $80, $a4, $15, $87, $94, $84, $64, $44, $25, $20, $10, $10, $00, $14
	db $13, $12, $11, $10, $10, $10, $10, $cd, $5d, $60, $c8, $3e, $03, $21, $2e, $63
	db $c3, $7f, $64, $cd, $ed, $64, $a7, $c0, $21, $e4, $df, $4e, $34, $06, $00, $21
	db $33, $63, $09, $7e, $a7, $ca, $53, $61, $5f, $21, $3c, $63, $09, $7e, $57, $06
	db $87, $18, $b3, $26, $80, $a4, $40, $87, $94, $84, $64, $44, $25, $20, $10, $10
	db $00, $48, $50, $58, $60, $68, $70, $74, $78, $cd, $58, $60, $c8, $3e, $04, $21
	db $70, $63, $c3, $7f, $64, $cd, $ed, $64, $a7, $c0, $21, $e4, $df, $4e, $34, $06
	db $00, $21, $75, $63, $09, $7e, $a7, $ca, $53, $61, $5f, $21, $7e, $63, $09, $7e
	db $57, $06, $87, $c3, $23, $63, $9c, $b7, $e0, $34, $c4, $cd, $5d, $60, $c8, $cd
	db $76, $60, $c8, $3e, $03, $21, $b3, $63, $c3, $7f, $64, $c3, $0b, $64, $00, $60
	db $1a, $80, $0d, $0e, $0f, $1c, $1d, $1e, $1d, $1c, $3e, $03, $21, $cb, $63, $c3
	db $7f, $64, $cd, $ed, $64, $a7, $c0, $21, $fc, $df, $7e, $e6, $07, $4f, $34, $06
	db $00, $21, $cf, $63, $09, $7e, $e0, $22, $3e, $80, $e0, $23, $c9, $00, $e1, $56
	db $80, $3e, $18, $21, $fa, $63, $c3, $7f, $64, $cd, $ed, $64, $a7, $c0

StopNoiseSFX::
	db $af, $ea
	db $f9, $df, $3e, $08, $e0, $21, $3e, $80, $e0, $23, $21, $cf, $df, $cb, $be, $c9
StopWaveSFX::
	db $af, $ea, $f1, $df, $e0, $1a, $21, $bf, $df, $cb, $be, $21, $9f, $df, $cb, $be
	db $21, $af, $df, $cb, $be, $21, $cf, $df, $cb, $be, $fa, $e9, $df, $fe, $05, $28
	db $05, $21, $f3, $6b, $18, $2a, $21, $d3, $6b, $18, $25

StartWaveSFX::
	db $e5, $ea, $f1, $df, $21
	db $bf, $df, $cb, $fe, $af, $ea, $f4, $df, $ea, $f5, $df, $ea, $f6, $df, $e0, $1a
	db $21, $9f, $df, $cb, $fe, $21, $af, $df, $cb, $fe, $21, $cf, $df, $cb, $fe, $e1
	db $cd, $fa, $64, $c9, $3e, $08, $e0, $17, $3e, $80, $e0, $19, $21, $af, $df, $cb
	db $be, $c9, $f5, $1d, $fa, $71, $df, $12, $1c, $f1, $1c, $12, $1d, $af, $12, $1c
	db $1c, $12, $1c, $12, $e5, $7b, $fe, $e5, $28, $09, $fe, $f5, $28, $0d, $fe, $fd
	db $28, $11, $c9, $21, $9f, $df, $cb, $fe, $e1, $18, $10, $21, $bf, $df, $cb, $fe
	db $e1, $18, $16, $21, $cf, $df, $cb, $fe, $e1, $18, $15

;@ def WriteSquare1Regs(regs: hl) -> hl
;@ path: sound/sfx/common
;@ Writes 5 bytes from regs to NR10-NR14.
;@ test: regs = rand(0x0000, 0x7F00)
;@ sig: 7ca6dd10
WriteSquare1Regs::
;> return WriteRegs(regs, 0x10, 5)
	push bc
	ld c, LOW(rNR10)
	ld b, $05
	jr WriteRegs

;@ def WriteSquare2Regs(regs: hl) -> hl
;@ path: sound/sfx/common
;@ Writes 4 bytes from regs to NR21-NR24.
;@ test: regs = rand(0x0000, 0x7F00)
;@ sig: 7f2c4f72
WriteSquare2Regs::
;> return WriteRegs(regs, 0x16, 4)
	push bc
	ld c, LOW(rNR21)
	ld b, $04
	jr WriteRegs

WriteWaveRegs::
	db $c5, $0e, $1a, $06, $05, $18, $05, $c5, $0e, $20, $06, $04

;@ def WriteRegs(regs: hl, first: c, count: b) -> hl
;@ path: sound/sfx/common
;@ Copies `count` bytes from regs to the sound registers from $FF00 + first.
;@ Shared tail of the Write*Regs routines (they push bc first).
;@ test: skip pops a bc pushed by its callers
;@ sig: 0eb19ce1
WriteRegs::
;>@loop for i in range(count):
;>     mem[0xFF00 + first + i] = mem[regs + i]
	ld a, [hli]
	ldh [c], a
	inc c
;=@loop
	dec b
	jr nz, WriteRegs

;> return regs + count
	pop bc
	ret



;@ def StartSFXLookup(index: a, table: hl, slot: de) -> (hl, de)
;@ path: sound/sfx/common
;@ Remembers the requested sound (wSndTemp) and looks it up; the slot pointer
;@ moves on two bytes in all (one here, one in TableLookup).
;@ writes: wSndTemp
;@ test: index = rand(1, 14); table = rng.choice([0x6000, 0x6038]); slot = rng.choice([0xDFE0, 0xDFF8])
;@ sig: bfb6e5bf
StartSFXLookup::
;> slot = (slot & 0xFF00) | lo(slot + 1)
	inc e
;> wSndTemp = index
;> return TableLookup(index, table, slot)          # falls through
	ld [wSndTemp], a

;@ def TableLookup(index: a, table: hl, slot: de) -> (hl, de)
;@ path: sound/sfx/common
;@ Returns entry `index` (1-based) of a table of addresses, and the slot
;@ pointer moved one byte on.
;@ clobbers: a, bc
;@ test: index = rand(1, 17)
;@ test: table = rng.choice([0x6480, 0x6490, 0x64A0, 0x64B0])
;@ test: slot = rng.choice([0xDFE0, 0xDFE8, 0xDFF8])
;@ sig: 267a559c
TableLookup::
;> slot = (slot & 0xFF00) | lo(slot + 1)
	inc e
;> offset = u8(2 * u8(index - 1))
	dec a
	sla a
;> ptr = table + offset
	ld c, a
	ld b, $00
	add hl, bc
;> entry = mem16[ptr]
	ld c, [hl]
	inc hl
	ld b, [hl]
	ld l, c
	ld h, b
	ld a, h
;> return entry, slot
	ret


;@ def SFXTick(slot: de) -> a
;@ path: sound/sfx/common
;@ Counts a sound effect's frames: returns 0 (and restarts the count) every
;@ `period` frames, otherwise the count so far.
;@ clobbers: hl
;@ test: slot = rng.choice([0xDFE2, 0xDFF2, 0xDFFA])
;@ test: mem[slot + 1] = rand(1, 8); mem[slot] = rand(0, mem[slot + 1] - 1)
;@ sig: 112db7a9
SFXTick::
;> count = mem[slot] = u8(mem[slot] + 1)
	push de
	ld l, e
	ld h, d
	inc [hl]
	ld a, [hli]
;> if count == mem[slot + 1]:
	cp [hl]
	jr nz, .done

;>     count = mem[slot] = 0
	dec l
	xor a
	ld [hl], a

;> return count
.done
	pop de
	ret

;@ def LoadWaveRAM(wave: hl) -> hl
;@ path: sound/sfx/common
;@ Copies a 16-byte waveform (32 samples) into wave RAM.
;@ test: wave = rand(0x0000, 0x7F00)
;@ sig: f0d05281
LoadWaveRAM::
;>@loop for i in range(16):
	push bc
	ld c, $30

;>     mem[WAVE_RAM + i] = mem[wave + i]
.loop
	ld a, [hli]
	ldh [c], a
;=@loop
	inc c
	ld a, c
	cp $40
	jr nz, .loop

;> return wave + 16
	pop bc
	ret


;@ def InitSoundEngine()
;@ path: sound/api
;@ Stops everything: all channels on both sides, no song, then ResetSoundEngine.
;@ writes: wPanMode, wCurrentSong
;@ sig: 4166e450
InitSoundEngine::
;> rNR51 = 0xFF
	ld a, $ff
	ldh [rNR51], a
;> wPanMode = 3
	ld a, $03
	ld [wPanMode], a
;> wCurrentSong = 0
;> ResetSoundEngine()                              # falls through
	xor a
	ld [wCurrentSong], a

;@ def ResetSoundEngine()
;@ path: sound/api
;@ Clears the effects, the music channels' effect flags, the pause and the
;@ danger state, then silences the channels (SilenceChannels).
;@ writes: wSFXPlaying, wWaveSFXPlaying, wNoiseSFXPlaying, wPauseTimer, wSoundPause, wDangerLevel, wTempoCount, wNearlyFull, wDangerMusic, wChannel1, wChannel2, wChannel3, wChannel4
;@ sig: a5bb0b0c
ResetSoundEngine::
;> for addr in (wSFXPlaying, wWaveSFXPlaying, wNoiseSFXPlaying, 0xDF9F, 0xDFAF, 0xDFBF, 0xDFCF,
;>              0xDF7E, 0xDF7F, 0xDF8F, 0xDF8D, 0xDF8E, 0xDF8A, 0xDF8B):
;>     mem[addr] = 0
;> SilenceChannels()                               # falls through
	xor a
	ld [wSFXPlaying], a
	ld [wWaveSFXPlaying], a
	ld [wNoiseSFXPlaying], a
	ld [wChannel1 + $0F], a
	ld [wChannel2 + $0F], a
	ld [wChannel3 + $0F], a
	ld [wChannel4 + $0F], a
	ld [wPauseTimer], a
	ld [wSoundPause], a
	ld [wDangerLevel], a
	ld [wTempoCount], a
	ld [wTempoCount + 1], a
	ld [wNearlyFull], a
	ld [wDangerMusic], a

;@ def SilenceChannels()
;@ path: sound/api
;@ Envelopes to zero volume (restarted so they take effect), sweep off,
;@ wave DAC off.
;@ sig: d98ac311
SilenceChannels::
;> rNR12 = 0x08
	ld a, $08
	ldh [rNR12], a
;> rNR22 = 0x08
	ldh [rNR22], a
;> rNR42 = 0x08
	ldh [rNR42], a
;> rNR14 = 0x80                                     # restart with the silent envelope
	ld a, $80
	ldh [rNR14], a
;> rNR24 = 0x80
	ldh [rNR24], a
;> rNR44 = 0x80
	ldh [rNR44], a
;> rNR10 = 0
	xor a
	ldh [rNR10], a
;> rNR30 = 0
	ldh [rNR30], a
	ret


;@ def StartRequestedSFX()
;@ path: sound/sfx/common
;@ A requested square effect starts (its start routine from SquareSFXStarts);
;@ otherwise the playing one goes on (SquareSFXUpdates). Both are jumped to
;@ with the slot pointer in de.
;@ reads: wSFXRequest, wSFXPlaying
;@ test: skip jumps to the effect's own routine
;@ sig: e89939d3
StartRequestedSFX::
;> if wSFXRequest:
	ld de, wSFXRequest
	ld a, [de]
	and a
	jr z, jr_000_6563

;>     routine, slot = StartSFXLookup(wSFXRequest, SquareSFXStarts, wSFXRequest)
;>     return goto(routine)
	ld hl, $6000
	call StartSFXLookup
	jp hl


jr_000_6563:
;> if wSFXPlaying:
	inc e
	ld a, [de]
	and a
	jr z, jr_000_656f

;>     routine, slot = TableLookup(wSFXPlaying, SquareSFXUpdates, wSFXPlaying)
;>     return goto(routine)
	ld hl, $601c
	call TableLookup
	jp hl


jr_000_656f:
	ret


;@ def StartRequestedNoiseSFX()
;@ path: sound/sfx/common
;@ The same for the noise channel (NoiseSFXStarts / NoiseSFXUpdates).
;@ reads: wNoiseSFXRequest, wNoiseSFXPlaying
;@ test: skip jumps to the effect's own routine
;@ sig: 73a73739
StartRequestedNoiseSFX::
;> if wNoiseSFXRequest:
	ld de, wNoiseSFXRequest
	ld a, [de]
	and a
	jr z, jr_000_657e

;>     routine, slot = StartSFXLookup(wNoiseSFXRequest, NoiseSFXStarts, wNoiseSFXRequest)
;>     return goto(routine)
	ld hl, $6038
	call StartSFXLookup
	jp hl


jr_000_657e:
;> if wNoiseSFXPlaying:
	inc e
	ld a, [de]
	and a
	jr z, jr_000_658a

;>     routine, slot = TableLookup(wNoiseSFXPlaying, NoiseSFXUpdates, wNoiseSFXPlaying)
;>     return goto(routine)
	ld hl, $603e
	call TableLookup
	jp hl


jr_000_658a:
	ret


SongBeats::
	db $0d, $0b, $0d, $0a, $0a, $0a, $0a, $0f, $0a, $0a, $05

;@ def StopMusic()
;@ path: sound/music
;@ Song request $FF: stops everything (StartRequestedSong jumps here).
;@ test: skip resets the sound engine through SilenceChannels
;@ sig: 1e31f21b
StopMusic::
;> return InitSoundEngine()
	jp InitSoundEngine


;@ def StartRequestedSong(song: a, current: hl)
;@ path: sound/music
;@ Starts song 1-10 ($FF stops the music): notes its beat length for the
;@ dancing viruses, marks it playing, sets up the channels and the panning.
;@ writes: wSongBeat
;@ test: skip starts a song through helpers not translated yet
;@ sig: 0e36912b
StartRequestedSong::
;> if song == 0xFF:
;>     return StopMusic()
	cp $ff
	jr z, StopMusic

;> if song >= 0x0B:
;>     return
	cp $0b
	ret nc

;> wSongBeat = mem[SongBeats + song]
	push af
	push hl
	ld hl, $658b
	ld c, a
	ld b, $00
	add hl, bc
	ld a, [hl]
	ld [wSongBeat], a
;> mem[current] = song                             # wCurrentSong
	pop hl
	pop af
	ld [hl], a
;> header, _ = TableLookup(song & 0x1F, SongTable, 0)
	ld b, a
	ld hl, $6044
	and $1f
	call TableLookup
;> StartSong(header)
	call StartSong
;> SetSongPanning()
	call SetSongPanning
	ret


;@ def SoundFrame()
;@ path: sound/api
;@ The sound engine's frame (UpdateSound jumps here, from the timer
;@ interrupt). A pause request silences everything and plays a short jingle
;@ (wPauseTimer counts it down, then holds at $10 until resumed). Otherwise
;@ requested songs and effects start; while the link game's bottle is nearly
;@ full the alarm effect 9 keeps repeating (unless a more important effect
;@ plays), and the danger music request turns into effect $0A. Then the music
;@ plays and all requests are cleared.
;@ reads: wSoundPause, wPauseTimer, wMusicRequest, wDangerMusic, wSFXRequest, wSFXPlaying, wNearlyFull
;@ writes: wSFXPlaying, wWaveSFXPlaying, wNoiseSFXPlaying, wPauseTimer, wDangerMusic, wSFXRequest, wMusicRequest, wWaveSFXRequest, wNoiseSFXRequest, wSoundPause
;@ test: skip runs the whole sound engine
;@ sig: ed77ab50
SoundFrame::
;> main = True
;> if wSoundPause == 1:                            # pause
;>@p1     SilenceChannels()
;>@p2     wSFXPlaying = wWaveSFXPlaying = wNoiseSFXPlaying = 0
;>@p3     for flags in (0xDF9F, 0xDFAF, 0xDFBF, 0xDFCF):  # the music owns its channels again
;>@p4         mem[flags] &= 0x7F
;>@p5     LoadWaveRAM(PauseWave)
;>@p6     wPauseTimer = 0x30
;>@p7     WriteSquare2Regs(PauseNotes)                # the jingle's first note
;>@p8     main = False
;>@res elif wSoundPause == 2:                         # resume
;>@res2     wPauseTimer = 0
;>@res3     wDangerMusic = 0
;>@pt elif wPauseTimer:                               # the pause jingle
;>@pt1     main = False
;>@pt2     wPauseTimer -= 1
;>@pt3     if wPauseTimer in (0x28, 0x18):
;>@pt4         WriteSquare2Regs(PauseNotes + 4)
;>@pt5     elif wPauseTimer == 0x20:
;>@pt6         WriteSquare2Regs(PauseNotes)
;>@pt7     elif wPauseTimer == 0x10:                   # then stay quiet
;>@pt8         wPauseTimer += 1
;=@res
	ld a, [wSoundPause]
	cp $01
	jr z, jr_000_6641

	cp $02
	jp z, Jump_000_667a

;=@pt
	ld a, [wPauseTimer]
	and a
	jp nz, Jump_000_6684

;> if main:
;>     while True:
Jump_000_65d3:
jr_000_65d3:
;>         if wMusicRequest:
;>@song             StartRequestedSong(wMusicRequest, wCurrentSong)
;>@songb             break
	ld hl, wMusicRequest
	ld a, [hli]
	and a
	jr nz, jr_000_663c

;>         if wDangerMusic:
	ld a, [wDangerMusic]
	and a
	jr z, jr_000_65e5

;>             wSFXRequest = 0x0A
	ld a, $0a
	ld [wSFXRequest], a

jr_000_65e5:
;>         if (wSFXRequest not in (0x08, 0x0A, 0x0B) and wSFXPlaying not in (0x08, 0x0A, 0x0B)
;>                 and wNearlyFull):               # the "nearly full" alarm repeats
	ld a, [wSFXRequest]
	cp $08
	jr z, jr_000_6618

	cp $0a
	jr z, jr_000_6618

	cp $0b
	jr z, jr_000_6618

	ld a, [wSFXPlaying]
	cp $08
	jr z, jr_000_6618

	cp $0a
	jr z, jr_000_6618

	cp $0b
	jr z, jr_000_6618

	ld a, [wNearlyFull]
	and a
	jr z, jr_000_6618

;>             wSFXRequest = 0 if wSFXPlaying == 9 else 9
	ld c, $09
	ld a, [wSFXPlaying]
	cp $09
	jr nz, jr_000_6614

	ld c, $00

jr_000_6614:
	ld a, c
	ld [wSFXRequest], a

jr_000_6618:
;>         StartRequestedSFX()
	call StartRequestedSFX
;>         if wMusicRequest == 0x0A:
;>             continue
	ld a, [wMusicRequest]
	cp $0a
	jr z, jr_000_65d3

;>         StartRequestedNoiseSFX()
;>         break
	call StartRequestedNoiseSFX

jr_000_6625:
;>     UpdateMusic()
	call UpdateMusic

jr_000_6628:
;> wSFXRequest = wMusicRequest = wWaveSFXRequest = wNoiseSFXRequest = 0
;> wSoundPause = 0
;> wDangerMusic = 0
	xor a
	ld [wSFXRequest], a
	ld [wMusicRequest], a
	ld [wWaveSFXRequest], a
	ld [wNoiseSFXRequest], a
	ld [wSoundPause], a
	ld [wDangerMusic], a
	ret


jr_000_663c:
;=@song
	call StartRequestedSong
;=@songb
	jr jr_000_6625

jr_000_6641:
;=@p1
	call SilenceChannels
;=@p2
	xor a
	ld [wSFXPlaying], a
	ld [wWaveSFXPlaying], a
	ld [wNoiseSFXPlaying], a
;=@p3
	ld hl, wChannel1 + $0F
	res 7, [hl]
	ld hl, wChannel2 + $0F
	res 7, [hl]
	ld hl, wChannel3 + $0F
	res 7, [hl]
	ld hl, wChannel4 + $0F
	res 7, [hl]
;=@p5
	ld hl, $6bf3
	call LoadWaveRAM
;=@p6
	ld a, $30
	ld [wPauseTimer], a

jr_000_666d:
;=@p7
	ld hl, $669c

jr_000_6670:
	call WriteSquare2Regs
	jr jr_000_6628

jr_000_6675:
;=@pt4
	ld hl, $66a0
	jr jr_000_6670

Jump_000_667a:
;=@res2
	xor a
	ld [wPauseTimer], a
;=@res3
	ld [wDangerMusic], a
	jp Jump_000_65d3


Jump_000_6684:
;=@pt2
	ld hl, wPauseTimer
	dec [hl]
	ld a, [hl]
;=@pt3
	cp $28
	jr z, jr_000_6675

;=@pt5
	cp $20
	jr z, jr_000_666d

	cp $18
	jr z, jr_000_6675

;=@pt7
	cp $10
	jr nz, jr_000_6628

;=@pt8
	inc [hl]
	jr jr_000_6628

PauseNotes::
	db $b2, $e3, $83, $c7, $b2, $e3, $c1, $c7, $3e, $80, $e0, $26, $3e, $77, $e0, $24
	db $3e, $ff, $e0, $25, $21, $00, $df, $36, $00, $2c, $20, $fb, $c9


;@ def SetSongPanning()
;@ path: sound/music
;@ Sets up the current song's panning from SongPanning (4 bytes per song:
;@ mode, period, NR51 value A, value B) and starts with value A.
;@ reads: wCurrentSong
;@ writes: wPanMode, wPanPeriod, wPanA, wPanB, wPanFrame, wPanToggle
;@ test: wCurrentSong = rand(1, 10)
;@ sig: 40f67806
SetSongPanning::
;> p = (SongPanning + 4 * ((wCurrentSong - 1) & 0xFF)) & 0xFFFF
	ld a, [wCurrentSong]
	ld hl, $6c80

jr_000_66bf:
	dec a
	jr z, jr_000_66c8

	inc hl
	inc hl
	inc hl
	inc hl
	jr jr_000_66bf

jr_000_66c8:
;> wPanMode = mem[p]
	ld a, [hli]
	ld [wPanMode], a
;> wPanPeriod = mem[p + 1]
	ld a, [hli]
	ld [wPanPeriod], a
;> wPanA = mem[p + 2]
;> rNR51 = wPanA
	ld a, [hli]
	ld [wPanA], a
	ldh [rNR51], a
;> wPanB = mem[p + 3]
	ld a, [hli]
	ld [wPanB], a
;> wPanFrame = 0
;> wPanToggle = 0
	xor a
	ld [wPanFrame], a
	ld [wPanToggle], a
	ret


;@ def UpdatePanning()
;@ path: sound/music
;@ Unless the panning is fixed (mode 1), every wPanPeriod frames NR51
;@ switches between the song's two values.
;@ reads: wPanMode, wPanPeriod, wPanA, wPanB
;@ writes: wPanFrame, wPanToggle
;@ test: wPanMode = rng.choice([1, 2, 3]); wPanPeriod = rand(1, 8); wPanFrame = rand(0, wPanPeriod - 1); wPanToggle = rand(0, 255); wPanA = rand(0, 255); wPanB = rand(0, 255)
;@ sig: 71009c65
UpdatePanning::
;> if wPanMode == 1:
;>     return
	ld hl, wPanMode
	ld a, [hli]
	cp $01
	ret z

;> wPanFrame += 1
	inc [hl]
;> if wPanFrame != wPanPeriod:
;>     return
	ld a, [hli]
	cp [hl]
	ret nz

;> wPanFrame = 0
	dec l
	ld [hl], $00
;> wPanToggle += 1
	inc l
	inc l
	inc [hl]
;> rNR51 = wPanB if wPanToggle & 1 else wPanA
	inc l
	ld a, [hld]
	bit 0, [hl]
	jp z, Jump_000_66fd

	inc l
	inc l
	ld a, [hl]

Jump_000_66fd:
	ldh [rNR51], a
	ret


;@ def CopyIndirectWord(src: hl, dest: de)
;@ path: sound/music
;@ Copies the word that the pointer at src points to into dest (dest
;@ stays inside its 256-byte page).
;@ test: src = rng.choice([0xDF90, 0xDFA0, 0xDFB0, 0xDFC0]); w = rand(0x6F00, 0x7F00); mem[src] = w & 0xFF; mem[src + 1] = w >> 8
;@ test: dest = src + 4
;@ sig: b12c4f83
CopyIndirectWord::
;> p = mem16[src]
	ld a, [hli]
	ld c, a
	ld a, [hl]
	ld b, a
;> mem[dest] = mem[p]
	ld a, [bc]
	ld [de], a
;> mem[(dest & 0xFF00) | lo(dest + 1)] = mem[u16(p + 1)]
	inc e
	inc bc
	ld a, [bc]
	ld [de], a
	ret


;@ def CopyWord(src: hl, dest: de) -> hl
;@ path: sound/music
;@ Copies two bytes from src to dest (dest stays inside its page) and
;@ returns src moved past them.
;@ test: src = rand(0x6F00, 0x7F00)
;@ test: dest = rng.choice([0xDF81, 0xDF90, 0xDFA0, 0xDFB0, 0xDFC0])
;@ sig: b88c62c7
CopyWord::
;> mem[dest] = mem[src]
	ld a, [hli]
	ld [de], a
;> mem[(dest & 0xFF00) | lo(dest + 1)] = mem[src + 1]
	inc e
	ld a, [hli]
	ld [de], a
;> return src + 2
	ret


;@ def StartSong(header: hl)
;@ path: sound/music
;@ Starts a song from its header: flags, note length table, a pattern list
;@ per channel; each channel's pattern pointer starts at its first pattern
;@ and its note timer at 1 (the first note plays at once).
;@ writes: wSongFlags, wNoteLengths, wChannel1, wChannel2, wChannel3
;@ test: skip resets the sound engine through SilenceChannels
;@ sig: aa2f85dd
StartSong::
;> ResetSoundEngine()
	call ResetSoundEngine
;> wSongFlags = mem[header]
	ld de, wSongFlags
	ld b, $00
	ld a, [hli]
	ld [de], a
;> wNoteLengths = mem16[header + 1]
	inc e
	call CopyWord
;> for k in range(4):                              # the pattern lists
;>     mem16[wChannel1 + 16 * k] = mem16[header + 3 + 2 * k]
	ld de, wChannel1
	call CopyWord
	ld de, wChannel2
	call CopyWord
	ld de, wChannel3
	call CopyWord
	ld de, wChannel4
	call CopyWord
;> for k in range(4):                              # the pattern pointers: each list's first pattern
;>     mem16[wChannel1 + 16 * k + 4] = mem16[mem16[wChannel1 + 16 * k]]
	ld hl, wChannel1
	ld de, wChannel1 + $04
	call CopyIndirectWord
	ld hl, wChannel2
	ld de, wChannel2 + $04
	call CopyIndirectWord
	ld hl, wChannel3
	ld de, wChannel3 + $04
	call CopyIndirectWord
	ld hl, wChannel4
	ld de, wChannel4 + $04
	call CopyIndirectWord
;> for k in range(4):
;>     mem[wChannel1 + 16 * k + 2] = 1             # note timer
	ld bc, $0410
	ld hl, wChannel1 + $02

jr_000_6761:
	ld [hl], $01
	ld a, c
	add l
	ld l, a
	dec b
	jr nz, jr_000_6761

;> mem[wChannel1 + 14] = mem[wChannel2 + 14] = mem[wChannel3 + 14] = 0
	xor a
	ld [wChannel1 + $0E], a
	ld [wChannel2 + $0E], a
	ld [wChannel3 + $0E], a
	ret


;=@InstrumentCommand.wave
jr_000_6774:
	push hl
	xor a
	ldh [rNR30], a
;=@InstrumentCommand.wave2
	ld l, e
	ld h, d
	call LoadWaveRAM
	pop hl
;=@InstrumentCommand.adv
	jr jr_000_67aa

;@ def InstrumentCommand(ptr: hl)
;@ path: sound/music
;@ Pattern command $9D: the next three bytes go to the channel's instrument
;@ (envelope or wave address, duty / length); on the wave channel they point
;@ to the waveform, which is loaded into wave RAM. Then the pattern goes on.
;@ test: skip goes on reading the pattern
;@ sig: fa0f9095
InstrumentCommand::
;> AdvancePointer(ptr)
	call AdvancePointer
;> b0 = ReadPointer(ptr)
	call ReadPointer
	ld e, a
;> AdvancePointer(ptr)
	call AdvancePointer
;> b1 = ReadPointer(ptr)
	call ReadPointer
	ld d, a
;> AdvancePointer(ptr)
	call AdvancePointer
;> b2 = ReadPointer(ptr)
	call ReadPointer
	ld c, a
;> mem[ptr + 2] = b0
;> mem[ptr + 3] = b1
;> mem[ptr + 4] = b2
	inc l
	inc l
	ld [hl], e
	inc l
	ld [hl], d
	inc l
	ld [hl], c
	dec l
	dec l
	dec l
	dec l
;> if wSndChannel == 3:
;>@wave     rNR30 = 0
;>@wave2     LoadWaveRAM(b1 << 8 | b0)                   # (inside StartSong's block)
;>@adv AdvancePointer(ptr)
;>@read return ReadPattern(ptr)
	push hl
	ld hl, wSndChannel
	ld a, [hl]
	pop hl
	cp $03
	jr z, jr_000_6774

;=@adv
jr_000_67aa:
	call AdvancePointer
;=@read
	jp ReadPattern


;@ def AdvancePointer(ptr: hl)
;@ path: sound/music
;@ Moves the 16-bit pointer at ptr on by one.
;@ test: ptr = rand_ram(2)
;@ sig: a23ec6ef
AdvancePointer::
;> p = (mem16[ptr] + 1) & 0xFFFF
	push de
	ld a, [hli]
	ld e, a
	ld a, [hld]
	ld d, a
	inc de

jr_000_67b6:
;> mem[ptr] = lo(p)
;> mem[ptr + 1] = hi(p)
	ld a, e
	ld [hli], a
	ld a, d
	ld [hld], a
	pop de
	ret


;@ def AdvancePointer2(ptr: hl)
;@ path: sound/music
;@ Moves the 16-bit pointer at ptr on by two.
;@ test: ptr = rand_ram(2)
;@ sig: 3e0d7f83
AdvancePointer2::
;> p = (mem16[ptr] + 2) & 0xFFFF
;> mem16[ptr] = p                                  # AdvancePointer's store
	push de
	ld a, [hli]
	ld e, a
	ld a, [hld]
	ld d, a
	inc de
	inc de
	jr jr_000_67b6

;@ def ReadPointer(ptr: hl) -> a
;@ path: sound/music
;@ The byte the 16-bit pointer at ptr points to (also left in b).
;@ test: ptr = rand_ram(2)
;@ sig: 77917b65
ReadPointer::
;> return mem[mem16[ptr]]
	ld a, [hli]
	ld c, a
	ld a, [hld]
	ld b, a
	ld a, [bc]
	ld b, a
	ret


jr_000_67cc:
	pop hl
	jr jr_000_67fb


;@ def SustainNote(timer: hl)
;@ path: sound/music
;@ A note goes on: a wave note with the fade flag drops to half volume 6
;@ frames before its end, and unless the note is a rest or a sound effect
;@ owns the channel its vibrato runs. Then the next channel.
;@ reads: wChannel3, wSndChannel
;@ test: skip goes on with the next channel
;@ sig: f3bcbece
SustainNote::
;> if wSndChannel == 3 and mem[wChannel3 + 8] & 0x80 and mem[timer] == 6:
	ld a, [wSndChannel]
	cp $03
	jr nz, jr_000_67e6

	ld a, [wChannel3 + $08]
	bit 7, a
	jr z, jr_000_67e6

	ld a, [hl]
	cp $06
	jr nz, jr_000_67e6

;>     rNR32 = 0x40                                # half volume
	ld a, $40
	ldh [rNR32], a

jr_000_67e6:
;> if mem[timer + 9] == 0 and not mem[timer + 13] & 0x80:   # not a rest, no effect on the channel
	push hl
	ld a, l
	add $09
	ld l, a
	ld a, [hl]
	and a
	jr nz, jr_000_67cc

	ld a, l
	add $04
	ld l, a
	bit 7, [hl]
	jr nz, jr_000_67cc

;>     UpdateVibrato(timer)
;> return SkipChannel(timer)                       # falls through
	pop hl
	call UpdateVibrato

;@ def SkipChannel(timer: hl)
;@ path: sound/music
;@ On to the next channel (hl back at the channel's start).
;@ test: skip goes on with the next channel
;@ sig: f7c90e10
SkipChannel::
jr_000_67fb:
;> return NextChannel(timer - 2)
	dec l
	dec l
	jp NextChannel


;@ def NextPattern(ptr: hl)
;@ path: sound/music
;@ A pattern ended ($00): the next entry of the channel's pattern list. $00xx
;@ ends the song (song 10 then asks for the level music via $DF89), $FFxx is
;@ followed by the address the list loops back to.
;@ reads: wCurrentSong
;@ writes: wCurrentSong, $DF89, wRestartMusic
;@ test: skip goes on reading the next pattern
;@ sig: 66182759
NextPattern::
;> ch = ptr - 4
	dec l
	dec l
	dec l
	dec l
;> AdvancePointer2(ch)                             # the list moves on
	call AdvancePointer2

jr_000_6807:
;> while True:
;>     entry = mem16[mem16[ch]]
;>     mem16[ptr] = entry                          # the new pattern
	ld a, l
	add $04
	ld e, a
	ld d, h
	call CopyIndirectWord
;>     if hi(entry) == 0x00:                       # the song is over
;>@end1         if wCurrentSong == 0x0A:                # the intro jingle: now the level music
;>@end2             wRestartMusic = 1
;>@end3         wCurrentSong = 0
;>@end4         return InitSoundEngine()
	cp $00
	jr z, jr_000_6832

;>     if hi(entry) != 0xFF:
	cp $ff
	jr z, jr_000_681b

;>         return ReadPattern(ptr)
;>@loop     mem16[ch] = mem16[mem16[ch] + 2]            # $FFxx: loop to the address after it
	inc l
	jp Jump_000_68d6


;=@loop
jr_000_681b:
	dec l
	push hl
	call AdvancePointer2
	call ReadPointer
	ld e, a
	call AdvancePointer
	call ReadPointer
	ld d, a
	pop hl
	ld a, e
	ld [hli], a
	ld a, d
	ld [hld], a
	jr jr_000_6807

;=@end1
jr_000_6832:
	ld hl, wCurrentSong
	ld a, [hl]
	cp $0a
	jr nz, jr_000_683f

;=@end2
	ld a, $01
	ld [wRestartMusic], a

;=@end3
jr_000_683f:
	ld [hl], $00
;=@end4
	call InitSoundEngine
	ret


;@ def NoteLengthsCommand(ptr: hl)
;@ path: sound/music
;@ Pattern command $9E: the next two bytes are a new note length table.
;@ writes: wNoteLengths
;@ test: skip goes on reading the pattern
;@ sig: 0afb6fe5
NoteLengthsCommand::
;> AdvancePointer(ptr)
	call AdvancePointer
;> lo_byte = ReadPointer(ptr)
	call ReadPointer
;> mem[wNoteLengths] = lo_byte
	ld [wNoteLengths], a
;> AdvancePointer(ptr)
	call AdvancePointer
;> mem[wNoteLengths + 1] = ReadPointer(ptr)
;> AdvancePointer(ptr)                             # (SongFlagsCommand's tail)
;> return ReadPattern(ptr)
	call ReadPointer
	ld [wNoteLengths + 1], a
	jr jr_000_6862

;@ def SongFlagsCommand(ptr: hl)
;@ path: sound/music
;@ Pattern command $9F: the next byte transposes the song (signed, in steps
;@ of the note table; ReadPattern adds it to every note).
;@ writes: wSongFlags
;@ test: skip goes on reading the pattern
;@ sig: 0ee30fc8
SongFlagsCommand::
;> AdvancePointer(ptr)
	call AdvancePointer
;> wSongFlags = ReadPointer(ptr)
	call ReadPointer
	ld [wSongFlags], a

;> AdvancePointer(ptr)
jr_000_6862:
	call AdvancePointer
;> return ReadPattern(ptr)
	jr jr_000_68d8

;@ def RepeatStartCommand(ptr: hl)
;@ path: sound/music
;@ Pattern command $9B n: the part up to the next $9C plays n times. The
;@ count goes into the channel's flags byte (low 7 bits), the repeat address
;@ (after n) into bytes $0C/$0D of the channel.
;@ test: skip goes on reading the pattern
;@ sig: 6073db6a
RepeatStartCommand::
;> AdvancePointer(ptr)
	call AdvancePointer
;> n = ReadPointer(ptr)
	call ReadPointer
;> ch = ptr - 4
;> mem[ch + 0x0F] |= n
	push hl
	ld a, l
	add $0b
	ld l, a
	ld c, [hl]
	ld a, b
	or c
	ld [hl], a
;> start = (mem16[ptr] + 1) & 0xFFFF               # after the count
;> mem16[ptr] = start
;> mem[ch + 0x0D] = hi(start)
;> mem[ch + 0x0C] = lo(start)
	ld b, h
	ld c, l
	dec c
	dec c
	pop hl
	ld a, [hli]
	ld e, a
	ld a, [hld]
	ld d, a
	inc de
	ld a, e
	ld [hli], a
	ld a, d
	ld [hld], a
	ld a, d
	ld [bc], a
	dec c
	ld a, e
	ld [bc], a
;> return ReadPattern(ptr)
	jr jr_000_68d8

;@ def RepeatEndCommand(ptr: hl)
;@ path: sound/music
;@ Pattern command $9C: counts the repeat down; back to the repeat address
;@ until it reaches 0, then on past the $9C.
;@ test: skip goes on reading the pattern
;@ sig: c5e71bda
RepeatEndCommand::
;> ch = ptr - 4
;> mem[ch + 0x0F] -= 1
;> if mem[ch + 0x0F] & 0x7F:
	push hl
	ld a, l
	add $0b
	ld l, a
	ld a, [hl]
	dec [hl]
	ld a, [hl]
	and $7f
	jr z, jr_000_68a4

;>     mem16[ptr] = mem16[ch + 0x0C]               # again
	ld b, h
	ld c, l
	dec c
	dec c
	dec c
	pop hl
	ld a, [bc]
	ld [hli], a
	inc c
	ld a, [bc]
	ld [hld], a
;>     return ReadPattern(ptr)
	jr jr_000_68d8

;> AdvancePointer(ptr)                             # (SongFlagsCommand's tail)
;> return ReadPattern(ptr)
jr_000_68a4:
	pop hl
	jr jr_000_6862

;@ def UpdateMusic()
;@ path: sound/music
;@ The music's frame: counts frames while the danger tempo runs, updates the
;@ panning and then the four channels, starting with channel 1.
;@ reads: wCurrentSong, wDangerLevel
;@ writes: wTempoCount, wSndChannel
;@ test: skip plays the channels through helpers not translated yet
;@ sig: 8d9ca9c7
UpdateMusic::
;> if not wCurrentSong:
;>     return
	ld hl, wCurrentSong
	ld a, [hl]
	and a
	ret z

;> if wDangerLevel == 3:
	ld hl, wTempoCount
	ld a, [wDangerLevel]
	cp $03
	jr nz, jr_000_68be

;>     wTempoCount = (wTempoCount + 1) & 0xFFFF
	inc [hl]
	jr nz, jr_000_68c1

	inc l
	inc [hl]
	jr jr_000_68c1

;> else:
;>     wTempoCount = 0
jr_000_68be:
	xor a
	ld [hli], a
	ld [hl], a

jr_000_68c1:
;> UpdatePanning()
	call UpdatePanning
;> wSndChannel = 1
	ld a, $01
	ld [wSndChannel], a
;> UpdateChannel(wChannel1)                        # falls through
	ld hl, wChannel1

;@ def UpdateChannel(ch: hl)
;@ path: sound/music
;@ One music channel's frame: an unused channel is skipped; while its note
;@ timer runs the note is sustained, otherwise the next pattern byte is read.
;@ test: skip goes on into SustainNote / ReadPattern
;@ sig: 279d6c51
UpdateChannel::
;> if mem[ch + 1] == 0:                            # no pattern list
;>     return SkipChannel(ch + 2)
	inc l
	ld a, [hli]
	and a
	jp z, SkipChannel

;> mem[ch + 2] -= 1                                # note timer
;> if mem[ch + 2]:
;>     return SustainNote(ch + 2)
	dec [hl]
	jp nz, SustainNote

Jump_000_68d6:
;> return ReadPattern(ch + 4)                      # falls through
	inc l
	inc l


;@ def ReadPattern(ptr: hl)
;@ path: sound/music
;@ Reads the channel's next pattern byte: a command, a new note length ($Ax,
;@ from the song's table) or a note. A note's frequency comes from the note
;@ table at $6B12, transposed by the song ($9F) and raised by the link
;@ game's danger level (one step per level; at level 3 it keeps rising with
;@ the time spent there, up to 31 more), so the music climbs as the other
;@ side gets close to winning. Noise notes pick a drum from $6BA4. Unless a
;@ sound effect owns the channel the registers are written, then the note
;@ timer starts and the next channel follows.
;@ reads: wSndChannel, wNoteLengths, wSongFlags, wDangerLevel, wChannel3, wTempoCount
;@ test: skip goes on with the next channel
;@ sig: 2ecfb272
ReadPattern::
jr_000_68d8:
;> cmd = ReadPointer(ptr)
	call ReadPointer
;> if cmd == 0x00: return NextPattern(ptr)         # end of the pattern
	cp $00
	jp z, NextPattern

;> if cmd == 0x9D: return InstrumentCommand(ptr)
	cp $9d
	jp z, InstrumentCommand

;> if cmd == 0x9E: return NoteLengthsCommand(ptr)
	cp $9e
	jp z, NoteLengthsCommand

;> if cmd == 0x9F: return SongFlagsCommand(ptr)
	cp $9f
	jp z, SongFlagsCommand

;> if cmd == 0x9B: return RepeatStartCommand(ptr)
	cp $9b
	jp z, RepeatStartCommand

;> if cmd == 0x9C: return RepeatEndCommand(ptr)
	cp $9c
	jp z, RepeatEndCommand

;> if cmd & 0xF0 == 0xA0:                          # a new note length
	and $f0
	cp $a0
	jr nz, jr_000_6919

;>     mem[ptr - 1] = mem[mem16[wNoteLengths] + (cmd & 0x0F)]
	ld a, b
	and $0f
	ld c, a
	ld b, $00
	push hl
	ld de, wNoteLengths
	ld a, [de]
	ld l, a
	inc e
	ld a, [de]
	ld h, a
	add hl, bc
	ld a, [hl]
	pop hl
	dec l
	ld [hli], a
;>     AdvancePointer(ptr)
	call AdvancePointer
;>     cmd = ReadPointer(ptr)
	call ReadPointer

jr_000_6919:
;> note = cmd
;> ch = ptr - 4
	ld c, b
	ld b, $00
;> AdvancePointer(ptr)
	call AdvancePointer
;> if wSndChannel == 4:                            # noise: the note picks a drum
;>@n1     for k in range(5):
;>@n2         mem[0xDFC6 + k] = mem[0x6BA4 + note + k]
;>@n3     reg, e_left = 0x20, 0xCB                    # NR41
;> else:
	ld a, [wSndChannel]
	cp $04
	jp z, Jump_000_6984

;>     if note == 1:                               # a rest
;>@rest1         mem[ch + 0x0B] = 1
;>@rest2         e_left = lo(ch + 9)
;>     else:
	push hl
	ld a, l
	add $05
	ld l, a
	ld e, l
	ld d, h
	inc l
	inc l
	ld a, c
	cp $01
	jr z, jr_000_697f

;>         mem[ch + 0x0B] = 0
	ld [hl], $00
;>         idx = note
;>         if wSongFlags:                          # transposed
	ld a, [wSongFlags]
	and a
	jr z, jr_000_6949

;>             idx = (idx + (wSongFlags - 256 if wSongFlags & 0x80 else wSongFlags)) & 0xFFFF
	ld l, a
	ld h, $00
	bit 7, l
	jr z, jr_000_6946

	ld h, $ff

jr_000_6946:
	add hl, bc
	ld b, h
	ld c, l

jr_000_6949:
;>         level = wDangerLevel
;>         if level:                               # higher as the other side gets closer
	ld a, [wDangerLevel]
	and a
	jr z, jr_000_6972

;>             idx += 2
	inc bc
	inc bc
;>             if level != 1:
	cp $01
	jr z, jr_000_6972

;>                 idx += 2
	inc bc
	inc bc
;>                 if level >= 3:
	cp $02
	jr z, jr_000_6972

	cp $03
	jr c, jr_000_6972

;>                     idx += 2
	inc bc
	inc bc
;>                     idx += 2 * min(mem[wTempoCount + 1], 0x1F)   # and climbing while it lasts
	ld a, [wTempoCount + 1]
	and a
	jr z, jr_000_6972

	cp $1f
	jr c, jr_000_696d

	ld a, $1f

jr_000_696d:
	inc bc
	inc bc
	dec a
	jr nz, jr_000_696d

jr_000_6972:
;>         freq = mem16[0x6B12 + idx]
;>         mem[ch + 9] = lo(freq)
;>         mem[ch + 0x0A] = hi(freq)
;>         e_left = lo(ch + 0x0A)
	ld hl, $6b12
	add hl, bc
	ld a, [hli]
	ld [de], a
	inc e
	ld a, [hl]
	ld [de], a
	pop hl
	jp Jump_000_699b


jr_000_697f:
;=@rest1
	ld [hl], $01
	pop hl
	jr jr_000_699b

Jump_000_6984:
;=@n1
	push hl
	ld de, wChannel4 + $06
	ld hl, $6ba4
	add hl, bc

jr_000_698c:
;=@n2
	ld a, [hli]
	ld [de], a
	inc e
	ld a, e
	cp $cb
	jr nz, jr_000_698c

;=@n3
	ld c, $20
	ld hl, wChannel4 + $04
	jr jr_000_69d2

Jump_000_699b:
jr_000_699b:
;>@reg     reg = {1: 0x11, 2: 0x16}.get(wSndChannel, 0x1B)
	push hl
	ld a, [wSndChannel]
	cp $01
	jr z, jr_000_69cd

	cp $02
	jr z, jr_000_69c9

;>     if wSndChannel == 3 and not mem[wChannel3 + 15] & 0x80:    # restart the wave channel
	ld c, $1a
	ld a, [wChannel3 + $0F]
	bit 7, a
	jr nz, jr_000_69b5

;>         rNR30 = 0
;>         rNR30 = 0x80
	xor a
	ldh [c], a
	ld a, $80
	ldh [c], a

jr_000_69b5:
;> if wSndChannel == 3:
;>@w1     nrx2 = mem[ch + 8]                          # volume
;>@w2     nrx1 = 0xEF if mem[wChannel3 + 8] & 0x80 else 0
;> else:
	inc c
	inc l
;=@w1
	inc l
	inc l
	inc l
	ld a, [hli]
	ld e, a
	ld d, $00
;=@w2
	ld a, [wChannel3 + $08]
	bit 7, a
	jr z, jr_000_69de

	ld d, $ef
	jr jr_000_69de

;=@reg
jr_000_69c9:
	ld c, $16
	jr jr_000_69d2

jr_000_69cd:
	ld c, $10
	ld a, $00
	inc c

jr_000_69d2:
;>@left     nrx2 = mem[ch + 6] if mem[ch + 7] == 0 else e_left   # (a quirk: a leftover register)
	inc l
	inc l
	inc l
	ld a, [hld]
	and a
	jr nz, jr_000_6a22

	ld a, [hli]
	ld e, a

jr_000_69db:
;>     nrx1 = mem[ch + 8]
	inc l
	ld a, [hli]
	ld d, a

jr_000_69de:
;> if mem[ch + 0x0B]:                              # a rest: silent envelope
	push hl
	inc l
	inc l
	ld a, [hli]
	and a
	jr z, jr_000_69e7

;>     nrx2 = 0x08
	ld e, $08

jr_000_69e7:
;> mem[ch + 0x0E] = 0                              # vibrato counter
	inc l
	inc l
	ld [hl], $00
	inc l
;> if not mem[ch + 0x0F] & 0x80:                   # unless a sound effect owns the channel
	ld a, [hl]
	pop hl
	bit 7, a
	jr nz, jr_000_69ff

;>     mem[0xFF00 + reg] = nrx1
;>     mem[0xFF00 + reg + 1] = nrx2
;>     mem[0xFF00 + reg + 2] = mem[ch + 9]
;>     mem[0xFF00 + reg + 3] = mem[ch + 0x0A] | 0xC0      # trigger
	ld a, d
	ldh [c], a
	inc c
	ld a, e
	ldh [c], a
	inc c
	ld a, [hli]
	ldh [c], a
	inc c
	ld a, [hl]
	or $c0
	ldh [c], a

jr_000_69ff:
;> mem[ch + 2] = mem[ch + 3]                       # the note timer: the note length
;> return NextChannel(ch)                          # falls through
	pop hl
	dec l
	ld a, [hld]
	ld [hld], a
	dec l

;@ def NextChannel(ch: hl)
;@ path: sound/music
;@ After channel 4 the frame is done (three channel counters at $xE go up);
;@ otherwise the next channel's turn.
;@ writes: wSndChannel
;@ test: skip goes on with the next channel
;@ sig: 36b89c8f
NextChannel::
;> if wSndChannel != 4:
	ld de, wSndChannel
	ld a, [de]
	cp $04
	jr z, jr_000_6a15

;>     wSndChannel += 1
;>     return UpdateChannel(ch + 16)
	inc a
	ld [de], a
	ld a, $10
	add l
	ld l, a
	jp UpdateChannel


jr_000_6a15:
;> for counter in (0xDF9E, 0xDFAE, 0xDFBE):
;>     mem[counter] += 1
	ld hl, wChannel1 + $0E
	inc [hl]
	ld hl, wChannel2 + $0E
	inc [hl]
	ld hl, wChannel3 + $0E
	inc [hl]
	ret


jr_000_6a22:
;=@ReadPattern.left
	ld b, $00
	push hl
	pop hl
	inc l
	jr jr_000_69db

;@ def VibratoOffset(count: b, table: de) -> e
;@ path: sound/music
;@ Byte count / 2 of the vibrato table.
;@ test: count = rand(0, 255)
;@ test: table = 0x6DCB
;@ sig: b6c10ea3
VibratoOffset::
;> idx = count >> 1
	ld a, b
	srl a
;> p = table + idx
	ld l, a
	ld h, $00
	add hl, de
;> return mem[p]
	ld e, [hl]
	ret



;@ def UpdateVibrato(timer: hl)
;@ path: sound/music
;@ Channels 1-3 with a vibrato type (low nibble of instrument byte +8)
;@ bend the note's frequency: types 1 and 2 by a signed 4-bit offset from
;@ VibratoTable1 / VibratoTable2 (indexed by the note's frame count, high
;@ nibble on even frames), higher types by a fixed -2.
;@ reads: wSndChannel
;@ writes: wSndTemp
;@ test: timer = 0xDF92 + 0x10 * rand(0, 2); wSndChannel = rand(1, 4)
;@ test: ch = timer - 2; mem[ch + 8] = rand(0, 4); mem[ch + 9] = rand(0, 255); mem[ch + 10] = rand(0, 7); mem[ch + 0x0E] = rand(0, 0x1D)
;@ sig: 951b49ba
UpdateVibrato::
;> ch = timer - 2
;> kind = mem[ch + 8] & 0x0F
;> if kind == 0:
;>     return
	push hl
	ld a, l
	add $06
	ld l, a
	ld a, [hl]
	and $0f
	jr z, jr_000_6a54

;> wSndTemp = kind
	ld [wSndTemp], a
;> if wSndChannel == 1: reg = 0x13                  # NR13/NR14
;> elif wSndChannel == 2: reg = 0x18                # NR23/NR24
;> elif wSndChannel == 3: reg = 0x1D                # NR33/NR34
;> else: return
	ld a, [wSndChannel]
	ld c, $13
	cp $01
	jr z, jr_000_6a56

	ld c, $18
	cp $02
	jr z, jr_000_6a56

	ld c, $1d
	cp $03
	jr z, jr_000_6a56

jr_000_6a54:
	pop hl
	ret


jr_000_6a56:
;> base = mem16[ch + 9]
	inc l
	ld a, [hli]
	ld e, a
	ld a, [hl]
	ld d, a
	push de
;> count = mem[ch + 0x0E]
	ld a, l
	add $04
	ld l, a
	ld b, [hl]
;> if kind in (1, 2):
;>@tab     table = VibratoTable1 if kind == 1 else VibratoTable2
;>@off     e = VibratoOffset(count, table)
;>@nib     nibble = (e if count & 1 else e >> 4) & 0x0F  # high nibble first
;>@sign     offset = nibble - 16 if nibble & 8 else nibble
;>@fix else:
;>@fix2     offset = -2
;=@fix
	ld a, [wSndTemp]
	cp $01
	jr z, jr_000_6a7a

	cp $02
	jr z, jr_000_6a75

	cp $03
	jr z, jr_000_6a70

jr_000_6a70:
;=@fix2
	ld hl, $fffe
	jr jr_000_6a96

jr_000_6a75:
;=@tab
	ld de, $6a9f
	jr jr_000_6a7d

jr_000_6a7a:
	ld de, $6abd

jr_000_6a7d:
;=@off
	call VibratoOffset
;=@nib
	bit 0, b
	jr nz, jr_000_6a86

	swap e

jr_000_6a86:
	ld a, e
	and $0f
;=@sign
	bit 3, a
	jr z, jr_000_6a93

	ld h, $ff
	or $f0
	jr jr_000_6a95

jr_000_6a93:
	ld h, $00

jr_000_6a95:
	ld l, a

jr_000_6a96:
;> f = (base + offset) & 0xFFFF
	pop de
	add hl, de
;> mem[0xFF00 + reg] = lo(f)
	ld a, l
	ldh [c], a
;> mem[0xFF00 + reg + 1] = hi(f)
	inc c
	ld a, h
	ldh [c], a
	jr jr_000_6a54

VibratoTable2::
	db $00, $ff, $ff, $fe, $ee, $ed, $dd, $dc, $cc, $cc, $cc, $bb, $bb, $bb, $ba, $aa
	db $aa, $aa, $aa, $99, $99, $99, $99, $99, $99, $99, $99, $99, $99, $99

VibratoTable1::
	db $00, $00
	db $00, $00, $00, $00, $10, $00, $0f, $00, $00, $11, $00, $0f, $f0, $01, $12, $10
	db $ff, $ef, $01, $12, $10, $ff, $ef, $01, $12, $10, $ff, $ef, $01, $12, $10, $ff
	db $ef, $01, $12, $10, $ff, $ef, $01, $12, $10, $ff, $ef, $01, $12, $10, $ff, $ef
	db $01, $12, $10, $ff, $ef, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
	db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
	db $00, $00, $00

NoteFrequencies::
	db $00, $0f, $2c, $00, $9c, $00, $06, $01, $6b, $01, $c9, $01, $23
	db $02, $77, $02, $c6, $02, $12, $03, $56, $03, $9b, $03, $da, $03, $16, $04, $4e
	db $04, $83, $04, $b5, $04, $e5, $04, $11, $05, $3b, $05, $63, $05, $89, $05, $ac
	db $05, $ce, $05, $ed, $05, $0a, $06, $27, $06, $42, $06, $5b, $06, $72, $06, $89
	db $06, $9e, $06, $b2, $06, $c4, $06, $d6, $06, $e7, $06, $f7, $06, $06, $07, $14
	db $07, $21, $07, $2d, $07, $39, $07, $44, $07, $4f, $07, $59, $07, $62, $07, $6b
	db $07, $73, $07, $7b, $07, $83, $07, $8a, $07, $90, $07, $97, $07, $9d, $07, $a2
	db $07, $a7, $07, $ac, $07, $b1, $07, $b6, $07, $ba, $07, $be, $07, $c1, $07, $c4
	db $07, $c8, $07, $cb, $07, $ce, $07, $d1, $07, $d4, $07, $d6, $07, $d9, $07, $db
	db $07, $dd, $07, $df, $07

NoiseNotes::
	db $00, $00, $00, $00, $00, $c0, $61, $00, $3a, $00, $c0
	db $b1, $00, $29, $01, $c0, $a1, $00, $20, $04, $c0, $a1, $00, $f4, $5e, $c0, $71
	db $00, $00, $3f, $c0, $23, $33, $45, $67, $89, $ab, $cd, $ef, $fe, $dc, $ba, $98
	db $8a, $a8, $32, $10

Waveform3::
	db $01, $23, $45, $67, $89, $ab, $cd, $ef, $fe, $dc, $ba, $98
	db $76, $54, $32, $10, $77, $23, $56, $78, $99, $98, $76, $67, $9a, $df, $fe, $c9
	db $85, $77, $77, $77

PauseWave::
	db $11, $23, $56, $78, $99, $98, $76, $67, $9a, $df, $fe, $c9
	db $85, $42, $11, $31, $11, $12, $22, $33, $34, $44, $55, $55, $66, $66, $66, $66
	db $66, $11, $22, $32, $87, $66, $65, $55, $54, $44, $43, $32, $22, $11, $11, $66
	db $61, $11, $66, $66, $01, $02, $04, $08, $10, $20, $06, $0c, $18, $00, $03, $06
	db $0c, $18, $30, $09, $12, $24, $04, $08, $02, $04, $08, $10, $20, $40, $0c, $18
	db $30, $05, $00, $01, $03, $05, $0a, $14, $28, $50, $0f, $1e, $3c, $03, $06, $0c
	db $18, $30, $60, $12, $24, $48, $08, $10, $01, $04, $02, $03, $07, $0e, $1c, $38
	db $70, $15, $2a, $54, $09, $12, $01, $02, $04, $08, $10, $20, $40, $80, $18, $30
	db $60, $0a, $15, $01, $02, $c0, $04, $09, $12, $24, $48, $90, $1b, $36, $6c, $0c
	db $18

SongPanning::
	db $01, $18, $ff, $fb, $01, $18, $ff, $eb, $01, $20, $ed, $b7, $01, $60, $de
	db $ed, $01, $ff, $de, $ff, $01, $18, $fe, $be, $01, $40, $ff, $f7, $01, $18, $ed
	db $e7, $01, $20, $ff, $f7, $01, $20, $ff, $f7

; Song data of the sound engine (decoded by tools/songdata.py): per song a header,
; a pattern list per channel and the patterns. Lists end with dw $0000 (song over)
; or dw $FFFF, Target (continue there - the loop). Pattern bytes: $9D + 3 = instrument,
; $Ax = note length, $01 = rest, $00 = end, others = notes.

; Song $01: FEVER
;@ path: sound/music/songs
Song01Header::
	db $00
	dw $6c4c
	dw Song01Sq1, Song01Sq2, Song01Wave, Song01Noise

; Song $02: CHILL
;@ path: sound/music/songs
Song02Header::
	db $00
	dw $6c5a
	dw Song02Sq1, Song02Sq2, Song02Wave, Song02Noise

; Song $03: Options screen
;@ path: sound/music/songs
Song03Header::
	db $00
	dw $6c4c
	dw Song03Sq1, Song03Sq2, Song03Wave, Song03Noise

; Song $04
;@ path: sound/music/songs
Song04Header::
	db $00
	dw $6c4c
	dw Song04Sq1, Song04Sq2, Song04Wave, Song04Noise

; Song $05
;@ path: sound/music/songs
Song05Header::
	db $00
	dw $6c4c
	dw Song05Sq1, Song05Sq2, Song05Wave, Song05Noise

; Song $06
;@ path: sound/music/songs
Song06Header::
	db $00
	dw $6c4c
	dw Song06Sq1, Song06Sq2, Song06Wave, Song06Noise

; Song $07: Silence (music OFF, demo)
;@ path: sound/music/songs
Song07Header::
	db $00
	dw $6c4c
	dw $0000, $0000, $0000, $0000

; Song $08
;@ path: sound/music/songs
Song08Header::
	db $00
	dw $6c4c
	dw Song08Sq1, Song08Sq2, Song08Wave, Song08Noise

; Song $09
;@ path: sound/music/songs
Song09Header::
	db $00
	dw $6c67
	dw Song09Sq1, Song09Sq2, Song09Wave, Song09Noise

; Song $0A
;@ path: sound/music/songs
Song0AHeader::
	db $00
	dw $6c2c
	dw Song0ASq1, Song0ASq2, Song0AWave, Song0ANoise

;@ path: sound/music/songs
Song0ASq1::
	dw Song0APat1, $0000

;@ path: sound/music/songs
Song0ASq2::
; (no end marker: the engine reads on into Song0AWave)
	dw Song0APat2

;@ path: sound/music/songs
Song0AWave::
; (no end marker: the engine reads on into Song0ANoise)
	dw Song0APat3

;@ path: sound/music/songs
Song0ANoise::
; (no end marker: the engine reads on into Song0APat1)
	dw Song0APat4

;@ path: sound/music/songs
Song0APat1::
	db $9d, $72, $00, $80, $a3, $3c, $3c, $3c, $a2, $36, $a3, $3c, $3c, $a2, $36, $3c
	db $36, $a3, $3c, $a3, $3a, $3a, $3a, $a2, $32, $a3, $3a, $3a, $a2, $32, $3a, $32
	db $a3, $3a, $a3, $3c, $3c, $3c, $a2, $36, $a3, $3c, $3c, $a2, $36, $3c, $36, $a3
	db $3c, $a2, $40, $4e, $01, $4e, $aa, $4e, $4a, $48, $a2, $58, $3a, $01, $3a, $a4
	db $32, $00

;@ path: sound/music/songs
Song0APat2::
	db $9d, $92, $00, $80, $a3, $4a, $4a, $4a, $a2, $01, $4a, $01, $a7, $4a, $a3, $4a
	db $4a, $a3, $48, $48, $48, $a2, $01, $48, $01, $a7, $48, $a3, $48, $48, $4a, $4a
	db $4a, $a2, $01, $4a, $01, $a7, $4a, $a3, $4a, $4a, $a2, $48, $54, $01, $54, $aa
	db $54, $52, $4e, $a4, $4a, $01, $00

;@ path: sound/music/songs
Song0APat3::
	db $9d, $f3, $6b, $20, $a4, $36, $a7, $2c, $36, $a3, $01, $2c, $36, $a4, $32, $a7
	db $22, $32, $a3, $01, $22, $32, $a4, $36, $a7, $2c, $36, $a3, $01, $2c, $36, $a7
	db $40, $a2, $40, $aa, $40, $44, $48, $a3, $4a, $40, $a4, $32, $00

;@ path: sound/music/songs
Song0APat4::
	db $9b, $06, $a2, $06, $06, $a3, $0b, $a2, $06, $06, $a3, $0b, $9c, $a7, $06, $a2
	db $06, $aa, $0b, $0b, $0b, $a3, $06, $06, $a4, $0b, $00

;@ path: sound/music/songs
Song01Sq1::
	dw Song01Pat1
Song01Sq1Loop:
	dw Song01Pat2, Song01Pat3, Song01Pat4, Song01Pat5, Song01Pat6, Song01Pat6, Song01Pat7, Song01Pat8, $FFFF, Song01Sq1Loop

;@ path: sound/music/songs
Song01Sq2::
	dw Song01Pat9
Song01Sq2Loop:
	dw Song01Pat10, Song01Pat11, Song01Pat12, Song01Pat13, Song01Pat14, Song01Pat14, Song01Pat7, Song01Pat15, $FFFF, Song01Sq2Loop

;@ path: sound/music/songs
Song01Wave::
	dw Song01Pat16
Song01WaveLoop:
	dw Song01Pat17, Song01Pat18, Song01Pat19, Song01Pat20, Song01Pat21, Song01Pat21, Song01Pat22, Song01Pat23, $FFFF, Song01WaveLoop

;@ path: sound/music/songs
Song01Noise::
	dw Song01Pat24
Song01NoiseLoop:
	dw Song01Pat25, Song01Pat26, Song01Pat27, Song01Pat28, Song01Pat29, Song01Pat30, Song01Pat31, Song01Pat32, $FFFF, Song01NoiseLoop

;@ path: sound/music/songs
Song01Pat2::
	db $9d, $71, $00, $80, $a2, $36, $3a, $36, $3a, $3a, $38, $36, $32, $36, $3a, $36
	db $36, $3a, $01, $9d, $91, $00, $80, $a0, $01, $28, $26, $24, $22, $20, $01, $01
	db $9d, $71, $00, $80, $a2, $36, $3a, $38, $3a, $3a, $38, $36, $3a, $9d, $81, $00
	db $80, $9b, $04, $a1, $28, $28, $a2, $28, $9c, $9d, $71, $00, $80, $a2, $36, $3a
	db $36, $3a, $3a, $38, $36, $32, $36, $3a, $36, $36, $3a, $01, $01, $01, $36, $3a
	db $36, $3a, $3a, $3a, $3a, $3a, $9d, $3b, $00, $80, $a0, $01, $72, $01, $66, $01
	db $01, $60, $01, $01, $4a, $01, $5c, $36, $01, $01, $01, $7e, $72, $6a, $44, $01
	db $3e, $66, $01, $50, $4c, $48, $44, $46, $40, $01, $01, $00

;@ path: sound/music/songs
Song01Pat10::
	db $9d, $81, $00, $80, $a2, $5e, $60, $5e, $60, $5c, $58, $58, $5c, $5e, $60, $5c
	db $58, $58, $01, $9d, $91, $00, $80, $a0, $01, $10, $0e, $0c, $0a, $08, $01, $01
	db $9d, $81, $00, $80, $a2, $5e, $60, $5e, $60, $5c, $58, $58, $5c, $9d, $a1, $00
	db $80, $a1, $18, $18, $a2, $18, $a1, $1a, $1a, $a2, $1a, $a1, $1c, $1c, $a2, $1c
	db $a1, $1e, $1e, $a2, $1e, $9d, $81, $00, $80, $a2, $5e, $60, $5e, $60, $5c, $58
	db $58, $5c, $5e, $60, $5c, $58, $58, $01, $01, $01, $5e, $60, $5e, $60, $5c, $58
	db $58, $5c, $9d, $72, $00, $80, $a1, $7e, $72, $6a, $68, $01, $72, $66, $01, $50
	db $4c, $01, $44, $01, $01, $01, $01, $00

;@ path: sound/music/songs
Song01Pat17::
	db $9d, $f3, $6b, $a0, $a2, $58, $58, $5e, $60, $4a, $4a, $50, $52, $58, $58, $5e
	db $60, $4a, $01, $01, $01, $58, $58, $5e, $60, $4a, $4a, $50, $52, $a1, $28, $28
	db $a2, $28, $a1, $2c, $2c, $a2, $2c, $a1, $2e, $2e, $a2, $2e, $a1, $30, $30, $a2
	db $30, $a2, $58, $58, $5e, $60, $4a, $4a, $50, $52, $58, $58, $5e, $60, $4a, $01
	db $01, $01, $58, $58, $5e, $60, $4a, $4a, $50, $52, $a5, $01, $00

;@ path: sound/music/songs
Song01Pat25::
	db $9b, $06, $a1, $0b, $06, $0b, $01, $9c, $a3, $01, $15, $9b, $04, $a1, $0b, $06
	db $0b, $01, $9c, $a3, $1a, $15, $1a, $15, $9b, $06, $a1, $0b, $06, $0b, $01, $9c
	db $a3, $15, $01, $9b, $04, $a1, $0b, $06, $0b, $01, $9c, $a8, $15, $a3, $1a, $00

;@ path: sound/music/songs
Song01Pat3::
	db $9d, $71, $00, $80, $a1, $40, $40, $a2, $40, $40, $40, $3c, $46, $44, $3c, $a1
	db $40, $40, $a2, $40, $40, $40, $44, $01, $01, $01, $a1, $40, $40, $a2, $40, $40
	db $40, $3c, $46, $44, $3c, $2c, $01, $01, $3e, $40, $01, $3c, $01
Song01Pat5:
	db $9d, $71, $00, $80, $a1, $28, $28, $a2, $32, $30, $2e, $2c, $01, $9d, $92, $00
	db $00, $a3, $24, $9d, $71, $00, $80, $a1, $28, $28, $a2, $32, $30, $2e, $2c, $01
	db $9d, $92, $00, $00, $a3, $26, $9d, $71, $00, $80, $a1, $28, $28, $a2, $28, $28
	db $28, $24, $24, $24, $24, $24, $01, $24, $01, $22, $01, $9d, $92, $00, $c0, $1a
	db $01, $00

;@ path: sound/music/songs
Song01Pat11::
	db $9d, $81, $00, $80, $a2, $50, $52, $50, $52, $4e, $4a, $4a, $44, $50, $52, $4e
	db $4a, $4a, $01, $01, $01, $50, $52, $50, $52, $4e, $4a, $4a, $44, $3e, $44, $48
	db $4e, $4a, $01, $48, $01
Song01Pat13:
	db $9d, $91, $00, $80, $a2, $50, $52, $4e, $4a, $4a, $01, $9d, $a2, $00, $00, $a3
	db $0c, $9d, $91, $00, $80, $a2, $50, $52, $4e, $4a, $4a, $01, $9d, $a2, $00, $00
	db $a3, $0e, $9d, $91, $00, $80, $a2, $50, $52, $50, $52, $4e, $4a, $4a, $44, $4a
	db $01, $4e, $01, $4a, $01, $9d, $a2, $00, $c0, $02, $01, $00

;@ path: sound/music/songs
Song01Pat18::
	db $a2, $32, $32, $38, $3a, $a1, $24, $24, $a2, $24, $2a, $2c, $32, $32, $38, $3a
	db $a1, $24, $24, $a2, $2a, $2c, $34, $32, $32, $38, $3a, $a1, $24, $24, $a2, $24
	db $2a, $2c, $36, $36, $3e, $44, $a1, $40, $40, $a2, $40, $40, $40
Song01Pat20:
	db $9d, $f3, $6b, $a0, $a1, $32, $32, $a2, $32, $38, $3a, $3c, $01, $9d, $f3, $6b
	db $20, $a3, $24, $9d, $f3, $6b, $a0, $a1, $32, $32, $a2, $32, $38, $3a, $3c, $01
	db $9d, $f3, $6b, $20, $a3, $26, $9d, $f3, $6b, $a0, $a1, $3a, $3a, $a2, $3a, $3a
	db $3a, $36, $36, $36, $36, $9b, $02, $a1, $40, $40, $40, $01, $9c, $a2, $32, $01
	db $9d, $f3, $6b, $20, $a3, $32, $00

;@ path: sound/music/songs
Song01Pat26::
	db $9b, $08, $a1, $15, $06, $0b, $01, $1a, $06, $15, $01, $9c
Song01Pat28:
	db $9b, $02, $a1, $15, $06, $0b, $01, $1a, $06, $15, $01, $a1, $1a, $01, $01, $01
	db $15, $01, $01, $01, $9c, $9b, $02, $a1, $15, $06, $0b, $01, $1a, $06, $15, $01
	db $9c, $a3, $15, $1a, $a2, $15, $a1, $15, $15, $a3, $1a, $00

;@ path: sound/music/songs
Song01Pat4::
	db $9d, $72, $00, $c0, $9b, $03, $a2, $32, $28, $32, $36, $32, $28, $40, $28, $9c
	db $3c, $24, $32, $36, $32, $24, $30, $24, $9b, $03, $a2, $32, $28, $32, $36, $32
	db $28, $40, $28, $9c, $3c, $24, $32, $36, $32, $24, $30, $24, $00

;@ path: sound/music/songs
Song01Pat12::
	db $9d, $96, $00, $c1, $a4, $22, $a3, $1e, $28, $a5, $1a, $a4, $2c, $a3, $28, $32
	db $a5, $24, $a4, $22, $a3, $1e, $28, $a5, $1a, $a4, $2c, $a3, $28, $30, $a5, $32
	db $00

;@ path: sound/music/songs
Song01Pat19::
	db $9b, $02, $a2, $32, $32, $40, $a1, $32, $32, $a2, $30, $30, $40, $a1, $30, $30
	db $a2, $2c, $2c, $40, $a1, $2c, $2c, $a2, $28, $28, $40, $a1, $28, $28, $a2, $24
	db $24, $3c, $a1, $24, $24, $a2, $22, $22, $3c, $a1, $22, $22, $a2, $36, $36, $36
	db $a1, $36, $36, $a2, $28, $28, $28, $a1, $28, $28, $9c, $00

;@ path: sound/music/songs
Song01Pat27::
	db $9b, $10, $a1, $06, $06, $0b, $01, $10, $06, $06, $06, $9c, $00

;@ path: sound/music/songs
Song01Pat6::
	db $9d, $81, $00, $c0, $9b, $03, $a2, $02, $02, $08, $0a, $0c, $0c, $0e, $10, $9c
	db $20, $06, $1c, $1a, $18, $16, $14, $12, $00

;@ path: sound/music/songs
Song01Pat14::
	db $9d, $81, $00, $c0, $9b, $03, $a2, $02, $02, $08, $0a, $0c, $0c, $0e, $10, $9c
	db $20, $1e, $1c, $1a, $18, $16, $14, $12, $00

;@ path: sound/music/songs
Song01Pat21::
	db $9b, $03, $a2, $1a, $1a, $20, $22, $24, $24, $26, $28, $9c, $38, $36, $34, $32
	db $30, $2e, $2c, $2a, $00

;@ path: sound/music/songs
Song01Pat29::
	db $9b, $02, $a2, $15, $15, $06, $01, $06, $01, $06, $01, $15, $06, $1a, $1a, $01
	db $01, $06, $10, $9c, $00

;@ path: sound/music/songs
Song01Pat30::
	db $9b, $02, $a2, $15, $06, $1a, $1a, $15, $15, $1a, $10, $15, $06, $1a, $1a, $15
	db $01, $1a, $10, $9c, $00

;@ path: sound/music/songs
Song01Pat1::
	db $9d, $71, $00, $80, $9b, $02, $a2, $10, $10, $16, $18, $1a, $18, $16, $14, $9c
	db $00

;@ path: sound/music/songs
Song01Pat9::
	db $9d, $71, $00, $80, $9b, $02, $a2, $10, $10, $16, $18, $1a, $18, $16, $14, $9c
	db $00

;@ path: sound/music/songs
Song01Pat16::
	db $9d, $f3, $6b, $20, $9b, $02, $a2, $28, $28, $2e, $30, $32, $30, $2e, $2c, $9c
	db $00

;@ path: sound/music/songs
Song01Pat24::
	db $9b, $02, $a2, $15, $15, $a8, $01, $9c, $00

;@ path: sound/music/songs
Song01Pat7::
	db $9b, $03, $a2, $10, $0e, $a8, $01, $9c, $a2, $12, $01, $a8, $01, $00

;@ path: sound/music/songs
Song01Pat22::
	db $9b, $03, $a2, $28, $26, $a8, $01, $9c, $a2, $2a, $01, $a8, $01, $00

;@ path: sound/music/songs
Song01Pat31::
	db $9b, $03, $a2, $15, $15, $a8, $01, $9c, $a3, $15, $01, $01, $15, $00

;@ path: sound/music/songs
Song01Pat8::
	db $9d, $62, $00, $80, $9b, $06, $a1, $58, $58, $4e, $4e, $40, $40, $4e, $4e, $9c
	db $9d, $70, $00, $81, $a8, $40, $a3, $01, $00

;@ path: sound/music/songs
Song01Pat15::
	db $9d, $70, $00, $81, $a4, $48, $4e, $40, $44, $40, $36, $9d, $80, $00, $81, $a8
	db $4e, $a3, $01, $00

;@ path: sound/music/songs
Song01Pat23::
	db $9d, $f3, $6b, $21, $a4, $58, $54, $52, $50, $4a, $48, $a8, $46, $a3, $01, $00

;@ path: sound/music/songs
Song01Pat32::
	db $9b, $03, $a2, $01, $0b, $1a, $06, $01, $06, $1a, $15, $9c, $a9, $01, $15, $1a
	db $15, $1a, $15, $1a, $15, $1a, $a3, $15, $00

;@ path: sound/music/songs
Song02Sq1::
	dw Song02Pat1
Song02Sq1Loop:
	dw Song02Pat2, Song02Pat3, Song02Pat4, Song02Pat5, Song02Pat6, Song02Pat7, Song02Pat8, Song02Pat9, Song02Pat10, Song02Pat11, $FFFF, Song02Sq1Loop

;@ path: sound/music/songs
Song02Sq2::
	dw Song02Pat12
Song02Sq2Loop:
	dw Song02Pat13, Song02Pat14, Song02Pat15, Song02Pat16, Song02Pat17, Song02Pat18, Song02Pat19, Song02Pat20, $FFFF, Song02Sq2Loop

;@ path: sound/music/songs
Song02Wave::
	dw Song02Pat21
Song02WaveLoop:
	dw Song02Pat22, Song02Pat23, Song02Pat24, Song02Pat25, Song02Pat26, Song02Pat27, $FFFF, Song02WaveLoop

;@ path: sound/music/songs
Song02Noise::
	dw Song02Pat28
Song02NoiseLoop:
	dw Song02Pat29, Song02Pat30, Song02Pat31, Song02Pat32, Song02Pat33, Song02Pat34, Song02Pat35, $FFFF, Song02NoiseLoop

;@ path: sound/music/songs
Song02Pat1::
	db $9d, $71, $00, $80, $a2, $01, $6a, $01, $01, $6a, $01, $01, $01, $68, $01, $01
	db $68, $01, $01, $01, $01, $01, $66, $01, $01, $66, $01, $01, $01, $62, $01, $a8
	db $01, $00

;@ path: sound/music/songs
Song02Pat12::
	db $9d, $81, $00, $80, $a2, $01, $70, $01, $01, $70, $01, $01, $01, $6e, $01, $01
	db $6e, $01, $01, $01, $01, $01, $6c, $01, $01, $6c, $01, $01, $01, $6a, $01, $a8
	db $01, $00

;@ path: sound/music/songs
Song02Pat21::
	db $9d, $f3, $6b, $a0, $a2, $44, $44, $4a, $44, $a1, $3a, $3a, $a2, $3a, $40, $42
	db $44, $44, $4a, $44, $3a, $01, $01, $01, $01, $44, $4a, $44, $a1, $3a, $3a, $a2
	db $3a, $40, $3a, $a8, $44, $9d, $f3, $6b, $21, $a0, $3a, $38, $36, $34, $32, $30
	db $2e, $2c, $01, $ab, $01, $00

;@ path: sound/music/songs
Song02Pat28::
	db $a3, $06, $15, $06, $15, $06, $15, $a2, $06, $15, $15, $01, $a3, $06, $15, $06
	db $15, $a2, $0b, $15, $1a, $a1, $01, $1a, $a1, $1a, $1a, $a2, $01, $1a, $01, $00

;@ path: sound/music/songs
Song02Pat2::
	db $9d, $71, $00, $80, $a2, $01, $52, $01, $01, $52, $01, $01, $01, $52, $01, $01
	db $52, $01, $01, $01, $01, $01, $52, $01, $01, $52, $01, $01, $01, $4e, $01, $01
	db $52, $01, $01, $01, $01, $01, $52, $01, $01, $52, $01, $01, $01, $52, $01, $01
	db $52, $01, $01, $01, $01, $01, $52, $01, $01, $52, $01, $01, $01, $9d, $91, $00
	db $83, $ac, $22, $a0, $22, $20, $20, $1e, $a0, $1e, $ac, $1c, $a0, $1c, $1c, $1a
	db $ac, $1a, $a0, $18, $18, $16, $16, $a0, $14, $14, $ac, $12, $a0, $12, $10, $a2
	db $18, $a7, $01, $00

;@ path: sound/music/songs
Song02Pat3::
	db $9d, $71, $00, $83, $a2, $01, $52, $4a, $52, $4a, $a7, $01, $a2, $44, $44, $4a
	db $44, $4a, $a7, $01, $a2, $01, $52, $4a, $52, $58, $01, $56, $4e, $a5, $54, $a2
	db $01, $a1, $52, $52, $a2, $4a, $52, $4a, $a7, $01, $a2, $44, $44, $4a, $44, $3a
	db $a7, $01, $a2, $01, $52, $4a, $52, $58, $01, $56, $4e, $52, $01, $a8, $01, $00

;@ path: sound/music/songs
Song02Pat4::
	db $9d, $70, $00, $81, $a5, $14, $10, $0e, $a8, $0c, $a1, $0c, $01, $01, $01, $00

;@ path: sound/music/songs
Song02Pat5::
	db $9d, $71, $00, $80, $9b, $04, $a2, $01, $74, $01, $01, $74, $01, $01, $01, $74
	db $01, $01, $74, $01, $01, $01, $01, $9c, $00

;@ path: sound/music/songs
Song02Pat13::
	db $9d, $81, $00, $80, $a2, $01, $5c, $01, $01, $5c, $01, $01, $01, $5c, $01, $01
	db $5c, $01, $01, $01, $01, $01, $5c, $01, $01, $5c, $01, $01, $01, $58, $01, $01
	db $5c, $01, $01, $01, $01, $01, $5c, $01, $01, $5c, $01, $01, $01, $5c, $01, $01
	db $5c, $01, $01, $01, $01, $01, $5c, $01, $01, $5c, $01, $01, $01, $9d, $91, $00
	db $80, $ac, $22, $a0, $22, $20, $20, $1e, $a0, $1e, $ac, $1c, $a0, $1c, $1c, $1a
	db $ac, $1a, $a0, $18, $18, $16, $16, $a0, $14, $14, $ac, $12, $a0, $12, $10, $a2
	db $18, $a7, $01, $00

;@ path: sound/music/songs
Song02Pat14::
	db $9d, $81, $00, $80, $a2, $01, $52, $4a, $52, $4a, $a7, $01, $a2, $44, $44, $4a
	db $44, $4a, $a7, $01, $a2, $01, $52, $4a, $52, $58, $01, $56, $4e, $a5, $54, $a2
	db $01, $a1, $52, $52, $a2, $4a, $52, $4a, $a7, $01, $a2, $44, $44, $4a, $44, $3a
	db $a7, $01, $a2, $01, $52, $4a, $52, $58, $01, $56, $4e, $52, $01, $a8, $01, $00

;@ path: sound/music/songs
Song02Pat15::
	db $9d, $71, $00, $80, $9b, $07, $a1, $44, $5c, $44, $44, $5c, $44, $44, $5c, $9c
	db $44, $5c, $44, $44, $5c, $01, $01, $01, $00

;@ path: sound/music/songs
Song02Pat16::
	db $9d, $81, $00, $80, $9b, $04, $a2, $01, $7a, $74, $6a, $7c, $01, $74, $6a, $7e
	db $74, $6a, $7c, $01, $01, $01, $01, $9c, $00

;@ path: sound/music/songs
Song02Pat10::
	db $9d, $72, $00, $80, $00

;@ path: sound/music/songs
Song02Pat20::
	db $9d, $81, $00, $80
Song02Pat11:
	db $9b, $08, $a2, $12, $14, $14, $14, $9c, $9b, $02, $a1, $14, $14, $a2, $14, $1a
	db $1e, $a1, $20, $20, $a2, $20, $1e, $1a, $14, $14, $1a, $01, $14, $14, $1a, $01
	db $a1, $14, $14, $a2, $14, $1a, $1e, $a1, $20, $20, $a2, $20, $1e, $1a, $a3, $14
	db $01, $01, $01, $9c, $00

;@ path: sound/music/songs
Song02Pat35::
	db $9b, $03, $a2, $15, $01, $01, $15, $15, $01, $01, $01, $9c, $15, $01, $01, $15
	db $a1, $1a, $1a, $01, $15, $15, $1a, $1a, $1a, $9b, $02, $a2, $15, $06, $1a, $a1
	db $06, $0b, $a2, $15, $15, $1a, $0b, $15, $15, $1a, $a1, $01, $01, $a2, $15, $15
	db $1a, $01, $15, $06, $1a, $a1, $06, $0b, $a2, $15, $15, $1a, $0b, $15, $01, $01
	db $a1, $15, $06, $a2, $15, $01, $01, $01, $9c, $00

;@ path: sound/music/songs
Song02Pat27::
	db $9d, $f3, $6b, $a0, $9b, $08, $a2, $2a, $2c, $2c, $2c, $9c, $9b, $02, $a1, $2c
	db $2c, $a2, $2c, $32, $36, $a1, $38, $38, $a2, $38, $36, $32, $2c, $2c, $32, $01
	db $2c, $2c, $32, $01, $a1, $2c, $2c, $a2, $2c, $32, $36, $a1, $38, $38, $a2, $38
	db $36, $32, $a3, $2c, $01, $01, $01, $9c, $00

;@ path: sound/music/songs
Song02Pat22::
	db $9d, $f3, $6b, $a0, $9b, $04, $a2, $2c, $2c, $32, $2c, $a1, $22, $22, $a2, $22
	db $28, $2a, $2c, $2c, $32, $2c, $22, $01, $01, $01, $01, $2c, $32, $2c, $a1, $22
	db $22, $a2, $22, $28, $22, $a1, $2c, $2c, $a2, $2c, $32, $2c, $32, $01, $01, $01
	db $9c, $00

;@ path: sound/music/songs
Song02Pat23::
	db $9d, $d3, $6b, $21, $a5, $2c, $32, $36, $a8, $38, $a1, $38, $01, $01, $01, $00

;@ path: sound/music/songs
Song02Pat24::
	db $9d, $f3, $6b, $a0, $9b, $04, $a2, $2c, $2c, $32, $32, $2c, $01, $01, $01, $01
	db $2c, $32, $32, $2c, $01, $01, $01, $9c, $00

;@ path: sound/music/songs
Song02Pat29::
	db $9b, $07, $a2, $15, $06, $1a, $06, $15, $06, $1a, $06, $9c, $15, $06, $1a, $a1
	db $06, $1a, $a1, $1a, $1a, $1a, $1a, $a2, $1a, $01, $00

;@ path: sound/music/songs
Song02Pat30::
	db $9b, $07, $a2, $15, $06, $1a, $06, $15, $06, $1a, $06, $9c, $15, $06, $1a, $0b
	db $a1, $1a, $1a, $a2, $06, $1a, $01, $00

;@ path: sound/music/songs
Song02Pat31::
	db $9b, $02, $a2, $06, $06, $15, $06, $06, $06, $15, $06, $9c, $9b, $04, $15, $06
	db $9c, $a2, $15, $15, $15, $a1, $15, $1a, $a1, $1a, $1a, $1a, $1a, $1a, $01, $01
	db $01, $00

;@ path: sound/music/songs
Song02Pat32::
	db $9b, $04, $a2, $15, $06, $1a, $15, $15, $06, $1a, $06, $15, $06, $1a, $15, $15
	db $01, $01, $01, $9c, $00

;@ path: sound/music/songs
Song02Pat6::
	db $9d, $71, $00, $80, $9b, $03, $a2, $01, $52, $01, $01, $52, $01, $01, $01, $52
	db $01, $01, $52, $01, $01, $a3, $5c, $9c, $a2, $01, $52, $01, $01, $52, $01, $01
	db $5c, $52, $01, $01, $52, $01, $01, $01, $01, $00

;@ path: sound/music/songs
Song02Pat17::
	db $9d, $81, $00, $80, $9b, $03, $a2, $01, $5c, $01, $01, $5c, $01, $01, $01, $5c
	db $01, $01, $5c, $01, $01, $a3, $4e, $9c, $a2, $01, $5c, $01, $01, $5c, $01, $01
	db $01, $5c, $01, $01, $5c, $01, $01, $01, $01, $00

;@ path: sound/music/songs
Song02Pat25::
	db $9b, $03, $a5, $01, $9c, $9d, $f3, $6b, $21, $a8, $01, $a0, $3e, $3c, $3a, $38
	db $36, $34, $32, $30, $01, $ab, $01, $9d, $f3, $6b, $a0, $a1, $2c, $2c, $a2, $2c
	db $2c, $32, $2c, $2c, $2c, $22, $a1, $2c, $2c, $a2, $2c, $2c, $32, $2c, $2e, $2c
	db $2e, $a1, $2c, $2c, $a2, $2c, $2c, $32, $2c, $2c, $2c, $22, $a1, $2c, $2c, $a2
	db $2c, $2c, $32, $01, $01, $01, $01, $00

;@ path: sound/music/songs
Song02Pat33::
	db $a2, $15, $06, $1a, $06, $15, $06, $1a, $0b, $15, $06, $1a, $15, $15, $01, $a1
	db $1a, $1a, $a2, $01, $15, $06, $1a, $06, $15, $06, $1a, $0b, $15, $06, $a0, $1a
	db $1a, $ab, $01, $a0, $1a, $1a, $ab, $01, $a2, $15, $a9, $01, $1a, $1a, $ab, $01
	db $a9, $15, $15, $15, $ab, $01, $9b, $03, $a1, $15, $06, $a2, $01, $1a, $06, $15
	db $06, $1a, $06, $9c, $a2, $15, $06, $1a, $15, $01, $01, $01, $01, $00

;@ path: sound/music/songs
Song02Pat7::
	db $9d, $20, $00, $c3, $aa, $01, $ac, $01, $00

;@ path: sound/music/songs
Song02Pat18::
	db $9d, $70, $00, $81
Song02Pat8:
	db $9b, $08, $a1, $62, $5c, $9c, $a1, $66, $56, $58, $5a, $5c, $60, $62, $60, $01
	db $6a, $66, $62, $60, $5c, $58, $56, $a2, $58, $a0, $56, $52, $ab, $01, $a0, $4e
	db $44, $ab, $01, $a3, $40, $a1, $01, $4a, $3a, $3e, $40, $44, $48, $44, $52, $48
	db $4a, $4e, $52, $56, $58, $56, $01, $5c, $4a, $4e, $52, $56, $58, $56, $5c, $5c
	db $01, $48, $01, $4a, $01, $4e, $52, $4e, $52, $01, $a3, $56, $a1, $5c, $5c, $01
	db $48, $01, $4a, $01, $4e, $52, $4e, $52, $01, $a3, $56, $a9, $56, $62, $66, $ab
	db $01, $a9, $64, $62, $60, $ab, $01, $a9, $5e, $5c, $5a, $ab, $01, $a9, $58, $56
	db $54, $ab, $01, $a9, $52, $50, $4e, $ab, $01, $a9, $4c, $4a, $48, $ab, $01, $a1
	db $46, $44, $42, $40, $a0, $3e, $3c, $ab, $01, $a0, $3a, $38, $ab, $01, $a0, $36
	db $34, $ab, $01, $a0, $32, $30, $ab, $01, $a6, $5c, $a1, $66, $a2, $64, $60, $5c
	db $60, $56, $58, $5c, $66, $64, $a4, $66, $a2, $01, $00

;@ path: sound/music/songs
Song02Pat19::
	db $a6, $60, $a1, $6e, $a2, $6a, $68, $64, $68, $a3, $5c, $60, $6a, $a4, $76, $00

;@ path: sound/music/songs
Song02Pat9::
	db $a6, $60, $a1, $6e, $a2, $6a, $68, $64, $68, $a3, $5c, $5c, $6a, $aa, $76, $01
	db $00

;@ path: sound/music/songs
Song02Pat26::
	db $9b, $06, $a1, $36, $36, $01, $01, $01, $9d, $f3, $6b, $21, $a6, $26, $a3, $28
	db $2c, $a1, $32, $01, $30, $01, $2c, $30, $01, $01, $01, $01, $3c, $3e, $01, $36
	db $01, $1e, $9c, $00

;@ path: sound/music/songs
Song02Pat34::
	db $9b, $06, $a1, $15, $15, $06, $01, $1a, $15, $a2, $06, $15, $06, $1a, $06, $15
	db $06, $1a, $15, $a1, $15, $01, $1a, $1a, $01, $1a, $01, $1a, $9c, $00

;@ path: sound/music/songs
Song03Sq1::
	dw Song03Pat1
Song03Sq1Loop:
	dw Song03Pat2, Song03Pat2, Song03Pat3, $FFFF, Song03Sq1Loop

;@ path: sound/music/songs
Song03Sq2::
	dw Song03Pat4
Song03Sq2Loop:
	dw Song03Pat5, Song03Pat5, Song03Pat6, $FFFF, Song03Sq2Loop

;@ path: sound/music/songs
Song03Wave::
	dw Song03Pat7
Song03WaveLoop:
	dw Song03Pat8, Song03Pat8, Song03Pat9, $FFFF, Song03WaveLoop

;@ path: sound/music/songs
Song03Noise::
	dw Song03Pat10
Song03NoiseLoop:
	dw Song03Pat11, Song03Pat11, Song03Pat12, $FFFF, Song03NoiseLoop

;@ path: sound/music/songs
Song03Pat1::
	db $9d, $71, $00, $80, $a1, $36, $36, $36, $36, $01, $00

;@ path: sound/music/songs
Song03Pat4::
	db $9d, $71, $00, $80, $a1, $40, $40, $40, $40, $01, $00

;@ path: sound/music/songs
Song03Pat7::
	db $9d, $d3, $6b, $20, $a1, $2c, $2c, $2c, $2c, $01, $00

;@ path: sound/music/songs
Song03Pat10::
	db $a1, $0b, $0b, $0b, $0b, $01, $00

;@ path: sound/music/songs
Song03Pat2::
	db $9d, $92, $00, $80, $a3, $4e, $a8, $01, $a9, $4a, $01, $01, $4a, $52, $58, $a3
	db $56, $5c, $9d, $81, $00, $80, $a9, $36, $01, $01, $36, $01, $06, $36, $01, $06
	db $36, $01, $06, $a3, $46, $4a, $44, $9d, $d1, $00, $80, $a3, $26, $00

;@ path: sound/music/songs
Song03Pat5::
	db $9d, $a1, $00, $80, $a3, $40, $a8, $01, $a9, $3a, $01, $01, $3a, $40, $4a, $a3
	db $44, $4e, $9d, $91, $00, $80, $a9, $40, $01, $01, $06, $01, $1e, $06, $01, $1e
	db $06, $01, $1e, $a3, $3a, $40, $3e, $9d, $d1, $00, $80, $a3, $0e, $00

;@ path: sound/music/songs
Song03Pat3::
	db $9d, $82, $00, $80, $a5, $58, $60, $58, $9d, $d1, $00, $80, $a8, $01, $a3, $1a
	db $00

;@ path: sound/music/songs
Song03Pat6::
	db $9d, $92, $00, $80, $a5, $4e, $58, $4e, $9d, $d1, $00, $80, $a8, $01, $a3, $0c
	db $00

;@ path: sound/music/songs
Song03Pat8::
	db $9d, $f3, $6b, $20, $aa, $60, $9d, $d3, $6b, $21, $a9, $66, $68, $66, $68, $01
	db $66, $68, $66, $68, $66, $58, $01, $01, $58, $62, $52, $4e, $01, $01, $a3, $56
	db $9d, $f3, $6b, $20, $a9, $60, $01, $36, $4e, $01, $36, $4e, $01, $36, $4e, $01
	db $36, $32, $01, $32, $38, $01, $38, $36, $01, $01, $a3, $26, $00

;@ path: sound/music/songs
Song03Pat11::
	db $a9, $15, $01, $0b, $1a, $01, $1a, $06, $01, $0b, $06, $01, $15, $15, $01, $0b
	db $1a, $01, $1a, $06, $01, $0b, $06, $01, $15, $15, $01, $0b, $1a, $01, $1a, $06
	db $01, $0b, $06, $01, $1a, $1a, $01, $15, $1a, $01, $15, $1a, $01, $06, $15, $01
	db $01, $00

;@ path: sound/music/songs
Song03Pat9::
	db $9d, $f3, $6b, $20, $9b, $03, $aa, $30, $a9, $32, $a9, $30, $01, $32, $a9, $30
	db $01, $32, $a9, $30, $01, $32, $9c, $aa, $30, $a9, $32, $a9, $30, $01, $32, $a3
	db $01, $24, $00

;@ path: sound/music/songs
Song03Pat12::
	db $a9, $15, $01, $0b, $06, $01, $1a, $15, $01, $0b, $06, $01, $15, $15, $01, $0b
	db $06, $01, $1a, $15, $01, $0b, $06, $01, $01, $15, $01, $0b, $06, $01, $1a, $15
	db $01, $0b, $06, $01, $15, $15, $01, $0b, $06, $01, $1a, $15, $01, $0b, $15, $01
	db $01, $00

;@ path: sound/music/songs
Song04Sq1::
	dw Song04Pat1, $0000

;@ path: sound/music/songs
Song04Sq2::
; (no end marker: the engine reads on into Song04Wave)
	dw Song04Pat2

;@ path: sound/music/songs
Song04Wave::
; (no end marker: the engine reads on into Song04Noise)
	dw Song04Pat3

;@ path: sound/music/songs
Song04Noise::
; (no end marker: the engine reads on into Song04Pat1)
	dw Song04Pat4

;@ path: sound/music/songs
Song04Pat1::
	db $9d, $81, $00, $c0, $ad, $50, $52, $54, $56, $58, $5a, $5c, $5e, $60, $9d, $70
	db $00, $c1, $a1, $50, $01, $a3, $3a, $a4, $3c, $00

;@ path: sound/music/songs
Song04Pat2::
	db $9d, $81, $00, $c0, $ad, $56, $58, $5a, $5c, $5e, $60, $62, $64, $66, $9d, $80
	db $00, $81, $a1, $76, $01, $a3, $48, $a4, $4a, $00

;@ path: sound/music/songs
Song04Pat3::
	db $9d, $d3, $6b, $20, $ad, $60, $62, $64, $66, $68, $6a, $6c, $6e, $70, $9d, $d3
	db $6b, $21, $a1, $58, $01, $a3, $5a, $a4, $5c, $00

;@ path: sound/music/songs
Song04Pat4::
	db $9b, $09, $ad, $06, $9c, $01, $a1, $0b, $01, $a8, $0b, $00

;@ path: sound/music/songs
Song05Sq1::
	dw Song04Pat1, $0000

;@ path: sound/music/songs
Song05Sq2::
; (no end marker: the engine reads on into Song05Wave)
	dw Song04Pat2

;@ path: sound/music/songs
Song05Wave::
; (no end marker: the engine reads on into Song05Noise)
	dw Song04Pat3

;@ path: sound/music/songs
Song05Noise::
; (no end marker: the engine reads on into Song06Pat1)
	dw Song04Pat4

;@ path: sound/music/songs
Song06Pat1::
	db $9d, $71, $00, $80, $a1, $50, $4a, $50, $9d, $70, $00, $81, $a7, $54, $00

;@ path: sound/music/songs
Song06Pat6::
	db $9d, $71, $00, $80, $a1, $62, $5a, $62, $9d, $80, $00, $81, $a7, $66, $00

;@ path: sound/music/songs
Song06Pat10::
	db $9d, $f3, $6b, $a0, $a1, $5a, $5a, $5a, $9d, $f3, $6b, $21, $a7, $5e, $00

;@ path: sound/music/songs
Song06Pat13::
	db $a1, $0b, $0b, $0b, $9b, $04, $a0, $06, $06, $06, $9c, $00

;@ path: sound/music/songs
Song06Sq1::
	dw Song06Pat1, Song06Pat2
Song06Sq1Loop:
	dw Song06Pat3, Song06Pat4, Song06Pat5, $FFFF, Song06Sq1Loop

;@ path: sound/music/songs
Song06Sq2::
	dw Song06Pat6, Song06Pat7
Song06Sq2Loop:
	dw Song06Pat8, Song06Pat9, $FFFF, Song06Sq2Loop

;@ path: sound/music/songs
Song06Wave::
	dw Song06Pat10, Song06Pat11
Song06WaveLoop:
	dw Song06Pat12, $FFFF, Song06WaveLoop

;@ path: sound/music/songs
Song06Noise::
	dw Song06Pat13, Song06Pat14
Song06NoiseLoop:
	dw Song06Pat15, $FFFF, Song06NoiseLoop

;@ path: sound/music/songs
Song06Pat2::
	db $9f, $08, $9e, $4c, $6c, $9d, $71, $00, $c0, $a2, $01, $4a, $4e, $4a, $00

;@ path: sound/music/songs
Song06Pat7::
	db $9d, $81, $00, $c0, $a2, $01, $1a, $1e, $1a, $00

;@ path: sound/music/songs
Song06Pat11::
	db $a4, $01, $00

;@ path: sound/music/songs
Song06Pat14::
	db $a2, $01, $1a, $1a, $1a, $00

;@ path: sound/music/songs
Song06Pat3::
	db $a2, $5c, $01, $58, $01, $52, $50, $4e, $4a, $4e, $4a, $01, $4a, $01, $01, $01
	db $4a, $4e, $4e, $4e, $4a, $52, $4a, $01, $4a, $9d, $71, $00, $c3, $01, $7a, $62
	db $01, $7a, $01, $9d, $71, $00, $c0, $4a, $4a, $5c, $5c, $58, $58, $50, $50, $4e
	db $4a, $4e, $4a, $01, $44, $01, $01, $01, $40, $4e, $4e, $4e, $4a, $52, $4a, $01
	db $4a, $9d, $71, $00, $c3, $01, $01, $62, $7a, $01, $01, $9d, $71, $00, $c0, $4a
	db $46, $44, $4a, $01, $4a, $01, $01, $01, $01, $40, $4a, $01, $4a, $01, $01, $01
	db $01, $3c, $4a, $01, $4a, $01, $01, $01, $40, $3a, $4a, $01, $4a, $01, $01, $01
	db $01, $44, $4a, $01, $4a, $9d, $71, $00, $c3, $01, $72, $70, $72, $9d, $71, $00
	db $c0, $40, $4a, $01, $4a, $01, $01, $01, $01, $3c, $4a, $01, $4a, $01, $01, $01
	db $40, $a5, $01, $00

;@ path: sound/music/songs
Song06Pat8::
	db $a2, $2c, $01, $28, $01, $22, $20, $1e, $1a, $1e, $1a, $01, $1a, $01, $01, $01
	db $1a, $1e, $1e, $1e, $1a, $22, $1a, $01, $1a, $01, $7a, $62, $01, $7a, $01, $1a
	db $1a, $2c, $2c, $28, $28, $20, $20, $1e, $1a, $1e, $1a, $01, $14, $01, $01, $01
	db $10, $1e, $1e, $1e, $1a, $22, $1a, $01, $1a, $01, $01, $62, $7a, $01, $01, $1a
	db $16, $14, $1a, $01, $1a, $01, $01, $01, $01, $10, $1a, $01, $1a, $01, $01, $01
	db $01, $0c, $1a, $01, $1a, $01, $01, $01, $10, $0a, $1a, $01, $1a, $01, $01, $01
	db $01, $14, $1a, $01, $1a, $01, $72, $70, $72, $10, $1a, $01, $1a, $01, $01, $01
	db $01, $0c, $1a, $01, $1a, $01, $01, $01, $10, $a5, $01, $00

;@ path: sound/music/songs
Song06Pat4::
	db $9d, $71, $00, $c3, $00

;@ path: sound/music/songs
Song06Pat9::
	db $9d, $91, $00, $c0
Song06Pat5:
	db $9b, $02, $a5, $01, $a2, $7a, $62, $01, $7a, $01, $01, $01, $01, $a5, $01, $a2
	db $01, $7a, $62, $01, $7a, $01, $01, $01, $9c, $9b, $03, $a4, $01, $a2, $01, $74
	db $70, $01, $9c, $a4, $01, $a2, $01, $01, $7a, $01, $9b, $03, $a4, $01, $a2, $01
	db $74, $70, $01, $9c, $a2, $72, $72, $72, $72, $a4, $01, $00

;@ path: sound/music/songs
Song06Pat12::
	db $9d, $f3, $6b, $20, $9b, $02, $a3, $32, $a2, $01, $38, $3a, $40, $44, $01, $a3
	db $24, $a2, $01, $2a, $2c, $32, $36, $01, $a3, $28, $a2, $01, $2e, $30, $36, $3a
	db $01, $a3, $32, $a2, $01, $38, $3a, $40, $44, $01, $9c, $a3, $24, $a2, $01, $2a
	db $2c, $01, $32, $01, $a3, $22, $a2, $01, $26, $28, $01, $32, $01, $a3, $1e, $a2
	db $01, $24, $2c, $01, $32, $01, $a3, $1a, $a2, $01, $20, $22, $01, $32, $01, $a3
	db $24, $a2, $01, $2a, $2c, $01, $32, $01, $a3, $22, $a2, $01, $26, $28, $01, $32
	db $01, $a3, $1e, $a2, $01, $24, $2c, $01, $32, $01, $28, $28, $28, $28, $01, $01
	db $01, $01, $00

;@ path: sound/music/songs
Song06Pat15::
	db $9b, $04, $a2, $15, $06, $1a, $1a, $06, $06, $15, $06, $15, $06, $1a, $1a, $06
	db $1a, $1a, $06, $9c, $9b, $03, $15, $06, $06, $15, $15, $06, $1a, $06, $9c, $15
	db $06, $06, $15, $15, $1a, $1a, $01, $9b, $03, $15, $06, $06, $15, $15, $06, $1a
	db $06, $9c, $1a, $15, $15, $15, $01, $1a, $1a, $01, $00

;@ path: sound/music/songs
Song08Sq1::
	dw Song08Pat1, $0000

;@ path: sound/music/songs
Song08Sq2::
; (no end marker: the engine reads on into Song08Wave)
	dw Song08Pat2

;@ path: sound/music/songs
Song08Wave::
; (no end marker: the engine reads on into Song08Noise)
	dw Song08Pat3

;@ path: sound/music/songs
Song08Noise::
; (no end marker: the engine reads on into Song08Pat1)
	dw Song08Pat4

;@ path: sound/music/songs
Song08Pat1::
	db $9d, $b2, $00, $c0, $a0, $06, $01, $3e, $a6, $01, $ac, $01, $2a, $ac, $01, $26
	db $ac, $01, $2e, $00

;@ path: sound/music/songs
Song08Pat2::
	db $9d, $c2, $00, $c0, $a0, $0a, $01, $44, $a6, $01, $ac, $01, $2c, $ac, $01, $28
	db $ac, $01, $30, $00

;@ path: sound/music/songs
Song08Pat3::
	db $9d, $f3, $6b, $20, $a0, $28, $01, $60, $a6, $01, $9b, $03, $ac, $01, $1e, $9c
	db $00

;@ path: sound/music/songs
Song08Pat4::
	db $a0, $15, $01, $10, $a6, $01, $9b, $03, $ac, $01, $10, $9c, $00

;@ path: sound/music/songs
Song09Sq1::
	dw Song09Pat1, Song09Pat2, Song09Pat3, Song09Pat4, Song09Pat5, Song09Pat4, Song09Pat2, Song09Pat3, Song09Pat4, Song09Pat5, Song09Pat4
Song09Sq1Loop:
	dw Song09Pat2, Song09Pat4, Song09Pat4, $FFFF, Song09Sq1Loop

;@ path: sound/music/songs
Song09Sq2::
	dw Song09Pat6, Song09Pat7, Song09Pat8, Song09Pat9, Song09Pat10, Song09Pat11, Song09Pat7, Song09Pat8, Song09Pat9, Song09Pat10, Song09Pat11
Song09Sq2Loop:
	dw Song09Pat7, Song09Pat9, Song09Pat11, $FFFF, Song09Sq2Loop

;@ path: sound/music/songs
Song09Wave::
	dw Song09Pat12, Song09Pat13, Song09Pat14, Song09Pat15, Song09Pat16, Song09Pat15, Song09Pat13, Song09Pat14, Song09Pat15, Song09Pat16, Song09Pat17
Song09WaveLoop:
	dw Song09Pat13, Song09Pat15, Song09Pat17, $FFFF, Song09WaveLoop

;@ path: sound/music/songs
Song09Noise::
	dw Song09Pat18, Song09Pat19, Song09Pat20, Song09Pat21, Song09Pat22, Song09Pat21, Song09Pat19, Song09Pat20, Song09Pat21, Song09Pat22, Song09Pat23
Song09NoiseLoop:
	dw Song09Pat19, Song09Pat21, Song09Pat23, $FFFF, Song09NoiseLoop

;@ path: sound/music/songs
Song09Pat1::
	db $9d, $20, $00, $83, $9b, $05, $a2, $70, $6e, $66, $62, $9c, $a8, $01, $00

;@ path: sound/music/songs
Song09Pat6::
	db $9d, $25, $00, $80, $a2, $70, $6e, $66, $62, $9d, $45, $00, $80, $a2, $70, $6e
	db $66, $62, $9d, $86, $00, $80, $9b, $03, $a2, $70, $6e, $66, $62, $9c, $a8, $01
	db $00

;@ path: sound/music/songs
Song09Pat12::
	db $9b, $05, $a4, $01, $9c, $a8, $01, $00

;@ path: sound/music/songs
Song09Pat18::
	db $9b, $05, $a4, $01, $9c, $a8, $01, $00

;@ path: sound/music/songs
Song09Pat5::
	db $9d, $2b, $00, $80, $a9, $01, $72, $00

;@ path: sound/music/songs
Song09Pat16::
	db $a9, $01, $01, $00

;@ path: sound/music/songs
Song09Pat22::
	db $a9, $01, $06, $00

;@ path: sound/music/songs
Song09Pat2::
	db $9d, $65, $00, $80, $a2, $66, $4e, $58, $4e, $5c, $4e, $56, $58, $66, $4e, $58
	db $4e, $5c, $4e, $60, $58, $58, $4e, $5c, $4e, $66, $4e, $58, $4e, $58, $46, $4a
	db $4e, $4a, $40, $4a, $38, $00

;@ path: sound/music/songs
Song09Pat3::
	db $9d, $2b, $00, $80, $a9, $64, $68, $00

;@ path: sound/music/songs
Song09Pat4::
	db $9d, $75, $00, $80, $a2, $58, $4e, $48, $40, $36, $40, $48, $4e, $56, $4e, $44
	db $3e, $36, $3e, $44, $4e, $58, $52, $4a, $40, $3a, $40, $4a, $52, $58, $50, $4a
	db $40, $50, $40, $4a, $50, $00

;@ path: sound/music/songs
Song09Pat7::
	db $9d, $80, $00, $81, $a2, $60, $62, $66, $6a, $a4, $66, $a2, $58, $5c, $60, $62
	db $a4, $60, $a2, $52, $58, $a3, $58, $a2, $4e, $58, $a3, $58, $a4, $4a, $a3, $48
	db $4e, $00

;@ path: sound/music/songs
Song09Pat8::
	db $9d, $3b, $00, $80, $a9, $66, $6a, $00

;@ path: sound/music/songs
Song09Pat9::
	db $9d, $80, $00, $81, $a5, $60, $a4, $5c, $a3, $58, $56, $a5, $58, $4a, $00

;@ path: sound/music/songs
Song09Pat10::
	db $9d, $2b, $00, $80, $a9, $01, $74, $00

;@ path: sound/music/songs
Song09Pat11::
	db $9d, $80, $00, $81, $a5, $60, $a4, $5c, $66, $a5, $70, $74, $00

;@ path: sound/music/songs
Song09Pat13::
	db $9d, $f3, $6b, $21, $a4, $58, $56, $52, $4e, $4a, $48, $46, $a3, $44, $42, $00

;@ path: sound/music/songs
Song09Pat14::
	db $a9, $01, $01, $00

;@ path: sound/music/songs
Song09Pat15::
	db $9d, $f3, $6b, $21, $9b, $03, $a4, $28, $40, $9c, $28, $a3, $40, $28, $00

;@ path: sound/music/songs
Song09Pat19::
	db $9b, $03, $a3, $15, $06, $1a, $06, $9c, $15, $01, $15, $15, $00

;@ path: sound/music/songs
Song09Pat20::
	db $a9, $06, $06, $00

;@ path: sound/music/songs
Song09Pat21::
	db $9b, $03, $a3, $15, $06, $1a, $06, $9c, $15, $01, $15, $15, $00

;@ path: sound/music/songs
Song09Pat17::
	db $a4, $28, $40, $28, $40, $48, $4a, $aa, $38, $36, $32, $ab, $01, $aa, $2e, $9d
	db $f3, $6b, $20, $aa, $2c, $28, $ab, $01, $00

;@ path: sound/music/songs
Song09Pat23::
	db $9b, $03, $a2, $15, $01, $06, $06, $1a, $06, $0b, $01, $9c, $aa, $15, $06, $0b
	db $ab, $01, $aa, $15, $15, $1a, $ab, $01, $00

; (not referenced by any song)
	db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
	db $00, $01, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00

;@ def UpdateSound()
;@ path: sound/api
;@ The sound engine's entry point (from the timer interrupt).
;@ test: skip runs the whole sound engine
;@ sig: 9a8ab392
UpdateSound::
;> return SoundFrame()
	jp SoundFrame


;@ def InitSound()
;@ path: sound/api
;@ The engine's other entry point: stop everything.
;@ test: skip resets the sound engine through SilenceChannels
;@ sig: 865237a5
InitSound::
;> return InitSoundEngine()
	jp InitSoundEngine


	db $c3, $a4, $66, $00, $00, $00, $00, $00, $5a, $00
