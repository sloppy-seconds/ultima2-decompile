# Verification log — `u2-game-meta-analysis.md` against our own bytes

**Purpose.** `docs/u2-game-meta-analysis.md` is a third-party synthesis used as a hypothesis
source. A hypothesis source is only useful if someone records what happened when it was
checked. This is that record: what it led us to, what our bytes contradicted, what it got
right that we had already proven independently, and what remains untested.

Grades are per `AGENTS.md` § 5. This document never promotes a third-party claim to fact; it
records the outcome of testing it.

**Standing rule when using the source document:** it may suggest where to look and what number
to grep for. It may not appear in an `asm/` header, may not name a file, and its certainty
matrix measures wiki agreement, not our binary.

---

## 1. What it helped us find — the value delivered

### 1.1 The creature AI region. This alone justifies keeping the document.

It asserted, with two checkable numbers, that an overworld monster at **15 HP or lower**
switches from pursuit to retreat, moves away, and **regenerates HP each turn** until it
recovers to **16**. Nothing in our captures suggested regeneration, and nothing in our
static reading had surfaced a threshold on monster HP.

`asm/2122` and `asm/212A` contain exactly that:

```
2122  mov al,[di+0x177]   ; mon_hp[slot]
2126  cmp al,0x10         ; 16
2128  jae 232e            ; >= 16 -> move normally
212a  incb [di+0x177]     ; < 16 -> regenerate +1 per turn
```

Full write-up: `docs/monster-spawn.md` § 12. Three previously unexplained observations fell
out of the surrounding code:

| observation | explanation from the region |
| --- | --- |
| what writes `DS:19`/`DS:1A` | the move is `adc al,[DS:19]` / `adc al,[DS:1A]`; `asm/152E` sets them to `player − creature` and `asm/0B0F` negates them. Toward is pursuit, negated is retreat |
| why an execution breakpoint on the coordinate store never fired | `21a6..21d8` gate on `DS:1F` against a ladder (`0x5c, 0x10, 4, 0, 0x14, 0x70`); `DS:1F` read `120` live, matched none, so the routine refused at `23fc` before reaching any store |
| the measured 7%-of-turns movement rate | very likely the output of that same ladder |

It also gave the **attack trigger**, which 200 turns of adjacent live observation failed to
settle: `2201`/`220a` compare the creature's candidate cell against the player's `DS:00/DS:01`
and branch to the contact path on equality. Monsters attack by walking onto you.

### 1.2 A reason to re-examine a routine we had dismissed

`asm/152E` had been written off as dungeon-only because its only `call` site is
`asm/1151_dungeon_darkness`. The retreat claim made it worth a second look, and it turns out
to hold the pursuit vector used by the overworld move routine. **A wrong dismissal, corrected
because an external source was specific enough to be worth checking.**

---

## 2. What our bytes contradicted

| claim | our evidence | verdict |
| --- | --- | --- |
| Damage `floor((WeaponPower*4 + STR)/4)` | `asm/2E3D_combat_attack_flow`: `al = [DS:61]; add al,al` three times → `8 * readied_weapon`, then `adc [DS:4B],al` (the strength byte), then `>>2`. **There is no weapon-power table at all** — the readied-weapon *index* is the multiplicand | **contradicted, and the contradiction is structural.** Their formula presumes a lookup table of weapon powers that does not exist in this binary. The multiplier on the index is 8, not 4. **But their "base damage without a weapon = floor(STR/4)" is exactly right**: with the index at 0, ours reduces to `S >> 2` |
| Shop discount: `CHA + INT ≥ 40` → 38%, `≥ 80` → 60% | `asm/20AB_bcd_price_from_stats` computes `int + [DS:4E]`, takes its **bit length**, derives `DI = (caller_AL + 8 + CF) − bitlength`, and runs a **Fibonacci walk seeded 4,4** for DI iterations. No threshold compare anywhere in it. Higher int+cha → smaller DI → lower price, so the *direction* is right and the mechanism is nothing like a two-step tier table | **contradicted in mechanism.** Also note our own routine still fails to reproduce the one observed price (200 is not in the sequence `4,8,12,20,32,52,84,136,220,...`) — that gap is ours, tracked as G23, and it means neither model is confirmed. And we cannot even name the second stat: `DS:4E` is disputed between charisma and wisdom |
| "a visible **11x11** tile viewport" | viewport measured from owner screenshots: **20x10 tiles**, player at window tile `(9,5)`, `U2_VIEW_COLS 20` / `U2_VIEW_ROWS 10` | **contradicted.** Likely the Apple II build, or wrong |
| "terrain passability is evaluated" on player input | CP4b: `asm/2423` never reads a tile, so on-foot walking is never rejected on the overworld | **contradicted for on-foot.** May hold for vehicles — unproven, and `asm/2423`'s mode argument is still an open question |
| "executing the command via the dedicated **P** key bypasses the resource check, consuming zero food" | measured: PASS spends **10** food (`$0A`), and the auto-pass spends the same | **unresolved, ours is the measurement.** Their spacebar figure (0.10 = 10 units) matches ours exactly. Owner deprioritised this check |
| "16 discrete subterranean and tower levels", the 10x10x10 space grid, planet coordinate table | not yet examined in this binary | **untested**, not disputed |
| Apple II Strength-never-rises bug, C64 disk-swap bypass, ST/Mac/Japanese port behaviour | out of scope — this project's ground truth is the DOS `ultimaii.exe` | **out of scope.** Recorded so nobody cites them as findings here |

### A correction to this document's own first draft

