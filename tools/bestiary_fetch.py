#!/usr/bin/env python3
"""bestiary_fetch.py — collect third-party Ultima II creature data into a local cache.

Why: the executable has no monster *name* table (tools/monster_shapes.py records
this), so the creature behind art index 0x0C can only be described by shape. Two
community sources carry names, stats and per-variant art, and they are independent
of each other:

  * Ultima Codex  — https://wiki.ultimacodex.com/wiki/Ultima_II_monster_data
                    four tables (land / townsfolk / dungeon / NPCs), one column
                    per shipped variant from Apple II 1982 to FM Towns 1990,
                    plus HP, damage, specials and item drops.
  * Gamer Corner  — https://guides.gamercorner.net/ultimaii/creatures/
                    one page per creature with HP, where it appears, prose notes
                    and a single DOS tile image.

Evidence grade: THIRD-PARTY. Everything this writes is somebody else's crowd
summary, not a measurement of our bytes. It sits below `observed` in the
AGENTS.md grading, and where it disagrees with the binary the binary wins. The
point of collecting it is that a *name* and a *bitmap* arrive together, which is
what lets bestiary_match.py join them to our tile table (see docs/bestiary.md).

Licensing: every image here is a copyrighted rip of game art. The cache is
gitignored and must never be committed, exactly like tmp/tiles/. Only our own
derived table (bestiary/bestiary.tsv) is committed, and only as facts plus
attribution. See AGENTS.md "Licensing & Commit Policy".

Cleanroom: bestiary/cache/ holds original art in thirteen variants. It is
forbidden to anyone drawing substitute art; docs/tile-art-spec.md section 2
lists it. Do not point an implementer at this directory.

Writes only inside --cache (default bestiary/cache), and refuses a --cache that
escapes the project root. Network use is rate-limited and every response is
recorded in cache/manifest.json with sha256 + timestamp, so a later run with
--offline reproduces the same parse from what is already on disk.

Usage:
    python3 tools/bestiary_fetch.py                 # fetch + parse + download art
    python3 tools/bestiary_fetch.py --offline       # re-parse the cached HTML
    python3 tools/bestiary_fetch.py --no-frames     # skip GIF frame extraction
    python3 tools/bestiary_fetch.py --limit 3       # first 3 creatures per source
"""
import argparse
import hashlib
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CODEX_URL = 'https://wiki.ultimacodex.com/wiki/Ultima_II_monster_data'
CODEX_BASE = 'https://wiki.ultimacodex.com'
GC_URL = 'https://guides.gamercorner.net/ultimaii/creatures/'
GC_BASE = 'https://guides.gamercorner.net'
USER_AGENT = ('decompile-u2-v2 bestiary fetch/1.0 '
              '(research tool; one-off fetch of two public wiki pages)')

# The four codex tables do not agree on how to name a platform: the land table has
# "DOS" and "DOS fan upgrade", the townsfolk table has "Image DOS (CGA)", the
# dungeon table has "DOS ( CGA )". Left alone they become five different buckets
# for two platforms, and a column that fails to match at all silently drops its
# images into the stats text. So every header goes through one canonical mapper
# and anything unmapped is a stat column, never a silent image sink.
VARIANT_PATTERNS = (
    ('pony canyon', '88', 'pc88-pony-canyon'),
    ('pony canyon', '98', 'pc98-pony-canyon'),
    ('starcraft', '88', 'pc88-starcraft'),
    ('starcraft', '98', 'pc98-starcraft'),
    ('fm towns', None, 'fm-towns'),
    ('apple', None, 'apple-ii'),
    ('atari st', None, 'atari-st'),
    ('atari', None, 'atari-8bit'),
    ('c64', None, 'c64'),
    ('commodore', None, 'c64'),
    ('msx', None, 'msx2'),
    ('mac', None, 'macintosh'),
    ('dos', 'cga', 'dos-cga'),
    ('dos', 'ega', 'dos-ega'),
    ('dos', 'fan upgrade', 'dos-fan-upgrade'),
    ('dos', None, 'dos'),
)


