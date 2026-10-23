# The `Z` status screen — spec for wiring it in the engine

Opened by `docs/handoff-2026-10-27-night.md` item 3, which called it "self-contained,
zero unknowns". It is self-contained but it is not zero unknowns, and the two things the
handoff guessed are both wrong: the handler is not `asm/462F_status_keys.asm`, and the
screen has a real handler chain that is already partly readable. This document is the
spec; the implementation is the next step and has not been done.

Everything below is graded. **observed** = read from `original/ultimaii.exe` or a live
session. **measured** = derived by a named tool or read. **inferred** = reasoned from a
partial read, not yet checked.

## 1. The handler, and why the handoff's guess was wrong

The A–Z command table at file `0x930` (runtime `0x730`, read out of the binary 2026-10-28
while chasing `docs/monster-spawn.md` § 15.2) gives entry 25 = `'Z'` → runtime `0x4568`,
which is `asm/4568_cmd_Z.asm`. That is the handler.

`asm/462F_status_keys.asm` prints the string `KEYS-` and belongs to a family of five
status-line fragments — `45C4_status_weapon`, `45E9_status_torches`, `460A_status_armour`,
`462F_status_keys`, `466F_status_tools`. The Z screen **reuses** those fragments, which is
exactly why it looks like they are the handler. They are shared drawing helpers, not the
entry point.

The chain, from the bytes at file `0x4768`:

```
4568 cmd_Z:   e8 b1 04      call L_004c1c      ; screen clear prologue, see § 4
              c6 06 4f 05 01   mov byte [0x54f],1
              c6 06 2e 00 01   mov byte [0x2e],1     ; cursor row = 1
              c6 06 31 00 26   mov byte [0x31],0x26
              e8 80 0c      call ...
              e8 fa 0a      call ...
4580:         call str_out ; db 0x8d,"A LEVEL ",0     ; 0x8d is the cursor escape
458D:         mov 0x56,%al ; call L_0055b5            ; level, packed decimal
4593/4598/459E/45A3/45AC/45B1:  spaces and DS:46 (sex), DS:47 (class), DS:48 (race)
```

`DS:2E/2F` are the shared text cursor row/col (the same pair `engine/src/game/status.c`
saves and restores around `u2_status_draw`). The Z screen drives it the same way.

## 2. The rendered page, transcribed

Captured 2026-10-28 headless: `spice86_start.sh --headless --patch-arrows --player
/var/tmp/u2/novnc-saves/PLAYER --auto-play --name zstats`, then `spice86_type.py --keys Z`
and `spice86_screenshot.py`. 320x200 at 8x8 cells = **40 columns x 25 rows**, and the text
wraps at 40, which is why the item list breaks mid-word.

```
G23MAX
 A LEVEL 99 FEMALE HUMAN FIGHTER

  WEAPON-QUICK SWORD      TORCHES-50
  ARMOUR-POWER            KEYS-20
  SPELL-NONE              TOOLS-20
  STRENGTH-40  STAMINA-40   WISDOM-40
  AGILITY-40   CHARISMA-40  INTELL.-40

WEAPONS: DAGGERS-01 MACES-01 AXES-01 B
OWS-01 SWORDS-01 GREAT SWORDS-01 LIGHT
 SWORDS-01 PHASERS-01 QUICK SWORDS-01
ARMOUR:
SPELLS:


ITEMS: RINGS-01 WANDS-01 STAFFS-01 BOO
TS-01 CLOAKS-01 HELMS-01 GEMS-01 ANKH
S-01 RED GEMS-01 SKULL KEYS-01 GREEN GE
MS-01 BRASS BUTTONS-01 BLUE TASSELLS-01
 STRANGE COINS-01 GREEN IDOLS-01 TRI-L
ITHIUMS-01
```

Note `A LEVEL 99`. The handoff records the owner's screenshot as `A LEVEL 00` for the same
character — either a different character or a different moment. Unresolved, and it matters
because `458D` prints `DS:56`, which `status.h` already identifies as the EXP high byte.
**Do not implement "level" from EXP until this is pinned down**; the field being printed is
`DS:56` either way, which is the honest thing to render.

## 3. The name tables — all of them are in the binary

A NUL-separated table at file `0x4F53..0x50FF` (runtime `0x4D53..`). Extracted by splitting
the region on `0x00`, 2026-10-28:

| group | entries | file range |
| --- | --- | --- |
| weapons (10) | `HANDS DAGGER MACE AXE BOW SWORD GREAT SWORD LIGHT SWORD PHASER QUICK SWORD` | `0x4F53..0x4F9D` |
| armour (8) | `SKIN CLOTH LEATHER CHAIN PLATE REFLECT POWER NONE` | `0x4F9E..0x4FCD` |
| dungeon features | `LIGHT DOWN LADDER UP LADDER PASSWALL SURFACE PRAYER` | `0x4FD0..0x5003` |
| spells | `MAGIC MISSILE BLINK KILL` | `0x5004..0x501C` |
| items (16) | `RING WAND STAFF BOOTS CLOAK HELM GEM ANKH RED GEM SKULL KEY GREEN GEM BRASS BUTTON BLUE TASSLE STRANGE COIN GREEN IDOL TRI-LITHIUM` | `0x501D..0x509F` |
| stats (6) | `STRENGTH AGILITY STAMINA CHARISMA WISDOM INTELL.` | `0x50A0..0x50D0` |
| races (4) | `HUMAN ELF DWARF HOBBIT` | `0x50D1..0x50E7` |
| classes (4) | `FIGHTER CLERIC WIZARD THIEF` | `0x50E8..0x5103` |

