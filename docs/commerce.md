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

The tavern is the worked example. On `1-BUY` the routine sets a 16-bit value at
`DS:27/28` to **5** (`mov $0x5,%al; mov %al,0x28` / `mov $0x0,%al; mov %al,0x27`) before
printing the price. The clue seller asks the player to type an amount and multiplies it
by 100. Neither reads a table.

Gold income is separate and already named: `asm/2D8C_combat_kill_reward` prints
`KILLED--GOLD+`, so kills award gold directly.

## 4. Street NPCs do not transact

Seven `street_*` handlers exist — guard, jester, merchant, fighter, cleric, wizard, thief
(`asm/40E0`–`asm/41D9`). Three of them have commerce-flavoured lines and **none of them
sells anything**: the merchant offers apples (`asm/412C`), the thief offers a watch
(`asm/41D9`), the guard demands taxes (`asm/40E0`). All three are fixed strings with no
purchase path. Bytes are proven; none of the three appears in `ExecutedInstructions` in
any of the 60 harvests, so the trigger conditions are unobserved.

## 5. What actually selects a shop — not the tile, and not the NPC behind it

**measured from the trampolines, not yet observed running.** The `T` path reaches a set of
small dispatchers that branch on **where the player is standing in the sector** and on the
**site kind**:

| routine | test | target |
| --- | --- | --- |
| `asm/1590` | `DS:00` (player x) vs `0x20` | region split |
| `asm/1598`, `asm/15A2` | `DS:01` (player y) vs `0x20` | `jb` → `L_0017ba` |
| `asm/15B4` | — | runtime `1F1D` |
| `asm/15BA` | `DS:4A` (site kind) `== 2` | `204F` if so, else `1CE0` |
| `asm/15D0` | — | runtime `2175` |

So a sector is divided into regions and each region has its own shop entry, and the site
kind picks between two of them. **The letter tile byte is not the selector and the NPC type
behind it is not either** — which is why the "find a merchant standing behind a letter
tile" heuristic was wrong and the sector-41 target built on it was aimed at the wrong
thing. The owner's correction stands: plenty of characters stand behind letter tiles and do
not sell.

**The right experiment** is to stand in each region of a town sector and press `T`, not to
hunt for a particular NPC. That also means G22's evidence gap is a *position* problem, and
the region boundaries are readable statically from these tests.

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
| Walk each shop routine's arithmetic to confirm every price is computed | closes the § 1 limit |
| Split `asm/19D7` into its real routines | boundary change, needs approval + `check_func.py` per range |
| Observe a real purchase | none of the shop routines appears in any harvest; all behaviour here is static |
| Confirm `[DS:46]` is gender and find the class byte the `NOT A CLERIC/WIZARD` guards test | the guards exist; the tested field is not yet named |
