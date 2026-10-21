"""Build proof sheets from the generated tiles. Scratch output only.

Rasterises the SVGs directly with PIL onto an explicit black plate. This is
deliberate: ImageMagick's SVG path on this machine has no rsvg-convert or
inkscape delegate, so it falls back to a renderer that paints a white backdrop
inside the cell and ignores -background. Tiles are mostly transparent, so that
white leaked through as the tile field and hid how much of each tile is empty.

Every tile here is drawn over solid black, which is the field colour the art is
designed against (spec section 3, and the "dark field" wording in section 6).
Transparent pixels therefore read as black, and a tile that is accidentally
blank looks blank instead of looking like white paint.
"""

import os
import re

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
TILES = os.path.join(HERE, "..", "tiles")
OUT = "/var/tmp/ultima-cleanroom-proof"
os.makedirs(OUT, exist_ok=True)

SCALE = 8
BG = (0, 0, 0)

PAL = {
    "#000000": (0, 0, 0),
    "#55FFFF": (85, 255, 255),
    "#FF55FF": (255, 85, 255),
    "#FFFFFF": (255, 255, 255),
}

RECT = re.compile(r"<rect([^>]*)/>")
ATTR = re.compile(r'(\w[\w-]*)="([^"]*)"')
GROUP = re.compile(r'<g fill="(#[0-9A-Fa-f]{6})">(.*?)</g>', re.S)


def parse_tile(art):
    """Return a 16x16 list of RGB tuples or None (transparent)."""
    path = os.path.join(TILES, "tile_%02X.svg" % art)
    text = open(path).read()
    grid = [[None] * 16 for _ in range(16)]
    for gm in GROUP.finditer(text):
        colour = PAL.get(gm.group(1).upper())
        if colour is None:
            raise SystemExit("stray colour %s in %s" % (gm.group(1), path))
        for rm in RECT.finditer(gm.group(2)):
            a = dict(ATTR.findall(rm.group(1)))
            x = int(float(a.get("x", 0)))
            y = int(float(a.get("y", 0)))
            w = int(float(a.get("width", 1)))
            h = int(float(a.get("height", 1)))
            for yy in range(y, y + h):
                for xx in range(x, x + w):
                    if 0 <= xx < 16 and 0 <= yy < 16:
                        grid[yy][xx] = colour
    return grid


def draw_tile(draw, grid, ox, oy, scale):
    """Blit one tile at integer scale, black where the tile is transparent."""
    inner = Image.new("RGB", (16, 16), BG)
    px = inner.load()
    for y in range(16):
        for x in range(16):
            if grid[y][x] is not None:
                px[x, y] = grid[y][x]
    big = inner.resize((16 * scale, 16 * scale), Image.NEAREST)
    draw._image.paste(big, (ox, oy))


def sheet(indices, cols, name, scale=SCALE, gap=2, repeat=1):
    """Contact sheet. repeat>1 tiles each art n x n times for seam checking."""
    cell = 16 * scale
    step = cell * repeat
    rows = (len(indices) + cols - 1) // cols
    W = cols * (step + gap) + gap
    H = rows * (step + gap) + gap
    img = Image.new("RGB", (W, H), (32, 32, 32))
    draw = ImageDraw.Draw(img)
    draw._image = img
    for i, art in enumerate(indices):
        grid = parse_tile(art)
        cx = (i % cols) * (step + gap) + gap
        cy = (i // cols) * (step + gap) + gap
        for ry in range(repeat):
            for rx in range(repeat):
                draw_tile(draw, grid, cx + rx * cell, cy + ry * cell, scale)
    path = os.path.join(OUT, name)
    img.save(path)
    return path


GROUND = [0x00, 0x01, 0x02, 0x03, 0x04, 0x09, 0x1C]
STRUCT = [0x05, 0x06, 0x07, 0x08, 0x0A, 0x0B, 0x12, 0x13,
          0x14, 0x15, 0x16, 0x30]
CREATURE = [0x0C, 0x0D, 0x0E, 0x0F, 0x10, 0x11, 0x18, 0x19,
            0x1A, 0x1B, 0x3C, 0x3D, 0x3E, 0x3F]
LETTERS = [0x20 + i for i in range(16)] + [0x31 + i for i in range(9)]
BLOCKS = [0x17, 0x1D, 0x1E, 0x1F, 0x3A, 0x3B]

if __name__ == "__main__":
    print(sheet(GROUND, 7, "ground.png"))
    print(sheet(STRUCT, 6, "structures.png"))
    print(sheet(CREATURE, 7, "creatures.png"))
    print(sheet(LETTERS, 9, "letters.png"))
    print(sheet(BLOCKS, 6, "blocks.png"))
    print(sheet(GROUND, 7, "ground-repeat.png", scale=4, repeat=3))


def usage_sheet(name, rotiles, coltiles, scale=6, gap=3):
    """Rotiles down the left, coltiles across the top, cell = overlay.

    This is the layout constraints V1 and V2 need: letters and creatures are
    stamped *onto* ground at runtime, so the only test that means anything
    shows them composited, not beside it.
    """
    cell = 16 * scale
    W = len(coltiles) * (cell + gap) + gap + cell + gap   # + gutter for labels
    H = len(rotiles) * (cell + gap) + gap
    img = Image.new("RGB", (W, H), (32, 32, 32))
    draw = ImageDraw.Draw(img)
    draw._image = img
    for ri, art in enumerate(rotiles):
        gy = ri * (cell + gap) + gap
        # label gutter: the row's own tile
        draw_tile(draw, parse_tile(art), gap, gy, scale)
        for ci, base in enumerate(coltiles):
            gx = gap + cell + gap + ci * (cell + gap)
            overlay = parse_tile(art)
            under = parse_tile(base)
            merged = [[overlay[y][x] if overlay[y][x] is not None
                       else under[y][x] for x in range(16)] for y in range(16)]
            draw_tile(draw, merged, gx, gy, scale)
    path = os.path.join(OUT, name)
    img.save(path)
    return path
