# Handoff — live-capture work, updated 2026-10-21 (evening)

Read this first after a compaction or a fresh session. It replaces the morning
version. Evidence lives in `docs/spice86-live-findings.md`; this file is the
index, the running state, and the list of what to do next.

## Running state right now

* **Spice86 is stopped.** Ports 20180 / 20181 / 20190 free. Nothing to clean up.
* **No recorder running.**
* Owner is offline for the rest of the day — do not start a capture expecting
  someone to play.
* Beware: `pgrep -f Spice86` matches its own shell and reports a phantom
  process. Check the ports instead.

## Harvests on disk

| dir | what it is |
| --- | --- |
| `captures/spice86/vga-test/` | **newest and richest** — 965 blocks, buffed-character fight, kill observed live |
| `captures/spice86/play-test-live/` | 959 blocks, the paralyze/thief/sea-monster session; its `spice86dumpMemoryDump.bin` is the one most analysis was run against |
| `captures/spice86/baseline-fight/` | pre-fight snapshot kept as a diff baseline |
| `captures/spice86/create-test-live/` | 901 blocks, pre-fight |
| others | tooling smoke tests, safe to delete with owner approval |

The before/after **CFG set-difference** is the technique that worked: diff the
`entry` fields of two `spice86dumpCfgBlocks.json` files and print `asm` for the
new blocks. It localised the entire combat path in seconds, and it is how the
gold/exp filename swap was found.

## Tools built, and whether they are actually tested

| tool | status |
| --- | --- |
| `tools/vga_screen.py` | **tested, works** — renders the text-mode screen from any memory dump |
| `tools/map_render.py` | **tested, works** — renders the 64x64 sector with player and monsters |
| `tools/xref_provenance.py` | **tested, works** — docs↔asm cross-reference |
| `tools/poll_probe.py` | **tested, works** — measured 250 req/s, zero errors |
| `tools/turn_recorder.py` | **works, two cosmetic flaws** (below) |
| `tools/vga_ring.py` | **UNTESTED** — written after the session ended |

`turn_recorder.py` flaws, both known and neither blocking: `DS:20` is scratch
rather than a pure invalid-move counter so `[reject]` rows are noise; and
position and food update non-atomically, so one move can split across two
samples and show as an odometer anomaly.

## The one experiment still owed

**Paralysis + boots.** Never completed — the owner fought instead. Procedure,
all of it verified working except the last step:

1. Start: `tools/spice86_start.sh --name boots-test --player tmp/20261021-084906/player`
   (that save is the buffed TEST character: stats 99, HP 4000, quick sword, power armour)
2. Start `tools/vga_ring.py` **before** the fight — turn-boundary sampling cannot
   catch combat text, continuous sampling is the only hope.
3. Let the caster paralyze → expect `LEGS PARALIZED!`
4. Try to act while paralyzed — does it block movement only, or commands too, and
   does a paralyzed turn still spend food?
5. Write boots: MCP `local-mcp_write_memory`, `segment=2238, offset=219, data="01"`
   (`DS:D6[3]`, and the MCP wants **decimal** integers)
6. Let it try again → expect `SAVED BY MAGICAL BOOTS!`

Step 6 is the payoff: `asm/0E70_combat_paralyzed_legs.asm` carries both strings
and the boots gate at runtime `0x22FD` returns early when `DS:6D` is non-zero,
but **no traced edge joins the gate to the paralysis event**. This proves or kills
the claim behaviourally.

## Fresh findings from today, not yet in the engine

* **The staff was stolen.** `DS:D6[2]` (STAFF) went to 0 during the fight and a
  BRASS BUTTON appeared at `[11]`. That is the theft decrement at `0x0FE7`
  observed happening for real — the owner had suspected exactly this.
* **Combat text does not survive turn-boundary sampling.** 151 turns of a real
  fight, zero readable lines in the framebuffer, though memory proved a kill.
* **A kill was measured live**: gold +13, exp +4, monsters 5→4 — inside the
  `(rand&0x17)|1` and `(rand&3)+1` ranges the model predicts.
* **`Z` pauses the game on the status screen.** Writes take effect immediately
  but the screen is frozen, and while paused no turns occur.

## Engine state

Tier 1 shipped this session (`74286ac`): the walk loop wraps instead of refusing,
an accepted move spends 19 food, `0x00` blocks, and unknown tile ids pass while
recording themselves into `u2_overworld_unmeasured_tiles()` so a permissive
default announces itself. `make test` green at HEAD.

Still wrong, still open:

1. Mountain tile id unknown — `0x10` is **not** mountain (the player stood on it)
   and the owner states mountains never pass on foot. Do not guess again.
2. Idle auto-PASS (~7.6 s at `--Cycles 3000`, −10 food, also advances monsters)
   is not modelled. Needs a clock-backend decision so it does not perturb the
   CP2 baseline under the script clock.
3. The Q-save on-foot guard reasoning from `DS:13 >= 0x78` — now seen three times
   in the original, so the idiom is real; the engine's use is probably fine.
4. `docs/spice86-capture.md` still describes the monster arrays at stride `0x20`.
5. `engine/src/core/state.h` labels `DS:4D` as int; it is STAMINA. And `DS:4E`
   vs `DS:4F` (WIS vs CHA) is **not provable** from a character where both are 10
   — see findings § 11 before labelling either.
6. `asm/2423` declares a `2423..242C` range for a routine running to ~`0x2680`.
   A CP3 re-decode of that span is owed.

## Decisions taken (do not re-litigate)

* **Cross-sector attacks**: original mode reproduces the sector-edge targeting
  restriction including the whiff; enhanced mode fixes it. A cross-sector hit is
  therefore a *legitimate* CP2 differential mismatch.
* **Provenance**: add `# provenance:` lines only where we actually know, filled in
  as work proceeds — not a backfill of `static` everywhere.
* **asm renames**: `2DC1` is gold gain, `2DEE` is exp gain (done). Renaming corpus
  files is allowed when byte-proven.

## Standing rules that bit me today

* **Compute indices in code; never split hex by eye.** I miscounted `DS:D6` and
  built a whole false "green gem vs blue tassle" discrepancy on it. The owner was
  right and the table was right.
* **List the corpus before harvesting.** `asm/` already had
  `0FCD_combat_thief_steal`, `0E70/0EC2_combat_paralyzed_legs/arms`,
  `0F12_combat_magic_missile`, `0F48_combat_sleep_spell`. I went hunting in
  runtime data for things already named on disk.
* **Ask before capturing, and never block for minutes.** Long foreground
  captures swallow the owner's queued messages. Run detached, check between
  turns.
* **Python block-buffers stdout through a pipe** — use `-u` or the recorder looks
  dead while working.
