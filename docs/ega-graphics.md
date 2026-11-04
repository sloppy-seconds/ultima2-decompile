# EGA graphics (`--ega`)

Status: **implemented 2026-11-04.** Owner idea, 2026-11-04; built the same day. This is the
user-facing page — what EGA mode is, how to turn it on, and where the art comes from. The
build record, format-spike verdicts and internals live in `docs/ega-graphics-plan.md`.

`--ega` draws the game in **16 colours** instead of the original CGA's 4, using the fan-made
*Ultima II Upgrade* art (recoloured tiles and full-screen pictures). It is a presentation
axis only: it changes no rules, and it is available with or without `--enhanced`. CGA stays
the shipped default and is byte-for-byte unchanged; nothing about a run changes unless you ask
for EGA.

## 1. What you need

The EGA art is **not part of this repository.** It is Origin's art, recoloured by the fan
patch, so it is never committed — the same rule as every other piece of original art here
(`AGENTS.md` licensing; the cleanroom wall). You supply it from your own copy.

The art ships in the Exodus **"Ultima II Upgrade"** package (the same patch that also restores
the planet maps — see `docs/planet-maps-galaxy-patch.md`). The files the engine reads:

| file | what it is |
| --- | --- |
| `EGATILES` | the 16-colour tile atlas — the map, towns, buildings and figures (the dominant visual) |
| `EGATHEME.10/`, `EGATHEME.ALT/`, `EGATHEME.C64/` | alternative tile themes, each holding its own `EGATILES`, and (for `10` and `C64`) its own `EGACOLOR` and pictures |
| `PICDRA-E`, `PICSPA-E`, `PICMIN-E`, `PICDNG-E`, `PICTWN-E`, `PICOUT-E`, `PICCAS-E` | the 16-colour full-screen pictures (some copies spell these `PICDRA.EGA` etc.) |

If you already ran the Exodus installer on your game, these files are in your game folder (the
runtime copies land under `updated/`). If you have the raw upgrade package instead, they are
at its top level and in the `EGATHEME.*` subfolders.

## 2. Where to put them and how to run

Point the engine at the folder that holds `EGATILES`:

```bash
./u2-sdl --ega --data-dir ~/u2 --ega-theme-dir ~/u2/updated
```

The themes directory is resolved as follows:

1. If you pass `--ega-theme-dir DIR`, that directory is used and must contain the chosen
   theme — there is no fall-through, so a wrong path is reported rather than papered over.
2. Otherwise the engine tries `--data-dir`, then (on a developer checkout) `references/u2upgrade/`,
   and uses the first that contains the theme.

Pick a theme with `--ega-theme` — one of `default`, `10`, `alt`, `c64` (default is the
canonical set the game itself uses):

```bash
./u2-sdl --ega --data-dir ~/u2 --ega-theme c64
```

The two places the art comes from are complementary, and neither is complete: the tile atlas
and the `EGATHEME.*` folders exist only in the upgrade package, while the full `PIC*-E`
picture set exists only in `updated/`. Instead of pointing at one and losing the other, build
a merged tree:

```bash
python3 tools/build_themes.py --report    # inventory every source, write nothing
python3 tools/build_themes.py             # build themes/ and verify every byte
./u2-sdl --ega --data-dir ~/u2 --ega-theme-dir themes/ --ega-theme c64
```

The builder copies **whole theme directories**, never selected files (a theme is `EGATILES`
plus an optional `EGACOLOR` plus optional pictures, and which extras exist is per-theme),
emits `EGATILES` byte-identical, keeps one file per picture base with the first `--source`
winning and the shadow reported, and finishes by re-checking the tree against its sources.
`themes/` is gitignored: it is your art, not this repository's.

While playing, **Ctrl-T** cycles to the next theme found in the directory (alphabetical
order), live — no restart. The map recolours and the message line names the theme you landed
on.

`--ega` is **strict**: if the themes directory does not exist, or the chosen theme is not in
it, the engine refuses to start and prints why, rather than quietly falling back to CGA. (The
full-screen pictures are the one soft case: if a `PIC*-E` is absent, that picture falls back
to its CGA version.)

## 3. What is drawn in EGA, and what is not

- The overworld map, towns and figures: from `EGATILES`.
- The title splash and the demo pictures: from the `PIC*-E` files when present, else the CGA
  picture.
- The status text band stays in the CGA colours (indices 0 and 3), which read as black and
  cyan on the EGA palette. This is a known cosmetic limitation of the interim flag, not a
  bug; the options menu will own text colouring later.

### 3.1 `EGACOLOR` — what it is, and what the engine does with it

