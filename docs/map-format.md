# Sector map files: format, authoring, and the probe harness

How to read, modify, and synthesise Ultima II sector maps, and how to place the
player to test them. Written up because the knowledge is cheap to lose and this
will be needed again for every remaining terrain question.

Related: `docs/passability-findings.md` (F11, F12) for what each byte means,
`docs/tooling-procedures.md` for driving the emulator.

---

## 1. Hard rule

`original/` and `references/` are the ground truth and are **never written to**.
Modified maps go into a per-run copy under `tmp/<timestamp>/`, which is what
`tools/spice86_start.sh` creates each launch. `tools/u2_mkprobe.py` refuses any
output path containing `original/` or `references/`.

## 2. File layout

Sector maps are `original/mapxNN`, one per sector, 33 of them, all exactly
**4224 bytes**:

| range | size | meaning |
| --- | --- | --- |
| `0x000..0xFFF` | 4096 | the `64x64` tile grid, row-major |
| `0x1000` | 1 | always `0x1A` - a header marker, present in all 33 files |
| `0x1001..0x107F` | 127 | mostly zero; 25 distinct variants across the 33 sectors, purpose unproven |

Tile lookup, verified against a live frame at 199/200 cell agreement:

    tile(x, y) = data[y * 64 + x]        # x, y in 0..63

The `0x1A` marker is easy to misread as a rare terrain byte, because it appears
exactly once per file. It is not in the grid. Do not treat it as a tile.

## 3. Byte semantics

Every byte that occurs in a grid is a multiple of 4, `0x00..0xFC` - exactly 64
values - and the tile atlas has exactly 64 entries. So:

    art_index = map_byte >> 2

`art_index` indexes `tmp/tiles/tile_<NN>.png` (hex-named `00`..`3F`), produced by
`tools/tile_atlas.py` from the executable. Regenerate with
`python3 tools/tile_atlas.py` if the atlas is missing.

Confirmed terrain, each measured by walking (see F11):

| map byte | art | terrain | walking |
| --- | --- | --- | --- |
| `0x00` | 0 | water, magenta waves | **blocks** |
| `0x04` | 1 | faint sparse dots | passes |
| `0x08` | 2 | grass, sparse cyan dots | passes |
| `0x0C` | 3 | forest, cyan double-dash | passes |
| `0x10` | 4 | mountain, white diamond lattice | **blocks** |
| `0x14`..`0x28` | 5..A | `%`, four-pane, tower, gate, lattice, cross | passes |

Four bytes out of 256 are proven by hand-walk; the rest of the table came from
the probe harness and is less thoroughly cross-checked. The *rule* is still
unknown - only instances of it.

Note `0x08` grass renders as nearly nothing. A "blank" cell in a screenshot is
real terrain, not a missing tile.

## 4. The world wraps

The viewport is toroidal, not clamped. With the player at `x=0`, the left edge
shows `x=55..63`. Verified by seeing the atlas `X Y Z` glyphs (map bytes
`0xF0..0xF8`) on the left of the screen while parked at `x=0`.

Practical consequence: scripted walks that assume a flat grid desynchronise
silently near an edge. **Start probe walks near the middle of the map.**

Viewport geometry: 20x10 tiles, 16x16 px each, player at screen cell `(9,5)`,
status band below.

## 5. Authoring a probe map

Real sectors make passability testing slow and incomplete: rare bytes occur 2-7
times and are often walled off behind water or mountains, so you cannot reach
them to step into them. A synthetic map puts every byte next to walkable ground
in one sector, so a single walk measures the whole table.

    python3 tools/u2_mkprobe.py -o /var/tmp/tp/mapx20.probe \
        --probe-y 31 --corridor-y 32

This fills the grid with grass, then lays one probe tile per byte value
(`0x00..0xFC` step 4) along row `y=31` at `x=0..63`, leaving row `y=32` as a
clear grass corridor. Stand on the corridor, step Up into a probe, step back.

Deploy it by overwriting the map inside a **run copy**, after the emulator has
started but before the game loads the sector (the map is read when the character
enters the sector, i.e. after pressing `P`):

    tools/spice86_start.sh --headless --name probe --player <save> --patch-arrows
    # parse "run dir <path>" from its output, then:
    cp /var/tmp/tp/mapx20.probe <run dir>/mapx20

To render a map to a PNG for eyeballing, paste `tile_<byte>>2>.png` per cell -
see the recipe in this file's history, or `tools/map_render.py`.

## 6. Placing the player: edit the save, do not poke memory

Covered properly in `docs/save-format.md`. The two facts that matter for map work:

* **Writing `DS:00/01` live does not teleport.** The write lands and reads back,
  but movement then stops working entirely - it is a mirror, not the source.
  Edit the save and reload instead: `python3 tools/u2_edit.py setpos <save> X Y`.
* **Sector is two decimal digits** at `DS:49/4A` (patched into the filename
  `MAPXFF`), so sector 20 is the pair `2,0`, and a numeric read gives 512.
  `tools/u2_edit.py set <save> sector 71` handles the split. Verified: digits
  `1,0` boots into sector 10.

Since the save record is `DS:36..135` verbatim, a probe map plus a teleport can
put the character on any tile of any sector without walking there.

**Sector is not stored in the save.** The game tracks it separately, so this
places you within whatever sector you land in; it cannot move you between
sectors. Cross-sector work still requires walking off a map edge.

## 7. Verifying a result

Two independent signals, both cheap:

1. **Screenshot** via MCP `screenshot` (needs the patched vendored build; see
   `docs/tooling-procedures.md`). Copy it out of `/tmp/spice86-mcp-screenshots/`
   into `tmp/screens/` to look at it.
2. **Position read** from `DS:00/01` before and after each key. A move that did
   not change position was blocked.

Cross-check the two. The probe harness reproduced the hand-walk results for
`0x00` and `0x10` independently, and that agreement is what made the table
trustworthy.

## 8. Traps

- **Memory reads pause the CPU.** `WhilePaused` in Spice86 pauses for every HTTP
  memory read and resumes afterwards, but keys sent immediately into that window
  are silently lost. Settle ~0.5-1 s after a read before injecting a key, and
  verify every step rather than assuming it landed.
- **`/api/memory/<addr>/range/<n>` is read-only.** Writes use
  `PUT /api/memory/<addr>/byte` with body `{"value": N}`, one byte at a time.
- **The MCP screenshot tool needs the patched build.** Stock upstream returns raw
  PNG bytes where base64 is required and the client rejects it.
- **`pgrep -f Spice86` matches its own shell.** Check ports instead.
- **Never run the game in place.** It rewrites its own `player` file; always use
  a run copy.
