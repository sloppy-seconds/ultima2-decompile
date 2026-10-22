# Commerce — what is sold, where the goods list lives, and why no price table exists

Answers **G21** ("what does each shop stock, and at what price"). Grades per
`AGENTS.md` § 5. Nothing here quotes dialogue verbatim into git beyond the short
catalogue labels needed to identify a shop; the strings are game content and stay
described rather than reproduced.

## 1. There is no goods table and no price table

**measured negative, with a stated limit.** Every shop catalogue in the executable is an
**inline string** printed via the string-output routine (call target `L_0051df`; the
routines are `asm/4FDF_str_out`, `asm/51EB_str_out_at`, `asm/51FD_str_out_core`), not a
record in a table. The four `shop_header_*` routines are 13-byte label printers that fall
through to whatever follows:

```
shop_header_weapons:
        call L_0051df
        db "WEAPONS: ",0x00
```

A full printable-string survey of `original/ultimaii.exe` (548 strings of 5+ chars,
runtime address = file offset − `0x200` per `captures/README.md:33`) returns 47
commerce-related hits, and every one is a message or a catalogue label. No array of
(item, price) pairs was found in any of them.

**The limit, stated plainly:** this is a survey of printable strings plus the shop
routines, not an exhaustive proof that no numeric price table exists anywhere in 37 KB.
What would settle it: walking the arithmetic in each shop routine and showing every price
is a computed immediate. The tavern already shows exactly that (§ 3).

## 2. What each shop sells

| shop | catalogue | where |
| --- | --- | --- |
| Weapons | 8 items, two-letter abbreviations (DA, MA, AX, BO, SW, GR, LI, PH) | `1E69`/`1E81` |
| Armour | 6 items: CLOTH, LEATHER, CHAIN, PLATE, REFLECT, POWER | `1D39`/`1D56` |
| Magic shop | 6 spells — **wizard** list | `19EC`/`1A05` |
| Cleric shrine | 6 spells — **cleric** list, donation asked as "your interest?" | `189E`/`18B7` |

**Audit, 2026-10-22.** Every string in this table was re-derived from the executable and
re-mapped to its owning routine using the correct convention (`asm/` filenames are runtime
offsets, `L_xxxx` labels are file offsets — see `docs/decompiling.md` § address bases).
**All owner attributions hold.** Two start addresses were a few bytes early because the
earlier pass measured the run of printable bytes rather than the string proper: the
transport shoppe is `1F89`, not `1F93`, and the clue seller is `1B11`, not `1B02`. Neither
changes a conclusion. A claim that these attributions were shifted by `0x200` was made in
session and was itself wrong; the owners were always right.
| Horse dealer | one item, price quoted then a yes/no deal | `1F93`/`1FC4` |
| Clue seller | one clue, price chosen by the player × 100 | `1B02` |
| Tavern | buy a drink, or tip | `15FC`/`1654` |
| Cleric | accepts a gold offering | `asm/3C2E_cmd_O` |

**The two spell lists are two different services, not two towns — and my first reading
of them was wrong.** I wrote this up as "the one real per-town difference" before checking
the owners. The bytes say otherwise:

| routine | framing | list |
| --- | --- | --- |
| `asm/1869_cleric_shrine` | `WELCOME ` / `BROTHER ` / `SISTER `, gated on `[DS:46]` (gender) | `4-PASS, 5-SURFACE, 6-PRAYER` |
| `asm/19D7_magic_shop_menu` | wizard gibberish (`MUSERREF OLDUM!`, `BIR IKI UC...?`) | `4-M.M., 5-BLINK, 6-KILL` |

Each is **class-gated**: `asm/184C_not_a_cleric_msg` prints `YOU ARE NOT A CLERIC!` and
`asm/19BA_not_a_wizard_msg` prints `YOU ARE NOT A WIZARD!`. So the shared first three
spells and the differing high tier are a healing/utility shrine versus an offensive
wizard shop — different buildings, different classes. **No town-to-town variation in any
shop catalogue is demonstrated anywhere.** The weapon and armour lists each exist once in
the shop code, which is consistent with every shop selling the same stock.

The same weapon and armour catalogue text appears **twice**: once in the shop and once in
the use-command (`cmd_W` reuses the armour list). So a shop and a command share strings;
do not read a second occurrence as a second shop.

