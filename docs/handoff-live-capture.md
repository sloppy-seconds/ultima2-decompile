# Handoff — 2026-10-21 evening (read this first after a compaction)

Supersedes the morning version. Everything is committed, pushed, and CI is green
on both workflows. Nothing is running.

## Read in this order

1. `AGENTS.md` — isolation, licensing, script rules. Hard law.
2. `docs/phase4-state.md` — resume notes, **Backlog**, Gate log, Deferred
   decisions. This is the live task state.
3. `docs/phase4-overnight-cp4b.md` — the T1–T9 queue plus the morning report and
   the **evening addendum**.
4. `docs/spice86-live-findings.md` — §7–§11 are today's evidence: combat, loot,
   provenance, the screen reader, and the editor offset tables.
5. `docs/handoff-live-capture.md` (this file) — index and running state.

## Running state

* **No emulator, no recorder, ports free.** Start one with
  `tools/spice86_start.sh --name LABEL --player tmp/<run>/player` — a fresh run
  dir has no character, so `--player` is required or you sit at the title.
* **Working tree clean, 0 ahead of `origin/main`, HEAD `1b715b3`.** 26 commits
  today.
* **CI green**: `asm-checksum` and `engine-tests` are now separate workflows with
  separate badges. `make test` = CP0..CP4 all PASS.
* **Pushing needs `GH_TOKEN`.** `git push` fails with a confusing
  `ksshaskpass died of signal 6` unless you source `.env` first:
  `set -a; . ./.env; set +a; git push`. `.env` is gitignored; do not commit it.
* `pgrep -f Spice86` matches its own shell and reports a phantom process. Check
  the ports instead.

## Overnight queue — where T1–T9 actually landed

| task | state |
| --- | --- |
| **T1** passability + crossing | **open, two named unknowns.** Wrap, `0x00` block and 19-per-move are implemented and cited to observed bytes. Still needed: the **mountain tile id** (one named sample from the owner — `0x10` is *not* mountain, the player stood on it) and the **`DS:15`/`DS:18` travel-mode argument**, which is what decides boat-on-water |
| **T2** time / food / auto-PASS | **closed.** Auto-PASS is a **poll count, not a clock** — no `INT 1Ah` exists in the corpus and the only `0x40:6C` read is the startup RNG seed. Threshold 256 is a documented placeholder, not proven |
| **T3, T4, T6, T7, T8** | done |
| **T5** creation tail | **closed.** Was a real fidelity bug: the original restarts the whole program (`call 0x0100`) after creation, which is why the owner saw the splash. `original` reproduces it; `enhanced` enters the world directly |
| **T9** blog + retro | **unblocked.** Today is unusually good material — see "what to write about" below |

**Next step, per the owner: work through the overnight task results.** That means
closing T1's two unknowns, then T9.

## What to write about (T9 raw material)

* A static reading that looked airtight and was disproven in ten seconds by a
  live CFG diff — and the retraction that followed.
* A cross-reference pass that found a real corpus bug (`2DC1`/`2DEE` transposed)
  **and** one of mine (a hex miscount invented a false discrepancy) in the same
  run.
* A tool that confidently lied: `CfgBlocks` is discovered, not executed, so it
  reported a Minax fight that never happened.
* Combat text that provably never survives turn-boundary sampling — 151 turns,
  zero readable frames, while memory proved a kill.
* Two owner corrections that each caught a real agent error (green gem; "we never
  fought Minax"). The argument for the owner as a verifier, not an audience.

## Harvests and tools

`captures/spice86/vga-test/` is the richest (965 blocks, buffed fight).
`play-test-live/` is the one most analysis ran against. `baseline-fight/` is a
diff baseline. The **CFG set-difference** between two harvests is the technique
that localised the whole combat path in seconds.

| tool | status |
| --- | --- |
| `tools/cfg_printed.py` | **fixed and validated** — messages a session printed, gated on `ExecutedInstructions` |
| `tools/vga_screen.py` | works — renders the text-mode screen from a memory dump |
| `tools/map_render.py` | works — 64×64 sector with player and monsters |
| `tools/xref_provenance.py` | works — docs↔asm cross-reference |
| `tools/poll_probe.py` | works — memory API does **250 req/s**, so the old 3 Hz rule is dead for reads |
| `tools/turn_recorder.py` | works, two cosmetic flaws (see Backlog) |
| `tools/vga_ring.py` | **UNTESTED** — never run against a live emulator |

## Proven today, do not re-derive

* Loot: every kill gives gold `(rand&0x17)|1` and exp `(rand&3)+1`, minimum 1
  each; the **item drop is gated on monster kind `0xFC`**.
* `A THIEF STOLE SOMETHING!` prints from the same block that decrements
  `DS:D6+i` — theft proven, not inferred.
* `--PARALIZED!` lives at runtime `0x2527`, **inside the passability routine**, so
  paralysis is a movement rejection — which is why the owner saw `--INVALID
  MOVE!` while paralyzed.
* Monster arrays are **stride 1**: `x=0x137+i`, `y=0x157+i`, `kind=0x197+i`,
  `tile=0x1B7+i`. `docs/spice86-capture.md` said `0x20`; corrected today.
* Items are `DS:D6+i` against the 16-entry table at file `0x501d`; weapons owned
  are `DS:76+i`; readied weapon `DS:61`; worn armour `DS:62` (8 entries, which is
  why the damage roll masks `&7`). Full table in findings §11.
* RNG seed = BIOS tick low byte at `0x40:6C`, read once at startup into
  `DS:23F..242` — hence deterministic monsters in a fresh emulator.
* `Z` pauses on the status screen; writes land instantly but the screen is frozen
  and no turns occur while paused.

## Standing rules that cost time today

These are now codified in **`AGENTS.md § 7 Evidence Discipline`** — read that
first; the list below is the short version of what happened.
* **Compute indices in code; never split hex by eye.** A miscount invented a false
  "green gem vs blue tassle" discrepancy.
* **List the asm corpus before harvesting runtime data.** Paralysis, theft and
  combat functions were already named on disk the whole time.
* **Ask before capturing, and never block for minutes.** Long foreground captures
  swallow the owner's queued messages. Run detached; check between turns.
* **Rebuild after swapping a generated header.** A guard looked tested but was a
  silent no-op because the binary still had the old header.
* **Python block-buffers stdout through a pipe** — use `-u` or a recorder looks
  dead while working.
* **Prove or pass.** Every claim above cites an address. Where a number is not
  proven, the code says so in the comment next to it.

## Open engine debt (small, specific)

1. Mountain tile id — blocked on one owner sample.
2. `asm/2423` declares `2423..242C` for a routine running to ~`0x2680`; a CP3
   re-decode is owed. The file now carries a WARNING so nobody repeats the error.
3. `DS:4E` vs `DS:4F` (WIS vs CHA) is **not provable** from a character where both
   are 10 — `state.h` labels them `cha`/`wis`; settle before shipping an editor
   label.
4. Monster advancement on the auto-PASS tick is unimplemented (no monsters in the
   engine yet) — marked in code, not faked.