The first version of this table called the discount claim *"suggestive, not yet read — the
constants `cmp $0x28` (40) and `cmp $0x50` (80) appear in price code"*. **That was wrong and
it was the same error I criticised § 11 for.** The grep hits were in `asm/253B`, `asm/25E0`,
`asm/2FB8_offer_what_msg`, `asm/38B0_cmd_L`, `asm/42AA` and `asm/039E` — **none of them the
price routine.** I pattern-matched on the existence of two magic numbers near a filename
containing "price" and upgraded a claim on the strength of it. Reading the actual routine
killed it in one pass. Coincidence in constants is not corroboration; `40` and `80` are
extremely common bytes in any 8-bit program.

---

## 3. What it got right that we had already proven independently

The most useful category, because agreement here is corroboration rather than borrowing.

| claim | our independent finding |
| --- | --- |
| **Agility ≥ 80 guarantees a 100% hit** | falls straight out of our proven formula. Ours: `(rand >> 1) < agility_byte`, so the maximum roll is 127. Packed-decimal 80 is byte `0x80` = **128**, and `127 < 128` always holds. Two unrelated derivations landing on the same threshold is the strongest single agreement in the document |
| "a random **7-bit** roll compared against BCD Agility" | our measured hit test, 12 swings at agi 5 → 1 hit, matching 3.9% = 5/128 |
| Food: **0.19** per tile, **0.10** per pass | measured: **19** per accepted move, **10** per pass. Their figures are ours divided by 100, which is consistent with the food field carrying two implied decimal digits |
| 90-point creation budget, six stats | `engine/src/game/creation.c`: `#define BUDGET_START 0x90 /* packed 90, asm/56E6 */`, six stats of at least 10 summing to 90 |
| Gender/race/class apply **BCD** stat bonuses; **STAMINA gets none** in every row of their table | our creation code notes "the ten BCD bonuses for sex / race / class, and that STAMINA gets none" — a non-obvious omission, independently reproduced |
| Stats stored as **BCD**, cap 99, wrap to 0 | proven: 1-byte packed decimal with no ceiling guard on any add site, confirmed from bytes after the owner recalled it |
| Gold and experience as 16-bit BCD, ceiling 9,999 | our `state.h` BCD field layout and the `das`/`adc` idiom in `asm/2DC1`/`asm/2DEE` |
| "64 discrete graphical tiles" | the art table holds exactly **64 records**, proven when resolving the `>>1` versus `>>2` confusion |
| Shop discounts keyed on **Charisma + Intelligence** | **half right, and the half that is right is the useful half.** `asm/20AB_bcd_price_from_stats` really does derive a price from `int + [DS:4E]`, and higher values really do produce a **lower** number — so "stats move prices down" is corroborated. The specific tier thresholds and percentages are contradicted (see § 2), and whether `[DS:4E]` is charisma or wisdom is an open dispute in our own tree |
| Deterministic dungeon structure, transient features reseeded | consistent with our dungeon findings; the dual-seed split specifically is untested |

---

## 4. Method — why this worked where a similar static reading failed the same day

`docs/monster-spawn.md` § 11 was a static reading of a byte cluster that I promoted into a
named subsystem and then killed with one breakpoint. § 12 is the same kind of static reading
and it survived. The difference is not care or talent:

* § 11's shape was inferred from bytes alone, with nothing falsifiable to aim at, so it could
  accommodate any observation. That is the disqualifying property.
* § 12 began from a claim naming **two numbers** — 15 and 16 — which could be looked for and
  could have been absent. They were present.

So the usable rule for a secondary reference: **prefer its numeric and structural claims over
its narrative ones.** "Monsters retreat at 15 HP" is checkable. "Dungeon movement incurs a
severe performance cost" is not. The document's own certainty matrix is close to useless for
this purpose, since a HIGH rank means several wikis agree, and wikis copy each other.

Two failure modes to keep watching for:

1. **Platform conflation.** The source mixes Apple II, C64, Atari and DOS behaviour freely. Our
   ground truth is one DOS `ultimaii.exe`, itself an Internet Archive pack that may carry
   community patches. A claim can be true of Ultima II and false of this binary.
2. **False precision.** The armor table's "Defense Rating" column (56, 63, 69, 75, 81, 88) and
   the HP taper brackets look measured but are unsourced. Treat as a place to look, never as
   a number to assert.

---

## 5. Open items raised by this document

Ordered by value. Items 1 and 3 were closed on 2026-10-23; the rest stand.

1. ~~**Reconcile the damage multiplier.**~~ **CLOSED.** There is no weapon-power table; the
   readied-weapon index is multiplied by 8 directly. Their `*4` presumes a table that does not
   exist here. Their unarmed base damage is correct.
2. **Confirm `238b -> 0x1240` is the attack.** Still open, and the lookup is not trivial:
   **no `asm/` file begins in `0x1230..0x1250`**, so `0x1240` sits inside another fragment's
   span. Finding it means walking the fragment that covers it, not grepping a filename. This
   is the item blocking a byte-true CP5 W6.
3. ~~**Read `asm/20AB_bcd_price_from_stats` end to end.**~~ **CLOSED — claim contradicted**
   (see § 2). It also re-opened G23: the routine cannot produce the one price we observed.
4. **Test the retreat loop live.** Damage an Orc to ≤ 15 HP and watch for `+1` HP per turn and
   a direction reversal. This is the first test of § 12 that is not static, and it is the one
   that would catch a misreading of the `jae` polarity — the threshold is proven to exist, but
   that the *low* branch is retreat rather than something else is still inference from the
   wiki, not from the bytes.
5. **Settle `DS:4E`: charisma or wisdom.** Cheap and blocking for anything price-shaped: seed
   a character with `DS:4E` and `DS:4F` set to **different** values and watch the quote. Every
   maxed character seeded here has them equal, which is why it has survived this long.
6. **Deprioritised by the owner:** the `P`-key versus spacebar pass cost.