## 3. Prices are computed inline, not stored

**First observed transaction, 2026-10-22.** The owner drove the game over VNC and
interacted with **two different characters**: a Fighter, who only said `UGH, ME TOUGH!`,
and a **vendor** — the Merchant — who actually sold the food. Harvesting that session shows
**461 addresses executed that had never executed before**. Which routines ran, checked
against the harvest rather than inferred:

| routine | range | executed |
| --- | --- | --- |
| `asm/412C_street_merchant` (the vendor) | `412C..415F` | **yes** |
| `asm/415F_street_fighter` | `415F..4188` | yes — flavour line only |
| `asm/4108_street_jester` | `4108..412C` | entry ran, **no reply** |
| `asm/1799_tavern_food_price` | `1799..17B2` | **yes** — `THE FOOD HERE COSTS` |
| `asm/181A_tavern_thanks` | `181A..183E` | **yes** — `THANK YOU, COME AGAIN!` |
| **`asm/19D7` declared span** | `19D7..2027` | **no — zero addresses** |
| **the transaction body** | **`2052..2130`** | **yes — 74 addresses** |

Strings in the newly-executed range: `PER 100, WANT ONE?` (`17C9`), `YES, NO ONIONS AND TO
GO PLEASE!` (`17FA`), `THANK YOU, COME AGAIN!` (`1826`), `YOU DONT HAVE THAT MUCH!`
(`2089`), and `A FIGHTER SAYS: UGH, ME TOUGH!` (`4162`/`4172`).

**Two corrections to what I wrote a moment ago.** First, I attributed the sale to the
Fighter because its string appeared in the same harvest — but the owner talked to two
characters, and the **seller is the Merchant**. Second, and more importantly: **the
`asm/19D7` span did not execute at all.** The transaction ran through `2052..2130`, which
is entirely **outside** that file's declared range of `19D7..2027`.

So G22's boundary defect is worse than "four shops in one file". The code that actually
handled the first observed purchase is **past the end of the file**, and the routines the
file is named after were never reached. Any split must extend the range upward and look for
a routine boundary in the `2028..2130` region, not merely subdivide what is there.

The price is **per 100 gold** and the joke lands as a fast-food order — *no onions and to
go please* — completing the `MC DONALLS` parody the owner recalled
(`docs/place-names.md` § 3). **The jester does not respond**, confirmed both by an
automated `TRANSACT-NORTH` and by the owner trying directly.

The tavern remains the worked example of inline pricing: on `1-BUY` the routine writes
`$0x5` to `DS:28` and `$0x0` to `DS:27`.

## 3b. The price source — found, and it corrects what § 3 said about `DS:27/28`

**measured, static, byte-cited.** § 3 concluded that `DS:27/28` was "a transient scratch
write, not the price field" because a dump taken *after* a vendor purchase found `22 19`
there instead of the `0200` the game had printed. That inference was wrong, and the
corrected statement is:

> **`DS:27:DS:28` is the price operand — the same two bytes are both printed and charged.**
> It is a calling convention, not storage. A dump taken after the transaction shows
> whatever the next user of the pair left behind, which is exactly the `22 19` that
> misled the first reading. Looking there during a transaction finds the price; looking
> afterwards does not.

Three pieces, each read out of `original/ultimaii.exe` and cross-checked against the
`asm/` tree:

**1. The printer.** `asm/51A5_sub_51a5.asm` (runtime `51A5`, file `0x53A5`):

```
push   %ax
call   L_0055b5        ; emit AL as two ASCII digits
mov    %di,%ax         ; (objdump: `mov ax,di`) so AL = DL
call   L_0055b5        ; emit the old DL as two ASCII digits
pop    %ax
ret
```

and `asm/53B5_sub_53b5.asm` (runtime `53B5`, file `0x55B5`) is the nibble-to-ASCII
emitter: `mov ah,al`, four `shr $1,%al` to isolate the high nibble, `or $0x30,%al`, emit;
then `mov al,ah`, `and $0x0f,%al`, `or $0x30,%al`, emit. So one call to `L_0053a5` prints
**`AL` then `DL` as four ASCII digits** — a two-byte BCD value, hundreds byte first.

