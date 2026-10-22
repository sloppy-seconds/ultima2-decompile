# Provenance note — substitute tile art

> **This file is NOT an implementer input.** It is the legal record of how the set was made,
> and it discusses the originals and cites paths that § 2 of `docs/tile-art-spec.md` forbids
> to whoever draws the art. If you have been asked to draw or redraw tiles, do not read this
> file: work from `docs/tile-art-spec.md` alone. Reading this one does not disqualify you from
> the protocol by accident — it disqualifies you because it tells you what the originals were
> described as, which is the thing the wall exists to keep out.

**Date:** 2026-10-21

## Roles

| role | who |
| --- | --- |
| spec author | an agent that examined the original 1983 binary |
| implementer | pi (AI agent), separate session, this directory only |

## Inputs available to the implementer

1. `tile-art-spec.md` — this specification, and nothing else from the original
   work. Pinned below.
2. A public font project was considered for the letter tiles and **rejected**
   before use: `smithkm/scriven` (SIL OFL 1.1). It was reviewed only by reading
   its public README and licence on GitHub. No glyph was rendered, imported or
   traced from it. Reason for rejection: its Runic design is documented as
   influenced by the Ultima games, which would compromise this cleanroom, and a
   mediaeval outline face does not rasterise legibly to 16x16 anyway.

No other external material was consulted. The glyphs, textures and figures were
authored from scratch as integer pixel grids.

### Spec version implemented

| | |
| --- | --- |
| file | `docs/tile-art-spec.md` |
| git blob SHA | `c03419892c7a367989c61f5752450314e5a01cf0` |
| blob size | 15234 bytes |
| committed in | `3e6adf6` ("tile-art-spec: colour is a fact, so specify it - and black is backdrop, not ink") |
| vendored into this repo | `b46e5be` ("vendor the cleanroom tile set, and let the viewer compare it against the originals") |

**Corrected 2026-10-22.** This section previously pinned
`f214a89b3d068f54f98a0615006699a9bf2cdeaf` (11313 bytes) and cited `99119e3` as the
commit that first carried the art. Both were wrong, and the art itself is the proof.

*`f214a89` is the spec's first commit (`9b0c8c5`), 234 lines, and it contains no
Colour-assignment section and no backdrop rule. § Verification below asserts that every
`#rrggbb` in the deliverable is one of the four palette colours and that black is the
backdrop — requirements that exist only from `d9c6df6`/`3e6adf6` onward. An implementer
handed `f214a89` could not have produced art that satisfies this note. The colour rules
arrived in `c034198`, which is what the deliverable follows.*

*`99119e3` does not resolve in this repository (`git log -1 99119e3` → unknown revision).
It was a commit in the originating repo. In this repo the set arrived in `b46e5be`.*

Verify:

    git rev-parse 3e6adf6:docs/tile-art-spec.md   # c03419892c7a... the pinned blob
    git cat-file -p c03419892c7a367989c61f5752450314e5a01cf0 | grep -c 'Colour assignment'   # 1
    git cat-file -p f214a89b3d068f54f98a0615006699a9bf2cdeaf | grep -c 'Colour assignment'   # 0

Do **not** verify with `git hash-object docs/tile-art-spec.md`: the working tree has moved
on (amendment A1 changed it), which is the whole reason a blob is pinned here.

The pin's purpose is unchanged: a reader should not have to trust a working tree that
moves on. What changed is that the pinned blob is now the one that was actually used.

### Amendment A1 — arts `13` and `0x4C`, and `14`/`0x50` renamed (2026-10-22)

The spec named art `13`/`0x4C` **signpost** and art `14`/`0x50` **spire**. Both are
vehicle tiles: `[DS:14] = map_byte >> 1` (measured on 53 of 54 walk samples) and
`asm/2FAD` dispatches BOARD against `0x22` horse / `0x24` ship / `0x26` plane / `0x28`
rocket, so `0x44`/`0x48`/`0x4C`/`0x50` are horse, ship, plane and rocket. The game
confirmed it: boarding a `0x4C` tile printed `' PLANE'`. Full chain in
`docs/spice86-live-findings.md` § 12 and `disasm/tile-art.tsv`.

The spec rows were corrected in place (see § Structures, Amendment A1). **The SVGs were
not redrawn, deliberately.** § 2 forbids the implementer from reading
`disasm/tile-art.tsv` — the very file holding this proof — because it describes originals
seen directly. Correcting a spec row is a spec-author act and may use that evidence;
redrawing `tile_13` is an implementer act and must not. The agent who made this
correction had read `disasm/tile-art.tsv` in the same session, so is disqualified from
that role and did not attempt it.

Consequence, stated rather than hidden: **`tile_13.svg` still depicts a notice board for a
tile the game calls a plane.** That is a known, recorded mismatch awaiting a clean
implementer pass, not an undiscovered one. `tile_14` needs no redraw — "a tall tapering
form on a wider base" already reads as a rocket on a pad; only its name was wrong.

*(Superseded by Revision 2 below: `tile_13` no longer depicts a notice board, though it does
not yet satisfy its rule.)*