Status: **decoded statically 2026-11-04 from the fan pack's own driver.** The claim this
replaces — "no theme carries its own palette, so the standard EGA table is used for all" —
was wrong twice over, and it sat in a header people read as contract.

Two themes do ship a colour file: `EGATHEME.10/EGACOLOR` and `EGATHEME.C64/EGACOLOR`, 32
bytes each, and they differ from one another. `EGATHEME.ALT` ships none. Reading the 32 bytes
as 16 little-endian RGB555 entries produces nonsense (`#78c018` everywhere, `0f0f` eight
times out of sixteen), which is the first clue it is not an RGB table at all.

It is not. `references/u2upgrade/ega.drv` says what it is, and the addresses below are file
offsets in that file — which are also its DS offsets, since the string operands (`EGATILES`
at `0x9e`, `MONSTERS` at `0xa7`, `EGACOLOR` at `0xb0`) match the file positions exactly.

*observed* — the driver opens `EGATHEME.<name>\EGACOLOR` at `0x535`, and on success copies
exactly `0x20` bytes (`mov cx,0x20; rep movsb`, `0x54f`..`0x552`) over a table already sitting
in its own data area at `0xF1`. That built-in default has the same shape as the shipped files
(`0f 02 04 0c 09 00 00 00 0b 0d 0f 0d 0c 0c 09 0f` then `0f 09 0c 0e 01 03 02 0a 08 0e 04 0b
0d 07 0f 08`), so an absent `EGACOLOR` means "keep the driver's defaults", not "identity".
Every byte in all three tables is `<= 0x0F`: these are 4-bit colour indices, one per entry,
not colours.

*observed* — five places read the table, and each one takes the table value and writes it as
the **colour index of a pixel or a character**, never to a palette register:

| entries | reader | what it feeds |
| --- | --- | --- |
| 0..7 | `0x214` (`mov cl,[bp+0xF1]`) | the 4x4 block fill, whose colour comes from the 3-bit field of the `MONSTERS` overlay stream (`shr al,5` at `0x33f`) |
| 8..15 | `0x47f` (`mov bl,[bx+0xF9]`) | the attribute byte handed to `int 0x10 / ah=0x09` — i.e. **text colour** |
| 16..19 | `0x370` (`mov cl,[si+0x101]`, `si & 3`) | a 2-bit selector passed to driver entry 13 |
| 20..30 | `0x2d0` (`mov cl,[bx+0x105]`) | a switch over ~11 named parts of a box/frame routine (`0x2b2`..`0x2ce`) |
| 31 | `0x3c2` (`mov cl,[0x110]`) | a fixed pen colour for the routine at `0x37b` |

*observed* — the tile-atlas blit (`0x247`..`0x25e`, the loop that unpacks the 4bpp nibbles and
XORs them into the plane) does **not** consult the table. So theme tile colour lives in the
`EGATILES` bytes, and `EGACOLOR` recolours only the driver's own primitives: the overlay
blocks, the text attribute, and box pens.

*inferred* — the band names in the right-hand column. The mechanism is bytes; "this band is the
text colour" is my reading of which BIOS call it feeds, and nobody has watched it on a real
EGA card.

**What the engine does with it: nothing.** `--ega` draws with the fixed 16-entry RGB table in
`core/frame.c` for every theme, which is correct for the tiles (they carry their own colour)
and ignores the overlay/text/box remap. Wiring `EGACOLOR` is a real piece of work with its own
questions — does a text-attribute remap belong in the frame palette or in the text renderer —
and it is not part of the theme builder's slice A. It is recorded here so the next person
starts from the driver rather than from a guess.

One more gap in the same direction: the theme directories `10` and `C64` each ship their own
`PICDNG.EGA` and `PICSPA.EGA`, and those differ from the top-level files. The engine resolves
pictures at the **top level** of the themes directory only (`pic_ega.c` `candidate_dirs`), so
per-theme pictures are copied by `tools/build_themes.py` and never read by the engine. The
fan pack's driver does look for them theme-relative, with a fall-back to the bare name
(`0x5f1`..`0x60d`), so the art is not exotic — our loader is just narrower.

## 4. Legal posture

Identical to the CGA tile art and the original pictures: the EGA files are the player's own,
read at run time from the directory you point at, and never committed. The committed cleanroom
substitute tiles (`engine/assets/tiles/cleanroom/`) remain the shipped fallback when no EGA
art is present. No new art enters the repository.

## 5. Relationship to the options menu

`--ega` is an interim launch flag. When `docs/options-menu.md` lands, the art mode and theme
become live-switchable menu rows (graphics is presentation, safe to change mid-run) seeded
from these flags, and the flags are folded into the settings model. The underlying 16-colour
pipeline is the same either way, so this is not throwaway work.
