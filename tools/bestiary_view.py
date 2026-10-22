#!/usr/bin/env python3
"""bestiary_view.py — a self-contained HTML bestiary with a variant selector.

Why: the interesting question about a creature is "what does the game actually draw
for it, and what did the other versions draw?" That is a visual question, and a TSV
cannot answer it. This builds one HTML file with every image embedded as a data URI,
so it opens from disk and makes no network requests — same shape as
tools/map_viewer.py.

For each creature it shows:
  * our own tile, decoded from original/ultimaii.exe (the ground truth of this project)
  * the community art for the variant you pick: C64, DOS, DOS CGA/EGA, FM Towns,
    PC-88 Starcraft, Gamer Corner. Animated FM Towns GIFs get their extracted frame
    strip as well, so the animation is visible without a GIF decoder.
  * the match verdict from bestiary_match.py, and the stats from both sources side by
    side, because they disagree (Guard HP is 255 on the codex and 500 on Gamer Corner)
    and a viewer that hides a conflict is worse than one that shows it.

Output is GAME CONTENT: it embeds copyrighted rips and the extracted originals. It
writes to bestiary/view.html, which is gitignored, and refuses to write anywhere else.
It is forbidden to anyone drawing substitute art (docs/tile-art-spec.md section 2).

Usage:
    python3 tools/bestiary_fetch.py
    python3 tools/bestiary_match.py
    python3 tools/bestiary_view.py            # -> bestiary/view.html
    python3 tools/bestiary_view.py --scale 6
"""
import argparse
import base64
import json
import os
import struct
import sys

from PIL import Image

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IDX_OFF, PIX_OFF, N_TILES = 0x7BC0, 0x7C42, 64
PAL = [(0, 0, 0), (0, 170, 170), (170, 0, 170), (255, 255, 255)]
VARIANT_ORDER = ['dos', 'dos-cga', 'dos-ega', 'dos-fan-upgrade', 'gamercorner-dos',
                 'c64', 'pc88-starcraft', 'fm-towns']
VARIANT_LABEL = {
    'dos': 'DOS (1983)', 'dos-cga': 'DOS CGA', 'dos-ega': 'DOS EGA',
    'dos-fan-upgrade': 'DOS fan upgrade', 'gamercorner-dos': 'Gamer Corner DOS',
    'c64': 'C64', 'pc88-starcraft': 'PC-8801 Starcraft', 'fm-towns': 'FM Towns (animated)',
}


def die(msg):
    print('bestiary_view: %s' % msg, file=sys.stderr)
    sys.exit(1)


def load_tiles(exe_path):
    data = open(exe_path, 'rb').read()
    idx = list(struct.unpack('<%dH' % N_TILES, data[IDX_OFF:IDX_OFF + 2 * N_TILES]))
    base = PIX_OFF - 2 - idx[0]
    out = {}
    for n in range(N_TILES):
        off = base + idx[n]
        if (data[off], data[off + 1]) != (0x04, 0x10):
            die('tile %d header is not 04 10 — refusing to render' % n)
        o = off + 2
        im = Image.new('RGB', (16, 16))
        for r in range(16):
            for b in range(4):
                byte = data[o + r * 4 + b]
                for j, s in enumerate((6, 4, 2, 0)):
                    im.putpixel((b * 4 + j, r), PAL[(byte >> s) & 3])
        out[n] = im
    return out


def data_uri(path):
    with open(path, 'rb') as fh:
        blob = fh.read()
    mime = 'image/gif' if path.lower().endswith('.gif') else 'image/png'
    return 'data:%s;base64,%s' % (mime, base64.b64encode(blob).decode())


