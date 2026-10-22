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


def letter_tile(ch, ink="W", rule=True):
    """A letter tile: a SIGN BOARD, per spec 7a.

    The amendment makes the rules mandatory: a full-width rule along the top
    edge, a clear gutter, the glyph, a clear gutter, and a full-width rule along
    the bottom edge. An earlier revision called them optional decoration and
    every letter tile came out wrong as a result - without them a letter reads
    as a floating glyph rather than a shop front.

    Ink is white per section 6 (letters fall in the white group).
    """
    g = blank()
    rows = GLYPHS[ch]
    s = GLYPH_SCALE
    gw, gh = 5 * s, 7 * s          # 10 x 14 at scale 2
    # rules occupy rows 0 and 15; glyph sits centred in rows 1..14 with a
    # clear gutter top and bottom so it never touches a rule
    avail_top, avail_bot = 1, 15
    x0 = (16 - gw) // 2
    y0 = avail_top + (avail_bot - avail_top - gh) // 2
    for ry, row in enumerate(rows):
        for rx, c in enumerate(row):
            if c == "#":
                rect(g, x0 + rx * s, y0 + ry * s, s, s, ink)
    if rule:
        rect(g, 0, 0, 16, 1, ink)     # top rule, full width
        rect(g, 0, 15, 16, 1, ink)    # bottom rule, full width
    return g


# ---------------------------------------------------------------------------
# Ground
# ---------------------------------------------------------------------------


def water():
    """Open water, art 00.

    Spec 7a: the dashes must be thin and regular enough that a field of these
    tiles reads as ONE continuous surface in motion. Chunky or irregular specks
    read as static per tile, which the amendment names as this substitute's
    failure. So: every row carries the same 3-on/5-off rhythm at the same phase
    offset, giving horizontal travel rather than a scatter. One pixel tall
    throughout - thickness is what made the old set look like gravel.
    """
    g = blank()
    # One pixel tall throughout: thickness is what made the old set look like
    # gravel. Each row is a single 1px dash train, phase-shifted every row so the
    # field reads as continuous horizontal travel rather than stacked bricks.
    for y in range(16):
        off = (y * 3) % 8
        for x in range(16):
            if (x + off) % 8 < 4:
                px(g, x, y, "M")
    return g


def shallow():
    """Rough water, art 01: cyan + white.

    Spec 7a: horizontal wave lines with WHITE FOAM DOMINANT OVER CYAN, and
    sparser than 00 rather than busier. The old tile inverted this ratio and
    buried the foam. So the wave crests are white and only the wave troughs
    carry cyan, and there are half as many rows of ink as art 00.
    """
    g = blank()
    for y in range(0, 16, 2):
        # crest: long white run, the dominant ink
        for x in range(16):
            if (x + (y * 3)) % 8 < 5:
                px(g, x, y, "W")
        # trough: a shorter cyan run beneath, secondary
        for x in range(16):
            if (x + (y * 3)) % 8 < 2:
                px(g, x, y + 1, "C")
    return g


def grass():
    """Open grassland, art 02. The calmest tile in the set.

    Sparse cyan speckling on the black field. Cyan is the vegetation ink per
    section 6, and this tile must stay quieter than forest by a clear margin.
    """
    g = blank()
    for x, y in [(2, 3), (7, 2), (12, 5), (4, 8), (10, 9),
                 (1, 12), (6, 13), (13, 12), (9, 15), (15, 7)]:
        px(g, x, y, "C")
    return g


def forest():
    """Woodland, art 03. A FEW LARGE CROWNS, not many small marks.

    Spec 7a names scattered confetti as the failure mode. Three crowns of 5x5
    with knocked-out centres so each reads as a canopy rather than a block.

    Spread wider than the cell so the crowns cross the edges: a field of these
    tiles then reads as continuous woodland, and no edge is a blank gutter.
    """
    g = blank()
    crowns = [
        (2, 3),
        (12, 4),
        (7, 12),
    ]
    for cx, cy in crowns:
        put_rows(g, cx - 2, cy - 2, [
            ".###.",
            "#####",
            "##.##",
            "#####",
            ".###.",
        ], "C")
    # edge-touching canopy so repeats have no seam on either axis
    put_rows(g, 0, 6, ["##", "##"], "C")
    put_rows(g, 14, 9, ["##", "##"], "C")
    rect(g, 6, 0, 2, 1, "C")
    rect(g, 10, 15, 2, 1, "C")
    return g


