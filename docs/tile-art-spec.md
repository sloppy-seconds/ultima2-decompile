# Tile Art Specification — original substitute art

**Status: specification only. No art has been produced from this document yet.**
**Purpose: to commission independent, original tile art for the Ultima II engine
reconstruction, so the project can ship a usable art set without distributing the
copyrighted 1983 assets.**

This document is written by an agent that has examined the original binary. That is
the first half of a cleanroom process. The implementer is a different agent, in a
different session, that must not examine the original. See § 2.

---

## 1. What this is, and what it is not

This is a specification for **substitute art**, not a reproduction. The goal is a
tile set that communicates the same thing at a glance, in the same palette, at the
same size. Where the result differs from the 1983 art, that difference is the
point and the requirement — it is what makes the set independently created.

**Do not attempt to match the original sprites.** Do not seek them out to "check
your work". If you find yourself comparing your output against a reference image
of the game, stop; that comparison is the act this process exists to prevent.

Nothing in this file is a pixel transcription. Descriptions are impressions of
function and character. Two competent artists following it will produce visibly
different sets, and both sets are correct.

## 2. Cleanroom protocol — read this before doing anything

The value of this exercise depends entirely on the wall being real.

**The implementer must not open, read, list, render, or search any of the
following, in this repository or anywhere else:**

| forbidden | why |
| --- | --- |
| `original/` | the copyrighted game files |
| `references/` | a second copy of the same |
| `tmp/tiles/` | extracted renderings of the original tile art |
| `tmp/tiles/tiles.json` | contains ASCII renderings of the originals |
| `disasm/tile-art.tsv` | descriptions written by someone who had the originals in view |
| `asm/`, `build/`, `captures/` | derived from the copyrighted binary |
| `tmp/*.png`, `tmp/screens/` | screenshots of the running game |

**Also be aware of two non-obvious leaks in this environment:**

1. **context-mode session memory.** Prior sessions in this project indexed ASCII
   renderings of the original tiles. A `ctx_search` in this project can surface
   them. Do not use `ctx_search`, `ctx_index` or `ctx_batch_execute` against this
   project while doing this work.
2. **`AGENTS.md` and the docs directory** name the asset paths above. Reading them
   for orientation will point you at forbidden material.

**Recommended working arrangement:** do the implementation in a separate
directory outside this repository, containing only this specification. If you are
an agent, state in your first reply that you will not read the paths listed above,
and let the requester confirm.

**Record keeping.** When the work is done, write a short provenance note next to
the output recording: the date, who authored this spec, who implemented it, which
inputs were available to the implementer (this file, and nothing else), and a
statement that the forbidden paths were not read. Keep it. That note is the
cleanroom claim.

## 3. Technical requirements

- **Format:** SVG, one file per tile.
- **Canvas:** `viewBox="0 0 16 16"`, no fixed `width`/`height`, so consumers can
  scale freely.
- **Rendering:** `shape-rendering="crispEdges"`; this is pixel art and must not
  blur when scaled.
- **Grid:** build from 1×1 unit rectangles (or paths aligned to integer
  coordinates). Nothing may straddle a pixel boundary.
- **Colours — three inks on a black backdrop, no others, no gradients, no alpha:**

  | role | name | hex |
  | --- | --- | --- |
  | ink | cyan | `#55FFFF` |
  | ink | magenta | `#FF55FF` |
  | ink | white | `#FFFFFF` |
  | backdrop | black | `#000000` — **never emitted in a tile** |

  This is the CGA composite mode-4 palette. Black is the field the engine paints
  before drawing (`u2_frame_clear(..., U2_CGA_BLACK)`), not a colour a tile owns.
  Emitting black would make a tile opaque in some cells and transparent in others,
  and on a black backdrop that inconsistency is invisible to any proof sheet - it
  can only be caught by asserting that `#000000` does not appear in the set.

  Consequence: a tile whose appearance is "all black" is expressed as an **empty
  tile**, not as a tile full of black rectangles. Art `1D` is exactly that case and
  is correct, not missing. A backend that needs opaque tiles composites onto black
  itself rather than each tile carrying its own background.
