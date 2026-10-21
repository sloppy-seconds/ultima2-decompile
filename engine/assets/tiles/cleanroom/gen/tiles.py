"""Generate original substitute tile art for the Ultima II engine reconstruction.

Inputs: tile-art-spec.md only. No original game art was consulted.
Output: one SVG per tile, 16x16, four-colour CGA composite palette.
"""

import os

PAL = {
    "K": "#000000",  # black
    "C": "#55FFFF",  # cyan
    "M": "#FF55FF",  # magenta
    "W": "#FFFFFF",  # white
}

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tiles")

# ---------------------------------------------------------------------------
# Pixel-grid helpers. Every tile is a list of 16 strings of 16 chars.
# ---------------------------------------------------------------------------


def blank(ch="."):
    return [ch * 16 for _ in range(16)]


def grid_fill(ch):
    return [ch * 16 for _ in range(16)]


def rect(g, x, y, w, h, ch):
    """Fill an axis-aligned integer rect. Clipped to the 16x16 cell."""
    for yy in range(y, y + h):
        if 0 <= yy < 16:
            row = list(g[yy])
            for xx in range(x, x + w):
                if 0 <= xx < 16:
                    row[xx] = ch
            g[yy] = "".join(row)
    return g


def px(g, x, y, ch):
    return rect(g, x, y, 1, 1, ch)


def put_rows(g, x0, y0, rows, ch, bg=None):
    """Stamp a list of strings. '.' = leave alone; '-' = bg (if given)."""
    for dy, row in enumerate(rows):
        for dx, c in enumerate(row):
            x, y = x0 + dx, y0 + dy
            if not (0 <= x < 16 and 0 <= y < 16):
                continue
            if c == ".":
                continue
            if c == "-":
                if bg is not None:
                    px(g, x, y, bg)
                continue
            px(g, x, y, c if c in PAL else ch)
    return g


def copy(base):
    return list(base)


# ---------------------------------------------------------------------------
# 5x7 bold bitmap capitals, hand-drawn. Cap height 7px, centred in 16x16.
# Drawn for legibility first: strokes are 1px with deliberate counters.
# ---------------------------------------------------------------------------

GLYPHS = {
    "A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
    "B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
    "C": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
    "D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
    "E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
    "F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
    "G": [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".###."],
    "H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
    "I": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "#####"],
    "J": ["..###", "...#.", "...#.", "...#.", "...#.", "#..#.", ".##.."],
    "K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
    "L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
    "M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
    "N": ["#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#", "#...#"],
    "O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    "P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
    "R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
    "S": [".###.", "#...#", "#....", ".###.", "....#", "#...#", ".###."],
    "T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
    "U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    "V": ["#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
    "W": ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "##.##", "#...#"],
    "X": ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"],
    "Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
    "Z": ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"],
}

# Tiles are 16x16. Draw at 2x the 5x7 cell so strokes land on real pixel pairs
# and stay bold at native size. 10x14 occupies the cell with 3px margins.
GLYPH_SCALE = 2


def letter_tile(ch, ink="M", rule=False):
    """Bold capital, scaled 2x and centred in 16x16."""
    g = blank()
    rows = GLYPHS[ch]
    s = GLYPH_SCALE
    gw, gh = 5 * s, 7 * s          # 10 x 14
    x0 = (16 - gw) // 2            # 3
    y0 = (16 - gh) // 2            # 1
    for ry, row in enumerate(rows):
        for rx, c in enumerate(row):
            if c == "#":
                rect(g, x0 + rx * s, y0 + ry * s, s, s, ink)
    if rule:
        rect(g, 2, 0, 12, 1, ink)
        rect(g, 2, 15, 12, 1, ink)
    return g


# ---------------------------------------------------------------------------
# Ground
# ---------------------------------------------------------------------------