**2. The call site that prints a price.** `asm/17B7_sub_17b7.asm` (runtime `17B7`, file
`0x19B7`) loads exactly that pair:

```
mov    0x27,%al        ; AL = [DS:27]
mov    $0x0,%bh
mov    0x28,%bl        ; BX = [DS:28]
mov    %bx,%di         ; DI = [DS:28]
call   L_0053a5
```

So the `0200` the owner read means `[DS:27]=0x02` and `[DS:28]=0x00` at the moment of
printing. The same three-instruction load appears in `asm/1869_cleric_shrine`, four times
in `asm/19D7_magic_shop_menu` and in `asm/42D1_sub_42d1` — every shop quotes its price
through this one operand pair.

**3. The charge uses the same pair.** `asm/2052_sub_2052.asm` (runtime `2052`, file
`0x2252`) is the gold charge, and its subtrahend is `DS:27/28`:

```
stc
mov    0x59,%al ; cmc ; sbb 0x28,%al ; das ; cmc ; mov %al,0x59
mov    0x58,%al ;       sbb 0x27,%al ; das ; cmc ; mov %al,0x58
jb     L_0022a7
```

**Read the branch polarity carefully, because the trailing `cmc` inverts it.** After the
`cmc;sbb;das;cmc` chain, `CF = 1` means **no borrow**, so `jb` is the **affordable** path:
it tails to `20A7` (`mov $0x0,%al ; ret`) with gold already reduced by the trial
subtract. Falling through means the player cannot afford it, and `asm/2070_sub_2070.asm`
adds the pair back and prints `YOU DONT HAVE THAT MUCH!`. Simulated against the real
instruction sequence: `9999 − 0200 → 9799, jb taken`; `9959 − 0040 → 9919, jb taken`
(the observed purchase); `0020 − 0200 → jb not taken`; `0004 − 0005 → jb not taken`.

One incidental consequence worth recording: on the failure path the trial subtract
briefly leaves the BCD-underflow value in gold — `0004 − 0005` writes `0x9999` — before
the add-back restores it. That is the `das` underflow the BCD census predicted, reached
through a real code path and then undone, so it is not a lasting corruption but it *is*
observable if anything samples between the two.

### Two price setters, with their arithmetic

* **Tavern drink — a constant.** `asm/15E1_tavern_menu.asm` at `L_00181d..L_001827`
  writes `mov $0x5,%al; mov %al,0x28; mov $0x0,%al; mov %al,0x27` and then
  `call L_002252`. Price `0005`, two immediates, no table, no computation.
* **Clue seller — the `×100` is byte placement, not arithmetic.** `asm/19D7` at
  `L_001d3f..L_001d4a` takes the typed digit, stores it to `DS:1F` **and to `DS:27`**,
  writes `0x00` to `DS:28`, then calls `L_002252`. Putting the digit in the *hundreds*
  byte and zeroing the low byte *is* the multiplication the prompt advertises
  (`HOW MUCH WILL YOU PAY *100?`). There is no multiply instruction in the path.

### Where it goes cold, precisely

**No site was found that writes `0x02,0x00` into `DS:27/28` for the vendor food quote.**
The static path into the printer is `asm/15B7` (`jmp L_001999`) → `asm/1799` (prints
`THE FOOD HERE COSTS `) → `asm/17B2` (`mov $0x3,%al; call L_0022ab`) → `asm/17B7`
(prints the pair).

The three candidate explanations this document offered on the first pass are now resolved
as far as static analysis can resolve them, and **two of them were wrong**. `asm/20AB` is
one routine, not three fragments, and it is now `asm/20AB_bcd_price_from_stats.asm` with
the full derivation in its header (merged 2026-10-23 under the G22 ruling).

What the bytes say, **observed** and then **measured** by stepping the instruction sequence:

* `DS:27/28` and `DS:29/2A` are both seeded to `0004`.
* The loop count is the **bit length** of `[DS:50] + [DS:4E]` (int + cha), not a popcount.
  The shift loop is `inc %si; clc; rcr $1,%al; or %al,%al; jne` — shifts to reach zero.
  An earlier pass here called it `popcount` and was wrong; the correction is recorded in
  the asm header too.