def canonical_variant(header):
    """Map a table header to a platform slug, or None if it is a stat column."""
    h = re.sub(r'\s+', ' ', header.lower()).strip()
    h = re.sub(r'^image\b', '', h).strip()
    h = re.sub(r'\s*\(\s*', ' (', h)
    h = re.sub(r'\s*\)\s*', ') ', h)
    if not h:
        return None
    for needle, extra, slug in VARIANT_PATTERNS:
        if needle not in h:
            continue
        if extra is not None and extra not in h:
            continue
        # "DOS" alone must not swallow "DOS (CGA)"; the more specific rows above
        # are ordered first, and this guard makes that ordering explicit.
        if extra is None and re.search(r'\((cga|ega)\)|fan upgrade', h):
            continue
        return slug
    return None


def die(msg):
    print('bestiary_fetch: %s' % msg, file=sys.stderr)
    sys.exit(1)


def slugify(text):
    s = re.sub(r'\(([^)]*)\)', r' \1 ', text.lower())
    s = re.sub(r'[^a-z0-9]+', '-', s).strip('-')
    return s or 'unnamed'


def strip_tags(html):
    text = re.sub(r'(?s)<(script|style).*?</\1>', '', html)
    text = re.sub(r'<br\s*/?>', ' ', text)
    text = re.sub(r'<[^>]+>', ' ', text)
    text = (text.replace('&amp;', '&').replace('&ndash;', '-')
                .replace('&mdash;', '-').replace('&#91;', '[').replace('&#93;', ']')
                .replace('&nbsp;', ' ').replace('&#160;', ' '))
    # The codex writes en-dashes as &#8211; in some cells and literally in others.
    text = re.sub(r'&#(\d+);', lambda m: chr(int(m.group(1))), text)
    text = re.sub(r'&#x([0-9a-fA-F]+);', lambda m: chr(int(m.group(1), 16)), text)
    text = text.replace('&amp;', '&')
    return re.sub(r'\s+', ' ', text).strip()


def dash_to_none(value):
    if value is None:
        return None
    v = value.strip()
    return None if v in ('', '-', '--', '–', '—') else v


# --------------------------------------------------------------------------
# HTTP with a small on-disk record
# --------------------------------------------------------------------------
class Fetcher:
    def __init__(self, cache, offline, sleep):
        self.cache = cache
        self.offline = offline
        self.sleep = sleep
        self.manifest_path = os.path.join(cache, 'manifest.json')
        self.manifest = {}
        if os.path.exists(self.manifest_path):
            try:
                self.manifest = json.load(open(self.manifest_path))
            except ValueError:
                die('cache/manifest.json is not valid JSON; refusing to overwrite')
        self.new_entries = 0

    def _record(self, rel, url, data, kind):
        self.manifest[rel] = {
            'source_url': url,
            'sha256': hashlib.sha256(data).hexdigest(),
            'bytes': len(data),
            'kind': kind,
            'fetched_at': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
        }
        self.new_entries += 1

    def get_text(self, url, rel):
        path = os.path.join(self.cache, rel)
        if os.path.exists(path):
            if self.offline:
                return open(path, encoding='utf-8', errors='replace').read()
        if self.offline:
            die('--offline but %s is missing from the cache' % rel)
        time.sleep(self.sleep)
        req = urllib.request.Request(url, headers={'User-Agent': USER_AGENT})
        try:
            data = urllib.request.urlopen(req, timeout=60).read()
        except urllib.error.URLError as exc:
            if os.path.exists(path):
                print('  WARN %s (%s) — using the cached copy' % (url, exc))
                return open(path, encoding='utf-8', errors='replace').read()
            die('fetch failed for %s: %s' % (url, exc))
        os.makedirs(os.path.dirname(path), exist_ok=True)
        open(path, 'wb').write(data)
        self._record(rel, url, data, 'html')
        return data.decode('utf-8', 'replace')

    def get_bytes(self, url, rel):
        path = os.path.join(self.cache, rel)
        if os.path.exists(path) and (self.offline or
                                     self.manifest.get(rel, {}).get('source_url') == url):
            return open(path, 'rb').read()
        if self.offline:
            return None
        time.sleep(self.sleep)
        req = urllib.request.Request(url, headers={'User-Agent': USER_AGENT})
        try:
            data = urllib.request.urlopen(req, timeout=60).read()
        except urllib.error.URLError as exc:
            print('  WARN image %s -> %s' % (url, exc))
            return open(path, 'rb').read() if os.path.exists(path) else None
        os.makedirs(os.path.dirname(path), exist_ok=True)
        open(path, 'wb').write(data)
        self._record(rel, url, data, 'image')
        return data

    def save(self):
        json.dump(self.manifest, open(self.manifest_path, 'w'),
                  indent=1, sort_keys=True)


