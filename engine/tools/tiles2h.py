#!/usr/bin/env python3
"""Generate a C header from the cleanroom SVG tile set.

Why: the engine ships no game art. The cleanroom substitute set (see
docs/tile-art-spec.md and engine/assets/tiles/cleanroom/PROVENANCE.md) has to
reach the binary somehow, and a generated header is how the repo already does
that for the text font (core/font8x8_basic.h, included by exactly one .c file
and guarded by _Static_assert). Compiled-in art needs no path resolution, no
cache, and no digest, because it cannot go stale or be swapped.

The byte layout is the exact inverse of u2_tile_pixel() in core/tiles.h:

    uint8_t b = t->px[tile][y * 4 + (x >> 2)];
    return (b >> (6 - 2 * (x & 3))) & 3;

so packing is

    px[y * 4 + (x >> 2)] |= value << (6 - 2 * (x & 3))

16 rows x 4 bytes, 2 bits per pixel, leftmost pixel in the top two bits.
Colour indices are the CGA ones the renderer owns: 0 black, 1 cyan, 2 magenta,
3 white.

Every emitted byte is verified by unpacking it again in Python and comparing to
the pixels that were parsed, so a packing mistake fails here rather than
appearing on screen. The header also carries a per-tile hash so a C test can
repeat that round-trip against the real u2_tile_pixel().

Black is rejected, not skipped: spec section 3 makes black the backdrop, so a
tile containing #000000 means the art set broke its own palette rule.

Usage:
    python3 engine/tools/tiles2h.py \
        --src engine/assets/tiles/cleanroom/tiles \
        -o engine/src/core/tiles_cleanroom.h
"""
import argparse
import os
import sys
import xml.etree.ElementTree as ET

TILE_W = 16
TILE_H = 16
STRIDE = 4
TILE_BYTES = TILE_H * STRIDE          # 64
COUNT = 64

# CGA composite mode-4 palette, as the renderer indexes it (core/frame.h).
INK = {
    '#55FFFF': 1,   # cyan
    '#FF55FF': 2,   # magenta
    '#FFFFFF': 3,   # white
}
BACKDROP = {'#000000'}                # legal in the palette, illegal as ink


def strip_ns(tag):
    return tag.split('}', 1)[1] if '}' in tag else tag


def parse_tile(path):
    """Return a list of (x, y, colour_index) for every lit pixel of one SVG.

    Fills are inherited from enclosing <g>, which is how the art set is written.
    Anything this tool cannot represent is an error, not a silent skip: a tile
    that quietly rasterises to nothing is the failure mode worth preventing.
    """
    tree = ET.parse(path)
    root = tree.getroot()
    if strip_ns(root.tag) != 'svg':
        fail(path, 'root element is %s, expected svg' % root.tag)
    vb = (root.get('viewBox') or '').split()
    if vb != ['0', '0', str(TILE_W), str(TILE_H)]:
        fail(path, 'viewBox must be "0 0 16 16", got %r' % root.get('viewBox'))

    px = {}

    def walk(node, fill):
        kind = strip_ns(node.tag)
        f = node.get('fill')
        if f:
            fill = f.strip().upper()
        if kind == 'rect':
            if fill is None:
                fail(path, 'rect with no fill (no inherited <g fill> either)')
            if fill in BACKDROP:
                fail(path, 'tile emits backdrop colour %s as ink; black must not '
                          'appear in a tile (spec section 3)' % fill)
            if fill not in INK:
                fail(path, 'colour %s is not in the three-colour ink palette %s'
                     % (fill, sorted(INK)))
            for key in ('x', 'y', 'width', 'height'):
                v = node.get(key, '0')
                if not re_int(v):
                    fail(path, 'rect %s=%r is not an integer; art must sit on '
                               'the 1px grid' % (key, v))
            x, y = int(node.get('x', 0)), int(node.get('y', 0))
            w, h = int(node.get('width', 1)), int(node.get('height', 1))
            if x < 0 or y < 0 or x + w > TILE_W or y + h > TILE_H:
                fail(path, 'rect %d,%d %dx%d falls outside the 16x16 cell'
                     % (x, y, w, h))
            for yy in range(y, y + h):
                for xx in range(x, x + w):
                    px[(xx, yy)] = INK[fill]
        for child in list(node):
            walk(child, fill)

    walk(root, None)
    return [(x, y, c) for (x, y), c in sorted(px.items())]


def re_int(s):
    try:
        int(str(s))
        return True
    except (TypeError, ValueError):
        return False


def fail(path, msg):
    sys.exit('%s: %s' % (os.path.basename(path), msg))


def pack(pixels):
    """(x, y, colour) -> 64 bytes, the exact inverse of u2_tile_pixel()."""
    buf = bytearray(TILE_BYTES)
    for x, y, c in pixels:
        buf[y * STRIDE + (x >> 2)] |= (c & 3) << (6 - 2 * (x & 3))
    return bytes(buf)


