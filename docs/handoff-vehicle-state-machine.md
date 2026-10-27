# Handoff — the vehicle state machine (travel modes)

**Status:** not started. Every rule needed to build it is proven and cited below. This document is
the whole brief; read `docs/passability-findings.md` **F14** first, because this file builds on it
and does not repeat its derivations.

**Scope:** travel modes. `BOARD`, `LAUNCH`/`LAND`, per-mode passability, per-mode food cost.
**Non-goals:** dungeons and towers (parked by owner ruling), the frigate (untested, see § 6), and
vehicles as *objects* — the original has no vehicle inventory, only a mode byte on the player.

---

## 1. The model, in one table

`DS:13` is the travel mode. It is also the player's stamp byte, which is why the engine already has
it under the other name (`state.h:69`, `player_stamp`, static-asserted at `0x013`).

| mode | `DS:13` | tile rule | food/step | evidence |
| --- | --- | --- | --- | --- |
| foot | `0x78` | the F14 ladder | `0x19` (19) | ladder bytes + `stepcost` capture |
| horse | `0x22` | **the same ladder** | `0x38` (38) | `asm/2557` is a delay loop, not a rule |
| ship | `0x24` | `mode == 0x00` only | none | `asm/2619` + `ship-port-boniface` capture |
| plane | `0x26` | everything **except `0x06`** | `0x38` (38) | `asm/2604` body |
| rocket | `0x28` | everything | none | `asm/25F8` is one `jmp` |

Vehicle tiles, via `mode = map_byte >> 1`: horse `0x44`, ship `0x48`, PLANE `0x4C`, rocket `0x50`.

**The gate variable is `map_byte >> 1`, never the art index (`>> 2`).** Getting this wrong is the
root cause of every passability regression the project has had. `DS:14` holds it live; `DS:29` is
scratch and reads a stale value at rest — measured, do not read `DS:29`.

---

## 2. What already exists in the engine

Do not rebuild these; wire to them.

| thing | where | note |
| --- | --- | --- |
| travel-mode field | `state.h` `player_stamp` @ `DS:13` | set to `0x78` at `overworld.c:927`; already read as a mode at `overworld.c:860` |
| on-foot ladder | `overworld.c` `u2_tile_passable()` | replaced the old per-tile table on 2026-10-29; **this is the foot/horse rule** |
| food subtract | `overworld.c` `food_spend()`, `U2_FOOD_PER_MOVE 0x19` | packed BCD; the raw immediate goes straight into `sbb` |
| command table | `commands.c` `cmd_table[]` | `B` and `L` are `NULL` with "needs vehicles" comments |
| handler signature | `static u2_cmd_result cmd_X(u2_ctx *, u2_overworld *, uint8_t letter)` | copy `cmd_E` or `cmd_P` as the simplest models |
| ladder gate | `engine/tests/passability_ladder.py`, wired as CP5 **P1** | 16 tiles, fresh seed each, control verified red |

`B` is in the **proven-executing** set (`asm/2F6F` ran in 4 of 163 harvests), so its `NULL` slot is a
real gap in a letter we are not supposed to leave unimplemented — unlike `C`/`D`, which are blocked
on parked subsystems.

---

## 3. Work items, in order

Each item lands with its gate. **Run the control before trusting the gate** — see § 5, item 1.

### W1 — `BOARD` (`cmd_B`)

`asm/2F6F_cmd_B` prints `"BOARD"` and falls into `asm/2FAD_vehicle_board_dispatch`, which is:

```
mov 0x14,%al          ; the destination/current mode, NOT the tile byte
cmp $0x22,%al
je  L_0031d6          ; asm/2FD6 vehicle_horse -> prints " HORSE"
...                   ; 0x24 -> asm/2FFE ship, 0x26 -> asm/3038 frigate, 0x28 -> rocket tail
```

Each vehicle routine prints its own name (`" HORSE"`, `" SHIP"`, `" PLANE"`) and sets `DS:13`.
Measured live: **`BOARD` sets `DS:13 = 0x24` and does not move the player**
(`captures/spice86/ship-port-boniface`).

Build: `cmd_B` reads the tile under the player, shifts right one, dispatches, sets
`ctx->state.player_stamp`, prints, returns `U2_CMD_DONE`. If the tile is not a vehicle tile the
original falls through — **check `asm/2FAD`'s tail before inventing a refusal message**, because a
made-up error string is exactly the invention this project forbids.

