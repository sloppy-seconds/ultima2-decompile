# Handover — `apple2-reference`: the Apple path is open, two contracts exist, and one was wrong

Session label continues `docs/handoff-2026-10-28b.md`. Branch **`apple2-reference`**, 11 commits,
working tree clean. Not merged to `main` — that is an owner call, see "Needs a person".

Read this file, then `AGENTS.md`, then `docs/contract-creature-tick.md` § "What this contract
deliberately does not claim". Everything below assumes you have done that.

## State of the world

| thing | state |
| --- | --- |
| `asm/` reconstruction + CI proof | green, untouched this session |
| `make -C engine test` | green at every commit that could break something (CP5 SPEC: PASS) |
| Apple II disks | parsed, extracted, memory-mapped, imported to Ghidra. `docs/apple2-reference.md` |
| Behavioural contracts | 2: `docs/contract-overworld-walk.md`, `docs/contract-creature-tick.md` (contract 2's two named holes closed 2026-10-28c) |
| Tooling added | `tools/ciderpress2/` (vendored, gitignored), `tools/apple2_image.py`, `tools/ghidra/Seed6502.java` |
| Docs fixed | stale "keystrokes are unavailable" killed in 4 places; 6 `AGENTS.md` gaps closed |

## The live plan

`docs/mission-briefing.md` if it gets committed; until then the operative pipeline is the six
steps Paul approved:

**Step 0 name lookup → 1 static bounds → 2 dynamic gap closure → 3 cross-reference → 4
contract → 5 falsification → 6 reconcile the docs.**

Step 0 is not ceremonial. Read the "Step 0 failed twice" section below before you start.

## Unattended queue

Ordered by value, each sized to finish in one sitting with no owner input. Every item is
**static-only** — nothing here needs the container, the emulator, or a decision from Paul.

### U1 — ~~the tile classifier at `asm/21A6..21D8`~~ **CLOSED 2026-10-28c**

The whole gate is decoded and it is `asm/2199_creature_step_gate` (runtime `0x2199..0x2200`),
named on disk. Rule, table, grades and falsification: `docs/contract-creature-tick.md`
§ "The step gate" and § "Falsification". Both of contract 2's named holes are gone — the tile
ladder and `slot_gate_unproven` (which was the horse-and-`DS:26` freeze, `asm/0A7C`/`asm/0A83`).

Four things fell out that were not in the ticket:

* `DS:26A` is the creature-move freeze counter and its only setter is `asm/3C04_coin_rub`.
  That closes the static half of `docs/needs-gameplay.md` G27.
* `asm/4F11` (now `4F11_monster_step_vector`) is the vector the step actually uses, and contract
  2 had the wrong routine and the wrong mechanism: `asm/50D8` is a **sign function**, not a
  torus wrap, and the torus behaviour is the `add al,al` pair in the caller. Contract 2 corrected.
* `asm/4F11` and `asm/4F36` both compute `player - creature - 1`, because `stc` sets CF and x86
  `sub` subtracts it. Derived consequence, never observed: G28.
* `DS:1B7` is the per-slot saved terrain byte of the grid stamp, not a mystery mirror table.

### U2 — ~~settle the `DS:1F` contradiction~~ **CLOSED 2026-10-28c, and it was a reconciliation**

There is no contradiction: `DS:1F` is shared scratch with three legitimate readings (tile in this
system, slot index in the placement cluster, saved `DS:13` stamp across `asm/2677`/`asm/269F`).
**The answer was already on disk** — `asm/0CB0_sub_0cb0.asm`'s header has said "shared scratch
with 20+ writers" since 2026-10-23 and cites the live reading of 120 that kills the slot-index
theory; 120 is `0x78`, the on-foot stamp. Third Step 0 miss in the same number of turns, and this
one I caught before writing a probe instead of after shipping a wrong claim. Written up in
`docs/contract-creature-tick.md` § "The `DS:1F` contradiction", including the verdict on
`asm/0CC0`'s breakpoint warning: still correct, still load-bearing, but path-local.

### U3 — ~~the arrow scancode path, end to end~~ **CLOSED 2026-10-28c — it was already traced**

`docs/phase4-implementation.md` § "Direction keys: proven, and they are the arrows" has had the
whole chain since CP4, including the table address, the backwards scan, the `DS:26E..271` data
initialiser and the live `captures/spice86/live-ds-4f4d.bin` confirmation. The handoff's "cited
but never traced" was wrong about its own tree — fourth Step 0 miss, first one where the answer
was in the file the ticket told me to write.

What was done instead: every hop re-verified against `original/ultimaii.exe` (table bytes, DS
initialiser, the four walk-loop compares, the swallow site — all match), and the trace turned up
three things that had not been written down. The swallow list is **three codes, not four**, so
`Ctrl-Y` should walk south (G30); `key_poll` **drains the typeahead buffer**, which is the real
mechanism behind standing hazard 1 and means no injection tool can fix a key burst; and the
`AH=0xFF`/`AH=0x00` return convention is one instruction that the Phase 3 fragment split put in a
different file from the branch that skips it. `asm/4F4D_key_poll` now carries the span and the
contract, and nine of its fragments got their clause.

### U4 — ~~item 1 as a reconciliation contract~~ **REFRAMED 2026-10-28c: the document was forbidden, so it became a generated gate**

The ticket asked for "a short contract that crosswalks `asm/0A1F_cmd_dispatch` →
`disasm/jump-table.txt` → the 26 `cmd_X` files, and records the per-letter handler entry points
in one place". That document must not be written by hand: `AGENTS.md` § 3 forbids exactly this —
"Do not create flow tables, address cheat-sheets or symbol indexes in `docs/` or `disasm/` that
duplicate [asm/] … Any derived view must be *generated* by a tool, never kept by hand." The
per-letter entry points are already in two authoritative places (the table file and the
filenames), so a third hand-maintained copy would only add a way to be stale.

What was built instead is `tools/cmd_handlers.py`: it joins the three existing sources —
`disasm/jump-table.txt`, the `asm/<ADDR>_cmd_<L>.asm` filename, and each header's
`entry executed in N of 60 harvests` line — prints the crosswalk, and **exits non-zero when the
three disagree**. Negative controls run and recorded: a letter/file mismatch, a table entry with
no file, and a malformed line all exit 1; the real inputs exit 0 with
`26 handlers crosswalked, 12 never executed in a capture`.

The join also corrected a number in the ticket. **It is 12 handlers never executed in the current
60-harvest corpus, not 19.** The 19 in `disasm/jump-table.md` counts handlers absent from the
single Phase 1 playthrough's runtime CFG (`disasm/entry-points.txt`), which is a different corpus
and a different question; both are right about their own. The tool says so in its own footer so
the two numbers cannot be mistaken for a contradiction later.

What is genuinely left, and is not a static job: 12 handlers have never executed in a capture
(`--unexercised-only` lists them), and most handler *bodies* are still unread — 26 small static
jobs, and the plan should pick them by need rather than by letter.

### U5 — resolve `FL`, `II`, `WII`, `UL` from the Apple build

Self-contained, low risk, and it closes the last unnamed files in `docs/apple2-reference.md` § 3.

- **First command:** `./tools/ciderpress2/cp2 catalog "references/apple/Ultima II (4am
  crack)/Ultima II (4am crack) disk 1 - program.dsk"`
- **Done when:** each is classified as code, data, or overlay, with the evidence. If one turns
  out to be a gameplay table, that is worth a paragraph, not a contract.

## Step 0 failed twice in one session, and twice more in the next — read this before you start

The first two, both in a single session, and the second was mine in the turn where I promised to
apply the discipline:

1. I called `0x50B3` an undecoded black box. It is `asm/50B3_map_tile_ptr`, named, byte-proven,
   live-observed in 49 of 60 harvests, 25 caller files, addressing spelled out in the header.
   Contract 2 shipped three wrong claims because of it and had to be corrected.
2. In the very next turn I proposed "read the jump table at file `0x0730`" as the first task.
   **It is already decoded.** `disasm/jump-table.txt` has all 26 entries, produced in CP2, and
   `docs/status-screen-z.md` records reading it out of the binary on 2026-10-28.

The pattern is identical both times: a plausible-sounding gap that a two-second `ls`/`grep`
would have closed. So, mechanically, before any task:

```bash
ls asm/ | grep -i <keyword>          # is it named?
grep -rn "<address>" docs/ disasm/   # has someone already written it down?
```

If the answer is yes, the work is reconciliation or extension, not extraction. Say which.

**The discipline was applied in the next session and still produced two more, which is the part
worth recording.** U2 (`DS:1F`'s "contradiction") was answered in `asm/0CB0`'s header six days
earlier, and U3 (the arrow scancode chain) was fully traced in `docs/phase4-implementation.md`
since CP4 — a file the ticket itself cited for a *different* claim. Both were caught before the
wrong claim shipped rather than after, which is the only thing that distinguishes them from the
first two. The lesson is not "grep once", it is that **the ticket is not the source of truth
about what is unknown**: a handoff written by a tired agent lists gaps it guessed at, and two of
the five gaps on the list below were not gaps. Grep the *question*, not the task title.

## Hard rules for unattended work

- **Dungeons stay parked.** `asm/1151`, `asm/147F`, `DNGDRAW.OBJ`, `SHAPES`, `TABLES.903C.OBJ`
  are out of scope. `AGENTS.md` § 3.
- **Never commit** `decompiled/`, `original/`, `references/`, `tools/ciderpress2/`. All
  gitignored for a reason. The Apple extractions are copyrighted game content.
- **Never write to `references/`.** Read-only. `cp2` is only ever pointed at it for reads.
- **`asm/` labels are body.** Only filenames and `#` comment lines may change. Editing a
  `sub_xxxx:` label fails CP0. If a rename seems needed, propose it, do not do it.
- **`bash tools/assemble_clean.sh` and `make -C engine test` must be green** at any commit that
  touches engine source, `asm/`, tests, or tooling. Docs-only commits may skip the suite.
- **A wrong name is worse than no name.** If bytes contradict an existing name, add a
  `# NAME DISPUTED:` line and propose the rename; do not silently rename.
- **Scratch and logs go to `/var/tmp`, never `/tmp`** (`/tmp` is tmpfs here and takes RAM).
- **Never run the game in place.** `tools/spice86_start.sh` copies pristine files per launch.

## Hazards this session cost time

- **`stc` before a `sub` is arithmetic on x86.** `SUB` subtracts CF, so a carry-setting
  instruction two bytes earlier makes every difference `a - b - 1`. Two routines in this binary
  compute the same delta, one with `stc ; cmc` (harmless) and one with a bare `stc` (off by one),
  and the CP3 fragment split puts the `stc` and the `sub` in different files. Read pairs in
  address order, and diff near-duplicate routines against each other rather than trusting one.
- **A predicate can return its verdict in the flags.** `asm/2199_creature_step_gate` ends both
  exits with `cmp $0x0,%al` before the `ret` and all three callers branch on ZF. Read as a value
  it looks like a function whose result nobody checks; the `cmp` is the calling convention.
- **The Apple `.dsk` is `order=dos/sect`.** A linear byte read crosses the sector skew and
  splits the 39-byte directory records. Hand-deriving it produced a grid that parsed cleanly
  and was off by one record, silently attributing every file's size and load address to its
  neighbour. Use `cp2`. Do not hand-parse the container.
- **Ghidra's 6502 decompiler is weak on this code.** The JSR-inline-string idiom breaks its
  stack assumptions and it emits 18 KB blobs. It confirmed the printer; it is not a contract
  source. Use it for orientation, read bytes for claims.
- **The Apple build is a corroborator, not a parent.** 1989 re-release. `--INVALID MOVE!`,
  `NORTH/SOUTH/EAST/WEST/PASS` are absent from it. Never derive DOS behaviour from it.
- **`check_func.py` takes a runtime address**, e.g. `python3 tools/check_func.py 50B3`.
- **`analyzeHeadless` takes `-processor "6502:LE:16:default"`, not `-language`.** And a raw
  image yields zero functions without `Seed6502.java`.

## Needs a person — do not attempt these unattended

1. **Merge `apple2-reference` to `main` or not.** All docs + `asm/` headers and three `asm/`
   renames (`2199_creature_step_gate`, `4F11_monster_step_vector`, `50D8_sign_of_al`), no engine
   change. `assemble_clean.sh` byte-matches and `make -C engine test` is green.
2. **Any live capture.** Watchpoints, the container, `sudo podman` — all need approval. Two new
   items are now on the list and both are cheap and agent-drivable: **G28** (does the `-1` stall a
   creature one cell short — two seeded cells, one run) and **G29** (what is tile `0x5C` — one
   step onto a `mapx03` cell). **G27**'s remainder is a single poke of `DS:26A`.
3. **The `0x2423` naming question.** It is called "passability" but its decoded body branches
   only on `DS:29 & 0x7F` with no tile participating. Renaming it is an `asm/` filename change
   and needs an owner decision.
4. **CP5 acceptance bar** and whether C5 placement is in scope — open since 2026-10-23, see
   `docs/phase4-state.md`.
5. **`DS:15..18` ← `DS:2CB/2DE/2E0/2F3`** have no static writers anywhere. This is the one
   known place the plan genuinely requires a watchpoint. Do not guess it.

## Verification commands

```bash
bash tools/assemble_clean.sh                 # the asm proof; must stay green
make -C engine && make -C engine test        # engine suite
python3 tools/cmd_handlers.py --check        # jump table ↔ asm filenames ↔ provenance gate
python3 tools/check_func.py 50B3             # map_tile_ptr, 37 B
python3 tools/check_func.py 0A6D             # sweep head
python3 tools/check_func.py 2199             # the creature step gate
python3 tools/check_func.py 0936             # walk loop head
./tools/ciderpress2/cp2 catalog "references/apple/Ultima II (4am crack)/Ultima II (4am crack) disk 1 - program.dsk"
```