## Revision 2 — 2026-10-22, set rebuilt against the amended spec

The substitute set was regenerated by a separate cleanroom implementer in its own repository
and imported here.

| | |
| --- | --- |
| built in | `/var/home/paul/Projects/ai/ultima-cleanroom` |
| their commit | `bcfb2e2` ("Regenerate the tile set against the amended spec") |
| spec implemented | blob `46e0d4d8318e0cfd8529892852b5d8f91342a496`, 24560 bytes |
| that blob is | the current `docs/tile-art-spec.md`, verified identical by `diff` — 0 lines |
| imported tiles | 64/64 byte-identical to their committed build, verified by sha256 |
| generator | their `gen/tiles.py` imported too; rerunning it reproduces all 64 SVGs exactly |
| implementer role | separate session, worked from the spec alone; their own PROVENANCE records this |

**Gate outcome, measured rather than assumed.** Conforming substitutes went from 5 to 17, with
**zero regressions** — the five tiles already enforced still pass.

* **Fixed (12):** `04` `05` `09` `0C` `0D` `0E` `16` `18` `1A` `1C` `3D` `3F` — the mountain
  crosshatch, the ring quincunx, the pass arch, seven monster sprites, the marker and the marsh.
* **Much closer but not passing (25 letters):** every letter tile now carries its top and
  bottom rules, which was the defect. They fail only because the glyph touches the gutter rows
  beneath and above the rules. That is a spacing refinement, not a missing feature.
* **Still failing the headline re-identifications:** `06` emblem (5 pieces, not 4-fold
  symmetric), `0A` signpost (4 pieces), `0B` sea monster (wrong component structure, water not
  a stipple), `30` moongate (no top rule), `13` plane, `14` rocket, `00`/`01` water lattice,
  `03` forest (6 components where 3 were asked for).

The gate is honest about this: 47 tiles remain in `PENDING_REDRAW` and are reported as visible
debt on every `make test`, so a partial redraw cannot be mistaken for a finished one.

## Forbidden paths

The following were **not** opened, read, listed, rendered or searched by the
implementer:

- `original/`
- `references/`
- `tmp/tiles/` and `tmp/tiles/tiles.json`
- `disasm/tile-art.tsv`
- `asm/`, `build/`, `captures/`
- `tmp/*.png`, `tmp/screens/`

The implementer did not use `ctx_search`, `ctx_index` or `ctx_batch_execute`
against this project, per section 2 of the spec. The implementer did not read
`AGENTS.md` or the repository docs directory for orientation, for the same
reason.

## Statement

The 64 files in `tiles/` were produced by the generator in `gen/tiles.py`,
which emits integer-aligned rectangles from hand-specified pixel grids. No file
in the set was produced by tracing, importing, converting or sampling original
game art, or any depiction of it. The set was not compared against any reference
image of the original game.

## Deviations and judgement calls

The spec leaves some details open. These were decided as follows:

| tile | decision |
| --- | --- |
| `1F` edge strip | light band on the **top** edge, 5px tall, with a cyan rule beneath |
| `17` checker border | 2x2 checker across the whole cell, no plain margin |
| `3A` / `3B` dark fills | `3A` = corner-pip motif; `3B` = centre cross motif |
| `12` ship | drawn front-on, mast centred, so it reads at 16x16 |
| `20`-`39` letters | 5x7 bold capitals scaled 2x to 10x14, magenta ink on black. No rules above/below (the spec makes them optional) |
| `30` wall | not a letter; drawn as built fabric per the spec |

`Q` is absent, as specified. Indices `20`-`2F` are A-P and `31`-`39` are R-Z.

## Verification performed

- 64 files, `tile_00.svg` … `tile_3F.svg`, no gaps in the index range.
- Every file has `viewBox="0 0 16 16"`, `shape-rendering="crispEdges"`, and no
  fixed `width`/`height`.
- Every `#rrggbb` value in every file is one of the four palette colours. No
  gradients, no opacity, no stray channels.
- Every emitted `<rect>` has integer `x`, `y`, `width`, `height` on the 1px grid.
- No two tiles in the same class are identical, and none differ by 3 pixels or
  fewer (checked pairwise by Hamming distance over the pixel grid).
- No tile is blank.
- Ground tiles have no blank edge gutters, so repeats do not form visible seams.

Proof sheets at 8x and 4x3x3-repeat were generated by `gen/proof.py` into
`/var/tmp/ultima-cleanroom-proof/` for visual review. They are scratch output
and are not part of the deliverable.

## Caveats

- The creature tiles are deliberate schematic abstractions: a 3px head, a five-
  wide torso, two legs, and an arm or accessory position that carries the
  distinction. They are distinguishable from each other at native size, which is
  the requirement. They are not characterful, and were not meant to be.
- Seamless tiling was verified by the absence of gutters and by repeated-render
  proof sheets, not by a perceptual seam metric.
- `09` mountain pass reuses the `04` lattice with a carved opening, so the two
  share most of their pixels. That is intentional per the spec and they remain
  distinguishable.

## Licence

Apache-2.0, per section 8 of the spec.