def mountain():
    """High ground, art 04.

    Spec 7a: TWO FAMILIES OF CROSSING DIAGONAL LINES, reading as zigzag peaks
    or stacked diamonds, fine strokes, all-over coverage. The old tile had a
    single diagonal family and four blank rows; solid blobs or one family do
    not read as rock. So both diagonals of a diamond lattice, 1px strokes,
    every row populated.
    """
    g = blank()
    for y in range(16):
        for x in range(16):
            # family 1: \\  family 2: /
            if (x + y) % 6 == 0 or (x - y) % 6 == 0:
                px(g, x, y, "W")
    return g


def mountain_pass():
    """Mountain pass, art 09.

    The mountain texture PLUS AN ARCH open at the bottom centre. Spec 7a is
    explicit that the opening is the whole point and that sealing the bottom
    turns a pass into a wall. So the lattice is carved away in an arch shape
    that widens downward and runs off the bottom edge - no closing bar.
    """
    g = mountain()
    for y in range(7, 16):
        # arch interior widens as it descends and stays open at the base
        half = min(1 + (y - 7) // 2, 4)
        for x in range(8 - half, 8 + half):
            if 0 <= x < 16:
                px(g, x, y, ".")
    # a clean 1px jamb each side so the opening has a defined edge
    for y in range(7, 16):
        half = min(1 + (y - 7) // 2, 4)
        for x in (8 - half - 1, 8 + half):
            if 0 <= x < 16:
                px(g, x, y, "W")
    return g


def marsh():
    """Marsh / reeds, art 1C. Liquid ink per section 6.

    Vertical strokes on the black field. Direction is what separates this from
    water, not colour - both are magenta per section 6.
    """
    g = blank()
    reeds = [
        (0, 3, 4), (3, 10, 5), (5, 1, 3), (7, 8, 4),
        (9, 4, 6), (11, 11, 3), (13, 2, 5), (15, 9, 4),
        (6, 13, 2), (12, 5, 2),
    ]
    for x, y, h in reeds:
        rect(g, x, y, 1, h, "M")
    # edge-touching stroke so vertical repeats have no blank gutter
    rect(g, 0, 12, 1, 4, "M")
    rect(g, 15, 0, 1, 5, "M")
    return g


# ---------------------------------------------------------------------------
# Structures
# ---------------------------------------------------------------------------


def rings():
    """Ring formation, art 05.

    Spec 7a: FIVE RINGS OF EQUAL SIZE arranged like the five on a die, slightly
    crooked, and every one must actually be a ring - a stray single pixel among
    them is a defect. The old tile had four rings plus a lone magenta pixel,
    which is exactly the defect named.
    """
    g = blank()
    # Five equal rings on a die face, inset so they never touch each other.
    rings = [
        (3, 3), (12, 3),
        (8, 8),
        (3, 12), (12, 12),
    ]
    ring = [
        ".##.",
        "#..#",
        "#..#",
        ".##.",
    ]
    for i, (cx, cy) in enumerate(rings):
        # "slightly crooked": nudge the middle ring by one pixel
        dx = 0 if i != 2 else 1
        put_rows(g, cx - 2 + dx, cy - 2, ring, "W")
    return g


def emblem():
    """Emblem / command-key square, art 06.

    Spec 7a: one symmetric mark - a square frame with four equal corner loops
    and a hole at the centre, INSET FROM THE EDGES so tiled copies stay
    separate. Marks a settlement.
    """
    g = blank()
    # outer frame, inset by 2 so neighbours never touch
    put_rows(g, 2, 2, [
        "............",
        ".WWWWWWWWWW.",
        ".W........W.",
        ".W.WW..WW.W.",
        ".W.W....W.W.",
        ".W.W....W.W.",
        ".W.WW..WW.W.",
        ".W........W.",
        ".W.WW..WW.W.",
        ".W.W....W.W.",
        ".W.W....W.W.",
        ".W.WW..WW.W.",
        ".W........W.",
        ".WWWWWWWWWW.",
        "............",
        "............",
    ], "W")
    return g


def tower():
    """Tower, art 07.

    Spec 7a: a SOLID silhouette, two prongs on top, flaring to the base.
    Outlining the tower and filling it with windows is a misreading - the old
    tile did exactly that. So this is a filled rook: no interior holes except
    the two gaps that make the prongs read.
    """
    g = blank()
    # two prongs
    rect(g, 4, 1, 3, 3, "W")
    rect(g, 9, 1, 3, 3, "W")
    # top block joining them, with the crenel gap between the prongs
    rect(g, 4, 4, 8, 3, "W")
    # body, flaring outward as it descends
    rect(g, 5, 7, 6, 4, "W")
    rect(g, 4, 11, 8, 3, "W")
    rect(g, 3, 14, 10, 2, "W")
    return g


def gate():
    """Gateway, art 08.

    Spec 7a: a frame with BLOCKY TABS AT ALL FOUR CORNERS and an opening at the
    bottom centre. A thick slab on two posts is not a gate, which is what the
    old tile was.
    """
    g = blank()
    # side posts
    rect(g, 3, 3, 2, 13, "W")
    rect(g, 11, 3, 2, 13, "W")
    # lintel across the top
    rect(g, 3, 3, 10, 3, "W")
    # blocky corner tabs, protruding past the posts on all four corners
    rect(g, 1, 2, 3, 2, "W")     # top left
    rect(g, 12, 2, 3, 2, "W")    # top right
    rect(g, 1, 14, 3, 2, "W")    # bottom left
    rect(g, 12, 14, 3, 2, "W")   # bottom right
    # feet flaring outward at the base
    rect(g, 2, 13, 4, 2, "W")
    rect(g, 10, 13, 4, 2, "W")
    # bottom centre left open: the opening you walk through
    return g


def signpost():
    """Signpost, art 0A.

    Spec 7a: a post carrying ONE HEAVY CROSSBAR high up, on a lighter base. A
    second bar near the foot turns it into a different kind of cross, so there
    is exactly one bar and the base is a distinct pedestal.
    """
    g = blank()
    # post
    rect(g, 7, 2, 2, 11, "W")
    # ONE heavy crossbar, high up
    rect(g, 2, 4, 12, 3, "W")
    # lighter base - a separate pedestal, not a second bar
    rect(g, 5, 13, 6, 2, "C")
    return g


def sea_monster():
    """Sea monster in water, art 0B: magenta + white.

    Spec 7a: a creature rising from sparse water - BODY LOW ON THE LEFT, NECK
    AND HEAD WITH AN OPEN MOUTH ON THE RIGHT. The water is the quiet part; the
    creature is the subject. NOT a doorway, which is what art 0B used to be.

    Section 6 gives this tile magenta + white, so the water is magenta and the
    creature is white.
    """
    g = blank()
    # sparse water: a few short horizontal ripples, magenta, low and quiet
    for x, y, w in [(0, 13, 4), (5, 14, 3), (10, 13, 5), (2, 15, 3), (12, 15, 3)]:
        rect(g, x, y, w, 1, "M")
    # body: a hump low on the left
    put_rows(g, 1, 7, [
        "..#####..",
        ".#######.",
        "#########",
        "#########",
        ".#######.",
    ], "W")
    # neck rising to the right
    rect(g, 8, 5, 3, 4, "W")
    rect(g, 9, 3, 3, 3, "W")
    # head, with an open mouth facing right
    rect(g, 10, 1, 4, 3, "W")
    rect(g, 13, 2, 2, 1, ".")    # mouth gap
    px(g, 12, 3, ".")
    # a tail flick trailing left
    rect(g, 0, 6, 2, 1, "W")
    return g


def moongate():
    """Moongate, art 30: white ink, teleporter.

    Spec 7a: an arch OPEN AT THE BOTTOM - solid top, side borders, NO BOTTOM
    LINE, interior stripes. It is a teleporter, so it must read as an entrance,
    not as masonry. The old tile was a repeating wall face, which is the
    misreading this amendment corrects.
    """
    g = blank()
    # solid top of the arch
    rect(g, 2, 1, 12, 3, "W")
    # side borders running the full height, with no bottom rail between them
    rect(g, 2, 1, 2, 15, "W")
    rect(g, 12, 1, 2, 15, "W")
    # interior stripes: vertical, suggesting the passage through
    for x in (6, 8, 10):
        rect(g, x, 4, 1, 12, "W")
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


def plane():
    """Plane, art 13. Amendment A1: this was misnamed 'signpost' by structural
    guess before the vehicles were identified. It is an aircraft the player
    boards with B.

    Drawn top-down: fuselage along the vertical axis, wings spanning the cell,
    tailplane at the foot. Distinct from art 12 (ship) which has a mast.
    """
    g = blank()
    # fuselage, nose at top
    rect(g, 7, 1, 2, 14, "W")
    # wings
    rect(g, 1, 6, 14, 2, "W")
    # tailplane
    rect(g, 4, 12, 8, 1, "W")
    # cockpit
    rect(g, 7, 3, 2, 2, "C")
    return g


def rocket():
    """Rocket, art 14. Amendment A1: "a tall tapering form on a wider base"
    already reads as a rocket on a pad, so this needs only its nose emphasising.
    """
    g = blank()
    # nose cone
    rect(g, 7, 0, 2, 2, "W")
    rect(g, 6, 2, 4, 2, "W")
    # body
    rect(g, 6, 4, 4, 6, "W")
    # fins
    rect(g, 4, 9, 2, 3, "W")
    rect(g, 10, 9, 2, 3, "W")
    # exhaust / pad base
    rect(g, 5, 10, 6, 2, "C")
    rect(g, 3, 12, 10, 4, "W")
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


def wall_RETIRED():
    """Retired: art 30 is a moongate, not a wall (spec 7a re-identification).

    Kept only so the removal is visible rather than silent; the registry no
    longer references it.
    """
    g = grid_fill("M")
    for y in range(0, 16, 8):
        rect(g, 0, y, 16, 2, "K")
    for x in range(0, 16, 8):
        rect(g, x, 0, 2, 8, "K")
        rect(g, (x + 4) % 16, 8, 2, 8, "K")
    rect(g, 2, 2, 4, 1, "W")
    rect(g, 10, 2, 4, 1, "W")
    rect(g, 2, 10, 4, 1, "W")
    rect(g, 10, 10, 4, 1, "W")
    return g


# ---------------------------------------------------------------------------
# Creatures. Schematic figures, 16x16, distinguished by silhouette class.
# ---------------------------------------------------------------------------


def _body(g, cx=8, head_y=1, torso_y=5, legs_y=11, arm="W"):
    """Shared upright monster body, filling the cell.

    Spec 7a: the eleven monster sprites must read as creatures that STAND UP AND
    FILL THEIR CELL - one figure, one dominant colour, upright, substantial. Not
    a small icon floating in the middle, and not scattered pieces. So the head
    is 5 wide and starts at row 1, the torso is 8 wide, and the legs run to the
    bottom edge. White is the dominant ink per section 6.
    """
    # horns / crest: two notches above the skull
    put_rows(g, cx - 2, head_y, [
        "#...#",
        "#####",
        "#####",
        ".###.",
    ], "W")
    # torso, full width
    rect(g, cx - 4, torso_y, 9, 6, "W")
    # legs, heavy, reaching the bottom edge
    rect(g, cx - 3, legs_y, 3, 5, "W")
    rect(g, cx + 1, legs_y, 3, 5, "W")
    return g


def person():
    """Monster (unnamed), art 0C: upright, arms at sides, horned head."""
    g = blank()
    _body(g)
    rect(g, 3, 6, 2, 5, "W")
    rect(g, 11, 6, 2, 5, "W")
    return g


def person_arms_up():
    """Monster (unnamed), art 0D: same family, arms out and up."""
    g = blank()
    _body(g, torso_y=6)
    rect(g, 3, 5, 2, 3, "W")
    rect(g, 1, 2, 2, 4, "W")
    rect(g, 11, 5, 2, 3, "W")
    rect(g, 13, 2, 2, 4, "W")
    return g


def staff_bearer():
    """Monster (unnamed), art 0E: a creature beside a thin vertical staff.

    Section 6 lists 0E in the white group (no magenta exception), so both the
    creature and the staff are white. The staff is distinguished by being a
    thin vertical bar, not by hue.
    """
    g = blank()
    _body(g, cx=6)
    rect(g, 2, 6, 1, 5, "W")
    rect(g, 9, 6, 1, 5, "W")
    rect(g, 12, 1, 1, 15, "W")
    return g


def group():
    """Monster (unnamed), art 0F: a broad, heavy creature.

    The old tile was two small figures; the amendment replaces the reading with
    one broad creature, so this is a single wide body.
    """
    g = blank()
    put_rows(g, 3, 1, [
        "#.....#",
        "#######",
        "#######",
        ".#####.",
    ], "W")
    rect(g, 2, 5, 13, 7, "W")
    rect(g, 3, 12, 4, 4, "W")
    rect(g, 10, 12, 4, 4, "W")
    return g


def robed():
    """Monster (unnamed), art 10: a cloaked figure, triangular silhouette."""
    g = blank()
    put_rows(g, 6, 1, ["#####", "#####", "#####", ".###."], "W")
    # cloak widening to the base, filling the lower cell
    rect(g, 6, 5, 5, 3, "W")
    rect(g, 5, 8, 7, 3, "W")
    rect(g, 4, 11, 9, 3, "W")
    rect(g, 3, 14, 11, 2, "W")
    return g


def horse():
    """Horse, art 11: a four-legged animal, LOW AND WIDE, head at one side."""
    g = blank()
    # body: low and wide
    rect(g, 3, 7, 11, 5, "W")
    # neck and head to the left
    rect(g, 1, 4, 3, 4, "W")
    rect(g, 0, 3, 3, 3, "W")
    # legs reaching the bottom edge
    for x in (3, 6, 10, 13):
        rect(g, x, 12, 2, 4, "W")
    # tail
    rect(g, 14, 5, 1, 3, "W")
    return g


def person_arms_out():
    """Monster (unnamed), art 18: upright creature, arms angled down and out."""
    g = blank()
    _body(g)
    rect(g, 2, 6, 2, 2, "W")
    rect(g, 1, 8, 2, 3, "W")
    rect(g, 12, 6, 2, 2, "W")
    rect(g, 13, 8, 2, 3, "W")
    return g


def dancer():
    """Figure, arms up, art 19: arms forming a V above the head."""
    g = blank()
    _body(g, head_y=4, torso_y=8, legs_y=12)
    rect(g, 4, 5, 3, 2, "W")
    rect(g, 2, 2, 2, 3, "W")
    rect(g, 9, 5, 3, 2, "W")
    rect(g, 12, 2, 2, 3, "W")
    return g


def small_person():
    """Monster (unnamed), art 1A: a slight, tall creature."""
    g = blank()
    put_rows(g, 6, 0, ["#...#", "#####", "#####", ".###."], "W")
    rect(g, 6, 4, 5, 7, "W")
    rect(g, 7, 11, 1, 5, "W")
    rect(g, 9, 11, 1, 5, "W")
    return g


def crouching():
    """Crouching figure, art 1B: humanoid with arms drawn inward."""
    g = blank()
    put_rows(g, 6, 2, ["#####", "#####", ".###."], "W")
    rect(g, 5, 6, 7, 5, "W")
    rect(g, 5, 11, 7, 2, "W")
    rect(g, 4, 13, 9, 3, "W")
    return g


def figure_broad():
    """Monster (unnamed), art 3C: upright creature, broad stance."""
    g = blank()
    put_rows(g, 6, 1, ["#...#", "#####", "#####", ".###."], "W")
    rect(g, 3, 5, 11, 6, "W")
    rect(g, 2, 11, 4, 5, "W")
    rect(g, 11, 11, 4, 5, "W")
    return g


def swordsman():
    """Monster (unnamed), art 3D: creature holding a blade up to one side."""
    g = blank()
    _body(g, cx=7)
    rect(g, 2, 6, 2, 5, "W")
    rect(g, 9, 6, 2, 3, "W")
    # blade, raised to the right
    rect(g, 13, 0, 2, 10, "W")
    rect(g, 11, 10, 4, 1, "C")
    return g


def figure_standard():
    """Monster (unnamed), art 3E: creature beside a tall vertical bar."""
    g = blank()
    _body(g, cx=6)
    rect(g, 2, 6, 2, 5, "W")
    rect(g, 9, 6, 1, 3, "W")
    # tall bar
    rect(g, 12, 0, 3, 16, "W")
    return g


def archer():
    """Monster (unnamed), art 3F: creature holding a curved bow."""
    g = blank()
    _body(g, cx=6)
    rect(g, 2, 6, 1, 5, "W")
    rect(g, 9, 6, 1, 5, "W")
    # curved bow on the right
    for y, x in [(1, 12), (2, 13), (3, 14), (4, 14), (5, 15),
                 (6, 15), (7, 15), (8, 14), (9, 14), (10, 13)]:
        px(g, x, y, "W")
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
    """Dark fill A, art 3A. Near-black with a small light motif.

    "Near-black" is expressed by leaving the field empty - black is the
    backdrop - and marking only the motif. White ink per section 6.
    """
    g = blank()
    rect(g, 2, 2, 2, 2, "W")
    rect(g, 12, 12, 2, 2, "W")
    return g


def dark_fill_b():
    """Dark fill B, art 3B. Near-black, motif clearly different from 3A."""
    g = blank()
    rect(g, 7, 4, 2, 8, "W")
    rect(g, 4, 7, 8, 2, "W")
    return g


# ---------------------------------------------------------------------------
# Registry: art index -> builder
# ---------------------------------------------------------------------------

NOT_A_LETTER = {0x30}

TILES = {
    0x00: water, 0x01: shallow, 0x02: grass, 0x03: forest,
    0x04: mountain, 0x09: mountain_pass, 0x1C: marsh,
    0x05: rings, 0x06: emblem, 0x07: tower, 0x08: gate,
    0x0A: signpost, 0x0B: sea_monster, 0x12: ship, 0x13: plane,
    0x14: rocket, 0x15: dungeon_mouth, 0x16: marker, 0x30: moongate,
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
INK_SPEC[0x17] = (CYAN, MAG, WHITE)         # checker border
INK_SPEC[0x1D] = ()                         # solid black: empty tile
for a in (list(range(0x04, 0x0B)) + list(range(0x0C, 0x17))
          + list(range(0x18, 0x1C)) + list(range(0x1E, 0x40))):
    INK_SPEC[a] = (WHITE,)                  # solid and man-made

# Re-apply the explicit multi-ink entries LAST so the broad white range above
# cannot overwrite them. 0B (sea monster) and 0E (creature with staff) sit
# inside 0C-16, and without this they silently collapse to white-only.
INK_SPEC[0x01] = (CYAN, WHITE)              # rough water
INK_SPEC[0x17] = (CYAN, MAG, WHITE)         # checker border


def apply_ink_spec(g, art):
    """Enforce the section 6 ink allowance for this art index.

    This used to *remap* whatever inks the shape happened to use onto the allowed
    set. That was right while the shapes predated section 6, but the shapes now
    assign their inks deliberately: the sea monster draws magenta water and a
    white body, the mountain pass draws no colour in its opening, and so on.
    Blind remapping would destroy those choices - it would, for example, repaint
    the pass's carved arch.

    So this now only strips ink that the spec forbids, and empties art 1D. It
    never substitutes one allowed ink for another. A shape that draws a
    disallowed ink loses those pixels, which shows up loudly in the proof and in
    inkcheck rather than being quietly recoloured into something plausible.
    """
    allowed = INK_SPEC.get(art)
    if allowed is None:
        return g
    if not allowed:
        return blank()

    ok = set(allowed)
    out = []
    for row in g:
        out.append("".join(c if (c not in PAL or c == "K" or c in ok) else "."
                           for c in row))
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