# --------------------------------------------------------------------------
# Ultima Codex
# --------------------------------------------------------------------------
def split_rows(table_html):
    return re.findall(r'(?s)<tr\b[^>]*>(.*?)</tr>', table_html)


def cells_of(row_html, tag):
    return re.findall(r'(?s)<%s\b[^>]*>(.*?)</%s>' % (tag, tag), row_html)


def parse_codex(html):
    """Return (records, variant_columns, table_meta). Records are keyed by header text."""
    tables = re.findall(r'(?s)<table\b[^>]*rules="all"[^>]*>(.*?)</table>', html)
    if not tables:
        die('no rules="all" tables found — the codex markup changed, '
            'refusing to guess a new structure')
    sections = re.split(r'(?s)<h[23][^>]*>', html)
    records, variants, table_meta = [], set(), []
    section_name = 'unknown'
    tidx = 0
    for chunk in sections:
        head = strip_tags(re.split(r'</h[23]>', chunk, maxsplit=1)[0])
        head = re.sub(r'\[\s*edit\s*\]', '', head).strip()
        if head:
            section_name = head
        for table in re.findall(r'(?s)<table\b[^>]*rules="all"[^>]*>(.*?)</table>', chunk):
            tidx += 1
            rows = split_rows(table)
            if not rows:
                continue
            headers = [strip_tags(c) for c in cells_of(rows[0], 'th')]
            if not headers:
                headers = [strip_tags(c) for c in cells_of(rows[0], 'td')]
                rows = rows[1:]
            else:
                rows = rows[1:]
            if not headers:
                continue
            # Two of the four tables carry a second header row (Min / Max under DMG).
            # It is not data and must not be dropped silently: whichever column those
            # sub-labels sit under decides whether "1  255" is HP+DMG or a range.
            subheaders = []
            if rows:
                th2 = cells_of(rows[0], 'th')
                if th2 and not cells_of(rows[0], 'td'):
                    subheaders = [strip_tags(c) for c in th2]
                    rows = rows[1:]
            table_meta.append({'table': tidx, 'section': section_name,
                               'headers': headers, 'subheaders': subheaders,
                               'rows': len(rows)})
            # The Townsfolk and Dungeons tables put a Min/Max sub-header under HP and
            # then ship one extra cell per data row, so a flat header->cell map is
            # wrong for every column after HP: Balron's level range lands in `Special`.
            # Detect the extra cell from the row width and give HP a 2-cell span.
            spans = [1] * len(headers)
            hp_col = next((i for i, h in enumerate(headers)
                           if h.lower().startswith('hp')), None)
            if subheaders and hp_col is not None:
                spans[hp_col] = 2
                table_meta[-1]['hp_span'] = 2
            cols = []
            for n, h in enumerate(headers):
                raw = re.sub(r'\s*\[n \d+\]', '', h).strip()
                slug = canonical_variant(raw)
                key = slug or (raw or 'col%d' % n)
                cols.append((n, key, slug is not None))
            seen = {}
            for n, key, is_variant in cols:
                if key in seen and not is_variant:
                    key = '%s_%d' % (key, n)
                    cols[n] = (n, key, is_variant)
                seen[key] = n
            for row in rows:
                tds = cells_of(row, 'td')
                if len(tds) < 2:
                    continue
                use_spans = spans if sum(spans) == len(tds) else [1] * len(headers)
                name = strip_tags(tds[0])
                if not name:
                    continue
                rec = {'name': name, 'section': section_name,
                       'table': tidx, 'images': {}, 'stats': {}}
                pos = 0
                cellmap = []
                for n, key, is_variant in cols:
                    cellmap.append((n, key, is_variant, pos))
                    pos += use_spans[n] if n < len(use_spans) else 1
                for i, key, is_variant, cidx in cellmap:
                    if cidx >= len(tds):
                        break
                    cell = tds[cidx]
                    if use_spans[i] == 2 and cidx + 1 < len(tds):
                        lo = dash_to_none(strip_tags(cell))
                        hi = dash_to_none(strip_tags(tds[cidx + 1]))
                        if lo and hi:
                            cell = '%s-%s' % (lo, hi)
                        elif lo:
                            cell = lo
                    if is_variant:
                        imgs = re.findall(
                            r'<img[^>]*\bsrc="([^"]+)"[^>]*>', cell)
                        dims = [re.findall(r'\b(width|height)="(\d+)"', i)
                                for i in imgs]
                        for j, src in enumerate(imgs):
                            if not src.startswith('/'):
                                continue
                            wh = dict(dims[j]) if j < len(dims) else {}
                            rec['images'][key] = {
                                'file': src.rsplit('/', 1)[-1],
                                'url': CODEX_BASE + src,
                                'width': int(wh.get('width', 0) or 0),
                                'height': int(wh.get('height', 0) or 0),
                            }
                            variants.add(key)
                        if not imgs:
                            txt = dash_to_none(strip_tags(cell))
                            if txt:
                                rec['stats'][key] = txt
                    else:
                        val = dash_to_none(strip_tags(cell))
                        if val:
                            rec['stats'][key] = val
                if rec['images'] or rec['stats']:
                    records.append(rec)
    return records, sorted(variants), table_meta


