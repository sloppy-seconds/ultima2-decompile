# Needs gameplay — capture worklist

**Status: live document.** Opened 2026-10-22. Purpose: a single tick-off list of
everything still blocked on someone playing the game, with an honest per-item
verdict on **whether the agent can do it unattended or whether it needs the owner**.

The reason this file exists is that "needs gameplay" had quietly become a synonym
for "needs the owner", and it is mostly neither. Most of these need a *driven*
session, not a *human* one. The distinction decides whether an item is blocked on
a diary appointment or on an afternoon of scripting.

> **Do not duplicate specs here.** Register dumps, breakpoints and success criteria
> live in `docs/passability-findings.md § Open` and the backlog items in
> `docs/phase4-state.md`. This file only adds the who/can-I-do dimension and the
> tick state. Two hand-maintained copies always drift (`AGENTS.md` § 3).

---

## Tick convention

| mark | meaning |
| --- | --- |
| `[ ]` | open, nothing captured |
| `[~]` | partial — some readings landed, a named gap remains |
| `[x]` | closed by a named capture under `captures/spice86/` |
| `[!]` | blocked on tooling, not on gameplay — fix the tool first |
| `[H]` | genuinely needs the owner; agent attempts would produce junk |

**An item is only `[x]` if a capture directory is named.** "I think it works this
way" is not a capture. Closed items move to § Closed with the harvest name and the
commit that recorded the finding.

---

## Standing hazards — read before driving anything

These are all paid-for. Every one of them produced a wrong answer at some point.

1. **A send is not a move.** `xdotool` returning 0 means dispatched, not landed.
   The first passability sweep concluded "impassable" from positions that never
   changed because keystrokes were lost during a read-pause — nine capture
   directories (`sweep00`..`sweep28`) of confidently wrong data, invalidated only
   after F13 noticed every measured tile was a shop/sign letter. **Never** infer
   terrain from a non-move without proving the key arrived. See item **G0**.
2. **HTTP memory reads pause the CPU.** Reads return correct data, and the
   emulator reports `isPaused: false` shortly after, but a read is not a free peek.
   Sequence deliberately when timing matters.
3. **The multi-key timing window is unmeasured on this host.** `~2 ms to ~1500 ms`
   is marked `sibling:hypothesis`; the 30 ms default "must be re-measured here
   before it is trusted".
4. **Never send a confirm key blind.** `Y` is the YELL command and takes a text
   argument; a stray `Y` opens a prompt and every later key is eaten as yell text.
5. **Re-read the grid every sample.** A probe that caches the 4 KB grid at startup
   produces stale tile labels, because the grid is a live object store (T5/T6).
   This fabricated a vehicle depot that did not exist.
6. **Radix.** Monster types in the findings are **decimal**. A `%02d` format against
   hex-named PNGs produced a committed-and-then-corrected wrong plane tile.
7. **Never run in place.** The game rewrites its own `player` file. Always
   `tools/spice86_start.sh`, which copies the pristine pack into a fresh timestamped
   dir under `tmp/`.
8. **Ask before capturing, and never block for minutes.** Run detached and poll.

---

## G0 — prerequisite: harden the probe `[!]`

**Who: agent. Confidence: high. Blocks: G2, G4, G5, G6.**

> **Finding 2026-10-22, measured — the obvious way to do G0 does not work, and two
> of the three candidate signals are already known-bad.** This section was written
> assuming a reject could be counted from the execution dump. It cannot.

**The reject site is real.** `asm/0A02_invalid_move_msg` prints `--INVALID MOVE!`,
and `tools/cfg_printed.py` confirms it genuinely printed in `mountain-walk`,
`play-test-live`, `create-test-live` and `sweep00`. So the address is right.

**But `ExecutedInstructions` is a deduplicated address set, not a trace.** In
`mountain-walk`, `play-test-live` and `create-test-live` the offset `0A02` appears
**exactly once each**, while the dumps hold 1,564–2,477 entries with only ~6
repeats total (offsets 0, 4, 12, 16 — not real re-executions). So it can answer
"did a reject ever happen in this session" and **cannot** answer "how many, and
between which steps". Per-step classification from existing dumps is impossible,
which is exactly what a passability probe needs.

**The second candidate is explicitly forbidden.** `DS:20` was documented as an
invalid-move counter, and `engine/src/core/state.h` now says: *"DISPUTED: docs
called this an invalid-move counter, but the harvest shows it decremented in the
walk loop and overwritten at runtime 0x2BC7. Treat as scratch; do not use as a
reject signal."* `tools/turn_recorder.py` was nevertheless labelling turns
`reject` from `DS:20` — it has been corrected to emit `stalled` (no move, no food
spent, **cause unresolved**) and to name the byte `scratch_20`. Any earlier
`rejected: true` in an existing `index.jsonl` is therefore not evidence of a
reject.

**Viable live signals:**

