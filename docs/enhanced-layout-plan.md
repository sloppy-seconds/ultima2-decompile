# Enhanced-mode screen layout — plan, not yet implemented

Status: **plan**. No engine code has been changed for this. The owner asked for the
FM Towns side-by-side layout to become our enhanced-mode layout, and asked that the
layout be validated against the reference screenshots first. It has been, and the
measurements are below.

Four decisions need a ruling before any of this is built (§ 4). Two of them change
what the player can see, which makes them gameplay decisions rather than cosmetic
ones, and one of them changes a string's provenance, which makes it a licensing
decision. Everything else is mechanical.

---

## 1. The reference layout, measured

Source: `references/fmtowns-screens/`, third-party photographs of the FM Towns
version running, captioned in `_CAPTIONS.tsv`. Grade: **measured**, from six frames
(`FMtownsu210`, `211`, `214`, `U2FMTowns1`, `19`, `32`) plus a grid overlay check.
These are camera photographs of a CRT, so read every number as ±2 px and do not
over-fit to one of them.

Frame is 640 × 480.

| region | x | y | size | note |
| --- | --- | --- | --- | --- |
| banner | 0..639 | 3..20 | 640 × 18 | yellow; title left, `FUJITSU` right |
| map | 0..~360 | 21..~405 | **11 × 12 tiles at 32 px** | grid overlay aligns at 32 px pitch (autocorrelation peak, corr 0.64) |
| panel | 362..638 | 25..~424 | 276 wide | three boxes, blue borders |
| — box 1 | | 47..98 | 52 tall | vitals + avatar |
| — gap | | 99..110 | 12 | blue |
| — box 2 | | 111..292 | 182 tall | stats + equipment |
| — gap | | 293..302 | 10 | blue |
| — box 3 | | 303..~424 | 122 tall | command window |
| bottom bar | 18..621 | 434..449 | 604 × 16 | red, **constant** |

The panel geometry was **identical in all six frames**, which is what makes it a
spec rather than one screenshot's accident.

The bottom bar is not a health bar. It spans x 18..621 with fill 0.94 in every
gameplay frame including one at `H:258` and one at `H:4922`, and it is absent only
in the four full-screen cutscenes. It is chrome. (The 0.78 readings are frames
where a `Press SPACE to read more` line overlaps the band.)

## 2. What each box holds

Read off the frames at 3–4× zoom, not guessed.

**Box 1 — vitals.**
```
PIX
 H:  258   E:   34
 F:  383   G:  313
```
plus a small avatar figure at the right. The label reads `PIX` on Earth, in a
dungeon, **and on Planet X**, so it is not a world or sector code; the simplest
explanation is the character's own name, which we carry at `DS:0x36 name[16]`.
`H F E G` are HP, Food, Experience, Gold — the same four values our classic status
band prints as `H.P.= FOOD= EXP.= GOLD=`, in a 2 × 2 grid instead of a column.

**Box 2 — stats and equipment.**
```
STRENGTH :  35
AGILITY  :  35
INTELLI  :  15
WISDOM   :  10
CHARISMA :  10
STAMINA  :  20
WEA:Dagger
ARM:Cloth
```
Two things to notice. The **order is not ours**: FM Towns runs STR, AGI, INT, WIS,
CHA, STA, while our creation form and status code run STR, AGI, STA, CHA, WIS, INT.
And the labels are **not our strings**: `INTELLI` is `INTELLIGENCE` truncated to fit
the leader column, and the equipment lines are `WEA:` / `ARM:`, whereas the DOS
binary we reconstruct uses `WEAPON-` / `ARMOUR-`. See decision D3.

**Box 3 — command window.** Echoed commands, NPC replies in yellow, and the input
line:
```
West
Transact
Direct?West
Guard says:
Pay your taxes!
@
```
`▶` appears as a line marker on several frames. What it means is an open question
(§ 6), not a decoration to copy blindly.

## 3. Our current layout, and the gap

