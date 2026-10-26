# Plan — cross-game replay: drive the engine with the original's recorded play, and diff state per turn

**Status: planned, not built.** Owner asked for this written up 2026-10-26 and called it the most
valuable thing on the list. To invoke: *"build the cross-game replay plan"*.

Owner framing, kept verbatim because it is the spec:

> what would be amazing is if we can somehow record the seed and turns of the original game so we
> could play them back on our game ... if we have telemetry on everything that happens, then we can
> easily tell where our game is different to the original

Two stated goals, both real:
1. **Cheaply replay a specific scenario** — for development and for regression evidence.
2. **Later, in enhanced mode, record a game for demos.**

---

## 1. The one-line idea

Record, from the original running under Spice86: the starting save, the RNG register, the key
sequence, and a snapshot of the DS working segment after every turn. Feed the same save, RNG state
and keys to our engine. Then diff the two DS segments field by field, turn by turn.

**The first turn where they disagree is a bug in our engine, with a reproduction attached.**

## 2. Why this works here and usually does not

A reimplementation normally has no shared observable with the original. Here there is one, and it is
large: `engine/src/core/state.h` is a byte-for-byte mirror of the original's DS working segment, with
`_Static_assert` on every offset. The same addresses mean the same things in both programs:

| field | DS offset | notes |
| --- | --- | --- |
| player position | `0x00`, `0x01` | `sector_x`, `sector_y` |
| sector digits | `0x49`, `0x4A` | two **decimal digits**, not an integer |
| hp | `0x51`, `0x52` | BCD pair, `unk_52` is the low byte |
| food | `0x53`, `0x54`, `0x55` | 3-byte BCD |
| gold, exp | `0x56..0x59` | BCD |
| stats | `0x4B..0x50` | str, agi, sta, cha, wis, int |
| items held | `0xD6..0xDF` | 16 slots |
| creature x / y / hp / type / kind / role | `0x137` / `0x157` / `0x177` / `0x197` / `0x1B7` / `0x1D7` | 32 slots each |
| creature wander vectors | `0x1F7`, `0x217` | role-3 step vectors, runtime state |
| RNG register | `0x23F..0x244` | 6-byte feedback shift register |
| paralysis counters | `0x26A..0x26D` | legs / arms / sleep / fourth |

Read the original's live values with the existing tool — no new plumbing:

```sh
python3 tools/spice86_type.py --peek 8be:23f:6 --mcp-port 20181   # RNG register
python3 tools/spice86_type.py --peek 8be:137:20 --mcp-port 20181  # creature x array
```

Under the hood that is `http://127.0.0.1:{http-port}/api/memory/{phys}/range/{n}` with the DS base
`0x8BE * 16 = 0x8BE0`. Sustains roughly 250 req/s (`tools/poll_probe.py`).

### The RNG is the load-bearing fact, and it is favourable

`engine/src/core/rng.h` records the decode of `asm/5217`/`asm/522B`/`asm/5236`:

> the state is the six bytes `DS:0x23F..0x244` and it is rewritten on every call: a feedback shift
> register, **not a clock sampler** ... the original's seed is the BIOS keyboard-flag byte at
> `0x40:6C`, which is normally zero at startup, so **the shipped game is itself effectively
> deterministic per boot**

So the original has no wall-clock input to its dice. Given the same starting state and the same
commands, it produces the same encounters, spawns and combat rolls. Our engine implements the same
carry chain byte for byte. **Determinism on both sides is the precondition for the whole idea, and it
holds.**

## 3. What already exists — do not rebuild it

| capability | where | state |
| --- | --- | --- |
| deterministic engine replay from (seed, key script) | `engine/src/core/replay.c`, `--replay-report F` | **works**, and CP2's committed evidence reproducing is the proof |
| verify a report against a fresh run | `engine/tools/playlog.py verify` | **works** |
| per-turn engine frame + state JSON | `--debug-path DIR --debug-limit 0` | **works**; gained creature table and truthful position in this session |
| inject keys into the original, headless | `tools/spice86_type.py --keys` | **works** |
| read original memory live | `tools/spice86_type.py --peek` | **works** |
| prove what executed in the original | `ExecutedInstructions` in `spice86dumpExecutionFlow.json`, `tools/cfg_printed.py` | **works** |
| screenshot the original, headless | `tools/spice86_screenshot.py` | **works** |

What does **not** exist: a recorder that pairs the original's turns with its state, a way to resume
the engine from an arbitrary RNG register, and the differ.

## 4. The five gaps, with targets

### 4.1 Resume the engine from a captured RNG register — blocker