1. **GDB `breakCsIp` trap on the reject site — BUILT AND MECHANISM-VALIDATED
   2026-10-22.** `tools/reject_trap.py`. Proven to fire: arming on the address the
   CPU was already executing produced a stop, with no gameplay involved. It speaks
   the remote protocol directly rather than driving `gdb(1)`, because gdb with a
   piped stdin emits nothing at all and `gdb -batch` cannot arm-and-wait (the
   target is running on attach, so `continue` is refused).
2. **Frame-diff on the message region** via `tools/vga_ring.py`. Still available as
   a fallback; heavier, and it must separate the reject message from other text
   changing in the same region.

**One trap for whoever uses this, and it is the dangerous kind:**
`monitor breakCsIp` parses its arguments as **hex**, while `/api/status` reports
**decimal**. Passing the API's decimal values silently arms a breakpoint on an
address that can never execute, and every later "no reject observed" then means
nothing. `tools/reject_trap.py` converts in one asserted place
(`cs_ip_from_status`) for exactly that reason.

**What still keeps G0 open:** the trap is proven as a mechanism, not yet against a
real rejected step. Closing G0 needs (a) driving a run into the world, (b) one
step into a known-blocked tile, (c) confirming the trap fires for it and not for a
successful step, and (d) wiring that into the probe with the per-step outcome
record and the tile-class histogram. The remaining requirements are unchanged:

* after each step require **one of**: position changed, or a counted reject; if
  neither, treat it as a **dropped key** and retry — never as terrain;
* record which outcome occurred, per step, in the harvest;
* assert the sample actually contains the tile class being claimed. The sweep
  measured fifteen tiles and all fifteen were letters `B`–`P`; a per-run histogram
  of tile classes would have caught that instantly.

**Staging is already solved:** `tools/u2_mkprobe.py` generates a probe sector that
puts every terrain byte next to walkable ground, and `spice86_start.sh --seed-map`
installs it pre-launch. A saved character (`AIRTEST`, seen in `tmp/*/player`) can be
seeded with `--player`, so character creation is not an obstacle either.

---

## The items

| id | item | who | confidence | blocks |
| --- | --- | --- | --- | --- |
| G1 | art index: `(map_byte>>1)&0xFE` vs `map_byte>>2` | agent | **high** | renderer correctness |
| G2 | does a blocked step cost 19 food | agent | **high** | turn economy |
| G3 | attribute the indirect writers of `DS:2CB`/`DS:2DE` | agent | **med-high** | C5, F3 |
| G4 | what sets mode byte `0x2e`; step onto a force field | agent | **medium** | C5, T8 |
| G5 | which tile is the mountain (rejection test) | agent + 30 s owner look | **medium** | CP4/CP6 passability |
| G6 | single-byte counter underflow: is it reachable | agent | **medium** | census claim |
| G7 | stat cap 99 wrap, observed rather than inferred | agent | **medium** | B1/B2 confidence |
| G8 | identify `DS:96+i` — owned-armour counts or not | agent | **high** | census candidate |
| G9 | dungeon light timer reaching 0 — does the screen darken | agent | **medium** | CP7 |
| G10 | dungeon geometry + wireframe renderer decode | **owner** | **low** | CP7, T9 |
| G11 | `A`–`Z` dungeon byte decode | **owner** | **low** | CP7 |
| G12 | force-field animated render (white/blue/purple) source | **owner** | **low** | C5 cosmetics |
| G13 | reproduce `mapx30 (0,0)=0x50` | agent | **low value** | nothing |

G1–G5 are `docs/passability-findings.md § Open` questions 1–5; the technical spec
lives there. What follows is only the driving plan and the honest verdict.

### G1 — art index `[ ]`
**Action:** enter any sector, take three ordinary steps, dump `DS:272` (256 B) and
the sector grid each time. Compare against both candidate transforms.
**Why the agent can do it:** pure memory read; no navigation judgement, no visual
identification. Ordinary walking is already scriptable.
**Needs owner:** no.

### G2 — food cost of a blocked step `[ ]`
**Action:** stand adjacent to **water** (`0x00`, already proven blocked) and step
into it; read `DS:53..55` before and after.
**Why the agent can do it:** water is a known blocked tile, so this does **not**
depend on settling the mountain first — that dependency was assumed and is wrong.
**Needs owner:** no.

### G3 — who writes `DS:2CB`/`DS:2DE` `[ ]`
**Action:** capture both bytes before and after each of: sector entry, boundary
crossing, boarding, alighting, stepping onto a field. Boarding is stageable —
`mapx03` has the four-vehicle depot at (36–39, 24), so `--seed-map`/`--player` can
put the character next to it.
**Why the agent can do it:** all reads; the events are reachable by scripted
movement. **Risk:** if the writer is only triggered by an event we have not
thought to stage, we get "no change observed", which is weaker than a real answer.
**Needs owner:** no, but a negative result should be treated as inconclusive.