Two things the screenshot makes visible and the table alone does not:

* **The lists are the table entry plus a literal `S`.** `DAGGER` prints as `DAGGERS-01`,
  `TRI-LITHIUM` as `TRI-LITHIUMS-01`, `INTELL.` as `INTELL.-40` (stats get no `S`). So the
  plural is a suffix in the print path, not a second table.
* **`BOOTS-01`, not `BOOKS-01`.** The line wraps as `BOO`/`TS-01` and reads as "BOOKS" to
  the eye. The table says `BOOTS`, and `state.h` independently names `items_held[BOOTS]`
  as the paralysis save. Transcribing the screenshot by eye would have invented an item.

The counts come from the save record, already mapped in `engine/src/core/state.h`:
`weapons_owned[10]` at `DS:76`, `items_held[16]` at `DS:D6`, `readied_weapon` `DS:61`,
`worn_armour` `DS:62`, `spell_pick` `DS:63`.

**None of these strings are in `engine/build/gen_content.h` today** (90 `U2_S_` defines,
none of them an item name). The extractor at `tools/extract/extractor.py` has to grow a
table mode before the screen can be built without hardcoding text, which `status.c`'s
header forbids on purpose.

## 4. Measured behaviour, not assumed

Headless, `G23MAX`, sector 20, before/after `Z` and before/after the dismissing key:

| check | result |
| --- | --- |
| food `DS:53/54/55` | unchanged (`[153,100,2]` before and after) — **`Z` costs no food** |
| HP `DS:51/52` | unchanged |
| player position `DS:00/01` | unchanged |
| `mon_x` `DS:137..140` | unchanged (all zero — the field was empty) |
| `DS:60` | unchanged |
| cursor row `DS:2E` | `0` while the page is up, `5` after the dismissing key |
| dismissal | a key returns to the world; the page is a full-screen overwrite, not an overlay |

So the handoff's acceptance question — "does `Z` cost food?" — is answered: **no**.

**Not measured, and it needs live monsters:** whether the post-command creature sweep runs
after `Z`. Per § 15.2 the sweep follows every command that returns through `cmd_done`, and
`asm/4565` (the fragment immediately before `cmd_Z`) is a `jmp L_000c33`, but no fragment
in the Z chain has been shown to reach `cmd_done`. If the sweep does run, `Z` gives every
creature a turn, which is a gameplay cost even though food does not move. Settle it with
monsters on the field: read `mon_x`, press `Z`, read again.

## 5. Open questions, named

1. **Exact column of every field.** The fragments set `DS:2E/2F` and use the `0x8d` escape,
   and the transcription above is eyeballed from a screenshot. Derive the positions from
   the writes in `4580..46BF` before asserting them in a test — a test that encodes an
   eyeballed column is the `view_check.c` mistake again.
2. **`ARMOUR:` and `SPELLS:` print empty** for a character wearing POWER armour. Either the
   lists show only *spares*, or the owned-armour array is elsewhere than `state.h`'s
   `reserved_80[0x16]`. Unresolved.
3. **`DS:31 = 0x26` and `DS:54F = 1`** are set at the top of the handler and their meaning
   is unknown. `DS:54F` is past the 256-byte save record, in the DS scratch area.
4. **`asm/4A1C_char_out.asm` is misnamed** — see the `# NAME DISPUTED:` line added to that
   file in the same commit as this document. It is not character output: `mov $0x1,%ax` is
   AX=0x0001, so AH=00 set-video-mode AL=01, and it falls through (no `ret`) into the
   cursor-zero at `4A22`. The engine has already inherited the wrong name in three places —
   `platform.h:13` maps `char_out -> seam_char_out`, `vram.h:17` and `vram.c:54` call it a
   teletype — so fixing it is an engine change with a seam in it, and it needs an owner.
   One caller today (`creation.c:231`), which is why this has not bitten yet.
5. **`A LEVEL 99` vs the handoff's `A LEVEL 00`** for the same character.

## 6. What implementing it actually needs, in order

1. `tools/extract/extractor.py`: extract the six name tables above as arrays, not as
   individual `U2_S_` defines, and add a `content-check` case for them.
2. `engine/src/game/status.c`: a `u2_status_draw_full()` that reproduces § 2 from the state
   record, driving the same cursor pair, with positions taken from the asm per open
   question 1.
3. `overworld.c`: a `case 'Z'` in the command switch (next to `case 'A'` at line 940) that
   draws the page and waits for a key without advancing the turn.
4. `engine/tests/status_check.c`: assert the rendered page against the transcription, and
   assert the measured no-cost properties (food, position, HP unchanged across `Z`).
   **Demonstrate it failing first** — flip one expected byte, watch it go red, restore.