- **Naming:** `tile_<NN>.svg`, `NN` = the two-digit uppercase hex **art index**
  from the table below. Not the map byte — see § 4.
- **Every tile must be legible at 16×16.** Test by rendering at native size, not
  zoomed.

## 4. Indexing

The engine stores one byte per map cell. The art index is:

```
art_index = map_byte >> 2
```

So map byte `0x00` selects art `00`, byte `0x04` selects art `01`, byte `0xFC`
selects art `3F`. Art indices run `00`–`3F`, 64 tiles. The byte column is given
below only so the mapping is unambiguous; it is not otherwise relevant to drawing.

## 5. Functional classes

The 64 entries are **not** 64 terrain types. They fall into five groups, and the
group tells you how much care a tile needs:

| class | meaning | risk |
| --- | --- | --- |
| ground | walkable or blocked surface, tiles the map in bulk | low — geometric, few expressive choices |
| structure | a built thing: walls, gates, towers, docks | medium |
| creature | a person or animal standing on the map | **high — these are the expressive ones** |
| letter | the capital letters A–Z, used as shop fronts and signs | low — it is a font |
| block | border and fill pieces for framing | low |

**The creature tiles are where the copyright risk actually lives.** A figurative
drawing is creative expression in a way that a dot field is not. For those, favour
the most generic, schematic figure that still reads, and deliberately avoid
reproducing any particular pose, silhouette or costume detail you may have seen.

## 6. Colour assignment

Colour is specified per tile. This is not a contradiction of the cleanroom rule:
colour is a **fact about the program's behaviour**, not expression, and a spec is
allowed to carry facts. What stays off-limits is the drawing - which pixels are lit
and how. Knowing that grass is cyan tells the implementer nothing about how to draw
grass.

The table below is **measured**, from the extracted art (`tmp/tiles/tiles.json`,
`color_names` per entry), not from impression.

| ink | art | meaning |
| --- | --- | --- |
| **cyan** | `02` `03` | vegetation - grass, forest |
| **magenta** | `00` `1C` | liquid - water, marsh |
| **white** | everything else: `04`-`0A`, `0C`-`16`, `18`-`1B`, `1E`-`3F` | solid and man-made - mountains, structures, creatures, letters, blocks |
| cyan + white | `01` | rough water |
| magenta + white | `0B` `0E` | arch in a field; figure with a staff |
| cyan + magenta + white | `17` | the checker border |
| **none** | `1D` | solid black - an empty tile per § 3 |

55 of 64 tiles use white alone. The pattern is worth understanding rather than
copying blindly: **cyan means vegetation, magenta means liquid, white means
solid.** Graded *inferred* - it is a reading of the pairing, and the pairing is
tight, the only two cyan tiles being grass and forest and the only two magenta
tiles being water and marsh.

**This deliberately pins the substitute set close to the original's appearance.**
An earlier revision of this spec said the opposite, arguing that a visibly different
fallback made it obvious which art was loaded. That is dropped: for a reconstruction,
fidelity is the point, and a fallback set that looks different on purpose is a
strange thing to ship. Recorded here so the change is visible rather than silent.

### Verification constraints

The assignment above is fixed, so these are checks on the drawing, not choices.

| # | constraint | why |
| --- | --- | --- |
| V1 | Letters (`20`-`39`) must stay legible against **every** ground tile they can sit on. | Signs are placed on varied ground; a letter that merges with its backdrop fails at its only job. White ink on cyan grass and on magenta water both need checking. |
| V2 | Creatures must not be confusable with any ground tile. | Creatures are stamped into the map at runtime, so they are seen *on* ground, not beside it. |
| V3 | The seven ground tiles must remain distinguishable at 16x16 **on black**. | This is the real viewing condition. A set that separates on white can collapse on black. |

## 7. Per-tile specification

### Ground

Must tile seamlessly when repeated, and must stay quiet under the other classes.