* The loop is **not** multiply-by-repeated-addition. Each pair takes the other's old value
  while the first receives the sum, so the pairs walk a Fibonacci sequence seeded 4,4:
  `4, 8, 12, 20, 32, 52, 84, 136, 220, 356, 576, 932 ...` and the result lands in
  `DS:27/28`, the printed and charged pair.
* Higher `int + cha` means **fewer** iterations, so a **lower** number. For the tavern
  call (`AL=3`) on a maxed character (`int=cha=0x40`): `DI = 11 − 8 = 3` → `0020`. With
  `int=cha=0`: `DI = 10` → `0576`.

**The model does not reproduce the observed price, and the gap is now known to be real
rather than a misreading of the print.** On 2026-10-23 the printer itself was decoded, and
it turned out to be **two more fragment-splits of exactly the G22 kind**: `asm/51A5`,
`asm/51A9` and `asm/51AE` are one routine, and `asm/53B5` and `asm/53C5` are another, each
cut on branch targets rather than at a boundary. Reassembled, the chain from `asm/17B7` is:

```
17B7  mov [DS:27],%al ; mov [DS:28],%bl -> %di ; call 51A5
51A5  push %ax ; call 53B5          ; print DS:27, two decimal digits
51A9  mov %di,%ax ; call 53B5       ; print DS:28, two decimal digits
51AE  pop %ax ; ret
53B5  mov %al,%ah ; shr $1 x4 ; or $0x30 ; emit   ; high nibble
53C5  mov %ah,%al ; and $0xf ; or $0x30 ; emit    ; low nibble
```

So the four printed digits are **DS:27 then DS:28, high nibble first**, and the observed
`0200` means `DS:27 = 0x02`, `DS:28 = 0x00`. That also *settles* the byte-order question
that was previously only inferred from `asm/2052`: DS:27 is the high byte, and the printer
says so directly.

**And it makes the discrepancy worse, not better.** The values this loop can ever place in
`DS:27/28` are

```
4, 8, 12, 20, 32, 52, 84, 136, 220, 356, 576, 932, ...
```

and **200 is not among them at any loop count.** On the current model `asm/20AB` cannot
output the number the game printed. Three ways out, none yet closed: the food quote does not
consume this routine's result; the loop is still misread; or the printed string was not
`0200`.

**A live capture was attempted on 2026-10-23 and did not reach the quote.** The run was
seeded to the owner's exact position from `captures/spice86/food-buy` (sector 31, (50,21),
Fighter at (51,21)), arrows confirmed working, and `tools/bp_read.py` armed at `17B7`. `T`
on its own registers — the band prints `CMD: TRANSACT-PASS` — but `T,Right` and `T,Up`
queued together at `--delay 0.02` both fell through to `CMD: PASS`, and `17B7` never
executed. The original quote came from a **human driving over VNC**; the documented headless
recipe does not reproduce it. G23 now carries that as the blocker, plus a cheap bonus: every
maxout character has `DS:4E == DS:4F`, which is exactly why `tools/u2_edit.py` still marks
the cha/wis labels DISPUTED, and one quote with the two bytes set **unequal** would settle
that field dispute as a side effect.

### Charisma affects costs — owner-confirmed

**The owner states on 2026-10-23 that charisma affecting costs is known behaviour of the
original game.** Grade: **recalled**, and per `AGENTS.md` § 5 an owner recollection is a
pointer at a place to measure, not a conclusion. It landed on exactly the right place: the
only stat-dependent arithmetic found anywhere in the commerce path reads `int` and `cha`
and nothing else, and its output decreases as those two rise. That is corroboration of
direction from an independent source, and it is the strongest support the reading has.

It is still **not** proof of the arithmetic, and the printer decode above strengthened the
case that something is wrong with the model, since 200 is unreachable. There is a second
hole the recollection does not cover: **`[DS:4E]` may be wisdom, not charisma.**
`engine/src/core/state.h` and `docs/spice86-live-findings.md` disagree, and every seeded
character has the two bytes equal, so the identity is unproven. If the labels are swapped
this routine reads `int + wisdom`, and the charisma recollection points at some *other*
mechanism still unfound. What the recollection buys is a **falsifiable prediction**: a
low-charisma character should be quoted a **higher** price at the same vendor for the same
item — and setting `DS:4E` and `DS:4F` apart is what tells us which byte this even is.

