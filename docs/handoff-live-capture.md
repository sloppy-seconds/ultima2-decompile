# Handoff — live-capture session, 2026-10-21 (read this first after compaction)

Written deliberately before a context compaction. Everything proven is on disk
and committed; this file is the index and the list of things that are now
**known wrong in the engine**.

## Read in this order

1. `AGENTS.md` — isolation, licensing, script rules. Hard law.
2. `docs/spice86-live-findings.md` — **the new evidence**, 7 sections. This is
   the freshest and most reliable thing we have.
3. `docs/phase4-implementation.md § CP4b` — contains a **RETRACTION** subsection.
   The two T1 subsections above it are false; the retraction is what stands.
4. `docs/phase4-overnight-cp4b.md § Morning report` — the T1 and part of the T2
   entries are marked retracted there too.
5. `docs/spice86-capture.md` — how to drive Spice86 (note: its monster layout
   and "DS:13 = player tile id" lines are corrected by the findings doc).

## Live state at time of writing

Spice86 is **running** with the owner playing in it:

```
pid 1513825   label play-test
run dir  tmp/20261021-064945      (TEST character seeded via --player)
http 20180   mcp 20181   gdb 20190
```

Do **not** kill it to be tidy. To stop it properly: `tools/spice86_stop.sh`.
To harvest without stopping: `tools/spice86_start.sh --harvest`.
Poll the API at a few Hz maximum — windowed Spice86 crashes above that
(`CfgCpuViewModel.cs:459` race, already lost one session to it).

Harvests on disk: `captures/spice86/{create-test-live,play-test-live}/` are the
two that matter (pre-fight and post-fight, 901 and 920 blocks). The rest are
tooling smoke tests and can be deleted with the owner's OK.

## What is now PROVEN (was previously guessed or wrong)

* Overworld passability is real and tile-based. `0x00` water blocks on foot,
  `0x0C` does not, mountains block (tile id not yet captured). Rollback happens
  **before** the redraw.
* Accepted move costs **19** food. Idle auto-PASS costs **10** and fires every
  ~7.6 s at `--Cycles 3000`. Idle auto-PASS also **advances monsters one cell**,
  so standing still is not safe.
* Accept path is runtime `0x2664`: `x &= 0x3F; y &= 0x3F; ret 0`. The overworld
  **wraps**. Reject path is runtime `0x25FF`: `mov al,0xFF; ret`.
* Combat: attack value from readied weapon `DS:61` ×8 + strength `DS:4B`
  (`0x2BFB`); a kill zeroes the monster record (`0x2D8C`) and awards gold
  `DS:58/59` and exp `DS:56/57`; player damage is `sbb [DS:22]` from `DS:51`
  (`0x0C09`). `A` attacks, `R` equips (not a combat key), arrows face.
* Monster arrays are **stride 1**: `x=DS:137+i`, `y=DS:157+i`, `sprite=DS:1B7+i`,
  `active=DS:197+i` (0x40 = empty). Not stride `0x20`.
* `monx20` is empty, so monsters are RNG-spawned; the seed comes from `0x40:6C`
  at launch and is frozen under emulation — which is why the same monster
  reappears across launches. It is not in the save.
* Character creation writes a complete loadable `player` record without `Q`.
* `DS:13` is the player's own tile id, **not** the travel mode.

## What is WRONG in the engine right now (the actual work list)

These are code defects created by the claims we have since disproven:

1. `engine/src/game/overworld.c` — the loop **refuses** out-of-range steps
   (`if (nx < 0 || nx >= U2_SECTOR_EDGE ...) continue;`). The original wraps
   `& 0x3F`. This is faithful-to-nothing; fix to wrap.
2. `engine/src/game/overworld.c` — **no passability at all**. Needs the tile
   table; `0x00` and mountains block. `--INVALID MOVE!` echo is already
   implemented as a string but never triggered.
3. `engine/src/game/overworld.c` — food tick only on `PASS` (`−10`). Missing
   **−19 per accepted move** and the **idle auto-PASS** (−10 / ~7.6 s, which
   must also move monsters). The auto-PASS needs a decision on clock backend so
   it does not perturb the CP2 baseline under the script clock.
4. `engine/src/game/overworld.c` — the Q-save "on foot" guard reasons from
   `DS:13 >= 0x78`, but `DS:13` is the player tile id. Re-derive or mark it.
5. `engine/tests/food_check.c` — still correct for PASS arithmetic, but its
   "4001st PASS kills" framing ignores that moves cost 19, so real starvation
   arrives far sooner. Extend, don't just trust it.
6. `docs/spice86-capture.md` — still says monster arrays are stride `0x20`. Fix.

## Not yet captured (the queue, in priority order)

1. **Mountain tile id** — stand next to a mountain, walk into it while the
   logger runs, read the destination tile. One minute of owner time.
2. **The passable-tile set** — `mapx20` has `0x00,0x04,0x08,0x0C,0x10,0x18,0x20,0x24`;
   only `0x00` (block) and `0x0C` (pass) are measured. Roam with the logger on.
3. **Boat on water** — the owner predicts a frigate on a water tile makes it
   passable. Untested. Needs a sector with a boat.
4. **What `[DS:15]` / `[DS:18]` really are** — the passability argument changes
   value between moves (`0x84,0x06,0x18,0x98`); the mode dispatch in the tail
   (runtime `0x2545..0x2660`) is still not understood. Do not guess a third time.
5. **Full combat capture** — a fight started *and* ended cleanly, plus a CFG
   harvest, to pin hit detection, monster damage rolls, and death.
6. **Sector edge** — walk to x=0 and one past, diff `DS:49/4A`, `DS:6E`, and the
   map buffer, to settle whether the `&0x3F` wrap is the whole story or the
   `DS:6E` arrival system also fires.

## Useful one-liners

Read live state (keep it to one request, a few Hz max):

```python
# DS = 0x08BE; physical = seg*16 + off
urllib.request.urlopen("http://127.0.0.1:20180/api/memory/35040/range/1536")
```

Tile under the player: map buffer is at `DS:[DS:0x472]` (was `DS:1800`),
indexed `y*64 + x`.

CFG diff that found the combat code: load two
`captures/spice86/*/spice86dumpCfgBlocks.json`, set-subtract the `entry` fields,
print `asm` for the new blocks. That diff did more than an hour of reading.
