"""Shared helpers for Dr. Mario's asset plugins: set the machine up like Start does and
run one frame the way MainLoop and the VBlank interrupt would."""


def boot(run):
    """What Start leaves behind (palettes, tiles, the OAM DMA routine in HRAM)."""
    run.set(0xFF47, 0xE1)          # rBGP
    run.set(0xFF48, 0xE1)          # rOBP0
    run.set(0xFF49, 0xE5)          # rOBP1
    run.copy_in('hOAMDMA', run.mem[0x2386:0x2390])
    run.call('ClearBGMap0')
    run.call('InitSound')
    run.call('LoadGameTiles')
    run.set(0xFF40, 0x80)
    run.set('hGameState', 0)


TIMER_HZ = 4096 / (256 - 0xBF)    # the timer interrupt (rTMA $BF), which runs the sound engine
FRAME_HZ = 4194304 / 70224


def frame(run):
    """One frame of MainLoop (without joypad and link), the timer interrupts that fall into
    it (the sound engine: it also sets wSongBeat, which the magnifier viruses dance to)
    and the VBlank handler."""
    run.timer_acc = getattr(run, 'timer_acc', 0.0) + TIMER_HZ / FRAME_HZ
    while run.timer_acc >= 1:
        run.timer_acc -= 1
        run.call('TimerHandler')
    run.call('RunGameState')
    for t in ('hTimer1', 'hTimer2'):
        if run.get(t):
            run.set(t, run.get(t) - 1)
    for n in ('hFrameCount', 'hDanceTimer1', 'hDanceTimer2', 'hDanceTimer3'):
        run.set(n, run.get(n) + 1)
    run.call('VBlankHandler')


BUTTONS = [('A', 0x01), ('B', 0x02), ('Select', 0x04), ('Start', 0x08),
           ('Right', 0x10), ('Left', 0x20), ('Up', 0x40), ('Down', 0x80)]


def lanes(held_per_frame):
    """Button lanes (frame spans) from the buttons held in each frame."""
    out = []
    for name, bit in BUTTONS:
        spans, start = [], None
        for f, b in enumerate(held_per_frame + [0]):
            if b & bit and start is None:
                start = f
            elif not b & bit and start is not None:
                spans.append([start, f])
                start = None
        if spans:
            out.append({'name': name, 'spans': spans})
    return out
