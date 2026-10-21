# Tile art

Two tile sets live under this directory, and they have very different legal status.
Do not mix them up.

| set | what it is | committed? |
| --- | --- | --- |
| `cleanroom/` | **our own original art**, independently created from a written spec | yes, Apache-2.0 |
| extracted originals | renderings pulled from `original/ultimaii.exe` | **no** — copyrighted, stays in `tmp/tiles/` |

The engine should prefer the player's own extracted art when a copy of the game is
present, and fall back to `cleanroom/` otherwise. That way this repository ships
usable art and never ships anyone else's.

## cleanroom/

`cleanroom/tiles/tile_00.svg` … `tile_3F.svg` — 64 tiles, one per art index
(`art = map_byte >> 2`).

- **`PROVENANCE.md`** is the legal record and must travel with the art. It names who
  wrote the spec, who implemented it, what inputs the implementer had, and which
  version of the spec was implemented. If you move or copy these tiles, copy that
  file with them.
- **`gen/tiles.py`** regenerates the whole set deterministically — no RNG, no
  network. The committed SVGs should be byte-identical to its output; if you edit a
  tile by hand, regenerate instead.
- **`gen/check.py`** asserts the acceptance criteria: palette, grid alignment, no
  blank tiles, no two tiles in a class confusable.

The specification itself lives at `docs/tile-art-spec.md` in the repo root. It is
the contract, and `PROVENANCE.md` pins which version was implemented by git blob
SHA, so the record can be checked even after the spec changes.

### Verifying the set

    python3 engine/assets/tiles/cleanroom/gen/check.py
    python3 engine/assets/tiles/cleanroom/gen/tiles.py
    git diff --stat engine/assets/tiles/cleanroom/tiles    # should be empty

### Into the engine

The engine cannot read SVG, so the set is converted at build time and the result
is committed:

    (cd engine && python3 tools/tiles2h.py \
        --src assets/tiles/cleanroom/tiles \
        -o src/core/tiles_cleanroom.h)

`src/core/tiles_cleanroom.h` is generated and **committed**, so a normal build
needs no Python. It is packed 2bpp, the exact inverse of `u2_tile_pixel()`, and
`core/tiles_builtin.c` turns it into a `u2_tiles`. `make test` enforces both
halves: the header must still match the SVGs, and the bytes must decode back to
the pixels the SVGs contain. Editing the header by hand fails the build.

This is a fallback, not a replacement. The player's own extracted art still wins
when the game files are present; `u2_tiles_builtin()` exists so the engine has
usable tiles when they are not.

### Palette

Three inks on a black backdrop: cyan `#55FFFF`, magenta `#FF55FF`, white
`#FFFFFF`. No tile emits `#000000` — black is what the renderer paints before
drawing (`u2_frame_clear(..., U2_CGA_BLACK)`), so an all-black tile is an empty
tile. Art `1D` is empty for exactly that reason and is not missing.

Colour is semantic, not decorative: cyan is vegetation, magenta is liquid, white is
solid and man-made. See spec § 6.
