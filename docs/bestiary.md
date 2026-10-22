# Bestiary — naming the creature tiles from third-party data

Status: **tools built, first join run**. The pipeline is `fetch → match → view`;
the machine-readable result is `bestiary/bestiary.tsv` and a rendered summary is
`bestiary/matches.md`.

## 1. Why this exists

The executable has **no monster name table**. `tools/monster_shapes.py` records
this: the string `THIEF` at file `0x50FE` is a *player class*, not a creature, and
nothing in the binary pairs a monster type with a word. That is why
`disasm/tile-art.tsv` could only say "white humanoid, arms down, legs apart" about
art `0x0C`. A creature could be given a face but not a name.

Two community sources carry names, stats and per-platform art, and they are
independent of each other and of this binary:

| source | shape | what it adds |
| --- | --- | --- |
| [Ultima Codex](https://wiki.ultimacodex.com/wiki/Ultima_II_monster_data) | four tables (land, townsfolk, dungeon, NPCs), one column per shipped variant from Apple II 1982 to FM Towns 1990 | names, HP, specials, item drops, art in 7 populated variants |
| [Gamer Corner](https://guides.gamercorner.net/ultimaii/creatures/) | one page per creature, sortable table | names, HP, where it appears, prose behaviour notes, one DOS tile image |

The move that makes them useful rather than decorative: a table cell delivers a
**name and a bitmap together**. Where a source's DOS bitmap is pixel-identical to
one of our 64 tiles, the name attaches to that art index by measurement.

## 2. Evidence grades

Be precise about what is proven, because the interesting part is not proven by the
binary.

| claim | grade | basis |
| --- | --- | --- |
| "this community bitmap and art index *NN* are the same 256 pixels" | **measured** | `tools/bestiary_match.py` against `original/ultimaii.exe`, same decode as `tools/tile_atlas.py` |
| "art index *NN* is called *Orc*" | **third-party** | inherited from the codex or Gamer Corner; the bytes never say |
| "Daemon has 64 HP and paralyzes legs at range 2" | **third-party, corroborated** | two independent sources agree, and `asm/0E70_combat_paralyzed_legs.asm` proves the leg-paralysis event exists |
| "monster type byte *T* draws art index *NN*" | **inferred** | `monster_shapes.py` derives `art = type >> 2` from one live finding; not proven end to end |

Where a third-party claim contradicts the binary, the binary wins, and the
contradiction is written down here rather than resolved silently. See § 6.

## 3. Method

```
python3 tools/bestiary_fetch.py      # two pages + their images -> bestiary/cache/
python3 tools/bestiary_match.py --self-test
python3 tools/bestiary_match.py --md # -> bestiary/bestiary.tsv, matches.md
python3 tools/bestiary_view.py       # -> bestiary/view.html
```

`bestiary_fetch.py` keeps `cache/manifest.json` with a sha256 and timestamp per
file, so `--offline` re-parses what is already on disk and makes no requests. It
splits the animated FM Towns GIFs into numbered frames **and** a single strip, so
the animation is usable with and without a GIF decoder. It also handles the codex's
ragged tables explicitly (§ 6), because a flat column map there ships a plausible
wrong stat on most rows.

`bestiary_match.py` refuses to be generous:

* an image is eligible only if it reduces to 16x16 by an **exact integer factor**.
  The codex mixes 16x16 rips, 32x32 upscales and 224x142 screenshot crops; a crop
  is reported `not-1:1` and never resized into a vote.
* a match is equality of all 256 colour indices. Near-matches are printed as
  `near-N` and never promoted to a name.
* animated images are ineligible as a whole; they are intent evidence, not pixels.

### The controls, and the proof that they bite

AGENTS.md: *a gate that cannot go red is worse than a tool that lies.* Six controls
run under `--self-test`:

1. our own art, round-tripped through the image path, matches its own index
2. the same bitmap with **one pixel flipped matches nothing**
3. an all-black image matches no figure
4. an animated FM Towns GIF — a different art set — matches nothing
5. a flat image can only ever be classified `trivial`, never `exact`
6. a 24x24 crop is ineligible; a clean 2x upscale is eligible and still matches

Controls 5 and 6 exist because of mistakes the first run made, not as decoration.
Three of our art indices are blank or solid (`0x1D` has zero ink, `0x1E` is fully
solid). The first version of the matcher reported **Kings, Minax and Sea serpent**
as names for art `0x1E`, because three codex C64 images reduce to a flat field and
a flat field equals a solid tile. A plausible wrong name is exactly the failure mode
the rule warns about.

The gate was then demonstrated failing, by mutating one guard at a time in a copy of
the module: loosening the comparison to a Hamming distance of 6 turns control 2 red;
disabling the trivial-tile guard turns control 5 red; disabling the resize guard
turns control 6 red. All three mutations go red, and the unmutated tool passes 6/6.

## 4. What the join produced

26 of 120 image comparisons named a tile, across 15 distinct art indices, with no
art index claimed by two different names:

| art | name | corroborated by our bytes |
| --- | --- | --- |
| `0B` | Sea Monster | **disputed**, see § 6 |
| `0C` | Orc | — |
| `0D` | Daemon | `asm/0E70_combat_paralyzed_legs.asm` — leg paralysis exists |
| `0E` | Devil | `asm/0EC2_combat_paralyzed_arms.asm` — arm paralysis exists |
| `0F` | Balron | `asm/0F48_combat_sleep_spell.asm` — sleep event exists |
| `10` | Minax | `asm/0F8E_combat_minax_attack.asm` — and the string `MINAX CRIES: DIE FOOL!` |
| `12` | Frigate | `asm/2FAD` BOARD dispatch already separates ship from horse/plane/rocket |
| `18` | Guard | — |
| `19` | Jester | — |
| `1A` | Merchant | — |
| `1B` | King | — |
| `3C` | Fighter | — |
| `3D` | Cleric | — |
| `3E` | Wizard | `asm/0F12_combat_magic_missile.asm` — magic missile event exists |
| `3F` | Thief | `asm/0FCD_combat_thief_steal.asm` — `A THIEF STOLE SOMETHING!` |

The four specials in the middle of that table are the useful result. Two
third-party sources, independently, say Daemon paralyses legs at range 2, Devil
paralyses arms at range 2, Balron sleeps at range 2 and Wizard casts magic missile
at range 2 — and the binary contains exactly one routine per event, each named from
a string that executed in a live capture. The sources did not have to be right about
which creature did which, and they agree on all four. That is corroboration, not
proof, and it is recorded as a `# corroboration:` line in those six `asm/` headers.

Nine names matched nothing, and the reason is known rather than mysterious: the
codex's dungeon creature images are 224x142 screenshot crops, not rips. Ghost,
Carrion creeper, Viper, Gremlin and Goblin stay unnamed until a real DOS dungeon
sprite is found or one is extracted from a live session.

## 5. What the join did **not** buy

* **No monster type byte is named.** The type→art path (`art = type >> 2`) is
  inferred from a single live observation. Naming a *type* needs that transform
  proven in bytes first. This is the deliberate line from the project plan: art
  names yes, type names not yet.
* **No asm file was renamed.** The tile-art table lives inside
  `asm/72A0_sub_72a0.asm`, which spans `72A0..8386` and is a mixed region of code,
  strings and data — calling it `tile_art_table` would be a wrong name, and a wrong
  name is worse than none. The names went to `disasm/tile-art.tsv` and the headers
  that own the behaviour instead.
* **No HP value is verified.** Nothing here has been checked against a live monster
  record. See `docs/needs-gameplay.md`.

## 6. Conflicts on the record

* **art `0B`.** Gamer Corner's "Sea Monster" tile is pixel-identical to our `0B`,
  but `disasm/tile-art.tsv` reads `0B` as a doorway set in a magenta field, and its
  kind is `object`, not `creature`. One of the two readings is wrong. Marked
  `Sea Monster?` and left as a dispute; do not rename on this evidence.
* **Guard HP.** Codex 255, Gamer Corner 500. Unresolved.
* **Merchant HP.** Codex 5–50, Gamer Corner 1. Unresolved.
* **The codex HP/DMG columns are not HP and DMG in two of the four tables.** Those
  tables carry a second header row (`Min`, `Max`) written without `colspan`, so in
  the raw HTML the two sub-labels land under *Name* and *Apple II* and cannot be
  positioned from markup. Reading the pair as HP+DMG is a guess, and the guess is
  wrong: Orc is `17` and `153` in those columns, and Gamer Corner's single HP column
  reads `17-153` for the same creature. So in Townsfolk and Creatures in Dungeons the
  pair is an **HP range** and DMG is absent — and the rows ship **one more cell than
  the header has columns**, because HP occupies both of those cells. A flat
  header→cell map therefore mislabels every column after HP: Balron's level range
  arrived as its `Special`. The row width is what settles it — `sum(spans) ==
  len(cells)` only closes if HP spans two — and Gamer Corner agrees independently.
  `bestiary_fetch.py` now detects the extra cell from row width and spans HP, so
  dungeon Balron reads `HP 209-249`, `Location 13–16`, `Special Puts enemies to
  sleep`. Two readings of this table were wrong in two different directions before
  that, which is the argument for measuring row width instead of trusting a header.
* **`0x1D` and `0x1E`.** Blank and solid art respectively. They are not creatures and
  cannot name anything, whatever a naive comparison says.

## 7. Licensing and the cleanroom wall

Every image in `bestiary/cache/` is a copyrighted rip of game art, in seven platform
variants, and `bestiary/view.html` embeds all of it plus our extracted tiles. Both
are gitignored and must never be committed — same rule as `original/` and
`tmp/tiles/`. What is committed is our own derived table and this document: facts plus
attribution, no bitmaps.

This is also the largest single pile of original art the project has ever held, which
makes it a cleanroom hazard. `bestiary/cache/`, `bestiary/view.html`,
`bestiary/bestiary.tsv` and `bestiary/matches.md` are all added to the forbidden list
in `docs/tile-art-spec.md` § 2 and `docs/cleanroom-procedure.md`. Whoever draws
substitute art may not read any of them. The bestiary answers *what is this creature
called*; the spec answers *what must the tile communicate*; they must not mix.

## 8. Next

1. Prove `art = type >> 2` in bytes, then monster **types** become nameable.
2. Verify HP and damage against a live monster record — an agent-drivable capture,
   filed in `docs/needs-gameplay.md`.
3. Find real DOS sprites for the five dungeon creatures whose codex images are crops.
4. Cross-check the item-drop claims (Fighter drops torches and helms, Guard drops 2
   keys, Wizard drops staves and wands) against the kill-reward code in
   `asm/2D8C_combat_kill_reward.asm` and friends.
