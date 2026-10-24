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
| Behavioural contracts | 2: `docs/contract-overworld-walk.md`, `docs/contract-creature-tick.md` |
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

### U1 — the tile classifier at `asm/21A6..21D8`  ← start here

This is the actual gate on whether a creature moves, and it is the named hole in contract 2.

- **Goal:** decode the classifier that reads `DS:1F` and compares it against `0x00`, `0x04`,
  `0x10`, `0x14`, `0x2C`, `0x48`, `0x5C`, `0x70`, `0x78`. Produce the rule as a table: which
  tile values let a creature step, which refuse, and what the refusals do.
- **First command:** `cd asm && for f in 21A6* 21AE* 21B2* 21B6* 21BD* 21C5* 21C9* 21CD* 21D1*
  21D5* 21D8* 21DF* 21E2* 21E9* 21F0* 21F7* 21FC*; do echo "## $f"; cat $f; done`
- **Also read:** `asm/50B3_map_tile_ptr.asm` (it is the producer of `DS:1F` — a fetch, not a
  test), `asm/2199*`, `docs/passability-findings.md`.
- **Done when:** contract 2's `slot_gate_unproven` hole is replaced by a real rule, and the
  contract gains a **Falsification** line: a specific tile value that must produce a different
  verdict from its neighbour. If every tile classifies the same way, the classifier is not what
  you think and you must say so rather than ship a table that cannot fail.
- **Stop when:** you find the verdict depends on a `DS:` field with no static writer. Write up
  what you need watched and stop; do not guess. That is a Step 2 job and it needs a person to
  approve the capture.

### U2 — settle the `DS:1F` contradiction

Contract 2 records it and leaves it open. It is probably resolvable statically.

- **Goal:** `asm/2199` stores a **tile byte** into `DS:1F`; `asm/0CC0` reads `DS:1F` as a
  **slot index** (`mov 0x1f,%bl`). A tile is a multiple of 4 up to `0xFC`; a slot is 0..31.
  Both cannot be right.
- **First command:** `cd asm && grep -ln "0x1f," *.asm | xargs grep -n "0x1f,"` and enumerate
  every reader and writer with its context.
- **Trap waiting for you there:** the same grep matches `mov $0x1f,%bl` in
  `asm/0A6D_monster_sweep_head.asm` and `asm/0C9C`, which is the **immediate 31** setting the
  sweep width, not a read of `DS:1F`. It has fooled people before (`docs/monster-spawn.md` § 11).
  Discard those before counting uses.
- **Done when:** either the two uses are shown to be different code paths that genuinely share
  the byte, or one of the two existing readings is proven wrong — and the losing header gets
  corrected in the same commit (Step 6).
- **Note:** `asm/0CC0`'s header already warns that a `MEMORY_WRITE` breakpoint on a fixed
  `DS:137+n` misses writes when `DS:1F` holds a different `n`. If you conclude that warning is
  built on a misreading, say so loudly — it is load-bearing for anyone instrumenting the sweep.

### U3 — the arrow scancode path, end to end

Contract 1 consumes direction codes at `DS:26E..271`. Nobody has traced how a scancode gets
there.

- **Goal:** close the chain hardware scancode → `INT 16h` AH=01h/00h → the translation table →
  `DS:26E..271` → the walk-loop compares. `docs/phase4-plan.md` § 350 asserts a table at
  `CS:0x4F09` with `48->0e, 50->19, 4d->05, 4b->17` and claims `Ctrl-E/N/W` are swallowed at
  the key seam. **That claim is cited but never traced.** Verify it or refute it.
- **First command:** `cd asm && ls | grep -iE 'key|poll|scancode|arrow'` then read
  `4F4D_key_poll.asm`, `2CD8_keys_add_two.asm`, `462F_status_keys.asm`.
- **Done when:** either a traced chain with addresses at every hop, or a named break point.
- **Falsification:** the four arrow scancodes must map to four distinct direction codes that
  match the four bytes the walk loop compares against. If two arrows land on the same code, the
  table reading is wrong.

### U4 — item 1 as a reconciliation contract, not an extraction

**Do not re-derive this.** See "Step 0 failed twice".

- **Goal:** a short contract that crosswalks `asm/0A1F_cmd_dispatch` → `disasm/jump-table.txt`
  → the 26 `cmd_X` files, and records the per-letter handler entry points in one place. The
  pieces all exist; nobody has joined them into a document an engine author can read.
- **Already done, do not repeat:** the table is decoded. `disasm/jump-table.txt` has all 26
  lines and they match the filenames exactly (`2B8F handler=A` ↔ `2B8F_cmd_A.asm`).
- **Genuine gaps left:** (a) 19 of 26 handlers have never been executed in a capture — see
  `disasm/jump-table.md` § "Cross-check vs entry-points.txt"; (b) what each handler *does* is
  mostly unread. (a) is a capture job, not yours. (b) is 26 small static jobs — pick the ones
  item 2/3/4 of the plan need, not all 26.

### U5 — resolve `FL`, `II`, `WII`, `UL` from the Apple build

Self-contained, low risk, and it closes the last unnamed files in `docs/apple2-reference.md` § 3.

- **First command:** `./tools/ciderpress2/cp2 catalog "references/apple/Ultima II (4am
  crack)/Ultima II (4am crack) disk 1 - program.dsk"`
- **Done when:** each is classified as code, data, or overlay, with the evidence. If one turns
  out to be a gameplay table, that is worth a paragraph, not a contract.

## Step 0 failed twice — read this before you start

Both failures in one session, and the second was mine in the turn where I promised to apply the
discipline:

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

1. **Merge `apple2-reference` to `main` or not.** 11 commits, all docs + tooling, no engine or
   `asm/` changes.
2. **Any live capture.** Watchpoints, the container, `sudo podman` — all need approval. U1's
   stop-condition may route here.
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
python3 tools/check_func.py 50B3             # map_tile_ptr, 37 B
python3 tools/check_func.py 0A6D             # sweep head
python3 tools/check_func.py 0936             # walk loop head
./tools/ciderpress2/cp2 catalog "references/apple/Ultima II (4am crack)/Ultima II (4am crack) disk 1 - program.dsk"
```
