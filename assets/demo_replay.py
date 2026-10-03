"""The title demo, played by the game's own code: TitleInit, the countdown, then the demo
(DemoInputs pressed by DemoPlayback, the fixed DemoBottle and capsules) until EndDemo."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _game  # noqa: E402

GROUP = 'replays'


def build(ctx):
    run = ctx.runner()
    _game.boot(run)
    frames, held = [], []
    demo_started = False
    for f in range(60 * 120):
        if f == 120:                       # 2 s of title, then skip the rest of the countdown
            run.set('hTimer1', 0)
            run.set('hDemoTimer', 1)
        _game.frame(run)
        state = run.get('hGameState')
        demo_started = demo_started or state not in (0, 1)
        held.append(run.get('hDemoButtons') if demo_started else 0)
        frames.append(run.screen())
        if demo_started and state == 0:    # EndDemo: back to the title
            break
    url = ctx.video(frames, 'demo')
    poster = ctx.poster(frames[min(len(frames) - 1, 60 * 12)], 'demo_poster')
    seconds = len(frames) / 60
    return [{
        'name': 'demo-replay', 'type': 'video', 'title': 'Title demo replay',
        'subtitle': '{:.0f} s · from the game\'s own code'.format(seconds),
        'file': url, 'poster': poster, 'width': 160, 'height': 144, 'fps': 60,
        'lanes': _game.lanes(held),
        'doc': ['The demo that starts when the title screen is left alone, recorded by running '
                'the game\'s own code frame by frame: RunGameState, then the VBlank handler, '
                'like MainLoop. DemoPlayback presses the buttons from DemoInputs; '
                'PlaceVirusesDemo loads DemoBottle and LoadDemoCapsules the capsules, so it '
                'plays out the same every time. It stops at EndDemo.',
                'The lanes under the video are the buttons the demo holds.'],
        'users': ['DemoPlayback', 'PlaceVirusesDemo', 'LoadDemoCapsules', 'EndDemo', 'TitleScreen'],
    }]