`u2_rng_seed(u2_ctx *ctx, uint8_t f)` only reproduces `asm/0100`'s startup form: six copies of one
byte, then `incb 0x23F` and `incb 0x240`. That cannot express a mid-game register, so a checkpoint at
turn 200 cannot be resumed.

Add, in `engine/src/core/rng.c` / `rng.h`:

```c
/* Load a captured register verbatim. Mirrors what a checkpoint restore must do: the original's
 * state is six arbitrary bytes, and asm/0100's one-byte form cannot express them. */
void u2_rng_load(u2_ctx *ctx, const uint8_t state[6]);
```

and a CLI flag `--rng-state HEX6` in `engine/src/main.c`, next to the existing `--seed` handling
(`main.c:243`). **Control:** seed with `u2_rng_seed(ctx, 0)`, read the six bytes, `u2_rng_load` them
into a second context, and assert the next 50 rolls match; then corrupt one byte and assert they do
not.

### 4.2 Turn detection on the original — the other blocker

There is no turn counter in the original. Two approaches, and the plan is to build the cheap one first
and upgrade if it proves flaky:

- **Poll-diff (start here).** Read the creature block plus player position at ~15 Hz; a change is a
  turn boundary. Cheap, no emulator hooks. **Known weakness, and it is the failure mode this project
  has been bitten by repeatedly: a change-triggered detector's silence is not evidence of absence.**
  A turn in which nothing moved — a refused step, a `PASS` with no spawns — produces no change and
  would be missed. Mitigation: also count consumed keys from the keyboard ring, and treat a consumed
  key as a turn even when nothing moved.
- **Trace-detected (upgrade path).** The post-command tail at `asm/0A38` runs exactly once per
  completed command, so a breakpoint there is an exact turn signal. `tools/bp_read.py` already stops
  the CPU at an address and dumps memory there, so this is close to built. Use it if poll-diff
  mis-aligns.

**Acceptance test for this component:** drive N known commands into the original and assert the
recorder reports exactly N turns, including commands that change nothing (`PASS` in a corner with no
spawns). That is the control that catches the silent-miss failure mode.

### 4.3 Key capture from live play

When the agent injects via MCP the key is known by construction. When the owner plays in noVNC it must
be read. `tools/spice86_type.py` already exposes the keyboard ring head/tail; a recorder that drains
the ring and decodes each consumed key is the missing piece.

Also needed: a **token vocabulary map**. The engine's script format uses tokens like `WAIT`, `ESC`,
`P`, `0x0d`; the original sees PC scancodes. The map must be explicit and tested, because a silent
mismatch here produces a replay that diverges for a boring reason and looks like a deep bug.

### 4.4 Capture the starting save, not just the seed

`replay.c` hardcodes `"save_dir": "fresh"`, which is fine for CP2's from-boot replay and useless for a
mid-game checkpoint. A checkpoint must carry: the `PLAYER` file (base64 or hex), the sector digits,
the RNG register, the roll count, and the turn index.

### 4.5 The differ

New tool, `tools/replay_diff.py`. Inputs: a recorded original session, and an engine run produced
from it. Output: the first N divergences, each as

```
turn 37  slot 31 (type 0xFC, role 3)
  original: x=35 y=59
  engine:   x=34 y=58
```

plus a summary line per field so a run reports *"creature positions diverge from turn 12; hp agrees
throughout"* rather than a wall of diffs.

## 5. The digest-scope decision is a prerequisite, not a side quest

`replay.c` hashes `u2_state_json()` into CP2's committed evidence:

```c
u2_state_json(ctx, state, (int)sizeof state);
sha256_hex(state, strlen(state), r->state_sha[i]);
```

So the debug serializer and the behavioural evidence digest are the same function. Adding a
diagnostic field invalidates every recorded replay — which happened during this session when the
creature table was added, and is why CP2 is currently red pending an owner decision.

**For this plan, the digest must be a defined, versioned scope** (screen text plus an explicit list of
state fields, `digest_version: 1`). Otherwise every telemetry addition rots existing recordings, and
a demo feature built on recordings cannot survive an engine release. This is the same decision as
option (c) in `docs/phase4-state.md`; it should be settled as part of this work, with the reason
logged in the CP2 gate log.

## 6. Determinism hazards — be honest about what is not proven