**What is settled regardless:** there is no price table, the printed price and the charged
price are the same operand pair, and the pair is written by a routine whose output depends
on `int + cha`. The `2 gold per food point` figure the owner measured is consistent with a
`0200` per-100 quote and needs no table to explain it.

### The vendor food price, measured

The owner reported the vendor's line in full: **`THE FOOD HERE COSTS 0200 PER 100, WANT
ONE?`** — 200 gold per 100 food, i.e. **2 gold per point**. Cross-checked against memory:
gold went 9999 → 9959, a spend of **40**, which is exactly **20 food points** at that rate.

That measurement also settled the gold byte order empirically. `DS:58 = 99`, `DS:59 = 59`,
and the status band prints **9959** — so `0x58` is the high byte and `0x59` the low, read in
address order. `state.h` asserted this from a comment; it is now observed.

Food could not be cross-checked the same way: the dump and the screenshot were taken at
different moments and food drains 19 per accepted step, so the two readings disagree by
design. Gold is stable, food is not.

Gold income is separate and already named: `asm/2D8C_combat_kill_reward` prints
`KILLED--GOLD+`, so kills award gold directly.

## 4b. The armour shop, opened — first transaction that is not the street vendor

**observed live 2026-10-23**, capture `captures/spice86/armour-buy/`. This is the first
shop interior ever reached in this project; every prior commerce claim was static.

The reason the earlier attempts failed was a **data** problem, not an input problem, and
`tools/shop_access.py` now answers it for every sector at once: it walks each shop sign of
3+ letters and reports which street-transacting NPCs stand on it or in the four orthogonal
cells. Fifty such pairings exist across the shipped sectors. Sector 32 has
`ARMOURY` at (35,4) with the **Merchant at (38,3)** — directly above the sign, in the same
column. Seeded to (38,5) and `T,Up` queued together, the shop opened.

```
THE ARMOUR SHOPPE:
1-CLOTH, 2-LEATHER, 3-CHAIN,
4-PLATE, 5-REFLECT, 6-POWER,
YOUR INTEREST? 1
THAT 1ST CLOTH
FOR YOU ONLY 0012
NOW 'BOUT IT?
```

### G8 is closed: `DS:96+i` is the owned-armour count, 1-based on the menu number

| reading | before the purchase | after buying CLOTH (menu item 1) |
| --- | --- | --- |
| `DS:96..9F` | `00 00 00 00 00 00 00 00 00 00` | `00 01 00 00 00 00 00 00 00 00` |
| gold `DS:58/59` | `9999` | `9987` |

`DS:97` went `00 → 01` and gold fell by exactly **12**, which is the quoted `0012`. So:

* **the census inference was right** — `DS:96+i` is an owned-armour count table, sitting
  beside `DS:76+i` the owned-weapon table, which is why the asm sites do BCD arithmetic on
  `0x96(%di)` and `0x76(%di)` in the same breath. `engine/src/core/state.h`'s `CANDIDATE,
  NOT PROVEN` note on `0x96` can be promoted.
* **the index is the menu number, 1-based.** CLOTH is item `1` and it set `DS:96+1`. `DS:96`
  itself is unused, so the array is `DS:97..9C` for the six armour types, not `DS:96..9B`.
  Anyone porting this must not zero-base it.

### Two things this exposed

* **The shop closes after one purchase.** A second `T,Up` followed by `3` then `y` produced
  `CMD: - ILLEGAL COMMAND!` and then `CMD: YELL WHAT?` — the menu was already gone and the
  keystrokes fell through to the command loop. So a scripted multi-item buy needs to
  re-open the shop per item, and a driver that does not check for `ILLEGAL COMMAND` will
  silently mis-attribute later keys. **A second armour type was therefore not observed**, and
  the 1-based reading rests on one purchase plus the menu numbering.
* **`tools/u2_edit.py maxout` does not populate the armour table.** The seeded character
  reports `wearing 6 (POWER)` at `DS:62` while `DS:96+6` reads `00`. Either the worn item
  is genuinely not counted as owned, or the seeder is incomplete. **Not established**, and
  it matters: if owned-means-worn, then `DS:96+i` is not an inventory count at all but
  something else that happened to tick on purchase. The weapon array gives no help —
  `maxout` sets all ten of `DS:76..7F` to `01`, so it cannot distinguish the two cases.

### A price data point for § 3b

CLOTH armour quoted `0012`, four digits, printed through the same `DS:27/28` operand pair.
That is a third price setter alongside the tavern's `0005` and the clue seller's
typed-digit-as-hundreds, and it is the first one observed executing rather than read
statically.

## 4. Street NPCs do not transact

Seven `street_*` handlers exist — guard, jester, merchant, fighter, cleric, wizard, thief
(`asm/40E0`–`asm/41D9`). Three of them have commerce-flavoured lines and **none of them
sells anything**: the merchant offers apples (`asm/412C`), the thief offers a watch
(`asm/41D9`), the guard demands taxes (`asm/40E0`). All three are fixed strings with no
purchase path. Bytes are proven; none of the three appears in `ExecutedInstructions` in
any of the 60 harvests, so the trigger conditions are unobserved.

**Amended 2026-10-23:** the last sentence no longer holds — `asm/412C` (the Merchant) has
now been seen executing, in the vendor food sale and again in § 4b's armour shop. What
still holds is that the street handler itself has no purchase path: the transaction runs
through the shop code, and the NPC's role is to be *standing at the right tile*.

## 5. What selects a shop — answered: an NPC standing at the sign

**Closed 2026-10-23 by § 4b.** The selector is neither the tile nor the region nor the
site kind: it is **a street-transacting NPC standing on the shop sign or in the four
orthogonal cells, with `T` and the direction queued together**. Sector 32's Merchant at
(38,3) above the `ARMOURY` run at (35..41,4) opened it on the first try; sector 03, where
no merchant stands beside a letter tile, never has.

`tools/shop_access.py` enumerates every such pairing in the shipped data — fifty of them
— so this is now a lookup rather than a hunt. The letter tile is not the selector on its
own, and neither is the NPC type on its own: the owner confirmed that plenty of characters
behind letter tiles do not sell, and § 4b shows the same Merchant type selling only where
it stands at a sign. **Facing** is the remaining unknown — `T,Up` reached the Merchant two
cells north through a talkable-through letter tile, so the direction names a ray rather
than an adjacent cell, and a teleported save never sets facing at all.

### 5b. The ray, and the message that proves it landed — measured 2026-10-23

`FUNNY, NO RESPONSE!` is **not** a dropped key and **not** a silent failure. It is printed
by `asm/40A6`, and three guards branch into that printer:

| guard | test | reading |
| --- | --- | --- |
| `asm/406E` | `[DS:4A] == 0` | site kind is overworld — nothing deals out in the open |
| `asm/4081` | `AL != 0x7C` | a type byte that is not this |
| `asm/409F` | `AL != 0x68` | **`0x68` is the Merchant type** in the street-NPC table |

So the message means *the ray landed on something that will not deal with you*, and it is
the shared answer for the directional commands — it was observed printing directly after
`CMD: TRANSACT-NORTH`, which is why `asm/40A6`'s `yell_no_response` name is now marked
`NAME DISPUTED` in its header.

**This is the oracle the transaction harness needed.** It separates the three outcomes that
position alone cannot: the key arrived and was rejected, versus the key never arrived. A
`CMD: TRANSACT-<dir>` line followed by `FUNNY, NO RESPONSE!` is a **delivered, rejected**
talk. Silence is a dropped key. `tools/reject_trap.py` does the same job for movement; this
does it for talking, and it needed no trap at all.

**Headless transactions are confirmed working, and my earlier "the recipe does not
reproduce" was wrong.** Sector 32, maxout character at (38,5), `T,Up` at `--delay 0.02`
opened `THE ARMOUR SHOPPE`, `1` quoted `FOR YOU ONLY 0012`, `y` completed it: gold
`9999 → 9987` and `DS:97` `00 → 01`. Reproduced end to end on 2026-10-23 with no human in
the loop. The sector-31 food vendor failed for a different reason than timing: from every
reachable tile the ray returned `NO RESPONSE`, so it was not landing on a `0x68` — the
`monx31` spawn table puts a Merchant at (51,15), but live creatures move, and the shipped
layout is where they *start*, not where they are.

### 5c. How the talk ray actually works — measured, and it explains the failed sweep

`cmd_T` is `asm/4050_cmd_T.asm` (it prints the `TRANSACT-` prefix). The chain, every step
cited to bytes:

1. `asm/406E` rejects if site kind `[DS:4A] == 0`.
2. `asm/407C` and again `asm/409C` call `L_0052b3`, which is **already named**
   `asm/50B3_map_tile_ptr`: `AL = byte[y*64 + x + word[DS:472]]` with `x = DS:23`,
   `y = DS:24`. It returns the **live grid cell**, not a creature record. (What feeds
   `DS:23/24` is *not* established — see the refutation below.)
3. `asm/4085` does `DS:23 += DS:19`, `DS:24 += DS:1A`. Whether that is the ray stepping is
   **not established** — see the refutation below.
4. The cell value must be `0x7C` (`asm/4081`) or `0x68` (`asm/409F`); otherwise the shared
   printer at `asm/40A6` says `FUNNY, NO RESPONSE!`.
5. On a match `asm/40A3` jumps to runtime **`1590`** — the dispatcher that leads to the
   food price. Corroboration: `1590`, `1591`, `1594`, `1596` all appear in
   `ExecutedInstructions` of `captures/spice86/food-buy`.

**The finding that matters: tile `0x68` is the merchant marker, and it lives in the map.**
In `mapx31` the byte `0x68` occurs at exactly seven cells — (14,13), (51,15), (55,19),
(6,41), (51,44), (50,46), (16,48) — and those are **precisely the seven Merchant spawn
slots in `monx31`**, a 7/7 exact match. The map encodes where a transactor stands and the
`monx` record is placed on top of it. So `tools/shop_access.py`'s "NPC standing at the
sign" rule has a sharper form available: **look for tile `0x68`**.

**Why the sweep failed: explained, with one piece still missing.** The cell north of the
player at (51,16) is (51,15), which *is* `0x68`, so it should have matched. Reading the
span as one routine (see `asm/4050_cmd_T.asm`, merged from 13 fragments on 2026-10-23)
gives the seed: `asm/23E6`, called at `4060`, does

```
DS:23 = DS:00 + DS:19      cursor = player_x + delta_x
DS:24 = DS:01 + DS:1A      cursor = player_y + delta_y
DI    = 31                 top creature slot -- start of a downward slot scan
```

So **`DS:19/1A` really is the delta** and the cursor is one delta-step from the player.
Every sample ever taken of `DS:19/1A` has read `(1, 1)` — after all four `T,<dir>` keys
*and* after five movement keys that demonstrably moved the player. So the talk was aiming
diagonally down-right every single time, which is why no `0x68` was ever landed on.
**What is still unknown is who writes `DS:19/1A` from a direction.** Unexamined candidates:
`asm/0B0F`, `asm/1086`, `asm/10AA`, `asm/10BF`, `asm/152E`. That is the last static gap, and
it is a small one.

**The two paths match on different namespaces, and that is what tripped this up.** `0x68`
and `0x7C` are **map grid cell values**; `0x6C`, compared at `40D0`, is a **creature type
byte** read from `[DI+0x197]`. An earlier pass wrote "`0x68` is the Merchant type" and
conflated the two. What is measured about `0x68` is a strong coincidence, not an identity:
in `mapx31` it occurs at exactly the seven `monx31` Merchant spawns (7/7), which says the
map marks where a transactor stands — do not generalise it to other sectors unchecked.

**The scan loop, read.** `asm/23E6` and the fragments after it are **one routine** — a
creature-slot scan, not just a seed:

```
23E6  DS:23 = DS:00 + DS:19 ; DS:24 = DS:01 + DS:1A    cursor = player + delta
      DI = 31                                          top creature slot