| art | byte | name | must read as |
| --- | --- | --- | --- |
| `00` | `0x00` | water | open water; a loose, irregular texture suggesting movement on a dark field |
| `01` | `0x04` | shallow / rough water | water with more broken texture than `00` |
| `02` | `0x08` | grass | open grassland; sparse light speckling on dark ground, the calmest tile in the set |
| `03` | `0x0C` | forest | woodland; denser, chunkier coverage than grass, clearly "more stuff on the ground" |
| `04` | `0x10` | mountain | high ground; a regular angular lattice, visually hard and bright |
| `09` | `0x24` | mountain pass | the mountain texture with an opening at the bottom centre, suggesting an entrance through |
| `1C` | `0x70` | marsh / reeds | vertical strokes on a dark field; distinct from water by direction, not colour |

### Structures

| art | byte | name | must read as |
| --- | --- | --- | --- |
| `05` | `0x14` | ring formation | a small group of ring shapes |
| `06` | `0x18` | masonry | a block of squared masonry, regular and man-made |
| `07` | `0x1C` | tower | a single upright tower with a crenellated or forked top |
| `08` | `0x20` | gate | two posts under a lintel; an opening you would walk through |
| `0A` | `0x28` | monument | an upright cross or marker on a base |
| `0B` | `0x2C` | arched doorway | an arch set in a filled field |
| `12` | `0x48` | ship | a boat: hull with a vertical mast |
| `13` | `0x4C` | plane | an aircraft the player can board with `B` — see amendment A1 |
| `14` | `0x50` | rocket | a tall tapering form on a wider base, i.e. a rocket on a pad — see amendment A1 |
| `15` | `0x54` | dungeon mouth | an enclosed opening; the "go down here" tile |
| `16` | `0x58` | marker | a small diagonal mark with a cross at its foot |
| `30` | `0xC0` | wall / bulk structure | a dense structural tile that occurs in large repeated blocks; must read as built fabric, not terrain |

### Amendment A1 — 2026-10-22, arts `13` and `14` renamed

Arts `13` and `14` were originally named **signpost** and **spire** by structural guess,
before the vehicles had been identified. The bytes are vehicle tiles, proven by
measurement and confirmed by the game:

* `[DS:14] = map_byte >> 1`, measured live on **53 of 54** walk samples across four
terrain bytes (`docs/spice86-live-findings.md` § 12);
* `asm/2FAD` dispatches BOARD on `[DS:14]` against `0x22` horse, `0x24` ship, `0x26`
plane, `0x28` rocket — so the vehicle map bytes are `0x44`, `0x48`, `0x4C`, `0x50`, i.e.
arts `0x11`, `0x12`, `0x13`, `0x14`;
* the game said so directly: standing on a `0x4C` tile in `mapx32` at (4,10), `B` set
`[DS:13] = 0x26` and printed `' PLANE'`, and `L` printed `LAUNCH--PLANE`.

`11`/`0x44` horse and `12`/`0x48` ship already agreed with this and are unchanged. Only
the two names were wrong.

**The art set was deliberately not regenerated by this amendment.** Renaming a row is a
spec-author act and uses live-capture evidence, which the spec author may read. Redrawing
`tile_13` is an implementer act, and § 2 forbids the implementer from reading
`disasm/tile-art.tsv` — the file that records this proof — because it describes originals
seen directly. Whoever performs the redraw must be a fresh implementer working from this
spec text alone, not from the evidence behind it. Until that happens `tile_13` still
depicts a notice board, which is a known and recorded mismatch, not an undiscovered one.

Art `14` needs no redraw: "a tall tapering form on a wider base" already reads as a rocket
on a pad. Only its name was wrong.

### Creatures

Schematic figures. Distinguish them by silhouette class, not by detail.