| hazard | status |
| --- | --- |
| RNG clock dependence | **ruled out** — FSR seeded from `0x40:6C`, see `rng.h` |
| engine headless determinism | **proven** — CP2 evidence reproduces |
| engine **SDL** determinism | **NOT proven.** `u2_clock_posix` and the F7/F8 speed rescale are in play. Do not claim an SDL session replays bit-exact until something demonstrates it. Build this headless first. |
| turn alignment | unknown until 4.2 is built; the acceptance test in 4.2 is what settles it |
| deliberately unmodelled behaviour | **needs an allowlist.** Dungeons are parked per AGENTS § 3, so a dungeon session will diverge legitimately. The differ must carry a list of *known, intentional* divergences with a reason and a doc link, or it will cry wolf and get ignored. |
| the original's own nondeterminism | unmeasured. If two identical original runs ever differ, the premise weakens — **test this first, it is one afternoon and it de-risks everything else.** |

**Do step 0 before anything else:** record the same scripted original session twice and diff the two
recordings. If they are not identical, stop and report — the whole plan rests on it.

## 7. Build order

Each phase is independently useful and has an acceptance test that can fail.

| # | deliverable | acceptance |
| --- | --- | --- |
| **0** | **Determinism probe.** Record one scripted original session twice; diff. | identical, or the plan is revised and this doc says so |
| **1** | Original-side recorder: per turn, key + DS snapshot + frame. | N commands in, exactly N turns out, including no-op turns |
| **2** | `u2_rng_load` + `--rng-state`. | load-and-match control in § 4.1 |
| **3** | Checkpoint format: save + sector + RNG + turn index, and engine resume-from-checkpoint. | resume at turn 200 and match a from-boot run's turn 200 state |
| **4** | `tools/replay_diff.py` with the allowlist. | **mutation control:** break something known in the engine (e.g. revert the contact gate) and confirm the differ names it, at the right turn |
| **5** | Wire it as a gate: a small committed corpus of original sessions that must replay with zero unexplained diffs. | the gate goes red on a deliberate engine regression |
| **6** | Demo path (enhanced mode, later): replay a key script and capture frames locally. | see § 8 policy |

Phase 4's mutation control is the one that matters most. A differ that reports "no differences"
because it is comparing nothing is worse than no differ, and this project has now been burned three
times by a checker that could not fail.

## 8. Policy constraints — read before building the demo path

- **The report holds digests and numbers, never game text.** That is `replay.h`'s stated content
  policy and it is what makes the artefact safe to commit. Keep it.
- **A recorded demo is game content.** Frames of Ultima II are not ours to redistribute, same rule
  that keeps `original/` and `references/` out of git. So "record a demo" must ship as a **key script
  plus a checkpoint**, replayed by someone who owns their own copy — not as video or image frames.
  This is a feature, not a limitation: scripts are tiny, text, and diffable.
- **`captures/` is gitignored.** Recorded sessions belong there or in a gitignored corpus; only the
  differ, the format spec, and small synthetic fixtures get committed.

## 9. What this unlocks, concretely

Every bug the owner found this session by eye would have been a diff line instead:

| bug | how it would have appeared |
| --- | --- |
| town thief steals when the original's does not | `turn 34: engine stole an item; original did not` |
| creature parks diagonally instead of moving | `turn 12: slot 31 original moved, engine stayed` |
| creature stacking | `turn 8: two creatures at the same cell in engine, one in original` |
| shallow-water wall | `turn 3: original player at (x,y), engine refused` |
| the stale stamp, still unfixed | `turn N: engine grid cell (x,y) holds 0xFC with no creature there` |

And it converts the owner's role from *test suite* to *test selector*: instead of playing and hoping
to notice something, play once, and let the differ say where to look.

Adjacent wins: G38's aggro question becomes a scripted diff; E6's diagonal asymmetry becomes
measurable rather than inferred; and the `--sdl` cannot-take-`--script` gap stops mattering, because
replay is headless by design.

## 10. Open questions to settle during phase 0/1

1. Does the original ever read the clock for gameplay (not just the speed rescale)? `asm/06AC` is the
   tick wait and is implicated in the speed model; if it feeds anything else, determinism is narrower
   than claimed.
2. Is the keyboard ring drainable without losing keys, at the rate the recorder polls?
3. What is the minimal DS field set worth diffing on day one? Proposal: position, sector, hp, food,
   gold, exp, items, all six creature arrays, the four paralysis counters, the two wander vectors,
   and the RNG register. That is ~250 bytes and covers everything found so far.
4. How long is a useful recorded session before `U2_REPLAY_MAX_STEPS 4096` bites?

## 11. Related open items, so nothing gets lost

- **The stale stamp** (owner-found, still unfixed): a creature's sprite persists on the cell it
  vacated. My first headless attempt to check it validated my own model instead of the rendered
  screen, so it proved nothing. This plan's phase 4 is the tool that would actually catch it.
- **CP2 digest scope** — § 5, prerequisite.
- **G38** — the aggro precondition for the thief.
- **E6** — the diagonal melee asymmetry, parked for enhanced mode.
