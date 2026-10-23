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
real rejected step.

**CLOSED for the trap itself on 2026-10-23 — it has now fired on a real rejected step.**
`tools/bp_read.py` armed `breakCsIp 17D 0A02` on a live headless run (sector 31, player
seeded to (50,21), a direction with a wall in it), then a movement key was sent. Result:
`STOP at 017D:0A02 (paused=True)` with `DS:00/01` still `(50,21)` — the step was rejected
and the reject print site was caught executing, not inferred. The harvest corroborates it:
`captures/spice86/g0-reject/` has `0A02` in `ExecutedInstructions` and `17B7`/`20AB`
absent, which is the right shape for a run that walked into a wall and did nothing else.

Two things this does **not** close. (a) The negative half — confirming the trap stays quiet
on a *successful* step — was not run; the tool was pointed at a blocked direction only. (b)
Wiring the per-step outcome into `tools/turn_recorder.py` and the probe `[!]` is still to
do, and that is the part the passability sweep actually needs. Requirements unchanged:

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
| G1 | ~~art index: `(map_byte>>1)&0xFE` vs `map_byte>>2`~~ **CLOSED 2026-10-23 by `captures/spice86/art-index/`.** The transform was never the live question -- `view.h`'s two-step composes to `>>2` for all 256 byte values. The live question was **which field**, and the answer is **the sector grid cell, not the monster `type`**: on the only disagreeing sample in the corpus (sector 00 slot 6, type `0x34`, cell `0x38`) the drawn tile matches art `0x0E` = `cell>>2` at **256/256 pixels** and art `0x0D` = `type>>2` at 171/256. Geometry independently confirmed on 18 further slots at 256/256. Full write-up: `docs/art-index.md` | agent | **done** | renderer correctness |
| G2 | does a blocked step cost 19 food | agent | **high** | turn economy |
| G3 | attribute the indirect writers of `DS:2CB`/`DS:2DE` | agent | **med-high** | C5, F3 |
| G4 | what sets mode byte `0x2e`; step onto a force field | agent | **medium** | C5, T8 |
| G5 | which tile is the mountain (rejection test) | agent + 30 s owner look | **medium** | CP4/CP6 passability |
| G6 | single-byte counter underflow: is it reachable | agent | **medium** | census claim |
| G7 | stat cap 99 wrap, observed rather than inferred | agent | **medium** | B1/B2 confidence |
| G8 | ~~identify `DS:96+i`~~ **CLOSED 2026-10-23 by `captures/spice86/armour-buy/`.** It **is** the owned-armour count table, and the index is the **menu number, 1-based**: buying CLOTH (item 1) took `DS:97` from `00` to `01` and gold from 9999 to 9987, exactly the quoted `0012`. `DS:96` itself is unused, so the six armour types live at `DS:97..9C` -- do not zero-base it. The shop was reached by the rule in `docs/commerce.md` § 5 (an NPC standing at the sign; sector 32's Merchant at (38,3) above `ARMOURY`), enumerated by `tools/shop_access.py`. Two caveats recorded in § 4b: the shop closes after one purchase so a second type was not observed, and `maxout` leaves the table empty while `DS:62` says POWER is worn | agent | **done** | census candidate, now proven |
| G9 | dungeon light timer reaching 0 — does the screen darken | agent | **medium** | CP7 |
| G10 | dungeon geometry + wireframe renderer decode | **owner** | **low** | CP7, T9 |
| G11 | `A`–`Z` dungeon byte decode | **owner** | **low** | CP7 |
| G12 | force-field animated render (white/blue/purple) source | **owner** | **low** | C5 cosmetics |
| G13 | reproduce `mapx30 (0,0)=0x50` | agent | **low value** | nothing |
| G14 | who writes `%di` before `0x3546` — settles five time periods against ten sector tens-groups | agent | **med-high** | time-period display, CP6 |
| G15 | locate towns -- **largely answered, and not the way the ticket assumed.** There is no separate site-kind byte: `DS:4A` is the ones digit of the sector number, and that digit *is* the site kind. All 15 `tlkx` dialogue files land in ones-digit 1/2/3 and none in 0/4/5, so the town sectors are known from the shipped file set alone. **What remains:** which *named* town occupies which sector, and what each shop stocks. See `docs/sector-rulesets.md` § 1 | agent | **medium** | shops, signs, CP6 |
| G16 | `0xC0` event tile: step on one and record what the event actually is (a probe threw the player y=20→57; 1311 occurrences, exactly 262 in each of `mapx25/35/45`) | agent | **medium** | tile art, CP4/CP6 |
| G17 | ~~find the HP computation~~ **done for the overworld**: the field is `[DI+0x177]` (proven by `asm/2E3D_combat_attack_flow.asm`, which subtracts damage from it and zeroes the record on borrow) and nine spawn arms store per-kind immediates that match the third-party HP **9 for 9** (`tools/monster_hp_dispatch.py`, exits non-zero on a disagreement). **Also closed:** `asm/147F_dungeon_monster_spawn.asm` is confirmed the dungeon spawner (only caller `asm/1151_dungeon_darkness`) and computes HP from the sprite, and Guard's 500 is **refuted by field width** -- HP is one byte, so the codex's 255 stands. **What is left:** the townsfolk. They have no arm at all (measured negative -- no `mov $0x60/0x64/0x68/0x6C/0xF4,%al` anywhere), and the static search is now **exhausted**: every write site of `[DI+0x177]` is enumerated (nine spawn immediates, the dungeon computation, two subtract paths, the kill clear) and none can be a town NPC spawner. The `asm/3611` lead raised on the site-kind test was retracted -- it applies damage, it does not create NPCs. So this one needs a live read of `[DI+0x177]` for a Guard or Merchant in a town, which closes the question either way. The dungeon formula is read but not validated against a live monster | agent | **high** | Merchant/Cleric/Jester/King stats; CP5 combat spec | | agent | **high** | Merchant/Cleric/Jester/King stats; CP5 combat spec |
| G18 | settle **which monster record field drives the drawn art**. The `0x40` contradiction is **closed** -- the thief is type `0xFC` with HP 32, so `0x40` is the empty sentinel and the earlier "thief is monster type 0x40" in `docs/spice86-live-findings.md` is wrong. But a second claim from the same day is now **retracted**: `[DI+0x1B7]` is NOT a sprite. A live read of all 32 slots shows it holds `0x08`/`0x0C` -- a small kind index, which is exactly what the spawn guards compare against (`cmp $0x8,%al`). The arms write `[DI+0x197]` and the map cell, not `0x1B7`. So the "8 agreements across two fields" was really **4 agreements from one field relabelled**, and the type->art transform rests on the four special-casting types only. What remains: confirm `>>2` on ordinary wandering spawns with a non-maxed character | agent | **medium** | naming monster types, CP5 |
| G20 | **~~enter an `X4` sector (24, 34 or 44)~~ CLOSED 2026-10-23 by `captures/spice86/tower-34` and `tower-34-open`.** Sector 34 is **dungeon-shaped**, not a third ruleset: map bytes all multiples of `0x10`, `IT'S DARK!` on entry, `I` = IGNITE TORCH with the `DS:26` light counter, arrows = `TURN LEFT`/`TURN RIGHT`, monsters use the `asm/147F` encoding and formula (40/40 slots). So the split is `{4,5}` vs `{0,1,2,3}`, not dungeon vs everything else. **Two things did not carry over:** `A` is ATTACK not ADVANCE (so the mode-aware dispatch keys off something narrower than inside/outside -- `DS:29` is 0x00 here vs 0x92 in the dungeon), and the first-person viewport renders a bordered but empty rectangle even with the torch lit. Full table: `docs/sector-rulesets.md` § 1b | agent | **done** | towers, CP5/CP6, the ruleset table |
| G21 | **what each shop stocks, and at what price -- ANSWERED, and the answer is "no table exists".** Every catalogue is an inline string printed via the string-output routine; the four `shop_header_*` routines are 13-byte label printers that fall through. Weapons 8 items, armour 6 (CLOTH/LEATHER/CHAIN/PLATE/REFLECT/POWER), plus horse dealer, clue seller, tavern and cleric offering. Prices are computed inline -- the tavern sets a 16-bit 5 at `DS:27/28`, the clue seller multiplies a typed amount by 100. The two 6-spell lists are **the cleric shrine and the wizard shop**, each class-gated (`asm/184C`, `asm/19BA`), **not** town variation -- no per-town catalogue difference is demonstrated anywhere. Full write-up with grades and limits: `docs/commerce.md`. Street NPCs (merchant/thief/guard) do not transact at all | agent | **high** | shops, economy, CP6 |
| G22 | **CLOSED 2026-10-23 -- owner ruled, merges executed.** The premise in this row was itself wrong: the region past `19D7`'s end is not shop code but three shared helpers, and `19D7..2027` was left alone because its handlers end in tail jumps, so any fall-through boundary there is a judgement and not a fact the bytes assert. What was done instead: `2028..2051` (7 fragments -> `read_decimal_digit`), `2052..20AA` (4 -> `gold_spend_price`), `20AB..2121` (5 -> `bcd_price_from_stats`). 16 files -> 3, body content proven conserved, `assemble_clean.sh` byte-match unchanged. Rationale, measurements and the doubt: `docs/g22-split-proposal.md` | done | -- | commerce, function-map accuracy |
| G23 | **is the vendor food price stat-derived? -- the static half is now answered and it did NOT come out clean.** `asm/20AB_bcd_price_from_stats.asm` seeds `DS:27/28` and `DS:29/2A` to `0004`, takes the loop count as the **bit length** of `[DS:50]+[DS:4E]` -- **not** the `popcount` this row originally said, that was a misreading -- and walks a Fibonacci-style BCD sequence seeded 4,4 into `DS:27/28`. The printer was decoded the same day (asm/17B7 -> 51A5/51A9/51AE -> 53B5/53C5, itself two more fragment-splits of the G22 kind): it emits **DS:27 as two decimal digits then DS:28 as two**, so the observed `0200` means `DS:27=0x02 DS:28=0x00`. The model for the tavern call (`AL=3`, maxed character) leaves `0020`. **And 200 is not a value this loop can produce at any loop count** -- the reachable set is 4, 8, 12, 20, 32, 52, 84, 136, 220, 356, 576, 932, ... So either the food quote does not consume this routine's result, or the loop is still misread, or the printed string was not `0200`. **A live attempt on 2026-10-23 first failed to reach the quote, but the reason was wrong the first time it was written and is now corrected: it was never a timing problem.** Headless transactions are proven working -- sector 32, `T,Up` at `--delay 0.02` opened `THE ARMOUR SHOPPE`, `1` quoted `FOR YOU ONLY 0012`, `y` completed it, gold `9999→9987`, `DS:97` `00→01`, no human involved. The sector-31 food vendor instead returned `CMD: TRANSACT-<dir>` then `FUNNY, NO RESPONSE!` from every reachable tile, and that message is now decoded (`docs/commerce.md` § 5b): it means **the ray did not land on a `0x68` Merchant**, not that the key was lost. `monx31` puts a Merchant at (51,15) but that is where creatures *start*; live ones move. **Sweep run 2026-10-23: NEGATIVE.** Live creature arrays (`DS:137/157/197`) confirmed five `0x68` Merchants in sector 31 including one at (51,15) unmoved from spawn, and one at (55,17) that had moved -- so the lookup works. But from every maze-reachable tile beside them, all four directions, retries at three delays, **no price breakpoint fired**; the band gave `CMD: TRANSACT-NORTH` then `FUNNY, NO RESPONSE!` (delivered, refused). The ray rule is not "stand two cells away" and the armoury geometry does not generalise. **Ray decoded 2026-10-23 (static, as planned).** `asm/50B3_map_tile_ptr` returns the live grid cell at `DS:23/24`; `asm/4085` steps that cursor by `DS:19/1A`; the cell must be `0x68` or `0x7C` or the game says `FUNNY, NO RESPONSE!`; on a match `asm/40A3` jumps to runtime `1590`, the vendor dispatcher (corroborated: `1590/1591/1594/1596` executed in `food-buy`). **`0x68` is the merchant marker and it is in the map itself** -- in `mapx31` it occurs at exactly the seven `monx31` Merchant spawns, 7/7. That also explains the failed sweep: the delta comes from the *movement* code (`asm/0B0F`), not the talk direction, so the cursor stepped to (52,17) instead of the `0x68` at (51,15). **Prediction to test, one run:** step one cell toward the target, then press `T` with no direction. Full chain and grades in `docs/commerce.md` § 5c. Bonus, still free in the same read: set `DS:4E` and `DS:4F` DIFFERENT values -- every maxout character has them equal, which is why `tools/u2_edit.py` still calls cha/wis DISPUTED -- and one quote identifies which byte the routine reads | agent | **high** -- the read is four bytes at a known IP, `tools/bp_read.py` now proves the trap fires on real gameplay (see G0), and headless transactions are proven working; the remaining work is a position/direction sweep to land the ray on a `0x68` | the `×100` economy, CP6, whether stats have a commerce effect, the cha/wis field dispute, whether `asm/20AB` is a price routine at all |
| G24 | **~~do the three status counters survive a save?~~ CLOSED 2026-10-23 by `captures/spice86/cp5-g24-save/` -- no, and they cannot be.** Poked `DS:26A..26D = 07 09 08 08`, pressed `Q` in-game, and the bytes are absent from the 384-byte file (they would have to sit at file offset 0x234); on reload they read `00 00 00 00`. Only five bytes differed seed-to-saved, all inside the proven record. The same arithmetic puts the § 16 town alarm (`DS:1D7` -> file 0x1A1) outside the record too, so an alerted town cannot survive a save either. Write-up: `docs/spice86-live-findings.md` § 17. Bonus from the same runs: the poked counters were watched decaying in lockstep while the player stood still, and `Q` outdoors in sector 00 turned out to be gated on `[DS:6D]` with `ONLY ON EARTH!`, which contradicts `DS:6D` being the stale boots count -- flagged in `docs/phase4-state.md` § CP5. The owner was asked whether paralysis persists and answered that they did not know about SAVE, but that **"there's not really a leaves-combat state"** -- so persistence-by-save is the only persistence question there is. C1 places the counters at `DS:26B/26C/26D` (619..621), which is **outside** the proven save record `DS:36..135` (54..309) per `docs/save-format.md`. So either they are never persisted, or the save record is larger than currently proven -- and the second would mean `save-format.md` is wrong about its own boundary. **Settleable headlessly, no play needed:** seed a character with legs=9, arms=8, sleep=8 (values actually observed together on 2026-10-21), let the game write the `player` file, reload it, and read 619..621 back. Also worth capturing while a session is live: whether the legs and arms gates really are independent in play, i.e. paralysed legs still permitting an attack and paralysed arms still permitting movement, which is what the owner recalls and what a single boolean flag cannot express | agent | **high** -- it is a seed-save-reload-read cycle, all four steps already scripted in `tools/u2_edit.py` and `tools/spice86_start.sh --player` | C1, C3, `docs/save-format.md`'s declared record boundary, whether CP5 can treat status as persistent state at all |
| G25 | **~~is the role byte the cause of hostility or its record?~~ CLOSED 2026-10-23 by `captures/spice86/cp5-g25-aggro/`.** `0x01` is an **alarm**, not a class: guards are born `0x03`/`0x00` (baseline at load), and landing a blow on *anything* in a town flips every guard in the loaded sector to `0x01` simultaneously -- including slots at d31, d44 and d46 that were never touched -- after which they form up on the player and take HP (`9999 -> 9796`). Two controls: 65 s idle on a fresh load flips nothing (guards wander, roles hold), and a *missed* swing flips nothing. So the byte records violence that landed; whether it is also read back as a cause is the remaining thread, noted in § 16. Full write-up: `docs/spice86-live-findings.md` § 16 | agent | **done** | CP5 encounter model, `docs/monster-spawn.md` § 6, the guard-hostility thread |
| G26 | **~~is the guard response sector-wide or radius-based?~~ ANSWERED for the alarm, 2026-10-23 by `captures/spice86/cp5-g25-aggro/`: sector-wide.** Every guard in the loaded sector flipped to `0x01` from one blow landed at the player's feet, and distance did not predict it -- d1 and d46 both flipped, and the d44/d46 pair sat in a different part of the map entirely. What is *not* settled: whether far guards then actually travel to the player (the d31+ ones flipped but stayed put in the window observed), and whether *killing* a guard escalates beyond wounding one | agent | medium -- CP5 can model the alarm as sector-wide and refine the pursuit rule later | CP5 guard behaviour, `docs/spice86-live-findings.md` § 15, § 16 |
| G27 | **what is `DS:26A`?** The tick routine `asm/0C33..0C53` decrements it exactly like legs/arms/sleep and `asm/080D` zeroes `DS:26A..26D` with them, but it read `0x00` in every frame of the 3000-turn fight recording and in every live run since. Something sets it and nothing observed has met that something. Needs a capture in which it goes non-zero, and the honest verdict is that nobody knows what would | agent | low -- inert in every observation so far, so CP5 can carry it as an unnamed counter and say so | C1's counter set, `asm/080D`'s undiscovered caller |
| G19 | the **dungeon creature set is unreachable by the tile join** — all seven codex dungeon images are `64x41` screenshot crops, and the dungeon is a wireframe renderer whose outlines probably live in `original/monsters` (64 records x 34 B of coordinate pairs, still T9). Dungeon Orc, Daemon and Balron are **different creatures from their overworld namesakes**: different art, HP `17-153` / `177-217` / `209-249` against `16` / `64` / `255`. Identify them through the stroke table, not the tile table | agent | **medium** | dungeon rendering, T9, any dungeon bestiary |

G14, G15 and G16 were carried in from the 2026-10-21 handoffs on 2026-10-22, where they
were open but recorded nowhere but a document being archived. See
`docs/archive/handoff-2026-10-22.md` § Triage.

G1–G5 are `docs/passability-findings.md § Open` questions 1–5; the technical spec
lives there. What follows is only the driving plan and the honest verdict.

G17, G18 and G19 were rewritten the same day they were filed, after the bestiary
join pulled up the existing monster findings. The first versions of G17 and G18
were both wrong about what is actually unknown: G17 assumed a monster HP field had
been located (it never has, and it is now known not to be stored), and G18 assumed
the type→art transform rested on one observation (it is corroborated by eight).

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

### G17 — the monster HP model `[ ]` *(static prerequisite first)*
**What is already settled:** monster HP is **not stored**. `tools/hp_table_scan.py`
searched the executable for a per-creature HP table across 13 encoding x indexing
combinations — raw byte, 16-bit LE and the hundreds-first BCD pair the player's own
HP uses, indexed by art and by the type/sprite values that fold to an art under
`>>2` — and nothing reached even a "all but one" bar. `original/monsters`
(64 records x 34 B) was tested the same way and is coordinate pairs, not stats, so
T9 loses that candidate. A loose threshold would have invented a table; the negative
is the useful answer.
**What the ranges say instead:** the seven dungeon HP ranges are two exact
arithmetic progressions, `min = 17 + 32k` and `max = 153 + 32*(k//2)` in
dungeon-table order — 14 data points, four constants, 7/7 on both. The overworld
values lean the same way: `32 x {1,2,2,4,5,6,7}` with Balron at `255` (`0xFF`, a
byte ceiling where 256 would land) and Orc's 16 the one outlier. Dungeon HP is
computed from creature index and depth; overworld HP has no depth, so it has no
range. Grade: **measured against third-party numbers**, which is not the same as
measured against the binary.
**Static step (do this first, no emulator):** find the computation in the spawn and
combat code. The unexplained fifth record field `DS:0x177+i` is the obvious
candidate — it is written from `asm/0D4F`, `asm/0D6F`, `asm/0DAF`, `asm/0DC4` and
`asm/147F`, and `asm/212A` does `incb 0x177(%di)`, which reads like a per-monster
counter rather than a position.
**Live step (then this):** the compound at sector 00 (30,32) already holds 31
simultaneous monsters and the spawn RNG is seed-repeatable, so one session can dump
all 32 slots at spawn and tie the formula to a live record. Memory reads sustain
about 250 req/s.
**Settled from the existing capture corpus, not a new run.** Reading the monster
record out of every dump in `captures/spice86/` showed the arms ARE the live path:
about 40 captures have live HP exactly equal to the arm immediate with zero
mismatches, and `play-test` (the landbridge session) shows a damaged Sea serpent at
44 of 64. The sector-0 compound reading 255 for everything is **not** an override and
never was -- `monx00[64:96]` is all `0xFF`, and placed monsters load HP from that table.
See `docs/monster-spawn.md` § 1, which supersedes the "area override" framing used here
earlier the same day.

That same dump confirms the townsfolk and validates the third-party ranges: Guard
`0x60` at **255** (codex right, Gamer Corner's 500 wrong), Merchant `0x68` at **30 and
50** (codex 5-50), Cleric `0xF4` at **25/30/40** (codex 10-60). Town NPC HP exists and
sits inside the published range; what remains unknown is the *assignment* site, since
no arm covers them.

**Genuinely still open, and narrow:** the rule by which an area raises HP above the
base (castle vs compound vs overworld), and why the sector-0 compound saturates every
slot to 255. That is a static question about area setup, not a capture question.

**Needs owner:** no. `--auto-play` and `tools/spice86_type.py` drive a headless run
end to end; no display, no keystrokes through X.
**Blocks:** nothing for the HP column, which is measured and live for ordinary
spawns. The area-override rule is what CP5 combat fidelity needs.

### G18 — which record field drives the art `[x]`

> **CLOSED 2026-10-23 by `captures/spice86/art-index/`.** The answer is **neither record
> field**: the renderer reads the **sector grid cell** at `DS:1800[y*64+x]`, and applies
> `>>2` to it. Proven on the only type/cell disagreement in the corpus (sector 00 slot 6,
> type `0x34`, cell `0x38`) where the drawn tile matches art `0x0E` = `cell>>2` at
> **256/256 pixels** and art `0x0D` = `type>>2` at 171/256, with the viewport geometry
> independently confirmed on 18 further slots. Full write-up and the one-sample caveat:
> `docs/art-index.md`. The text below is kept as the record of how the claim got wrong
> twice before it got right once.
**What is already settled:** the record is three parallel byte arrays, stride 1,
32 slots — `x = DS:0x137+i`, `y = DS:0x157+i`, `sprite = DS:0x1B7+i`,
`active = DS:0x197+i` — measured, and the earlier stride-`0x20` guess is recorded as
wrong. Two of those fields are candidate "type" bytes, and **both** fold to the
right art under `>>2`:

| field | measured value | `>>2` | bestiary name | documented behaviour |
| --- | --- | --- | --- | --- |
| `0x197` | `0x34` | `0x0D` | Daemon | leg paralysis |
| `0x197` | `0x38` | `0x0E` | Devil | arm paralysis |
| `0x197` | `0x3C` | `0x0F` | Balron | sleep |
| `0x197` | `0xF8` | `0x3E` | Wizard | magic missile |
| `0x1B7` | `0x60` | `0x18` | Guard | drops 2 keys |
| `0x1B7` | `0xF0` | `0x3C` | Fighter | drops torches |
| `0x1B7` | `0xF8` | `0x3E` | Wizard | magic missile |
| `0x1B7` | `0xFC` | `0x3F` | Thief | steals items |

**Correction, 2026-10-22 (same day).** The table above is the retracted version. The
"eight for eight from two independent fields" claim is **wrong**: `[DI+0x1B7]` is not a
sprite but a small kind index (`0x08`/`0x0C`), which is what the spawn guards compare
against. So there were never two fields — there were **four agreements from one field
relabelled**, and they are arithmetic only. The spawn arms contain no shift and no mask;
they store the type as a plain immediate (`mov $0x30,%al; mov %al,0x197(%di)`).

**What is settled now, and it is more than the transform:**

* The `0x40` contradiction is **closed** — the thief is type `0xFC` with HP 32, `0x40` is
  the empty sentinel, and "the thief is monster type `0x40`" in
  `docs/spice86-live-findings.md` is wrong.
* **`view.h` is not defective and L2 was misframed.** `u2_view_index` returns the staging
  byte `(map_byte>>1)&0xFE` and `u2_view_art` halves it; `((b>>1)&0xFE)>>1 == b>>2` for
  every one of the 256 byte values, checked exhaustively. The engine already implements
  `>>2`, in the two-step the original uses. Anyone tempted to "fix" it should read
  `view.h:78-94` first.
* **New open question:** the dungeon `type` field is a **different encoding**, not the
  overworld type byte. In `dungeon-35-live` the active slots hold `0x01`/`0x02`, not the
  `0x2C`–`0xFC` of the overworld, and `asm/147F` builds HP as `or $0x10,%al` rather than
  storing an arm immediate. So dungeon monsters are a separate representation and the
  overworld grid test does not apply to them.
* **A term I invented and must not survive:** there is **no "airport mode"**. The
  `airport*` capture directories are names from a prior session chasing an owner
  recollection of "a town with an airport"; the game has plane and rocket *tiles*
  (`mapx03` depot, plane = map byte `0x4C` art `0x13`, landing gated to grass `0x08`),
  not a mode. `airport32`'s 4 KB grid at `DS:1800` is **byte-identical** to
  `dungeon-35-live`'s — it is a dungeon capture with a stale name. Any claim of the form
  "dungeon and airport mode have no grid stamping" was wrong twice over.
* **Grid stamping holds at scale in the overworld:** `DS:0x1800[y*64+x] == type` for 330 of
  387 monster cells across 49 captures. The base itself was already documented twice
  (`spice86-live-findings.md:85` "Sector buffer is loaded at DS:1800" and
  `phase4-overnight-cp5-report.md:393`), so this was a re-derivation, not a discovery.

**Action:** map the dungeon encoding — what `0x01`/`0x02` mean, and where dungeon objects
are drawn from. Do not reuse the overworld grid test on dungeon dumps.
**Why the agent can do it:** both dumps are already on disk; this is a search, not a capture.
**Needs owner:** no.
**Blocks:** naming monster *types*. Art indices are named already; types are not, and a
wrong field would attach every name to the wrong creature. Sibling of G1.

### G19 — the dungeon set is outside the tile join `[ ]`
**Why it exists:** the bestiary join named **zero** dungeon arts, and that was
design, not a miss — every codex dungeon image is a `64x41` screenshot crop, so the
eligibility rule rejected all seven. Worse, the dungeon is a wireframe renderer, and
`tools/monster_shapes.py` already suspects `original/monsters` (64 records x 34 B of
coordinate pairs) is where the outlines live.
**The trap:** dungeon Orc, Daemon and Balron are **different creatures from their
overworld namesakes** — different art, and HP `17-153` / `177-217` / `209-249`
against `16` / `64` / `255`. Town is the opposite case: Thief and Wizard are the
*same* creature as on the overworld, same image and same HP, reused as NPCs.
So a name earned from the overworld tile table must never be carried into a dungeon
row. Note also that the codex's dungeon Daemon image is filed as
`U2DungeonMinotaur.png` — the source disagrees with itself about what that creature
is called.
**Action:** decode the stroke table (this is also T9), then identify dungeon
creatures from their drawn outline.
**Why the agent can do it:** static decode plus a dungeon session already scriptable.
**Needs owner:** no, though G10 (dungeon geometry) does.
**Blocks:** any dungeon bestiary, T9, the dungeon renderer.


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

### G26 — the creature-table layout `[x]` *(closed same day — the question was bogus)*
**Outcome:** `docs/monster-spawn.md` § 2 was right all along. The layout was never
wrong; the script that claimed otherwise sliced `monxNN` from offset 128 instead of 0,
four fields out of position, and every "structural impossibility" it reported was an
artefact of that one constant. A fresh live capture (sector 31, `G23MAX`) matches
`monx31` at **32/32** on `hp`, `type` and `role`, and 30/32 on `kind`, with `x`/`y`
under-matching only because creatures walk after spawn. The post-mortem, including the
two process rules that came out of it — check what the code reads before declaring the
code wrong, and give every new script a positive control — is § 10 of that document.
**Cost of the false alarm:** the CP5 creature stamp was compiled out for hours, W2/W4/W5/W6
were declared blocked, and the owner was told the reconstruction had a defect. It did not.

### G27 — what the game does after the death announcement `[ ]` *(agent-drivable, ~20 min)*

**Question:** `asm/0C62..0C99` zeroes `DS:51..59` and prints `<NAME> IS DEAD!`, and every
site that can kill jumps into it. Nothing has ever recorded what happens *next*. Does the
walk loop accept another command? Does it go back to the title, wipe the save, or sit
there with a dead character who can still walk?

**Why it matters now:** the engine prints the announcement and carries on playing, which is
a guess by omission recorded in `engine/src/game/overworld.c:u2_death`. It is also the one
thing between `death1.png` and a CP5 gate that ends a fight the way the original does.

**Who can do it:** an agent, unattended. The recipe already exists — the capture that
produced `captures/spice86/cp5-weak-fight/death1.png` was a seeded low-stat character
driven headless. Seed 1 HP, stand next to something hostile until the death line prints,
then keep sending keys and screenshot after each. `--patch-arrows` plus
`tools/spice86_type.py`, and confirm every key landed by reading DS, never by the send
returning ok.

**Success criterion:** a named capture directory holding the frame *after* the
announcement, plus a verdict on whether `DS:00/01` moved under a direction key.

### G28 — what makes a world-map cell a town gate `[ ]` *(agent-drivable)*

**Question:** `E` (ENTER) dispatches on `[DS:14] >> 1` — 6 town, 7 tower, 8 castle,
9 dungeon — and refuses with ` WHAT?` everywhere else. `DS:14` is `mode_a`, copied from
the `DS:2DF` region by `asm/5B71_mode_table_copy`, and that region has no direct writers
(`docs/passability-findings.md` F3). So the open question is narrow: **what is `DS:14` at
a cell where `E` works, and how does it relate to the tile byte under the player?**

**Why it matters:** this is the last thing between the engine and "walk into a town". The
entry machinery itself is six steps and a digit and is written up in
`docs/sector-rulesets.md` § 6; the sector-edge leave path is already fully proven. Only
the gate value is missing.

**Who can do it:** an agent, unattended, and the cheap version is not a 4096-cell sweep.
Start a world sector (`mapx30`), and at each of a dozen cells of *different tile bytes*
read the mode block `DS:12..DS:18` over the HTTP API and press `E`, recording whether the
answer is ` WHAT?`. Twelve samples of (tile byte, DS:14, DS:15, DS:18, E-answer) is
enough to see whether `DS:14` is a function of the tile at the player's cell or of
something else entirely — which is the answer that actually unblocks the work.

**Success criterion:** a named capture directory holding the sample table, and a verdict
on whether `mode_a` is derived from the tile byte.

## Closed

*Nothing yet.* Opened 2026-10-22 with thirteen items.

### G30 — what tile is underneath an unlocked door

**Grade: recalled (owner, 2026-10-27) — "when you open a door it disappears, I don't
remember what's underneath the tile."** Named unknown, not a guess to be filled in.

`asm/435E_sub_435e.asm` ends with `mov 0x14,%al; add %al,%al; ... mov %al,(%bx)` — it
writes `DS:14 * 2` into the map cell, so the door really is replaced in the sector
data rather than flagged elsewhere. What `DS:14` holds at that moment is not traced.

**Agent-drivable, no owner needed.** Headless Spice86: pick a sector containing map
byte `0xA0` (175 occurrences across 15 sectors), `--player` + `u2_edit.py setpos` to
stand adjacent, read the sector grid at `DS:0x1800` for that cell, send `U` then a
direction key, read the cell again. The before/after pair is the answer. Confirm the
key landed by reading memory, never by the send returning ok.

Also capture in the same session: `DS:65` (keys) before and after, to confirm the
`das` decrement end to end, and whether the opened cell survives leaving and
re-entering the sector — that decides whether the write goes to the sector map or to
a separate overlay, which is the `(%bx)` question the asm leaves open.

### G29 — sector crossing on the west land bridge: scroll or teleport

**Grade: recalled (owner, 2026-10-27) — "when I cross the land bridge west into the
next sector you have me teleporting, but it should scroll seamlessly, at least in the
overworld."**

This is not only a rendering complaint. It contradicts something the project has been
treating as byte-proven, and per the rule that an owner observation outranks an agent
inference, the contradiction has to be resolved before anything is changed.

**What the engine does now.** One resident sector (`engine/src/core/world.h`), and
`asm/5AE1` gives the window origin as `(x-9, y-5)` — the player sits at screen cell
(9,5) of a 20x16 viewport, not the centre. Off-sector cells take their tile from the
single byte `DS:12` (`tile_offsector`), which is proven and is why the engine paints a
uniform strip at the edges. Crossing is handled by `site_leave()` / the edge test.

**The conflict.** `asm/242D/2434` was read as testing **only the high edge**, which
means walking east or south leaves the sector while walking **west or north wraps
round the torus inside the same sector**. That reading is recorded in `site_leave()`
and in `world.h` as "the viewport never straddles a file". If it were true the owner
could not cross west into the next sector at all in the original — and they say they
can, routinely, and that it scrolls.

So one of these is wrong, and it is probably the reading of `242D/2434`, not the
owner. Two candidate designs, and they need different fixes:

1. **The original never straddles** (current engine model). Then "seamless" means the
   crossing must not move the player's *screen* position — the sector reload has to
   place the player at the opposite edge so the picture is continuous, and the
   teleport is a bug in how the engine repositions on reload, not in the viewport.
2. **The original does straddle**, and `DS:12` is only a fallback for cells beyond the
   world edge. Then the overworld needs two (or nine) resident sectors and the viewport
   sampling across the boundary — a real change to `world.c`, `view.c` and the crossing
   path.

**The capture that decides it.** Headless Spice86, sector 20, `--player` +
`tools/u2_edit.py setpos` to stand near the west edge on a land bridge. Read the
staging grid at `DS:0x272` (256 B) and `DS:12`, then walk west one step at a time
across the boundary, reading after each step.

- If the staging grid ever contains tiles from two different `mapx` files, design 2 is
  correct and `DS:12` is a fallback.
- If it never does, design 1 is correct, and the question becomes what the original
  does to the player's screen position at the moment of reload — read `DS:00/01` and
  the window origin across the crossing step.
- Either way, record whether the west edge actually changes sector or wraps in place,
  because that is the `242D/2434` reading being confirmed or refuted.

**Owner-only part:** whether the original's crossing is a smooth scroll or a fast
pan. The bytes can say what the viewport contains; only a person watching can say what
it looks like. Worth 5 minutes of the original under `tools/spice86_start.sh
--patch-arrows` with a real window.

#### G29 progress — capture 2026-10-27, the framing was wrong

Live capture against the containerised original (`deploy/spice86-novnc`, owner walking).

**Settled, by bytes:**

- The owner walked east from `x=57`; position became `x=7`, and the resident sector was
  still **20**. Decided mechanically, not by interpretation: `mapx20` and `mapx30` differ
  on 8 of 64 rows, and over those 512 discriminating cells the live map buffer at
  `[DS:0472]` (which reads `0x1800`) matched `mapx20` on **511** and `mapx30` on 496.
- Therefore **crossing an edge does not load a neighbouring sector.** The overworld is a
  torus *within* one 64x64 sector, and the tens digit of the sector name is not an
  east/west coordinate the way the engine's `site_leave()` assumes.
- `DS:12` reads `0xFF` in a live overworld session. The engine sets `tile_offsector = 4`.
  One of those is wrong and it is probably the engine's.

**What this does to the ticket.** The two candidate designs as written are both wrong:
there is no second sector to straddle, so design 2 is dead. The seamlessness the owner
describes has to come from the **viewport wrapping its coordinates inside the sector** —
origin `(x-9, y-5)` masked to 0..63 — instead of painting off-sector cells from `DS:12`.
That is a much smaller change than design 2, and it is in `view.c`, not `world.c`.

**Still open, and the capture that was supposed to close it failed.** The wrap-versus-fill
test compared the staging row against both hypotheses and got **4/20 either way**, which
discriminates nothing. The row read back as uniform `0x84` — a staging byte with bit 7
(the do-not-draw flag) set — so the assumed grid geometry is wrong: either `DS:272` is
not the grid base in this build, or it is not 20 columns wide, or row 5 is not the
player's row. `U2_VIEW_TILES` in the engine is the thing to re-derive, not to trust.

Re-run: stand at a small `x` (say 2) on a row whose map tiles are visually distinctive at
both ends, dump `DS:272..DS:3B0` raw, and find the grid by matching the *known* tiles
around the player rather than assuming the layout. Once the grid is located, the
wrap-versus-fill question answers itself in one sample.

#### G29 RESOLVED 2026-10-27 — it was neither design. The viewport wraps.

Closed by capture, not by argument. The original does not load a neighbouring sector at
an edge (proven 511/512 against the discriminating rows of `mapx20` vs `mapx30`), and it
does not blank off-sector cells either. At player `(0,11)` with origin `(-9,6)`, staging
row 5 held the map's own columns 55..63 with bit 7 set:

    84 84 84 84 84 84 84 84 84 78 84 84 84 84 84 84 84 84 86 86

`0x08` grass -> `0x04` -> `0x84`; `0x0C` forest -> `0x06` -> `0x86`; column 9 is `0x78`,
the player stamp. The fill loop masks its coordinates into the sector and reads the torus
straight through. `u2_view_fill` now does the same. `DS:12` is not consulted by the
viewport at all, which leaves its real purpose open as **G31**.

A CP4 test had been asserting the opposite behaviour by name and passing; it is replaced
and the replacement says why.
