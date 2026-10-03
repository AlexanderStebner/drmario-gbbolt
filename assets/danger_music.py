"""The link game's danger music: FEVER and CHILL at danger levels 0-3.

MainLoop sets the timer modulo from hDangerLevel (rTMA $BF / $C8 / $D0 / $D8), so the
sound engine, which runs from the timer interrupt, plays faster; and ReadPattern raises
every note by one step per level, at level 3 more and more while it lasts
(wTempoCount). Here the engine runs at each tempo with wDangerLevel set every update,
as MainLoop does.
"""
GROUP = 'sound'

TMA = [0xBF, 0xC8, 0xD0, 0xD8]
SONGS = [(1, 'FEVER'), (2, 'CHILL')]


def build(ctx):
    tracks = []
    for song, title in SONGS:
        for level, tma in enumerate(TMA):
            hz = 4096 / (256 - tma)
            secs = 90 if level == 3 else 40
            a = ctx.audio('music', song, '{}_{}'.format(title.lower(), level), pokes={'wDangerLevel': level},
                          hz=hz, max_seconds=secs, loops=False)
            note = 'tempo {:.0f}%, notes +{} step{}'.format(100 * hz / (4096 / (256 - 0xBF)), level, '' if level == 1 else 's')
            if level == 0:
                note = 'normal'
            if level == 3:
                note += ', then climbing up to 31 more'
            tracks.append({'title': '{} at danger level {}'.format(title, level), 'note': note,
                           'file': a['file'], 'seconds': a['seconds']})
    return [{
        'name': 'danger-music', 'type': 'tracks', 'title': 'Danger music simulator',
        'subtitle': 'FEVER and CHILL as the other player gets closer',
        'tracks': tracks,
        'doc': ['In a link game the music tells you how close the other player is to winning. '
                'RemovePops sets hDangerLevel 0-3 from the other side\'s viruses left (against a '
                'quarter, an eighth and a sixteenth of its start count, hVirusThresholds). MainLoop '
                'turns it into the timer modulo rTMA ($BF, $C8, $D0, $D8): the sound engine runs from '
                'the timer interrupt, so the whole song speeds up (63, 73, 85, 102 updates a second).',
                'ReadPattern also raises every note by one step of the note table per level; at '
                'level 3 it adds one more step for every 256 updates spent there (wTempoCount, up to '
                '31), so the song keeps climbing until the round ends.',
                'Recorded with the game\'s own sound engine running at each tempo, wDangerLevel set '
                'before every update like MainLoop does.'],
        'users': ['MainLoop', 'RemovePops', 'ReadPattern', 'UpdateMusic'],
    }]