Gate: for each of the four vehicle tiles, seed a save standing on it (see § 4 recipe), press `B`,
assert `DS:13` and that the position did not change.

### W2 — per-mode passability

`u2_tile_passable()` becomes a dispatch on `player_stamp`. The rules are all in § 1 and all proven.
Keep the foot ladder byte-for-byte as it is; add arms around it.

Ship is `mode == 0x00` **only**. `asm/2619` also compares against `0x80`, and that comparison is
**unreachable** — the largest value the arm can see is `0xFC >> 1 = 0x7E`. Do not model it. If a
future capture shows the ship entering a non-water tile, that finding overturns this, and the
capture recipe is in `captures/spice86/ship-port-boniface/readings.md`.

Gate: extend `passability_ladder.py` with a mode column. It already builds a fresh seed per case and
asserts whether the player moved, so this is a loop change, not a new harness. **Re-run the foot
cases unchanged** — if they move, the refactor broke the ladder.

### W3 — per-mode food cost

`0x78` → 19, `0x22` → 38, `0x26` → 38, `0x24` → 0, `0x28` → 0. Already measured by forcing
`DS:13` on the maxed seed in sector 31 (`stepcost`, 2026-10-25, recorded in
`asm/2626_food_drain_mounted`'s header). The horse's 38 is **two** 19s: `asm/2557` jumps into
`asm/2626`, which subtracts once and then calls through to `asm/2599` which subtracts again.

Note the discriminator that makes this trustworthy: a delta of 38 is `mod 10 == 8`, which no number
of 10-food auto-PASSes can imitate, so the two charges are separable from the idle-gap confound.

Gate: assert the food delta per mode from the turn dumps. `--dump-ds` / `--load-ds` now exist, so
this can force a mode without a `BOARD` implementation if you want W3 independent of W1.

### W4 — `LAUNCH` / `LAND` (`cmd_L`)

`asm/38B0_cmd_L` is the largest handler (`0x2E2` bytes) and starts:

```
mov 0x13,%al
cmp $0x26,%al ; jne ...  ; plane branch at L_003bfa
cmp $0x28,%al ; je L_003ad2  ; rocket: "LAUNCH--ROCKET"
call str_out " ; "LAUNCH WHAT?" -> jmp cmd_done
```

Landing is gated at runtime `0x3B56`, with `"LAND PLANE."` at `0x3B5A` and `"LAND--NOT HERE!!!!!"`
at `0x3B72`. **Both branches executed** in `captures/spice86/flight-launched-live`, so this is not
speculation. Landing is accepted only on tile `0x08` (grass); anything else keeps you flying.

Strings needed: `LAUNCH WHAT?`, `LAUNCH--ROCKET`, `LAUNCH--PLANE`, `LAND PLANE.`,
`LAND--NOT HERE!!!!!`, `(PRESS ANY KEY)`. Add them to `engine/tools/extract/extractor.py`'s
`STRINGS` table with exe offsets — several carry the leading `0x8d` glyph byte and so need the
`("run", offset, len, text)` tuple form, like `U2_S_KILLED` and the two force-field entries.

**Do not port the whole handler at once.** Land the plane branch (launch, land, refuse) and leave
the rocket branch until W5, and say so in the code.

### W5 — rocket

`asm/25F8` is a single `jmp` to the accept path and never reaches a drain, which is why the rocket is
free. Once `cmd_L` handles `0x28`, rocket is nearly free too.

### W6 — the plane's airborne flag — **OPEN, do not guess**

The plane arm rejects mode `0x06` (map `0x0C`, forest). It is **not established** whether that rule
applies while airborne, while grounded, or always. The owner's note is "plane on land can't traverse
forest", which suggests the rule is the *grounded* one and that airborne may differ — but that is a
reading of a sentence, not a measurement.

Resolve it by capture, not by inference. Sector 41 (the CCCP / KGB / LAUNCH town, which also has
three ship tiles at `(34,12)`, `(34,14)`, `(34,16)`) is the place: `BOARD` a plane, `LAUNCH`, then
fly over forest and record accept/refuse at each altitude. Owner has agreed to this test later.

Until then, if you must ship a plane rule, apply the forest rejection unconditionally and mark it
in-source as unproven for the airborne case, per the `UNPROVEN` marker convention.

---

## 4. Capture recipe (for W6 and any live check)

All of this was used successfully on 2026-10-29:

```sh
# 1. park a real character in a sector, at a chosen world cell
cp /var/tmp/u2/s03/PLAYER /var/tmp/u2/sNN/PLAYER
python3 tools/u2_edit.py set   /var/tmp/u2/sNN/PLAYER sector NN
python3 tools/u2_edit.py setpos /var/tmp/u2/sNN/PLAYER X Y     # entry_x/entry_y @ DS:5A/5B

# 2. start a session. EXPLICIT ports, always.
bash tools/spice86_stop.sh
bash tools/spice86_start.sh --headless --name cap --player /var/tmp/u2/sNN/PLAYER \
     --auto-play --patch-arrows --http-port 20185 --mcp-port 20186

# 3. read state. DS = 0x08BE.
python3 tools/spice86_type.py --peek 08be:0000:2 --http-port 20185   # position
python3 tools/spice86_type.py --peek 08be:0013:1 --http-port 20185   # travel mode
python3 tools/spice86_type.py --peek 08be:0014:1 --http-port 20185   # map_byte >> 1
python3 tools/spice86_type.py --keys Left --http-port 20185 --mcp-port 20186
```

Sector 31 ship tiles: `(6,23)` and `(8,25)` are ringed by water and **unreachable on foot**;
`(14,23)` is docked with grass north and east, and `(15,23)` is the standing spot that works.

---

## 5. Traps. Each of these cost time on 2026-10-29.

1. **A control that cannot fail.** An edit that did not compile left the old binary in place and the
   gate passed green. *Always* confirm the control run actually rebuilt: check the binary's `md5sum`
   or `strings` for a symbol you added, not just the exit code.
2. **Deploying a stale binary.** `make -C engine sdl` had not finished linking before the binary was
   copied, and the container image layer was cached, so the "new" deployment ran old code. Verify
   the md5 **inside** the container against the host build.
3. **Port collision.** `spice86_start.sh` picked the same port for HTTP and MCP when 20180/20181
   were held by the noVNC container, and the recorder then reported "emulator is not advancing".
   Pass `--http-port` and `--mcp-port` explicitly.
4. **Reused save dirs.** The engine rewrites the save in place. A reused dir produced a wrong turn
   count (32 instead of 16) that looked like a real result. Fresh seed per case.
5. **Check the recording is in the sector you think it is.** A "sector 21" capture was silently
   sector 03, and analysing it against `mapx21` produced 3448 phantom differences and a confident
   nonsense conclusion. Read `DS:49/4A` before analysing.
6. **`DS:29` is scratch.** It read `0x14` at rest through an entire ship capture and never changed.
   Read `DS:14`.
7. **`map_byte >> 1` is the mode; `>> 2` is the art index.** They are different quantities and the
   engine used the wrong one for a whole phase.
8. **Renaming an `asm/` file breaks hardcoded names.** `extractor.py`'s `STRINGS` table holds
   filenames; a rename took CP0 to red until the entry was updated. Grep for the old name after any
   rename.
9. **Read the routine, not its header.** F14's first version said "plane accepts everything"
   because it summarised a header line. The body rejects forest. Same class of error the file
   already documents at F6 and F10.
10. **`--sdl` cannot take `--script`** (backend selection runs before argument parsing). Until that
    is fixed, no SDL pixel bug can be gated in CI.

---

## 6. Explicitly out of scope / still unknown

- **The frigate** (`asm/3038_vehicle_frigate`) is a separate dispatch arm from the ship and was
  never tested. It may not be a ship at all. Do not assume it shares `asm/2619`'s rule.
- **Dismount.** No evidence found for a dismount command. `BOARD` sets the mode; nothing here shows
  it being cleared. Do not invent one — check whether stepping onto land simply ends it, or whether
  the mode persists until death or save.
- **`DS:14` on a refused step** did not change, so it may hold the tile the player is ON rather than
  the attempted destination. One more refusal onto a known-different tile settles it.
- **Vehicles and the sector grid.** Whether a vehicle tile is consumed on boarding, or stays for
  others, is untested. The ship tile was still `0x48` in the map after boarding.

---

## 7. Verification, every commit

```sh
make -C engine && make -C engine test     # CP0..CP5
bash tools/assemble_clean.sh              # must print "37344 bytes identical"
bash tools/check_all.sh                   # all gates, currently 20
```

`assemble_clean.sh` is the authority on the reconstruction; the engine tests are the authority on
behaviour. They are separate workflows on purpose — engine work-in-progress must not look like a
regression in the byte proof.

When a finding changes how a *generic* DOS decompilation harness should be built, the same commit
adds a line to `docs/harness-portability.md` § 6. Method transfers; conclusions do not.
