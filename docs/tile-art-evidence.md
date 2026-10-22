# Tile art evidence — spec-author notes, NOT an implementer input

**Read this before using it.** Everything in this file was written by someone with the
original game art in view, or derived from measurements of it. That makes it exactly the
material § 2 of `docs/tile-art-spec.md` forbids to whoever draws the substitute art.

It lives here rather than inside the spec for one reason: **the spec is the implementer's only
legal input, so it may carry intent but never a trace.** A trace is anything that lets you
reproduce the original without looking at it — pixel coordinates, measured densities, cyclic
periods, component sizes. Intent is what the tile must communicate.

| document | who may read it |
| --- | --- |
| `docs/tile-art-spec.md` | spec author, implementer, anyone |
| this file | spec author, reviewers, the owner — **not the implementer** |
| `tools/tile_rules.py` | the gate, spec author, reviewers — **not the implementer** |
| `disasm/tile-art.tsv`, `tmp/tiles/`, `asm/` | spec author, reviewers — **not the implementer** |

If a redraw is ever audited, the question this file answers is: *did the implementer work
from the spec alone?* The answer must be yes, and the existence of this file is why the
question can be answered honestly.

---

## A1 evidence — arts `13` and `14` are the plane and the rocket

Moved out of the spec on 2026-10-22 because the spec text cited `asm/2FAD`,
`docs/spice86-live-findings.md` and `disasm/tile-art.tsv` — three paths forbidden to the
implementer — and described tile-art.tsv as "the file that records this proof", which is an
invitation to breach the wall from inside the one document they are allowed to read.

The finding stands; only its location changes.

* `[DS:14] = map_byte >> 1`, measured live on **53 of 54** walk samples across four terrain
  bytes.
* `asm/2FAD` dispatches BOARD on `[DS:14]` against `0x22` horse, `0x24` ship, `0x26` plane,
  `0x28` rocket. Vehicle map bytes are therefore `0x44`, `0x48`, `0x4C`, `0x50` — arts
  `0x11`, `0x12`, `0x13`, `0x14`.
* The game confirmed it directly: standing on a `0x4C` tile in `mapx32` at (4,10), `B` set
  `[DS:13] = 0x26` and printed `' PLANE'`; `L` printed `LAUNCH--PLANE`.
* Arts `11` (horse) and `12` (ship) already agreed. Only `13` and `14` were misnamed.

The original's own glyph for art `13` was described as *"crossbar over a vertical post on a
base"* — which is why a previous author guessed "signpost". The name was applied two tiles
away from the actual signpost, which is art `0A`.

---

## Measured structure of the originals (the basis for the gate's bands)

These are **traces**. They are here so a reviewer can check the gate is honest, and so the
bands in `tools/tile_rules.py` have a cited source. They must not be copied into the spec.

| art | what it is | measured structure of the original |
| --- | --- | --- |
| `00` | water | single-pixel dashes, odd columns only, inked rows cyclic period 4, density 12.5% |
| `01` | shallow water | ink on even rows only (period 2) and odd columns, 1px, density 9.0%, white 16 : cyan 7 |
| `02` | grass | sparse stipple, odd columns, density 4.3% |
| `03` | forest | 3 components of 27px at (left,top) (left,bottom) (right,middle), density 31.6% |
| `04` | mountain | h-run 1, diagonals 6 (down-right) and 9 (down-left), every row and column inked, density 22.3% |
| `05` | ring formation | 5 hollow components of 8px each, centres on a quincunx, top pair offset one row |
| `06` | emblem | one component, 72px, 4-fold symmetric (h, v, diagonal), 4 corner holes of 9px + centre hole of 4px, density 28.1% |
| `07` | tower | one solid component, 88px, 2 runs in the first inked row, widest at the base, density 34.4% |
| `08` | gate | one component, 2 runs in the last inked row (the opening), ink within 2px of all four corners, density 28.1% |
| `09` | mountain pass | art 04's crosshatch plus an arch at rows 9–15; bottom row open through the centre, density 25.4% |
| `0A` | signpost | one component, one crossbar band of 5 rows (base excluded), density 32.8% |
| `0B` | sea monster | magenta = 2 components (28px neck+head right rows 5–13, 21px body low-left); white = 20 components totalling 22px |
| `0C`–`0F`, `10`, `18`, `1A`, `3C`–`3F` | monster sprites | components 1 (only `0E` is 2), density 20.3–48.4%, aspect h/w 1.00–1.56, sprite height 14–16 rows. `0E` is MAGENTA (65 px) not white |
| `11` | horse | density 27.7%, aspect h/w 0.79 (low and wide) |
| `12` | ship | density 34.4%, 8 enclosed holes |
| `13` | plane | density 30.5%, aspect 1.14 |
| `14` | rocket | density 16.0%, aspect 1.45 (tall and narrow) |
| `15` | dungeon mouth | 2 components, density 25.4%, aspect 1.17 |
| `16` | marker | density 6.2% (very sparse) |
| `17` | checker border | diagonal dot lattice: x period 2, y period 8, colour cycles every 2 rows, density 50.0%, all four palette colours |
| `1C` | marsh | 26 components, magenta dominant, density 21.9% |
| `1D` | solid black | **entirely black — zero ink** |
| `1E` | solid white | 100% density, 4-fold symmetric |
| `1F` | edge strip | 2 components, density 12.5% |
| `3A`, `3B` | dark fills | 1 component each, density 18.0% |

Letters `20`–`2F` and `31`–`39`: every one has rows 0 and 15 fully inked (16/16) with rows 1
and 14 clear. The substitute has both rules missing on all 25.

---

## Open naming questions this review did not settle

Recorded so nobody mistakes a placeholder for a finding:

* **`15`** — spec says dungeon mouth; a blind model read a heater shield with an S-squiggle
  and called it a sign. Unresolved.
* **`16`** — spec says marker; the blind read was "sword" (a diagonal with a crossbar).
* **`1C`** — spec says marsh/reeds; the blind read was "forest", which collides with art `03`
  already being forest. The blind label was rejected on that basis.
* **Six of the eleven monster sprites have no known name** (types 48, 96, 104, 240, 244 and
  the item-drop type `0xFC`). A blind model offered "Devil" for type 48 with high confidence
  and no source; that is a hypothesis, not a name.

See `/var/tmp/game-knowledge-deltas.md` (also not an implementer input) for the full
game-knowledge deltas D1–D12 and their grades.