`fm-full.png` is our engine with FM Towns art at 640 × 400: the map fills the top
as 20 × 10 tiles, and the bottom band holds `CMD:` at the left with a right-aligned
`H.P.= / FOOD= / EXP.= / GOLD=` column. No boxes, no borders, no stats, no
equipment, no avatar, no banner.

So the gap is not "add a panel". It is three separate changes: the **viewport
shape**, the **frame size**, and the **panel itself**. The first two are the hard
ones and they are the ones that need a ruling.

## 4. Decisions needed

**D1 — does enhanced mode adopt the FM Towns viewport of 11 × 12?**
Our 20 × 10 is not a preference; it is derived from the DOS original's staging
buffer (`asm/4ABB`, the 6400-byte span the game flushes to video). Adopting 11 × 12
shrinks the visible world from 200 cells to 132 and moves the player's centre from
(col 9, row 5) to about (col 5, row 6). That is a gameplay-visible change, and it
makes the engine's view no longer the DOS view. The FM Towns binary has its own view
size and we have **not** analysed it — we crosswalked its art, nothing more — so
this layout would be reimplemented from photographs, with no byte-level authority
behind it.
Options: (a) adopt 11 × 12 in enhanced mode and keep 20 × 10 in classic; (b) keep
20 × 10 and fit the panel beside a narrower map, accepting that the layout is then
ours and not the reference's; (c) adopt the panel arrangement only, below the map,
which is a smaller change and further from the reference.

**D2 — frame size.** The measured layout needs 640 × 480. Our frame is capped at
`U2_FRAME_MAX_W/H = 320×2 × 200×2 = 640 × 400`, and the SDL window is derived from
`U2_SCREEN_W/H × frame_scale × SDL_SCALE`. Adopting 480 means raising that cap and
touching the staging buffer, the texture and the window — all three of which the
640 × 400 ruling was written to keep from drifting per theme. Alternative: compress
the layout into 640 × 400 (banner 16 + map 12 × 32 = 384 + bar 16 = 416, already
over, so the map drops to 11 rows).

**D3 — where the panel's strings come from.** `STRENGTH`, `AGILITY`, `WISDOM`,
`CHARISMA`, `STAMINA` and `INTELLIGENCE` all exist in the binary we reconstruct, in
the creation form. `WEA:` and `ARM:` do not; ours are `WEAPON-` and `ARMOUR-`. The
project's line has been that shipped text comes from the bytes we reconstruct, and
the FM Towns abbreviations live in a binary we have not reconstructed. My
recommendation is to use **our** strings and let the layout be faithful while the
text stays sourced; the alternative is to declare the FM Towns labels a second
provenance and say so in a comment at each site.

**D4 — when the layout turns on.** Candidates: whenever `--ega` is active; only for
v2 32 px themes (a 16 px theme in an 11 × 12 map is 176 × 192 and looks stranded);
or an explicit `--layout classic|enhanced` with a `config.ini` default. Note the
precedent already set: frame scale is a property of the **art mode**, not the theme,
specifically so a Ctrl-T cycle cannot resize the window. A layout that changes with
the theme would reopen exactly that problem, which argues for tying it to the mode or
to an explicit flag, not to the theme.

## 5. What already exists to reuse

The panel's data is all in `state.h`, with offsets proven and `_Static_assert`
guards: `name[16]` (0x36), the six stats (0x4B..0x50, charisma and wisdom both
proven by capture), `hp` (0x51), `food`/`food_hi`/`food_lo` (0x53..0x55),
`exp_lo`/`exp_hi` (0x56/0x57), `gold_lo`/`gold_hi` (0x58/0x59), `readied_weapon`
(0x61), `worn_armour` (0x62).