def tile_uri(im, scale):
    big = im.resize((16 * scale, 16 * scale), Image.NEAREST)
    import io
    buf = io.BytesIO()
    big.save(buf, 'PNG')
    return 'data:image/png;base64,%s' % base64.b64encode(buf.getvalue()).decode()


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--cache', default=os.path.join(PROJECT_ROOT, 'bestiary', 'cache'))
    ap.add_argument('--tsv', default=os.path.join(PROJECT_ROOT, 'bestiary', 'bestiary.tsv'))
    ap.add_argument('--exe', default=os.path.join(PROJECT_ROOT, 'original', 'ultimaii.exe'))
    ap.add_argument('--out', default=os.path.join(PROJECT_ROOT, 'bestiary', 'view.html'))
    ap.add_argument('--scale', type=int, default=4)
    args = ap.parse_args()

    out = os.path.realpath(args.out)
    if out != os.path.realpath(os.path.join(PROJECT_ROOT, 'bestiary', 'view.html')):
        die('--out must be bestiary/view.html (gitignored, copyrighted content); '
            'refusing to write %s' % args.out)
    for p in (args.cache, args.tsv, args.exe):
        if not os.path.exists(p):
            die('%s missing — run bestiary_fetch.py and bestiary_match.py first' % p)

    tiles = load_tiles(args.exe)

    # --- the join -------------------------------------------------------------
    lines = [l for l in open(args.tsv) if not l.startswith('#')]
    cols = lines[0].split('\t')
    rows = [dict(zip(cols, l.rstrip('\n').split('\t'))) for l in lines[1:]]
    by_art = {}
    for r in rows:
        if r['verdict'] in ('exact', 'ambiguous') and r['art_index']:
            for a in r['art_index'].split():
                by_art.setdefault(a, []).append(r)
    # The match tool already normalised the codex columns that lie (the Townsfolk and
    # Dungeons "HP/DMG" pair is really an HP range). The viewer must show the
    # corrected numbers, not the raw ones, or it re-ships a mistake we already made.
    corrected = {}
    for r in rows:
        c = corrected.setdefault(r['name'].lower(), {})
        for key, col in (('HP', 'hp'), ('DMG', 'dmg'), ('Special', 'special')):
            v = r.get(col)
            if not v:
                continue
            cur = c.get(key)
            if cur is None:
                c[key] = v
            elif v not in cur.split(' / '):
                # Sources disagree (Guard is 255-255 on the codex, 500 on Gamer
                # Corner). Show both; a viewer that silently picks one invents a fact.
                c[key] = cur + ' / ' + v

    # --- the art, per creature and variant ------------------------------------
    art = {}
    for src in ('codex.json', 'gamercorner.json'):
        p = os.path.join(args.cache, src)
        if not os.path.exists(p):
            continue
        for rec in json.load(open(p))['records']:
            key = rec['name'].lower()
            entry = art.setdefault(key, {'name': rec['name'], 'images': {}, 'stats': {}})
            entry['images'].update(rec['images'])
            for k, v in rec['stats'].items():
                entry['stats'].setdefault(src + ':' + k, v)
            for k, v in corrected.get(key, {}).items():
                entry['stats'][k] = v

    variants = [v for v in VARIANT_ORDER
                if any(v in e['images'] for e in art.values())]
    if not variants:
        die('no variant images in the cache')

    cards = []
    for key in sorted(art):
        e = art[key]
        matched = []
        for a, rs in by_art.items():
            if any(r['name'].lower() == key for r in rs):
                matched.append(a)
        art_html = ''.join(
            '<figure class="ours"><img src="%s" alt="art %s"/>'
            '<figcaption>ours&nbsp;%s</figcaption></figure>'
            % (tile_uri(tiles[int(a, 16)], args.scale), a, a)
            for a in sorted(matched)) or '<span class="none">no tile matched</span>'
        img_html = ''
        for v in variants:
            meta = e['images'].get(v)
            if not meta or not meta.get('local'):
                continue
            path = os.path.join(args.cache, meta['local'])
            if not os.path.exists(path):
                continue
            extra = ''
            if meta.get('frame_dir'):
                strip = os.path.join(args.cache, meta['frame_dir'], 'strip.png')
                if os.path.exists(strip):
                    extra = ('<div class="strip"><span>%d frames</span>'
                             '<img src="%s" alt="frames"/></div>'
                             % (meta.get('frame_count', 0), data_uri(strip)))
            img_html += ('<figure class="v-%s" data-variant="%s"><img src="%s" '
                         'alt="%s"/><figcaption>%s</figcaption>%s</figure>'
                         % (v.replace('-', '_'), v, data_uri(path), e['name'],
                            VARIANT_LABEL.get(v, v), extra))
        prim = {'HP', 'DMG', 'Special'}
        order = ['HP', 'DMG', 'Special', 'Location (Levels)', 'Item Drop', 'Notes',
                 'Appears on', 'Location', 'Special Notes']
        shown = [k for k in order if k in e['stats']] + \
                [k for k in sorted(e['stats'])
                 if k not in order and k not in prim
                 and k.split(':', 1)[-1] not in (prim | {'prose', 'Name'})]
        stats = ' '.join('<b>%s</b> %s' % (k.split(':', 1)[-1], str(e['stats'][k])[:90])
                         for k in shown)
        prose = e['stats'].get('gamercorner:prose', '')
        cards.append('<section class="card" data-name="%s" data-matched="%s">'
                     '<h3>%s%s</h3><div class="row">%s%s</div>'
                     '<div class="stats">%s</div>%s</section>'
                     % (e['name'], 'yes' if matched else 'no', e['name'],
                        ' <em>%s</em>' % ','.join(sorted(matched)) if matched else '',
                        art_html, img_html or '<span class="none">no art cached</span>',
                        stats,
                        '<p class="prose">%s</p>' % prose[:400] if prose else ''))

    buttons = ''.join('<button data-v="%s" class="vb">%s</button>'
                      % (v, VARIANT_LABEL.get(v, v)) for v in variants)
    html = """<!doctype html><meta charset="utf-8"><title>Ultima II bestiary</title>
<style>
body{background:#111;color:#ddd;font:14px/1.45 system-ui,sans-serif;margin:0;padding:16px}
h1{font-size:19px;margin:0 0 4px}
.note{color:#888;font-size:12px;margin-bottom:12px;max-width:78ch}
.bar{position:sticky;top:0;background:#111;padding:8px 0;z-index:2;border-bottom:1px solid #333}
.vb{background:#222;color:#ccc;border:1px solid #444;padding:5px 9px;cursor:pointer;margin:2px}
.vb.on{background:#0a6;border-color:#0c8;color:#fff;font-weight:600}
input#q{background:#222;border:1px solid #444;color:#eee;padding:5px 8px;width:220px}
.card{border:1px solid #2c2c2c;border-left:3px solid #0a6;margin:10px 0;padding:10px 12px;background:#161616}
.card[data-matched="no"]{border-left-color:#633;opacity:.72}
.card h3{margin:0 0 8px;font-size:15px}.card h3 em{color:#0a6;font-style:normal;font-size:12px}
.row{display:flex;gap:10px;flex-wrap:wrap;align-items:flex-start}
figure{margin:0;text-align:center}
figure img{image-rendering:pixelated;border:1px solid #333;background:#000;display:block}
figcaption{font-size:10px;color:#777;margin-top:3px}
figure.ours img{border-color:#0a6}
.strip{margin-top:4px}.strip span{font-size:9px;color:#0a6;display:block}
.strip img{max-width:260px;height:auto;border:1px solid #084}
.stats{margin-top:8px;font-size:12px;color:#9a9}
.stats b{color:#cde;font-weight:600;margin-right:2px}
.prose{font-size:12px;color:#889;margin:6px 0 0;max-width:90ch}
.none{color:#664;font-size:12px;align-self:center}
</style>
<h1>Ultima II bestiary</h1>
<p class="note">Left (green border) is the tile decoded from <code>original/ultimaii.exe</code>.
The rest is third-party community art for the variant you select. A name is attached only
where a community bitmap is pixel-identical to one of ours; the name itself is third-party
and the binary outranks it. Unmatched cards are dimmed. Generated by
<code>tools/bestiary_view.py</code> &mdash; embeds copyrighted rips, never commit it.</p>
<div class="bar"><input id="q" placeholder="filter by name"/> %s
<span class="note" id="count"></span></div>
%s
<script>
let cur=null;
function apply(){
  const q=document.getElementById('q').value.toLowerCase();
  let n=0;
  document.querySelectorAll('.card').forEach(c=>{
    const show=!q||c.dataset.name.toLowerCase().includes(q);
    c.style.display=show?'':'none'; if(show)n++;
    c.querySelectorAll('figure[data-variant]').forEach(f=>{
      f.style.display=(!cur||f.dataset.variant===cur)?'':'none';});
  });
  document.getElementById('count').textContent=n+' creatures';
}
document.querySelectorAll('.vb').forEach(b=>b.onclick=()=>{
  cur=(cur===b.dataset.v)?null:b.dataset.v;
  document.querySelectorAll('.vb').forEach(x=>x.classList.toggle('on',x===b&&cur));
  apply();});
document.getElementById('q').oninput=apply;
apply();
</script>
""" % (buttons, '\n'.join(cards))
    os.makedirs(os.path.dirname(out), exist_ok=True)
    open(out, 'w').write(html)
    print('wrote %s (%d creatures, %d variants, %.1f MB embedded)'
          % (out, len(cards), len(variants), os.path.getsize(out) / 1e6))
    print('REMINDER: embeds copyrighted art; bestiary/view.html is gitignored.')


if __name__ == '__main__':
    main()
