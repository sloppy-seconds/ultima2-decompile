# Contract 1 — overworld walk (direction input, move-then-undo)

Format follows the mission brief: entry addresses, state touched, algorithm, then a C
contract with exact numbers. Grades are stated per claim, per `AGENTS.md` § 5:
**observed** = a byte read from the binary, **measured** = derived by a named tool,
**inferred** = reasoned from a partial read.

## System: overworld walk

* **Primary entry address:** runtime `0x0936` = file `0x0B36` (function head,
  `asm/0936_walk_loop.asm`)
* **Identifying instruction:** the direction-key compares against the table at
  `DS:26E..DS:271`. Those four bytes are what make this loop recognisable; the head at
  `0x0936` is only a 10-byte fragment and is not the interesting part.
* **Span:** runtime `0x0936..0x0BF1`, file `0x0B36..0x0BF1`. It is split across 37 tiny
  `asm/` files because of the CP3 label-preservation rule, so read the range, not one file.

### Memory state touched

| address | role | grade |
| --- | --- | --- |
| `DS:00` | player **x** (west/east axis) | observed (`incb`/`decb 0x0` in the E/W arms) |
| `DS:01` | player **y** (north/south axis) | observed (`incb`/`decb 0x1` in the N/S arms) |
| `DS:15` | mode byte passed to the passability call for **north** | observed (`mov al,[0x15]` at `0x0962`) |
| `DS:16` | mode byte for **south** | observed (`mov al,[0x16]` at `0x0989`) |
| `DS:17` | mode byte for **east** | observed (`mov al,[0x17]` at `0x09D5`) |
| `DS:18` | mode byte for **west** | observed (`mov al,[0x18]` at `0x09AF`) |
| `DS:26` | toggled by the accept tail; zeroed by `PASS` and by the no-match path | observed |
| `DS:26E..271` | direction key table, one byte per direction | observed |
| `DS:5D` | one-byte scratch, written then read back at the head | observed |
| `DS:13` | vehicle byte, read by the passability routine | see `docs/passability-findings.md` F3 |

### Algorithm breakdown

1. **Head** (`0x0936`): round-trips `AL` through `DS:5D`, then tests `AL == 0x20` (space).
   Space is the **PASS** action: it zeroes `DS:26`, prints `"PASS"`, and leaves.
2. **Direction dispatch** (`0x094F` onward) is a linear compare chain, and the order is
   **N, S, W, E** — not the intuitive N, S, E, W. Each compare is against one table byte:

   | arm | key byte | move | undo | mode byte | word printed |
   | --- | --- | --- | --- | --- | --- |
   | north | `DS:26E` | `dec DS:01` | `inc DS:01` | `DS:15` | `NORTH` |
   | south | `DS:26F` | `inc DS:01` | `dec DS:01` | `DS:16` | `SOUTH` |
   | west  | `DS:271` | `dec DS:00` | `inc DS:00` | `DS:18` | `WEST` |
   | east  | `DS:270` | `inc DS:00` | `dec DS:00` | `DS:17` | `EAST` |

   Note the two asymmetries, both of which are easy to get wrong and both observed: the
   dispatch order is `26E, 26F, 271, 270`, and the mode-byte order is `15, 16, 18, 17`.
3. **Move first, ask later.** Each arm mutates the position *before* testing anything.
   It then prints the direction word via `str_out` (runtime `0x4FDF`, file `0x51DF`).