def water():
    """Open water. Loose irregular cyan dashes on black, offset per row band so
    it repeats on a 16px grid without visible seams."""
    g = blank()
    dashes = [
        (2, 2, 3), (9, 1, 2),
        (4, 5, 2), (11, 4, 3),
        (1, 7, 3), (8, 8, 2),
        (5, 10, 3), (12, 11, 2),
        (2, 13, 2), (9, 14, 3),
        (6, 15, 2),
    ]
    for x, y, w in dashes:
        rect(g, x, y, w, 1, "C")
    # a few single pips to break up the rhythm
    for x, y in [(0, 4), (15, 7), (3, 11), (13, 2)]:
        px(g, x, y, "C")
    return g


def shallow():
    """Rough water: more broken texture, some magenta flecks for contrast."""
    g = water()
    extra = [
        (0, 1, 2, "M"), (7, 2, 2, "M"), (13, 3, 2, "C"),
        (2, 6, 2, "M"), (6, 7, 3, "C"), (14, 8, 1, "M"),
        (0, 9, 2, "C"), (4, 12, 2, "M"), (10, 12, 2, "C"),
        (7, 13, 2, "M"), (14, 14, 2, "M"), (1, 15, 3, "C"),
    ]
    for x, y, w, c in extra:
        rect(g, x, y, w, 1, c)
    return g


def grass():
    """Calmest tile: sparse white speckling on black, low density."""
    g = blank()
    for x, y in [(2, 3), (7, 2), (12, 5), (4, 8), (10, 9),
                 (1, 12), (6, 13), (13, 12), (9, 15), (15, 7)]:
        px(g, x, y, "W")
    return g


def forest():
    """Denser, chunkier coverage than grass: clumps, not single pips."""
    g = blank()
    clumps = [
        (1, 1), (8, 2), (13, 0),
        (4, 5), (11, 6),
        (0, 8), (7, 9), (14, 10),
        (3, 12), (10, 13),
        (6, 15), (15, 14),
    ]
    for x, y in clumps:
        rect(g, x, y, 2, 2, "W")
    for x, y in [(5, 2), (2, 6), (12, 4), (9, 11), (0, 14)]:
        px(g, x, y, "W")
    return g