### G4 — mode byte `0x2e` `[ ]`
**Action:** one ordinary step and one step onto a force field, dumping
`AL, DS:13, DS:15, DS:18, DS:29, DS:2CB, DS:2DE` plus the destination tile.
**Why medium:** a force field has to be *reached*. One is on record at fight turn
2909 in sector 03, so the location is known — but navigating to it reliably is the
same hard problem as G0.
**Needs owner:** no, provided G0 lands first.

### G5 — the mountain `[ ]`
**Action:** stage a map with a candidate tile adjacent to the player, attempt the
step, record whether the ladder rejects.
**Why not fully agent:** the *rejection* is measurable automatically; the
identification — "is the thing being rejected what a player calls a mountain" — is
a visual judgement. The owner's earlier answer (art `0x04`, diamond lattice) is
already on record, so this may be a formality rather than a session.
**Needs owner:** a 30-second look at one screenshot, not a session.

### G6 — single-byte underflow reachability `[ ]`
**Action:** get `keys`, `torches` or `tools` to zero deliberately, then trigger the
decrement anyway and read the byte. The census proved the subtract sites have **no
borrow test**, so the bytes predict `0 − 1 → 99`; nothing has ever observed it.
**Why medium:** reaching zero may take a long scripted grind, and an upstream
"do you have one?" guard may make it unreachable — which is itself the answer.
**Needs owner:** no. **Value:** converts the census's most speculative claim from
inferred to observed, or kills it.

### G7 — stat cap 99 wrap `[ ]`
**Action:** raise one stat to 99 (the OFFER-GOLD path in `asm/3C2E` and the cleric
raise in `asm/1869` both add without a clamp), then raise it once more and read.
**Why medium:** needs gold and a repeatable raise path.
**Needs owner:** no. **Value:** this is the owner's recalled behaviour; observing
it would be the cleanest possible confirmation of the whole BCD-wrap line of work.

### G8 — identify `DS:96+i` `[ ]`
**Action:** buy an armour piece, read `DS:96+i` before and after; then have a thief
steal one and read again.
**Why high:** three asm sites already do BCD arithmetic on `0x96(%di)` beside
`0x76(%di)`; one purchase confirms or kills the owned-armour hypothesis in minutes.
**Needs owner:** no. This is the cheapest un-closed item on the list.

### G9 — dungeon light timer `[ ]`
**Action:** sit in a dungeon until the light counter reaches 0 and capture the
frame. `dungeon_capture.py` already does change-triggered frame recording.
**Needs owner:** no, though getting into a dungeon and surviving is the fiddly part.

### G10 — dungeon geometry and the wireframe renderer `[H]`
The largest unexplained surface. Dungeons are first-person 3D; the tile renderer
does not cover them. `mapx35` uses only 7 distinct bytes, all multiples of `0x10`,
and only 7 of 16 possible combinations occur — a flag or small-enum encoding, not
an art index. Leads are in the backlog item.
**Why not the agent:** navigating a first-person wireframe maze to reach specific
geometry is exactly the skill a scripted probe lacks, and the renderer is not in
the decoded tree at all (no pixel-plot path anywhere in `asm/`).
**Also owns:** T9 — the `original/monsters` stroke table at `DS:2900` has no
consumer until this is decoded.
**Needs owner:** yes.

### G11 — `A`–`Z` dungeon byte decode `[H]`
Biggest prize, same blocker as G10. Leads recorded in the backlog; do not burn an
unattended night on it.
**Needs owner:** yes.

### G12 — force-field animated render `[H]`
What drives the white/blue/purple animation is not in `asm/24B5` (it only flashes
and sounds). Recognising an animation needs eyes on a screen.
**Needs owner:** yes — a short video or a few timed screenshots, not a session.

### G13 — the `mapx30 (0,0)=0x50` rocket `[ ]` *(low value)*
One cell, one capture, four dead ends already (see findings § 13). Only worth
re-checking opportunistically if a sector-30 session happens for another reason.
**Do not schedule anything for this.**

---

## Session planning — group by setup, not by question

One launch can close several items. Cheapest order:

1. **Sector 20, fresh character** → G1, G2, G5, G8. No special staging.
2. **`mapx03` vehicle depot staging** → G3, G4.
3. **Grind session (gold, zeroed counters)** → G6, G7.
4. **Dungeon 35** → G9, and the first probes for G10/G11 with the owner driving.

G0 must land before any of the rejection-based items (G2, G4, G5, G6) produce
results worth recording.

---

## Maintenance

When a finding anywhere in the project turns out to be **blocked on gameplay** —
including one that says "inferred from ISA semantics, never observed" — the same
commit that records the finding adds an item here with a who/confidence verdict.
When a session closes an item, tick it, name the harvest directory, and move the
detail to § Closed.

## Closed

*Nothing yet.* Opened 2026-10-22 with thirteen items.