# --------------------------------------------------------------------------
# Gamer Corner
# --------------------------------------------------------------------------
def parse_gamercorner(index_html, detail_pages):
    """detail_pages: {slug: html}. Returns records in the same shape as codex."""
    hrefs = sorted(set(re.findall(r'href="(/ultimaii/creatures/[^"?#]+)"', index_html)))
    slugs = [h.rstrip('/').rsplit('/', 1)[-1] for h in hrefs if h.rstrip('/') != '/ultimaii/creatures']
    records = []
    for slug in slugs:
        html = detail_pages.get(slug)
        if html is None:
            continue
        title = re.search(r'card-header-larger-font[^>]*>.*?<span class="non-link"[^>]*>([^<]+)</span>',
                          html, re.S)
        name = strip_tags(title.group(1)) if title else slug
        stats = {}
        for m in re.finditer(r'(?s)<div class="card-field">\s*<span class="label">'
                             r'(.*?)</span>\s*<span class="value">(.*?)</span>', html):
            key = strip_tags(m.group(1))
            val = dash_to_none(strip_tags(m.group(2)))
            if key and val:
                stats[key if key not in stats else key + '_2'] = val
        note = re.search(r'(?s)<div class="card-note">(.*?)</div>', html)
        if note:
            stats['prose'] = strip_tags(note.group(1))
        imgs = re.findall(r'<img src="(https://assets\.gamercorner\.net/images/ultimaii/[^"]+)"',
                          html)
        images = {}
        if imgs:
            images['gamercorner-dos'] = {
                'file': imgs[0].rsplit('/', 1)[-1],
                'url': imgs[0],
                'width': 0, 'height': 0,
            }
        records.append({'name': name, 'section': 'gamercorner', 'table': 0,
                        'slug': slug, 'images': images, 'stats': stats})
    return records


# --------------------------------------------------------------------------
# images and animation frames
# --------------------------------------------------------------------------
def image_info(path):
    try:
        from PIL import Image, ImageSequence
    except ImportError:
        return None
    try:
        im = Image.open(path)
    except Exception:
        return None
    frames = 1
    try:
        frames = getattr(im, 'n_frames', 1)
    except Exception:
        pass
    return {'width': im.size[0], 'height': im.size[1],
            'mode': im.mode, 'frames': frames}


