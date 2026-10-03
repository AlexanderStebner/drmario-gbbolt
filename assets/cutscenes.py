"""The underwater cutscenes, played by the game's own code, with their music (song 9)."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _game  # noqa: E402

GROUP = 'animations'

SCENES = [  # game state, name, title, when, longest run in seconds
    (0x08, 'turtle', 'Turtle', 'after level 5 on HI speed', 60),
    (0x13, 'crab', 'Crab', 'after level 10 on HI speed', 60),
    (0x18, 'swordfish', 'Swordfish', 'after level 15 on HI speed', 60),
    (0x07, 'snail', 'Snail', 'the MED speed ending (level 20 cleared)', 60),
    (0x1B, 'low-ending', 'LOW ending', 'the LOW speed ending (level 20 cleared)', 30),
    (0x1A, 'coelacanth', 'Coelacanth', 'the HI speed ending (level 20 cleared)', 75),
]
CODE = {0x07: 'CutsceneEndingMED', 0x08: 'CutsceneTurtle5', 0x13: 'CutsceneCrab10',
        0x18: 'CutsceneSwordfish15', 0x1A: 'CutsceneEndingHI', 0x1B: 'CutsceneEndingLOW'}


def build(ctx):
    song = ctx.audio('music', 9, 'song9', max_seconds=80, loops=False)
    out = []
    for state, name, title, when, longest in SCENES:
        run = ctx.runner()
        _game.boot(run)
        run.call('InitGameScreen')         # a level was played before: its variables are set up
        run.call('ClearShadowOAM')         # NextLevelOrCutscene clears the sprites
        run.set('hGameState', state)
        run.set('hCutscenePhase', 0)
        frames, done_at = [], None
        for f in range(60 * longest):
            _game.frame(run)
            frames.append(run.screen())
            if done_at is None and state != 0x1A and run.get('hCutscenePhase') >= 4:
                done_at = f
            if done_at is not None and f > done_at + 120:
                break
        url = ctx.video(frames, name, audio=song['path'])
        out.append({
            'name': 'cutscene-' + name, 'type': 'video', 'title': 'Cutscene: ' + title,
            'subtitle': '{} · {:.0f} s'.format(when, len(frames) / 60),
            'file': url, 'poster': ctx.poster(frames[min(len(frames) - 1, 60 * 6)], name + '_poster'),
            'width': 160, 'height': 144, 'fps': 60,
            'doc': ['The cutscene ' + when + ', recorded by running its game state ({}) frame by frame '
                    'together with the VBlank handler (which animates the water and '
                    'types the text). The sound is song 9, rendered from the game\'s sound engine.'.format(CODE[state])],
            'users': [CODE[state], 'LoadUnderwaterScreen', 'TypeEndingText', 'VBlankDraw'],
        })
    return out