def mountain():
    """High ground: regular angular lattice, hard and bright."""
    g = blank()
    # regular triangular lattice across the cell
    for y in range(0, 16):
        for x in range(0, 16):
            bx = (x + (4 if (y // 4) % 2 else 0)) % 8
            by = y % 4
            if by == 0 and bx in (0, 1, 2, 3):
                px(g, x, y, "W")
            elif by == 1 and bx in (3, 4):
                px(g, x, y, "W")
            elif by == 2 and bx in (4, 5):
                px(g, x, y, "W")
    return g


def mountain_pass():
    """Mountain lattice with a clean opening at the bottom centre."""
    g = mountain()
    # carve a widening passage, cleared to '.' so no lattice speck survives
    for y in range(8, 16):
        half = min(1 + (y - 8) // 2, 4)
        rect(g, 8 - half, y, half * 2, 1, ".")
    # jambs sit one pixel outside the cleared span so they never get eaten
    for y in range(9, 16):
        half = min(1 + (y - 8) // 2, 4)
        px(g, 8 - half - 1, y, "M")
        px(g, 8 + half, y, "M")
    rect(g, 2, 15, 12, 1, "M")
    return g


def marsh():
    """Vertical strokes on black. Direction distinguishes it from water."""
    g = blank()
    reeds = [
        (1, 3, 4), (3, 10, 5), (5, 1, 3), (7, 8, 4),
        (9, 4, 6), (11, 11, 3), (13, 2, 5), (15, 9, 4),
        (6, 13, 2), (12, 5, 2),
    ]
    for x, y, h in reeds:
        rect(g, x, y, 1, h, "C")
    # bases
    for x, y, h in reeds[:8]:
        px(g, x, y + h, "M")
    return g


# ---------------------------------------------------------------------------
# Structures
# ---------------------------------------------------------------------------


def rings():
    """A small group of ring shapes."""
    g = blank()
    for cx, cy in [(4, 4), (11, 5), (5, 11), (12, 12)]:
        hx, hy = cx - 2, cy - 2
        g = put_rows(g, hx, hy, [
            ".###.",
            "#...#",
            "#...#",
            "#...#",
            ".###.",
        ], "C")
    px(g, 8, 8, "M")
    return g


def masonry():
    """Squared masonry: regular courses with offset joints."""
    g = blank()
    for y in range(0, 16, 4):
        rect(g, 0, y, 16, 1, "W")
        off = 0 if (y // 4) % 2 == 0 else 4
        for x in range(off, 16, 8):
            rect(g, x, y, 1, 4, "W")
    return g


def tower():
    """Upright tower with a crenellated top."""
    g = blank()
    rect(g, 4, 3, 8, 13, "M")
    rect(g, 5, 4, 6, 12, "K")
    # crenellations
    for x in (4, 8, 11):
        rect(g, x, 0, 1, 3, "M")
    rect(g, 4, 2, 8, 1, "M")
    # window slit and door
    rect(g, 7, 6, 2, 3, "C")
    rect(g, 7, 12, 2, 4, "C")
    return g


def gate():
    """Two posts under a lintel."""
    g = blank()
    rect(g, 2, 1, 12, 3, "M")   # lintel
    rect(g, 2, 4, 2, 12, "M")   # left post
    rect(g, 12, 4, 2, 12, "M")  # right post
    rect(g, 2, 4, 12, 1, "M")
    rect(g, 4, 13, 8, 3, ".")   # threshold gap
    return g


def monument():
    """Upright cross on a base."""
    g = blank()
    rect(g, 7, 1, 2, 10, "W")   # shaft
    rect(g, 4, 3, 8, 2, "W")    # arms
    rect(g, 3, 11, 10, 2, "M")  # base
    rect(g, 2, 13, 12, 2, "M")
    return g


def arched_doorway():
    """An arch set in a filled field."""
    g = grid_fill("M")
    # recesses: stepped arch
    rect(g, 4, 8, 8, 8, "K")
    rect(g, 5, 5, 6, 3, "K")
    rect(g, 6, 4, 4, 1, "K")
    # arch inner highlight
    rect(g, 5, 8, 6, 1, "C")
    rect(g, 6, 5, 4, 3, "C")
    rect(g, 6, 5, 1, 3, "K")
    rect(g, 9, 5, 1, 3, "K")
    return g


def ship():
    """Boat: hull with a vertical mast. Front-on, mast centred."""
    g = blank()
    # hull: tapered
    hull = [
        (4, "..########.."),
        (5, ".##########."),
        (6, "############"),
        (7, ".##########."),
        (8, "..##....##.."),
    ]
    for y, row in hull:
        put_rows(g, 2, y, [row], "W")
    # mast and yard
    rect(g, 7, 0, 2, 11, "W")
    rect(g, 3, 3, 10, 1, "W")
    # sail hint
    rect(g, 4, 4, 3, 4, "C")
    rect(g, 9, 4, 3, 4, "C")
    # waterline
    rect(g, 0, 10, 16, 1, "C")
    return g


def signpost():
    """A post with a horizontal board."""
    g = blank()
    rect(g, 7, 7, 2, 9, "M")    # post
    rect(g, 1, 2, 14, 5, "W")   # board
    rect(g, 2, 3, 12, 1, "K")   # top rule
    rect(g, 2, 6, 12, 1, "K")   # bottom rule
    # a few suggested glyph blocks between the rules
    rect(g, 3, 4, 2, 2, "K")
    rect(g, 6, 4, 1, 2, "K")
    rect(g, 8, 4, 2, 2, "K")
    rect(g, 11, 4, 1, 2, "K")
    return g


def spire():
    """Tall tapering form on a wider base."""
    g = blank()
    rect(g, 7, 0, 2, 1, "C")
    rect(g, 6, 1, 4, 2, "C")
    rect(g, 6, 3, 4, 6, "W")
    rect(g, 5, 9, 6, 3, "W")
    rect(g, 4, 12, 8, 4, "M")
    rect(g, 7, 4, 2, 4, "M")
    return g


def dungeon_mouth():
    """Enclosed opening: the 'go down here' tile."""
    g = grid_fill("M")
    rect(g, 3, 5, 10, 11, "K")
    rect(g, 4, 4, 8, 1, "K")
    # stepped descending steps inside
    rect(g, 5, 12, 6, 4, "C")
    rect(g, 6, 9, 4, 3, "C")
    rect(g, 7, 6, 2, 3, "C")
    # frame highlight
    rect(g, 3, 4, 1, 12, "W")
    rect(g, 12, 4, 1, 12, "W")
    return g


def marker():
    """A small diagonal mark with a cross at its foot."""
    g = blank()
    # diagonal stroke
    for i in range(8):
        px(g, 7 + i, 2 + i, "C")
        px(g, 8 + i, 2 + i, "C")
    # cross at the foot
    rect(g, 5, 12, 8, 1, "W")
    rect(g, 8, 10, 1, 6, "W")
    return g


def wall():
    """Dense structural tile for large repeated blocks. Built fabric."""
    g = grid_fill("M")
    # heavy mortar course grid, darker, so repeats read as a wall face
    for y in range(0, 16, 8):
        rect(g, 0, y, 16, 2, "K")
    for x in range(0, 16, 8):
        rect(g, x, 0, 2, 8, "K")
        rect(g, (x + 4) % 16, 8, 2, 8, "K")
    # brick face highlights
    rect(g, 2, 2, 4, 1, "W")
    rect(g, 10, 2, 4, 1, "W")
    rect(g, 2, 10, 4, 1, "W")
    rect(g, 10, 10, 4, 1, "W")
    return g


# ---------------------------------------------------------------------------
# Creatures. Schematic figures, 16x16, distinguished by silhouette class.
# ---------------------------------------------------------------------------


def _body(g, cx=8, head_y=2, torso_y=6, legs_y=11, arm="C"):
    """Shared upright humanoid.

    Head is a 3x3 with the lower corners knocked out so it reads as a skull
    rather than a solid block, and a 1px neck gap separates it from the torso.
    """
    put_rows(g, cx - 1, head_y, ["###", "###", ".#."], "W")
    rect(g, cx - 2, torso_y, 5, 4, "C")
    rect(g, cx - 2, legs_y, 1, 4, "W")
    rect(g, cx + 2, legs_y, 1, 4, "W")
    return g


def person():
    g = blank()
    _body(g)
    # arms at sides
    rect(g, 5, 7, 1, 4, "C")
    rect(g, 10, 7, 1, 4, "C")
    return g


def person_arms_up():
    g = blank()
    _body(g)
    # arms out and up
    rect(g, 5, 6, 1, 1, "C")
    rect(g, 4, 5, 1, 1, "C")
    rect(g, 3, 4, 1, 1, "C")
    rect(g, 10, 6, 1, 1, "C")
    rect(g, 11, 5, 1, 1, "C")
    rect(g, 12, 4, 1, 1, "C")
    return g


def staff_bearer():
    g = blank()
    _body(g, cx=7)
    rect(g, 5, 7, 1, 4, "C")
    rect(g, 9, 7, 1, 3, "C")
    # staff, vertical, to the right
    rect(g, 11, 1, 1, 14, "W")
    px(g, 11, 0, "M")
    return g


def group():
    g = blank()
    # two figures, close but with a visible gap so they don't fuse into a bar
    _body(g, cx=5)
    _body(g, cx=11)
    rect(g, 3, 6, 1, 4, "C")
    rect(g, 13, 6, 1, 4, "C")
    return g


def robed():
    g = blank()
    rect(g, 7, 2, 3, 3, "W")      # head
    # triangular cloak
    for i in range(11):
        w = 3 + i
        rect(g, 8 - w // 2 - (i % 2), 5 + i, w, 1, "C")
    rect(g, 7, 5, 3, 4, "M")
    return g


def horse():
    g = blank()
    # body
    rect(g, 3, 6, 10, 5, "C")
    # neck and head to the left
    rect(g, 2, 3, 3, 4, "C")
    rect(g, 0, 2, 3, 3, "C")
    px(g, 0, 1, "C")
    # legs
    rect(g, 3, 11, 2, 5, "W")
    rect(g, 6, 11, 2, 5, "W")
    rect(g, 10, 11, 2, 5, "W")
    rect(g, 13, 11, 2, 5, "W")
    # tail
    rect(g, 13, 4, 1, 3, "W")
    # eye
    px(g, 1, 3, "K")
    return g


def person_arms_out():
    g = blank()
    _body(g)
    rect(g, 5, 7, 1, 1, "C")
    rect(g, 4, 8, 1, 1, "C")
    rect(g, 3, 9, 1, 1, "C")
    rect(g, 10, 7, 1, 1, "C")
    rect(g, 11, 8, 1, 1, "C")
    rect(g, 12, 9, 1, 1, "C")
    return g


def dancer():
    g = blank()
    _body(g, head_y=5, torso_y=8, legs_y=12)
    # arms forming a clear V above the head
    for i in range(3):
        px(g, 7 - i, 4 - i, "C")
        px(g, 9 + i, 4 - i, "C")
    px(g, 4, 1, "M")
    px(g, 12, 1, "M")
    return g


def small_person():
    g = blank()
    # noticeably smaller humanoid, shifted down
    rect(g, 7, 6, 3, 3, "W")
    rect(g, 6, 9, 5, 4, "C")
    rect(g, 7, 13, 1, 2, "W")
    rect(g, 9, 13, 1, 2, "W")
    rect(g, 5, 10, 1, 3, "C")
    rect(g, 11, 10, 1, 3, "C")
    return g


def crouching():
    g = blank()
    rect(g, 7, 4, 3, 3, "W")     # head
    rect(g, 6, 7, 5, 5, "C")     # hunched torso
    rect(g, 5, 8, 1, 3, "C")     # arms drawn inward
    rect(g, 11, 8, 1, 3, "C")
    rect(g, 5, 12, 7, 2, "C")    # folded legs
    rect(g, 6, 14, 2, 1, "W")
    rect(g, 10, 14, 2, 1, "W")
    return g


def figure_broad():
    g = blank()
    _body(g)
    rect(g, 5, 7, 1, 1, "C")
    rect(g, 4, 8, 1, 2, "C")
    rect(g, 4, 10, 1, 3, "C")
    rect(g, 10, 7, 1, 1, "C")
    rect(g, 11, 8, 1, 2, "C")
    rect(g, 11, 10, 1, 3, "C")
    # broad stance
    rect(g, 4, 11, 2, 4, "W")
    rect(g, 11, 11, 2, 4, "W")
    return g


def swordsman():
    g = blank()
    _body(g)
    rect(g, 5, 7, 1, 4, "C")
    rect(g, 10, 7, 1, 3, "C")
    # blade up to one side
    rect(g, 12, 1, 1, 8, "W")
    rect(g, 11, 9, 3, 1, "M")    # guard
    return g


def figure_standard():
    g = blank()
    _body(g, cx=6)
    rect(g, 4, 7, 1, 4, "C")
    rect(g, 9, 7, 1, 4, "C")
    # tall vertical bar (standard)
    rect(g, 12, 1, 2, 15, "M")
    rect(g, 11, 2, 4, 1, "W")
    px(g, 12, 0, "W")
    return g


def archer():
    g = blank()
    _body(g, cx=7)
    rect(g, 5, 7, 1, 3, "C")
    rect(g, 9, 7, 1, 3, "C")
    # curved bow
    for y, x in [(2, 12), (3, 13), (4, 13), (5, 13), (6, 13),
                 (7, 13), (8, 13), (9, 13), (10, 13), (11, 12)]:
        px(g, x, y, "W")
    rect(g, 11, 2, 1, 1, "W")
    rect(g, 11, 11, 1, 1, "W")
    # string
    rect(g, 11, 3, 1, 8, "M")
    return g


# ---------------------------------------------------------------------------
# Blocks and borders
# ---------------------------------------------------------------------------


def checker_border():
    """Repeating checkered band, spec art 17: cyan + magenta + white.

    Three inks, arranged so the check survives at 16x16: white and cyan form
    the classic 2x2 check, with a magenta spine row every fourth row to seat
    the pattern on the black field. Black is never drawn - it is the backdrop.
    """
    g = blank()
    for y in range(0, 16):
        for x in range(0, 16):
            if y % 4 == 3:
                g = px(g, x, y, "M")
            elif ((x // 2) + (y // 2)) % 2 == 0:
                g = px(g, x, y, "W")
            else:
                g = px(g, x, y, "C")
    return g


def solid_black():
    return grid_fill("K")


def solid_white():
    return grid_fill("W")


def edge_strip():
    g = grid_fill("K")
    rect(g, 0, 0, 16, 5, "W")
    rect(g, 0, 5, 16, 1, "C")
    return g


def dark_fill_a():
    g = grid_fill("K")
    # corner pip motif
    rect(g, 2, 2, 2, 2, "C")
    rect(g, 12, 12, 2, 2, "C")
    return g


def dark_fill_b():
    g = grid_fill("K")
    # centre cross motif
    rect(g, 7, 4, 2, 8, "M")
    rect(g, 4, 7, 8, 2, "M")
    return g


# ---------------------------------------------------------------------------
# Registry: art index -> builder
# ---------------------------------------------------------------------------

NOT_A_LETTER = {0x30}

TILES = {
    0x00: water, 0x01: shallow, 0x02: grass, 0x03: forest,
    0x04: mountain, 0x09: mountain_pass, 0x1C: marsh,
    0x05: rings, 0x06: masonry, 0x07: tower, 0x08: gate,
    0x0A: monument, 0x0B: arched_doorway, 0x12: ship, 0x13: signpost,
    0x14: spire, 0x15: dungeon_mouth, 0x16: marker, 0x30: wall,
    0x0C: person, 0x0D: person_arms_up, 0x0E: staff_bearer, 0x0F: group,
    0x10: robed, 0x11: horse, 0x18: person_arms_out, 0x19: dancer,
    0x1A: small_person, 0x1B: crouching, 0x3C: figure_broad,
    0x3D: swordsman, 0x3E: figure_standard, 0x3F: archer,
    0x17: checker_border, 0x1D: solid_black, 0x1E: solid_white,
    0x1F: edge_strip, 0x3A: dark_fill_a, 0x3B: dark_fill_b,
}

# letters: A-P = 0x20-0x2F, R-Z = 0x31-0x39
LETTER_IDX = {}
for i, ch in enumerate("ABCDEFGHIJKLMNOP"):
    LETTER_IDX[0x20 + i] = ch
for i, ch in enumerate("RSTUVWXYZ"):
    LETTER_IDX[0x31 + i] = ch


# ---------------------------------------------------------------------------
# SVG emit
# ---------------------------------------------------------------------------


def to_svg(g, art):
    rects = []
    # group by colour to keep files compact
    for name, hexval in PAL.items():
        # Black is the backdrop, not ink. The engine clears the cell to black
        # before drawing, so a black rect and an absent rect are the same
        # picture. Emitting black made 11 tiles compose differently from the
        # rest and made "is this tile blank?" unanswerable from the file.
        if name == "K":
            continue
        cells = []
        for y in range(16):
            x = 0
            row = g[y]
            while x < 16:
                if row[x] != name:
                    x += 1
                    continue
                run = 1
                while x + run < 16 and row[x + run] == name:
                    run += 1
                cells.append((x, y, run))
                x += run
        if not cells:
            continue
        rects.append('  <g fill="%s">' % hexval)
        for x, y, run in cells:
            rects.append(
                '    <rect x="%d" y="%d" width="%d" height="1"/>' % (x, y, run)
            )
        rects.append("  </g>")
    body = "\n".join(rects)
    if body:
        body += "\n"
    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16" '
        'shape-rendering="crispEdges">\n'
        '  <title>tile_%02X</title>\n'
        "%s"
        "</svg>\n" % (art, body)
    )


# ---------------------------------------------------------------------------
# Ink assignment, spec section 6
# ---------------------------------------------------------------------------
# The spec prescribes which inks each tile may use. Its table is measured rather
# than impressionistic, and acceptance criterion 8.7 requires the set to match.
#
# The shape functions above were authored before that table existed and pick
# their own colours, so the assignment is applied here as a transform on the
# finished grid. This keeps every pixel where the shape put it and only relabels
# ink: geometry and colour stay separable, which is what makes the reassignment
# reviewable.
#
# For single-ink tiles the mapping is total. For the few multi-ink tiles the
# tile's own majority ink is kept as the primary and the remainder is remapped
# onto the secondary ink the spec allows, preserving how much texture the shape
# intended.

CYAN, MAG, WHITE = "C", "M", "W"

INK_SPEC = {}
for a in (0x00, 0x1C):                      # liquid: water, marsh
    INK_SPEC[a] = (MAG,)
for a in (0x02, 0x03):                      # vegetation: grass, forest
    INK_SPEC[a] = (CYAN,)
INK_SPEC[0x01] = (CYAN, WHITE)              # rough water
INK_SPEC[0x0B] = (MAG, WHITE)               # arch in a field
INK_SPEC[0x0E] = (MAG, WHITE)               # figure with a staff
INK_SPEC[0x17] = (CYAN, MAG, WHITE)         # checker border
INK_SPEC[0x1D] = ()                         # solid black: empty tile
for a in (list(range(0x04, 0x0B)) + list(range(0x0C, 0x17))
          + list(range(0x18, 0x1C)) + list(range(0x1E, 0x40))):
    INK_SPEC[a] = (WHITE,)                  # solid and man-made


def apply_ink_spec(g, art):
    """Relabel a finished grid so its inks match the spec for this art index.

    Preserves each shape's light/dark structure: the tile's most-used ink keeps
    the spec's first (primary) ink, the rest receive the remaining allowed inks
    in order of their own frequency. Pixels are never added or removed, except
    for art 1D where the spec requires an empty tile.
    """
    allowed = INK_SPEC.get(art)
    if allowed is None:
        return g
    if not allowed:
        return blank()

    # ordered by how much the shape uses each ink, descending
    counts = {}
    for row in g:
        for c in row:
            if c in PAL and c != "K":
                counts[c] = counts.get(c, 0) + 1
    order = sorted(counts, key=lambda c: (-counts[c], c))

    if len(allowed) == 1:
        mapping = {c: allowed[0] for c in order}
    else:
        mapping = {}
        for i, c in enumerate(order):
            mapping[c] = allowed[i] if i < len(allowed) else allowed[-1]
    # anything the shape did not use may still appear as the single allowed ink
    for c in (CYAN, MAG, WHITE):
        mapping.setdefault(c, allowed[0])

    out = []
    for row in g:
        out.append("".join(mapping.get(c, c) for c in row))
    return out


def build_all():
    os.makedirs(OUT, exist_ok=True)
    grids = {}
    for art, fn in TILES.items():
        grids[art] = fn()
    for art, ch in LETTER_IDX.items():
        grids[art] = letter_tile(ch)
    for art in list(grids):
        grids[art] = apply_ink_spec(grids[art], art)
    for art, g in grids.items():
        with open(os.path.join(OUT, "tile_%02X.svg" % art), "w") as f:
            f.write(to_svg(g, art))
    return grids


def validate(grids):
    errs = []
    if len(grids) != 64:
        errs.append("expected 64 tiles, got %d" % len(grids))
    missing = sorted(set(range(0x40)) - set(grids))
    if missing:
        errs.append("missing indices: %s" % [hex(m) for m in missing])
    for art, g in grids.items():
        if len(g) != 16:
            errs.append("%02X: %d rows" % (art, len(g)))
        for y, row in enumerate(g):
            if len(row) != 16:
                errs.append("%02X row %d: %d cols" % (art, y, len(row)))
            for ch in row:
                if ch != "." and ch not in PAL:
                    errs.append("%02X row %d: bad char %r" % (art, y, ch))
    return errs


if __name__ == "__main__":
    grids = build_all()
    errs = validate(grids)
    if errs:
        print("VALIDATION FAILED")
        for e in errs:
            print(" ", e)
        raise SystemExit(1)
    print("wrote %d tiles to %s" % (len(grids), os.path.normpath(OUT)))