def extract_frames(path, outdir):
    """Split an animated GIF into numbered PNGs plus one horizontal strip."""
    try:
        from PIL import Image, ImageSequence
    except ImportError:
        return []
    paths = []
    try:
        im = Image.open(path)
        frames = [f.convert('RGBA') for f in ImageSequence.Iterator(im)]
    except Exception:
        return []
    if len(frames) < 2:
        return []
    os.makedirs(outdir, exist_ok=True)
    for i, f in enumerate(frames):
        p = os.path.join(outdir, 'frame_%02d.png' % i)
        f.save(p)
        paths.append(p)
    w, h = frames[0].size
    strip = Image.new('RGBA', (w * len(frames), h), (0, 0, 0, 255))
    for i, f in enumerate(frames):
        strip.paste(f, (i * w, 0))
    sp = os.path.join(outdir, 'strip.png')
    strip.save(sp)
    paths.append(sp)
    return paths


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--cache', default=os.path.join(PROJECT_ROOT, 'bestiary', 'cache'))
    ap.add_argument('--offline', action='store_true',
                    help='re-parse cached HTML, make no network requests')
    ap.add_argument('--no-frames', action='store_true',
                    help='do not split animated GIFs into frames')
    ap.add_argument('--sleep', type=float, default=0.6,
                    help='seconds between requests (default 0.6)')
    ap.add_argument('--limit', type=int, default=0,
                    help='stop after N creatures per source (smoke test)')
    args = ap.parse_args()

    cache = os.path.realpath(args.cache)
    if not (cache + os.sep).startswith(os.path.realpath(PROJECT_ROOT) + os.sep):
        die('--cache %s escapes the project root; refusing to write' % args.cache)
    os.makedirs(cache, exist_ok=True)
    f = Fetcher(cache, args.offline, args.sleep)

    print('== Ultima Codex ==')
    html = f.get_text(CODEX_URL, 'raw/codex-monster-data.html')
    codex, variants, table_meta = parse_codex(html)
    print('  %d creature rows, %d variant columns' % (len(codex), len(variants)))
    print('  variants: %s' % ', '.join(variants))
    for tm in table_meta:
        if tm['subheaders']:
            print('  table %d (%s) has a second header row: %s'
                  % (tm['table'], tm['section'], ', '.join(x for x in tm['subheaders'] if x)))
    if args.limit:
        codex = codex[:args.limit]

    print('== Gamer Corner ==')
    idx = f.get_text(GC_URL, 'raw/gamercorner-index.html')
    hrefs = sorted(set(re.findall(r'href="(/ultimaii/creatures/[^"?#]+)"', idx)))
    slugs = [h.rstrip('/').rsplit('/', 1)[-1]
             for h in hrefs if h.rstrip('/') != '/ultimaii/creatures']
    if args.limit:
        slugs = slugs[:args.limit]
    details = {}
    for slug in slugs:
        details[slug] = f.get_text(GC_BASE + '/ultimaii/creatures/' + slug,
                                    'raw/gamercorner-%s.html' % slug)
    gc = parse_gamercorner(idx, details)
    print('  %d creature pages' % len(gc))

    # --- download the art -----------------------------------------------------
    print('== art ==')
    n_img = n_frames = 0
    for rec in codex + gc:
        for variant, meta in rec['images'].items():
            vslug = slugify(variant)
            rel = 'art/%s/%s' % (vslug, meta['file'])
            data = f.get_bytes(meta['url'], rel)
            if data is None:
                meta['status'] = 'missing'
                continue
            path = os.path.join(cache, rel)
            meta['local'] = rel
            meta['sha256'] = hashlib.sha256(data).hexdigest()
            meta['bytes'] = len(data)
            info = image_info(path)
            if info:
                meta['measured'] = info
                if meta.get('width') and info['width'] != meta['width']:
                    meta['size_mismatch'] = '%dx%d declared, %dx%d actual' % (
                        meta['width'], meta['height'], info['width'], info['height'])
            meta['status'] = 'ok'
            n_img += 1
            if not args.no_frames and info and info['frames'] > 1:
                outdir = os.path.join(cache, 'frames', vslug,
                                      meta['file'].rsplit('.', 1)[0])
                made = extract_frames(path, outdir)
                if made:
                    meta['frame_dir'] = os.path.relpath(outdir, cache)
                    meta['frame_count'] = len(made) - 1
                    n_frames += len(made) - 1
    print('  %d images cached, %d animation frames extracted' % (n_img, n_frames))

    # --- emit the parsed records ---------------------------------------------
    json.dump({'source': CODEX_URL, 'variants': variants,
               'tables': table_meta, 'records': codex},
              open(os.path.join(cache, 'codex.json'), 'w'), indent=1)
    json.dump({'source': GC_URL, 'records': gc},
              open(os.path.join(cache, 'gamercorner.json'), 'w'), indent=1)
    f.save()
    print('\nwrote %s' % cache)
    print('  codex.json (%d records), gamercorner.json (%d records), manifest.json (%d files)'
          % (len(codex), len(gc), len(f.manifest)))
    print('REMINDER: cache/ is copyrighted game art and is gitignored. Never commit it.')


if __name__ == '__main__':
    main()