2402  al = [DI+0x197]        ; type
2406  cmp al,0 ; je  241f                              empty slot -> next
240A  al = [DI+0x137]        ; x
240E  cmp al,[DS:23] ; jne 241f
2414  al = [DI+0x157]        ; y
2418  cmp al,[DS:24] ; jne 241f
241E  ret                    ; FOUND -- returns with DI = the matching slot
241F  dec DI
2420  jne 2402               ; scan downward
2422  ret                    ; EXHAUSTED -- returns with DI == 0
```

That closes the puzzle raised in `asm/4050_cmd_T.asm`'s header. `4075`'s `cmp bl,0;
jne 40C0` is **not** dead code and the map-tile path is not unreachable: `DI` is whatever
the scan left behind, so a creature standing on the cursor takes the creature path and an
empty cursor falls through to the map-tile path. The branch structure and the runtime
behaviour now agree.

**What writes `DS:19/1A` is still open, and the obvious candidates are wrong.**
`asm/1086` loads `DS:19` from `[DI+0x1F7]` and `DS:1A` from `[DI+0x217]`, indexed via
`DS:25`, and `asm/10AA`/`asm/10BF` are the matching writers into those arrays. Those are
**per-entity arrays, not direction vectors** — so `DS:19/1A` is being loaded from
somewhere that has nothing to do with a keystroke, which is consistent with it reading
`(1,1)` in every sample and is *not* consistent with it being the talk direction. Two
unexamined writers remain (`asm/0B0F`, `asm/152E`).

**So do not claim the ray is aimed by the direction key.** What is measured: the cursor is
`player + DS:19/1A`, the scan looks for a creature on that cell, and `DS:19/1A` has never
read anything but `(1,1)`. What is not known: what is supposed to put a direction in there.
That is the remaining gap, and it is the one that matters for G23.

**Grades.** The guards, the `1590` success jump, the `23E6` seed arithmetic, the scan loop
above and the 7/7 tile match: **measured**. "The scan resolves the DI branch": **measured**,
it follows from the loop's two exits. The direction→delta writer: **unknown**, and the
`10AA`/`10BF`/`1086` family is now ruled out rather than merely unexamined.


**The earlier claim stays withdrawn.**

**I wrote here that a shop is selected by the player's region within the sector plus the
site kind, citing `asm/1590`–`asm/15D0` as trampolines. That is disproven and removed.**
A live test on 2026-10-22 — seeded to sector 31 (Port Boniface) directly below the
`MC DONALLS` sign, `T` sent — executed `cmd_T` at `4050`/`405D` and then went to the
return-to-prompt path at `0C33`. **None of `1590`–`15D0` executed.** Those fragments sit
immediately before `asm/15E1_tavern_menu` and are at least as likely to be tavern
plumbing. The `DS:4A == 2` test in `asm/15BA` is real bytes; what it dispatches is not
known.

What is known about the trigger: the letter tile is not the selector, and neither is the
NPC type standing behind it — the owner confirmed that plenty of characters behind letter
tiles do not sell. The remaining suspect is **facing**, which a teleported save does not
set. See `docs/place-names.md` § 4.

## 6. Why G21 was never answered — a boundary defect (this is G22)

`asm/19D7_magic_shop_menu.asm` declares `# func 19D7..2027`, **0x651 bytes**, and
contains **59 strings**, including the armour shoppe (`1D20`), the weapons shoppe
(`1E52`), the horse shoppe (`1F93`) and the clue seller (`1B02`).

