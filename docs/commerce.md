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
(prints the pair). But `asm/20AB_sub_20ab.asm`, the routine `17B2` calls, writes
`DS:27=0x00` and `DS:28=0x04` — which would print `0004`, not `0200`. So one of three
things is true and the bytes read so far do not separate them:

1. the food quote does not enter through `asm/17B2`, and `asm/17B7` is reached from
   somewhere else with the pair already loaded;
2. `sub_20ab` is not a price setter but a **BCD multiply by repeated addition** —
   `asm/20EB_sub_20eb.asm` adds `DS:27/28` into `DS:29/2A` under `dec %di; jne`, and
   `sub_20ab` seeds both pairs with `0x0004` and derives a loop count from
   `popcount([DS:50] + [DS:4E])`, i.e. from **int + cha** — and the product lands in
   `DS:29/2A`, not `DS:27/28`;
3. something rewrites the pair between the two calls.

Option 2 is the interesting one and it is only half-read: a price derived in part from the
character's intelligence and charisma would be a genuine mechanic, and it would explain
why nobody found a price table. It is **not established**. The single datum that settles
it is a live read of `DS:27`, `DS:28`, `DS:29`, `DS:2A` and `DI` at runtime `17B7`, plus
one at `2052`, during a real vendor transaction. That is a capture, not a static search,
and it is registered as **G23** in `docs/needs-gameplay.md`.

**What is settled regardless:** there is no price table, the printed price and the charged
price are the same operand pair, and two of the three observed price setters are pure
immediates or byte placement. The `2 gold per food point` figure the owner measured is
consistent with a `0200` per-100 quote and needs no table to explain it.

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