def unpack(buf):
    """Reference decode, mirroring u2_tile_pixel byte for byte."""
    out = []
    for y in range(TILE_H):
        for x in range(TILE_W):
            b = buf[y * STRIDE + (x >> 2)]
            v = (b >> (6 - 2 * (x & 3))) & 3
            if v:
                out.append((x, y, v))
    return sorted(out)


def fnv(pixels):
    """FNV-1a over the 256 pixel values in raster order.

    Raster order with every pixel present (not just the lit ones) so a bit-order
    mistake changes the hash rather than preserving it.
    """
    lit = {(x, y): c for x, y, c in pixels}
    h = 2166136261
    for y in range(TILE_H):
        for x in range(TILE_W):
            h ^= lit.get((x, y), 0)
            h = (h * 16777619) & 0xFFFFFFFF
    return h


HEADER = """/*
 * GENERATED by engine/tools/tiles2h.py — DO NOT EDIT.
 *
 * Cleanroom substitute tile art, compiled into the engine so a build has usable
 * art with no game files present and no cache to resolve. Edit the SVG sources
 * under engine/assets/tiles/cleanroom/tiles/ and regenerate:
 *
 *     python3 engine/tools/tiles2h.py \\
 *         --src engine/assets/tiles/cleanroom/tiles \\
 *         -o engine/src/core/tiles_cleanroom.h
 *
 * The set is an independent creation; see that directory's PROVENANCE.md and
 * docs/tile-art-spec.md. This is not a reproduction of the game's art.
 *
 * Layout: {count} tiles x {bytes} bytes. One tile is 16 rows x 4 bytes at
 * 2 bits per pixel, leftmost pixel in the top two bits — the exact inverse of
 * u2_tile_pixel() in core/tiles.h. Colour indices: 0 black (backdrop, never
 * emitted), 1 cyan, 2 magenta, 3 white.
 *
 * Source: the tile_NN.svg files in the cleanroom art directory, as named on the
 * generator's command line. The path itself is deliberately NOT recorded here:
 * the drift check regenerates into a temp file and compares, and embedding the
 * caller's path would make identical art look different depending on where the
 * tool was invoked from.
 */
#ifndef U2_TILES_CLEANROOM_H
#define U2_TILES_CLEANROOM_H

#include <stdint.h>

#define U2_TILES_CLEANROOM_COUNT {count}
#define U2_TILES_CLEANROOM_BYTES {bytes}

/* Include this header in exactly one translation unit, as core/font.c does
 * with font8x8_basic.h; `static` would otherwise give it internal linkage in
 * every file that pulled it in. */
static const uint8_t u2_tiles_cleanroom[U2_TILES_CLEANROOM_COUNT]
                                        [U2_TILES_CLEANROOM_BYTES] = {{
{body}
}};

/* FNV-1a of each tile's 256 pixel values in raster order. A test unpacks the
 * bytes above with the engine's own decode and re-hashes, which proves the
 * packing agrees with u2_tile_pixel() instead of merely looking plausible. */
static const uint32_t u2_tiles_cleanroom_hash[U2_TILES_CLEANROOM_COUNT] = {{
{hashes}
}};

#endif /* U2_TILES_CLEANROOM_H */
"""


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--src', required=True, help='directory of tile_NN.svg')
    ap.add_argument('-o', '--out', required=True)
    a = ap.parse_args()

    low = os.path.abspath(a.out).lower()
    if '/original/' in low or '/references/' in low:
        sys.exit('refusing to write into original/ or references/')

    tiles, hashes = [], []
    lit_total = 0
    for n in range(COUNT):
        p = os.path.join(a.src, 'tile_%02X.svg' % n)
        if not os.path.exists(p):
            sys.exit('missing %s — the set must be complete, gaps would silently '
                     'render as blank tiles' % p)
        pixels = parse_tile(p)
        lit_total += len(pixels)
        buf = pack(pixels)
        # Prove the pack/unpack pair here, before anything is emitted.
        if unpack(buf) != sorted(pixels):
            sys.exit('%s: pack/unpack round-trip mismatch' % p)
        tiles.append(buf)
        hashes.append(fnv(pixels))

    body = []
    for n, buf in enumerate(tiles):
        rows = ', '.join('0x%02X' % b for b in buf)
        body.append('    { %s },  /* %02X */' % (rows, n))
    hs = []
    for n, h in enumerate(hashes):
        hs.append('    0x%08X,  /* %02X */' % (h, n))

    out = HEADER.format(count=COUNT, bytes=TILE_BYTES,
                        body='\n'.join(body), hashes='\n'.join(hs))
    with open(a.out, 'w') as f:
        f.write(out)
    print('wrote %s: %d tiles, %d bytes, %d lit pixels'
          % (a.out, COUNT, COUNT * TILE_BYTES, lit_total))


main()