4. **Test** (`call 0x2423` with `AL` = the arm's mode byte). Return `0` means accept,
   non-zero means reject. The accept path inside `0x2423` masks **both** coordinates with
   `0x3F` before returning, so the world wrap happens inside the callee, not in this loop
   (`docs/passability-findings.md` F2).
5. **Reject** undoes the step with the inverse `inc`/`dec`, jumps to `0x0A02`, which prints
   `"--INVALID MOVE!"` and falls through to the command-done tail. The undo happens before
   any redraw, so a rejected step is invisible on screen even though the player did move.
6. **Accept tail** (`0x09E9`): `DS:26 = ~DS:26` (xor `0xFF`), then jump to `cmd_done`.
7. **No direction matched** (`0x09F4`): saves `AX`, zeroes `DS:26`, restores `AX`, then
   classifies the key: `0x41..0x5A` (`A`..`Z`) goes to the letter-command dispatch at
   `0x0A1F`, everything else jumps to runtime `0x2275`. The letter dispatch is
   `sbb al,0x41` → `add al,al` → `jmp *cs:[0x730+ax]`, i.e. a 26-entry word table at file
   `0x0730`.

### C behavioral contract

```c
/* Direction key table, DS:26E..DS:271. Contents are keycodes; the layout order is
 * the dispatch order, which is N, S, W, E. */
extern uint8_t DS[];

#define DIR_NORTH  DS[0x26E]
#define DIR_SOUTH  DS[0x26F]
#define DIR_EAST   DS[0x270]
#define DIR_WEST   DS[0x271]

/* Returns 0 to accept the step, non-zero to reject it. Side effect on accept: both
 * player coordinates are masked with 0x3F, which is the world wrap. It is called with
 * the arm's mode byte in AL, NOT with a tile index. */
extern int8_t passability_2423(uint8_t mode_byte);

static void print_str(const char *s);          /* str_out, runtime 0x4FDF */
static void cmd_done(void);                   /* runtime 0x0A33 */
static void letter_dispatch(uint8_t key);     /* runtime 0x0A1F, table at file 0x0730 */
static void other_key_dispatch(uint8_t key);  /* runtime 0x2275 */

void walk_loop(uint8_t key)                   /* runtime 0x0936 */
{
    DS[0x5D] = key;                           /* observed round-trip; AL preservation */
    key      = DS[0x5D];

    if (key == 0x20) {                        /* PASS */
        DS[0x26] = 0x00;
        print_str("PASS");
        cmd_done();
        return;
    }

    /* One arm per direction: move, echo, test, undo-and-complain on reject. */
    int8_t verdict;

    if (key == DIR_NORTH) {
        DS[0x01]--;                           /* y decreases north */
        print_str("NORTH");
        verdict = passability_2423(DS[0x15]);
        if (verdict != 0) { DS[0x01]++; goto rejected; }
    } else if (key == DIR_SOUTH) {
        DS[0x01]++;
        print_str("SOUTH");
        verdict = passability_2423(DS[0x16]);
        if (verdict != 0) { DS[0x01]--; goto rejected; }
    } else if (key == DIR_WEST) {             /* third in dispatch order */
        DS[0x00]--;                           /* x decreases west */
        print_str("WEST");
        verdict = passability_2423(DS[0x18]);
        if (verdict != 0) { DS[0x00]++; goto rejected; }
    } else if (key == DIR_EAST) {             /* fourth in dispatch order */
        DS[0x00]++;
        print_str("EAST");
        verdict = passability_2423(DS[0x17]);
        if (verdict != 0) { DS[0x00]--; goto rejected; }
    } else {
        DS[0x26] = 0x00;                      /* no direction matched */
        if (key >= 0x41 && key <= 0x5A) letter_dispatch(key);
        else                            other_key_dispatch(key);
        return;
    }

    DS[0x26] ^= 0xFF;                         /* accept tail, runtime 0x09E9 */
    cmd_done();
    return;

rejected:                                     /* runtime 0x0A02 */
    print_str("--INVALID MOVE!");
    cmd_done();
}
```

### What this contract deliberately does not claim

* **`passability_2423` is a poor name and the contract keeps it flagged.** The decoded
  routine at runtime `0x2423..0x2680` branches only on `DS:29 & 0x7F`; **no tile value
  participates** (`docs/passability-findings.md` F2). So on foot in the overworld this call
  may never reject a step, and the reject path may be reachable only from a vehicle or
  interior context. The name is kept because it is the established label, not because the
  behaviour is passability.
* **The mode bytes are unexplained.** `DS:15..18` are filled by a table copy at runtime
  `0x5B71..0x5B92` from `DS:2CB`, `DS:2DE`, `DS:2E0`, `DS:2F3`, and those four have **no
  direct writers anywhere in the exe** (F3). Until an indexed writer is found, the argument
  passed to `passability_2423` is a placeholder, and any test that asserts a specific verdict
  is asserting an unknown.
* **`DS:26` has two documented lives and they may not be the same variable.** Here it is
  toggled by `xor 0xFF` on accept and zeroed on `PASS`, which reads as a moved/changed flag.
  In dungeons it is the torch step counter, set to ~149 by `I` and decremented per step
  (`docs/phase4-state.md` CP7). Both are recorded; neither is proven to be one field with two
  uses rather than a coincidence.

## Apple II cross-reference: negative result

This is the finding that constrains the contract, and it is a refutation rather than a
confirmation.

The Apple build has **no counterpart to this loop's user-visible behaviour**. Searched
`ULTIMA.II.OBJ` (and the other resident segments) in both plain and high-bit-set form:

| string | DOS | Apple |
| --- | --- | --- |
| `NORTH` / `SOUTH` / `EAST` / `WEST` | echoed by each arm | **absent** |
| `PASS` | echoed on space | **absent** |
| `--INVALID MOVE!` | echoed on reject | **absent** |

The era table (`ANOS: 1990 A.D.` at `$77E8`) and `ANKH` (`$73E3`) *are* present, so the
absence is not a search artefact. Grade: **observed** (byte search, both encodings, all
resident segments).

Consequences, stated as limits:

* The direction echo and the reject message are **DOS-side additions**. Do not attribute them
  to the 6502 original.
* The move-then-undo shape cannot be checked against the Apple build by string anchor. If the
  underlying position update is shared, it has to be found structurally: zero-page `$00`/`$01`
  `INC`/`DEC` pairs inside a routine reachable from the main input loop.
* Nothing in this contract should be re-derived from the Apple tree. The DOS bytes are the
  specification here, and they already are byte-exact.

## Verification

The contract is a transcription of `asm/` bytes in the range above, not a new measurement. To
re-check the load-bearing details:

```bash
python3 tools/check_func.py 0936          # proves the head fragment byte-exact
grep -rn "incb   0x0\|decb   0x0\|incb   0x1\|decb   0x1" asm/09[3-9]*.asm asm/09[A-F]*.asm
```

The dispatch order (`26E, 26F, 271, 270`) and the mode-byte order (`15, 16, 18, 17`) are the
two details most likely to be silently "fixed" into a tidy order by a future reader. They are
not tidy and they are not wrong.

## Next contract: premise check on "time-door spawning"

The work brief asked for a contract on time-door spawning. Before writing one the premise was
tested, and **it does not survive**. Grade: measured, by byte census over `original/mapxNN`
and the Apple `M/AP.NN`.

* The moongate is **map tile art index `30`, map byte `0xC0`** (`docs/tile-art-spec.md`).
* In the overworld it is **authored into the sector grid**. `mapx03` contains exactly four
  `0xC0` cells, at `(15,25)`, `(20,25)`, `(21,25)`, `(26,25)`, and Apple `AP.03` contains the
  same four. Same authored positions, two platforms, no code needed to explain them.
* **No moongate-specific spawn site was found, and the tiles do not need one.** The four
  `0xC0` cells in `mapx03` are present in the authored data on both platforms, so their
  existence is fully explained without any runtime writer. What was *not* found is any code
  that names `0xC0` in order to place it: the only `mov $0xc0,%al` sites are `asm/0896`, which
  initialises the combat damage accumulator at `DS:22`, and `asm/0DC4`. Neither is a map
  writer.
* **Correction, stated so it is not repeated:** an earlier draft of this section claimed "there
  is no store to the sector grid at `DS:1800` anywhere in `asm/`". That is **unproven and too
  strong**, and a grep for direct stores would have produced it as a plausible false negative.
  `asm/5EF2` loads `$0x1800` into `%bx` alongside `$0x800` into `%ax`, `$0x47` into `%cx`,
  `$0x800` into `%dx` and `$8` into `%bp`, then calls runtime `0x5DA9` — a block operation on
  the grid reached through a register, which a direct-store grep cannot see. `asm/68C0` also
  documents `word[DS:472] = 0x1800` as the dungeon grid base. So the grid is writable through
  pointers and the correct claim is the narrow one above: no *moongate placement* site exists,
  not that the grid is immutable.
* `NEGATE TIME` (`asm/3BCE_cmd_N.asm`) is a command that prints a string, not a door. It is
  the `N` letter command, and per `docs/u2-game-meta-analysis.md` it consumes Strange Coins to
  freeze creature movement.

One caution before anyone generalises this: the high `0xC0` counts in `mapx15`/`25`/`35`/`45`
(252 to 258 each) are **dungeon sectors**, where byte semantics differ from the overworld and
`0x80`-class values mean something else entirely. `AGENTS.md` parks dungeons for exactly this
reason, and the moongate claim above is about overworld sectors only.

So the brief's "time-door spawning" is most likely a conflation imported from the secondary
analysis this project already keeps a refutation doc for. The real adjacent targets, both
evidenced and both live in CP5, are:

1. **The creature movement tick.** `asm/0A6D`..`asm/0AA1` sweep the 32 creature slots. The
   slot tables are `DS:137+x` = x, `DS:157+x` = y, `DS:177+x` = HP, `DS:197+x` = type, and
   movement is `(x + DS:19) & 0x3F` and `(y + DS:1A) & 0x3F`, with `DS:19`/`DS:1A` set to
   player-minus-creature by `asm/152E` and negated by `asm/0B0F` to turn pursuit into retreat.
   Contact is detected by comparing both masked coordinates against `DS:00`/`DS:01`.
2. **The `PASS` and letter-command dispatch**, the other half of the loop above, with its jump
   table already located at file `0x0730`.