That is at least four distinct shop routines inside one file named after one of them.
Anyone searching for "the shop code" finds a file labelled *magic shop menu* and stops.
**This is why the commerce subsystem looked unmapped — it was not unmapped so much as
filed under the wrong name.**

Splitting it is a Phase 2/3 function-boundary change, which touches the byte-proof
harness, so it is **recorded as a defect and not done here.** It needs the owner's
go-ahead and a per-function `check_func.py` run for each new range.

## 7. Follow-ups

| item | note |
| --- | --- |
| ~~Find the branch that selects between the two spell catalogues~~ **closed same day** — there is no town branch; the two lists are the cleric shrine and the wizard shop, each class-gated | resolved above |
| ~~Find the real price source~~ **closed 2026-10-23 for the mechanism** — `DS:27/28` is the price operand, printed by `asm/51A5` and charged by `asm/2052`; see § 3b | resolved above |
| **G23** — read `DS:27/28/29/2A` and `DI` live at runtime `17B7` and `2052` during a vendor purchase, to settle whether the food price is a constant or is derived from `int + cha` | the one datum § 3b cannot get statically; registered in `docs/needs-gameplay.md` |
| Walk each shop routine's arithmetic to confirm every price is computed | closes the § 1 limit |
| Split `asm/19D7` into its real routines | boundary change, needs approval + `check_func.py` per range |
| Confirm `[DS:46]` is gender and find the class byte the `NOT A CLERIC/WIZARD` guards test | the guards exist; the tested field is not yet named |
