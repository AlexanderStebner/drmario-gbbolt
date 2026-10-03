"""Numbers behind the game, read from its tables and worked out by its own routines."""
GROUP = 'charts'


def speed_chart(ctx):
    table = ctx.addr('DropSpeedTable')
    pts = [[i, ctx.rom[table + i]] for i in range(36)]
    return {
        'name': 'chart-drop-speed', 'type': 'chart', 'kind': 'step', 'title': 'Drop speed',
        'subtitle': 'frames per row, by speed index',
        'x': 'speed index (hSpeedIndex)', 'y': 'frames per row',
        'series': [{'name': 'frames the capsule waits per row', 'points': pts}],
        'marks': [{'x': 0, 'label': 'LOW'}, {'x': 9, 'label': 'MED'}, {'x': 20, 'label': 'HI'}],
        'doc': ['How long the capsule waits before dropping a row (DropSpeedTable). A level starts '
                'at index 0 (LOW), 9 (MED) or 20 (HI), plus the virus level above 20 (LevelInit); '
                'every 10 capsules SpeedUp moves one step on, up to index 35: 5 frames, 12 rows a second.'],
        'users': ['SetDropSpeed', 'SpeedUp', 'LevelInit'],
    }


def chain_chart(ctx):
    run = ctx.runner()
    series = []
    for name, base in (('LOW', 1), ('MED', 2), ('HI', 3)):
        pts = []
        for combo in range(6):
            run.set('hCombo', combo)
            run.cpu.d = base
            run.call('ComboPoints', d=base)
            d = run.cpu.d
            pts.append([combo + 1, 100 * int('{:x}'.format(d))])   # BCD hundreds
        series.append({'name': name, 'points': pts})
    return {
        'name': 'chart-chain-points', 'type': 'chart', 'kind': 'bar', 'title': 'Points per virus',
        'subtitle': 'doubling along a chain',
        'x': 'virus number in the chain', 'y': 'points',
        'series': series,
        'doc': ['What one cleared virus is worth (ScoreVirus): 100 x 1 / 2 / 3 for LOW / MED / HI, '
                'doubled for every virus cleared earlier in the same chain, up to 5 times '
                '(ComboPoints, run here for each case). Chain reactions after the '
                'halves fall keep the count going (hCombo), so a big combo is worth a lot.'],
        'users': ['ScoreVirus', 'ComboPoints'],
    }


def virus_charts(ctx):
    rows_mask, cols_mask = ctx.addr('VirusRowMasks'), ctx.addr('VirusColMasks')
    count, height = [], []
    for level in range(21):
        count.append([level, min(4 * (level + 1), 84)])
        b, c = ctx.rom[rows_mask + level], ctx.rom[cols_mask + level]
        top = min(0x7F - ((((d << 4) | (d >> 4)) & 0xFF & b) + (d & c)) for d in range(256))
        height.append([level, 16 - (top >> 3)])
    return [{
        'name': 'chart-viruses-per-level', 'type': 'chart', 'kind': 'bar', 'title': 'Viruses per level',
        'subtitle': '4 x (level + 1)',
        'x': 'virus level', 'y': 'viruses',
        'series': [{'name': 'viruses in the bottle', 'points': count}],
        'doc': ['A level has 4 x (level + 1) viruses (VirusCountForLevel), 84 at level 20; past 20 '
                'the count stays at 84 (LevelInit caps the level at 20 for this).'],
        'users': ['VirusCountForLevel', 'LevelInit'],
    }, {
        'name': 'chart-virus-height', 'type': 'chart', 'kind': 'bar', 'title': 'How high the viruses go',
        'subtitle': 'rows of the bottle they can fill',
        'x': 'virus level', 'y': 'rows from the bottom',
        'series': [{'name': 'highest row a virus can be placed in', 'points': height}],
        'doc': ['PlaceOneVirus picks a random start cell counted back from the bottom: $7F minus '
                '(DIV swapped & VirusRowMasks[level]) plus (DIV & VirusColMasks[level]), then scans '
                'down to the first cell that takes a virus. The masks grow with the level, so easy '
                'levels keep the viruses in the lower part of the bottle (computed here over all 256 '
                'DIV values).'],
        'users': ['PlaceOneVirus', 'TryPlaceVirus'],
    }]


def capsule_table(ctx):
    import site_gen
    sprites = site_gen.render_sprites(ctx.project, 24)
    tiles = ctx.tileset('LoadGameTiles')
    run = ctx.runner()
    hits = [0] * 12
    for div in range(256):
        run.set(0xFF04, div)
        run.call('Random')
        hits[run.cpu.a // 2] += 1
    rows = []
    for k in range(12):
        sid = 2 * k
        entries = sprites[sid]
        img = [[255] * 16 for _ in range(8)]
        x0 = min(e[1] for e in entries) if entries else 0
        for y, x, t, attr in entries:
            for r in range(8):
                lo, hi = tiles[t * 16 + 2 * r], tiles[t * 16 + 2 * r + 1]
                for cx in range(8):
                    bit = cx if attr & 0x20 else 7 - cx
                    v = ((hi >> bit) & 1) << 1 | ((lo >> bit) & 1)
                    if v and 0 <= x - x0 + cx < 16:
                        img[r][x - x0 + cx] = v
        rows.append([{'image': {'width': 16, 'height': 8, 'pixels': ctx.pixels(img)}},
                     '${:02X}'.format(sid), hits[k], '{:.1f} %'.format(100 * hits[k] / 256)])
    return {
        'name': 'table-capsule-odds', 'type': 'table', 'title': 'Capsule odds',
        'subtitle': 'how often each capsule comes up',
        'columns': ['capsule', 'sprite', 'DIV values', 'chance'],
        'rows': rows,
        'doc': ['Random counts DIV - 1 steps through the 12 capsules (sprite ids $00-$16) and takes '
                'where it stops; run here for all 256 DIV values. 256 is not a multiple of 12, so the '
                'first four capsules are a little more likely. RandomCapsule also re-rolls some '
                'repeats, and link and demo games deal from a fixed list instead (wCapsuleList).'],
        'users': ['Random', 'RandomCapsule', 'NextCapsule'],
    }


def build(ctx):
    return [speed_chart(ctx), chain_chart(ctx)] + virus_charts(ctx) + [capsule_table(ctx)]
