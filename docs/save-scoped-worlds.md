# Save-scoped worlds: moving sector write-back out of the content directory

Status: **proposal, not built.** Decisions D1-D5 below need the owner's ruling before any
code changes, because this moves where a player's saved game lives.

Owner request, 2026-11-05: "we need to make sure any changes to maps go into the save
game path ... in fact maybe we do `./saves/PLAYER/PLAYER` ... that then also sets us up
for multiple savegames in future, and gives us a good dir to put any changed maps into."

## 1. The problem with today's layout

Sector write-back currently lands in the **content** directory. `u2_world_store()`
writes into the layer the sector was read from (`world.c:415`), which is
`data/original/` or `data/updated/`. Three consequences, all observed:

1. **A player's release maps are permanently edited.** `mapx` is a 4096-byte grid and
   the engine writes the *stamped* grid back, not the pristine one — faithful to
   `asm/2305`, which writes from `word[DS:472]` and every live capture shows that word
   holding `0x1800`, the stamped grid. So creature type bytes land in the map file.
   Observed on the owner's install: `mapx20` differed from the release copy at
   `(35,23) 0x08 -> 0x30` and `(23,25) 0x0C -> 0xFC`.
2. **The corruption is sticky.** `map_base`, the pristine copy the creature restamp
   rebuilds terrain from, is loaded *from that same file*. So a baked creature byte
   becomes terrain, and the next restamp treats it as ground. Long play accumulates.
3. **Two files differing only by case.** The release spells the save `player`, the
   engine's `U2_SAVE_FILE_NAME` is `PLAYER`. `resolve_save_name()` (added 2026-11-05)
   makes the engine prefer the exact `PLAYER` and adopt a case variant only when it is
   absent, so a played install ends up holding both: the blank release template and the
   real game. That is what `saves/` looked like on jarvis on 2026-11-05.

There is also no room for a second save game. One `PLAYER` file, one world.

## 2. Proposed layout

One directory per save game, holding the record and every sector that save has changed:

```
game/
  data/
    original/            # release content, treated as READ-ONLY
    updated/             # Galaxy patch layer, READ-ONLY
  themes/                # unchanged
  saves/
    PLAYER/              # the default save slot
      PLAYER             # the 384-byte record, spelled as the engine spells it
      mapx20             # only sectors this save has changed
      monx20
    <slot>/              # a future second save, same shape
  config.ini
  _INSTALL.tsv
```

`--install` stops writing into `data/` after first creation and never edits a content
file again. Content becomes an immutable base; all mutation goes under `saves/`.

## 3. Read and write rules

**Read order for a sector** (first hit wins):

1. `saves/<slot>/<prefix><NN>` — this save's overlay
2. `data/updated/` then `data/original/` — the content roots, as today

**Write target:** always `saves/<slot>/`. Never the content directory. This is the whole
point: a sector write can no longer damage the release files, and `--install --check`
stops reporting content drift as "played-in" because content never drifts.

**The blank template** the installer seeds (`saves/player` today) goes away. A new slot
starts with no overlay at all and reads pure content, which is what a new game should
do anyway. That also deletes the case-collision problem in § 1.3 by construction.

`resolve_save_name()` stays, but its job shrinks to finding a record inside a slot
directory rather than guessing between two spellings in one directory.

## 4. Migration

An existing install has `saves/PLAYER` (a file) and possibly `saves/player`. Migration
must be **move, never copy, and never overwrite**:

1. If `saves/PLAYER` is a file and `saves/PLAYER/` does not exist: create the directory,
   move the file to `saves/PLAYER/PLAYER`.
2. Any `mapx*`/`monx*` currently dirty in `data/original/` (detected by comparing against
   `_INSTALL.tsv`'s recorded sha) move to `saves/PLAYER/` and the content copy is
   restored from its recorded source. This is the repair for § 1.1 and § 1.2.
3. A lowercase `saves/player` that is byte-identical to the release blank is deleted.
   If it is NOT identical, it is a real save and gets promoted to its own slot rather
   than discarded — losing a player's game to a cleanup is the failure this whole
   document exists to prevent.
4. Migration runs once, is idempotent, and prints what it moved. A refusal must leave
   the old layout working.

## 5. Decisions needed

| # | question | recommendation |
| --- | --- | --- |
| **D1** | Default slot name. `saves/PLAYER/PLAYER` is faithful but reads oddly, a directory and a file with the same name. | Keep it. It matches the engine's `U2_SAVE_FILE_NAME`, and `--save NAME` selects other slots without renaming anything. |
| **D2** | Does the original game ever share this directory? It reads `mapx` from the game root, so maps we move under `saves/` become invisible to it. | Accept it. The engine's directory is the engine's. Worth stating in the release notes so nobody is surprised running both on one tree. |
| **D3** | Which files overlay? `mapx`/`monx` are written by the game. `tlkx` is never written by anything (docs/save-format.md), so overlaying it buys nothing. | Overlay `mapx`/`monx` only. Keep `tlkx`, `pic*` and the exe as pure content. |
| **D4** | Where does the tile cache `tiles.u2tl` live? It is derived from the player's exe, not from a save, so per-slot would rebuild it per slot. | Keep it shared, at `saves/.cache/` or the game root. Not part of a slot. |
| **D5** | Multi-save UI now or later? The layout enables it; a `--save NAME` flag and a slot picker are separate work. | Layout now, flag later. Building the layout without the flag costs nothing extra and the flag is then small. |

## 6. What has to change, and what guards it

- `engine/src/core/roots.c` — a save-slot layer joins the read order ahead of content.
- `engine/src/core/world.c` — `u2_world_store()` targets the slot; the "write back into
  the layer it was read from" rule at `world.c:409` is replaced by "always the slot".
- `engine/src/core/save.c` — the record path becomes `saves/<slot>/PLAYER`.
- `engine/src/core/install.c` — stop seeding `saves/player`; add the migration of § 4.
- `tools/save_cross_load.py` — this is the gate that loads a record between the engine
  and the original game. It reads and writes paths directly and **must be updated in the
  same change**, or it will test the old location and pass vacuously. Per AGENTS.md § 3,
  save handling changes require running it by hand, not in CI.
- `engine/tests/install_check.c` and `install_controls.py` — new properties: content is
  never written after install; a dirty sector lands in the slot; migration is idempotent;
  migration never deletes a non-blank lowercase save.

The property worth gating hardest is the one that matters most: **after install, no file
under `data/` is ever modified by running the game.** That is checkable by hashing the
content tree before and after a scripted play session, and it is the exact thing that
went wrong this time.

## 7. What this does not fix

The stamped-grid write-back stays faithful. Creatures still get baked into the overlay
copy of a sector, because the original does that. What changes is *where* it happens:
into a per-save overlay that can be deleted, rather than into the player's only copy of
the release data. If the accumulation turns out to be wrong, the fix is then local to the
overlay and reversible, which it is not today.