| art | byte | name | must read as |
| --- | --- | --- | --- |
| `0C` | `0x30` | person | an upright humanoid figure, arms at sides |
| `0D` | `0x34` | person, arms raised | same family, arms out and up |
| `0E` | `0x38` | staff bearer | a humanoid beside a thin vertical staff |
| `0F` | `0x3C` | group | two figures close together |
| `10` | `0x40` | robed figure | a humanoid in a wide cloak, triangular silhouette |
| `11` | `0x44` | horse | a four-legged animal, head at one side |
| `18` | `0x60` | person, arms out | upright figure, arms angled down and out |
| `19` | `0x64` | dancer | figure with arms forming a V above the head |
| `1A` | `0x68` | small person | a noticeably smaller humanoid |
| `1B` | `0x6C` | crouching figure | humanoid with arms drawn inward |
| `3C` | `0xF0` | figure, arms out | upright figure, broad stance |
| `3D` | `0xF4` | swordsman | figure holding a blade up to one side |
| `3E` | `0xF8` | figure with standard | humanoid beside a tall vertical bar |
| `3F` | `0xFC` | archer | figure holding a curved bow |

### Letters A–Z

Art `20`–`39` are the capital letters A to Z in sequence, with one exception:
art `30`, where **Q** would fall, is the wall tile above and is not a letter.
So the set is A–P, then R–Z, and Q is absent:

| art | letter | art | letter | art | letter |
| --- | --- | --- | --- | --- | --- |
| `20` | A | `28` | I | `31` | R |
| `21` | B | `29` | J | `32` | S |
| `22` | C | `2A` | K | `33` | T |
| `23` | D | `2B` | L | `34` | U |
| `24` | E | `2C` | M | `35` | V |
| `25` | F | `2D` | N | `36` | W |
| `26` | G | `2E` | O | `37` | X |
| `27` | H | `2F` | P | `38` | Y |
| `30` | *not a letter* | | | `39` | Z |

There is no `Q` tile. If a place name needs one, the engine has no glyph for it,
which is a fact about the original data and not something to fill in here.

Requirements: a single bold capital glyph centred in the cell, drawn from **any
public-domain or self-drawn bitmap letterform** — do not trace a reference. These
tiles are used as shop fronts and notices in towns, so they must be legible at
16×16 above all else. A horizontal rule above and below the glyph is optional
decoration, not a requirement.

Note that in some sectors these same indices are used as structural fill rather
than as letters. That is the map's business; draw them as letters.

### Blocks and borders

| art | byte | name | must read as |
| --- | --- | --- | --- |
| `17` | `0x5C` | checker border | a small repeating checkered band |
| `1D` | `0x74` | solid black | fill, black |
| `1E` | `0x78` | solid white | fill, white |
| `1F` | `0x7C` | edge strip | white at one edge, dark elsewhere |
| `3A` | `0xE8` | dark fill A | near-black with a small light motif |
| `3B` | `0xEC` | dark fill B | near-black, motif clearly different from `3A` |

## 8. Acceptance criteria

1. 64 files, `tile_00.svg` … `tile_3F.svg`, each a valid `16×16` SVG.
2. Only the three ink colours appear anywhere in the set, and **no `#000000` is
   emitted** - black is the backdrop (§ 3). Art `1D` is an empty tile.
3. Every tile is distinguishable from its neighbours in the same class at 16×16.
4. Ground tiles tile seamlessly when repeated on a grid.
5. No file was produced by tracing, importing, or converting original game art.
6. A provenance note exists per § 2, naming the implementer, the date, and the
   inputs used. **It must record which version of this spec was implemented** - the
   commit hash or blob SHA, not just the filename. Without that the record cannot be
   checked later, because the spec changes.
7. Constraints V1-V3 in § 6 hold, and the ink assignment matches the § 6 table.
8. **Proof sheets are composited on black, not white.** Tiles are transparent and
   the engine clears to black before drawing, so any tile whose ink is white is
   invisible on a white sheet. A checker that renders on white silently cannot see
   those tiles and will report success while two ground types render blank. If a
   near-blank or white-ink tile exists, the proof must show it.

## 9. What happens to the output

Place the result in the engine's own asset directory, clearly labelled as original
substitute art, and reference it from `LICENSE`/`NOTICE` as such. The engine should
prefer the player's own extracted art when present and fall back to this set
otherwise, so the shipped repository contains no copyrighted asset at any point.

This document and any art produced from it are Apache-2.0, consistent with the rest
of the project.