`status.c` already renders the four vitals with the packed-BCD convention and the
byte-order trap documented (a swapped pair reads 3800 instead of 0038), so box 1 is
a re-layout of existing drawing code, not new number formatting. The Z screen
already resolves equipment names through `Z_NAME(U2_T_WEAPONS, …)` and
`U2_T_ARMOUR`, so `WEA:Dagger` is a lookup we already do. The box-1 avatar is the
themed player tile, which is exactly the art-index-to-pool mapping fixed today in
`u2_frame_draw_view_ega` — that fix is a precondition for drawing it correctly in a
v2 theme.

## 6. Open questions that need evidence, not opinion

1. **What is `▶`?** It prefixes several lines in box 3. Copying it without knowing
   what it marks is the kind of plausible-but-wrong detail this project has been
   bitten by. Needs a live FM Towns session or the FM Towns binary.
2. **Does box 3 scroll, and how deep?** Frames show 5–7 lines. Our vram log is a
   40 × 25 grid; a 276 px box at 16 px glyphs is 17 characters wide, so the log
   would have to re-wrap. Whether it wraps or clips changes what a player can read
   back.
3. **Is the panel identical in every mode?** Dungeon frames show the same three
   boxes with a level label (`L13`..`L16`) above the map, and the space frame shows
   the panel too. Town needs confirming from a frame that is unambiguously a town.
4. **Does the box-1 avatar vary by race or class?** The FM Towns `PLAYER` bank is
   entirely unmapped in our crosswalk precisely because it varies by race and class,
   an axis the DOS atlas does not have. If the box-1 figure comes from that bank,
   we cannot draw it faithfully from what we have mapped.
5. **Is the banner part of the game?** It carries `Ultima Trilogy` and `FUJITSU`,
   which is packaging and hardware branding rather than game output, and we would
   be inventing our own text for it either way.

These belong on `docs/needs-gameplay.md` when the plan is accepted, with a
who-can-do-it verdict, and several of them need the FM Towns disc rather than a
DOS session.

## 7. Proposed slices, in order

The ordering is deliberate: S1–S4 are additive and cannot change what a classic-mode
player sees, so they can land and be tested while D1 and D2 are still open. S5 and S6
are the invasive ones and should not start until they are ruled.

| # | work | gate |
| --- | --- | --- |
| S1 | `core/layout.h` — the panel geometry as data, with the measured numbers and their source named in comments | a check asserting the boxes tile the panel without overlap and match the measured extents |
| S2 | panel primitives: box border, dotted leader, right-aligned value | unit check on each primitive |
| S3 | box 1 and box 2 from `state` | values must match state; BCD order asserted against the proven convention, including the swap control |
| S4 | box 3 fed by the existing vram log | every message visible in classic must be visible in enhanced — the no-silent-mutation rule, asserted rather than eyeballed |
| S5 | *(needs D1)* view dimensions at runtime instead of `U2_VIEW_COLS/ROWS` | CP1/CP5 view tests unchanged for classic; new test for the enhanced shape |
| S6 | *(needs D2)* frame size, texture, window, scale caps | frame check plus a render at the new size |
| S7 | box-1 avatar through the theme map | reuses today's overlay fix; assert it draws the mapped tile |
| S8 | docs, and the § 6 questions onto `needs-gameplay.md` | — |

## 8. Risks worth stating plainly

- **No byte authority.** The DOS layout is derived from the binary. This layout would
  be derived from photographs of a different binary we have not disassembled. That is
  a lower grade of evidence and every number in § 1 should carry that caveat in the
  code that uses it.
- **View shrink is a gameplay change.** 200 cells to 132 is fewer monsters seen,
  fewer tiles of warning before an attack, and it interacts with the contact and
  sweep code that already assumes the DOS staging shape.
- **Over-fitting a photograph.** Camera geometry is skewed; ±2 px is the honest
  resolution, so the layout should be expressed in tile and character units with the
  pixels as a comment, not the other way round.
- **Two sources of truth for text.** If D3 goes the other way, the engine ships
  strings that did not come from the bytes it reconstructs, and that needs saying at
  each site rather than being left implicit.
