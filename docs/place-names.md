# Place names — towns and shops are spelled out of map tiles

Found 2026-10-22 from an owner recollection. This is a structural finding: **no town name
and no shop name exists as a string in the executable.** They are drawn on the map as
individual letter tiles.

Grades per `AGENTS.md` § 5.

## 1. The mechanism — measured

Map bytes `0x80`–`0xE4` in steps of 4 decode to the letters `A`–`Z`:

```
letter = chr('A' + (byte - 0x80) // 4)
```

Placed in runs, they spell signs. Reading sector 31 as text:

```
y= 0 | THINGS ARE NOT AS THEY SEEM         SAIL OUT THE NORTH CHANNEL
y=26 |                     I                      MC     DONALLS
y=30 |       PORT BONIFICE
y=57 |                         PORT  BONIFICE
```

This is why every string survey of the binary missed them. `BONIFACE`, `DONALLS` and
`MCDONALD` return **zero hits** in `original/ultimaii.exe` — the names are not in the
code, they are terrain.

**It also resolves the open tension in `docs/passability-findings.md` F13**, which asked
why `0x80` (`A`) occurs 15,651 times across 23 sectors — far too often to be a sign.
Sector 15 answers it directly: its top rows are solid blocks of `A` and `Y` tiles that
are plainly structure, not text. **`A` and `Y` carry a second use as generic solids**, and
F13's suspicion that they did was correct.

## 2. Name inventory — measured

237 letter runs of 3+ tiles across 15 sectors. Readable names:

| sector | names and signs |
| --- | --- |
| 03 | SHADOW, GUARD, CHAMBER, TIME ZONE, MUSEUM, TORTURE CHAMBER, APOTHECARY, THIEVES GUILD, MORGUE, DEVIL, WORSHIP |
| 11 | **BARADINS TOWN**, ORACLE, DELI, MAGES, CLERGY, MAGIC |
| 21 | **ALFREDS CHIPS FISH**, GORKY, HOLY, JESTER, SPELLS, WIZARDRY |
| 22 | **LINDA PUB**, ARMOURY, THE TOWNE, TRANSPORT, VARG, WEAPONS |
| 23, 33 | BRITISH, CHAPEL, LORD, MESS, PRISON, VAULT, KITCHEN, HALL |
| 31 | **PORT BONIFICE**, **MC DONALLS**, SEER, REST ROOM, CHAD, MADS, CHAPEL, ROAD |
| 32 | **ANTONIO**, **GWEN**, **IOLO**, PIZZA, HOTEL, PUB, ARMOURY, STABLES, SWASHBUCKLERS, CUSTOMS, PRISON, TRANSPORT, POOL |
| 41 | **CATOLIK**, **LOBSTE**, **TASS SKWARE**, RED COVE, KGB, CCCP, LAUNCH, PIRATES, DEFENCE, PROPAGA |
| 61 | **JACK**, **BIG BOX**, FOOLS, FUN, MONKEY, DRUID, ISLAND, SWAMP |
| 71 | **DEBBIES**, CABIN, CAMP, COMPUTER, COOK, CRAFTS, MESS, POOL |
| 81 | **KURTS**, **TOMMERSVILLE**, **TOMMERSVILLE CORNER**, CHEF, CLERGY, SOFTALK |
| 82 | **ADAMS**, **BETHS**, **GEORGES**, HORSE MAKLER, ARMOR, ARMS, PUB, TOWNE |
| 92 | **BASKO**, **OZY'S**, ARMOURY, DRUNK, MAGES, TRANSPORT, WEAPONS |
| 93 | **KING KUEEN**, **SUSANS**, BARATARIA, CASTLE, CHAPEL, JAIL, KITCHEN |

Personal names own the shops — Linda's Pub, Alfred's Chips Fish, Antonio's, Gwen's,
Debbie's Cabin, Kurt's, Beth's, George's, Adams, Susans, Ozys, Barataria. Several are
visible parodies, and the Cold War jokes in sector 41 (KGB, CCCP, Red Cove, Propaganda)
sit alongside them.

## 3. The owner recollection, checked

Recalled: a town called **Port Boniface** with a food shop called **McDonels** or similar,
a McDonald's parody, and a suspicion that a recording of it exists.

| part | verdict |
| --- | --- |
| Port Boniface exists | **confirmed** — sector 31, spelled twice |
| A food shop with a McDonald's-parody name | **confirmed in substance** — the sign reads **`MC     DONALLS`**, not *McDonels*. The `MC` prefix and the parody structure are exactly as recalled |
| A recording of it exists | **not found.** No capture in `captures/spice86/` was taken in sector 31, and no screen text of it was ever dumped |

Per the project rule that an owner observation outranks an agent inference: the recollection
located this. The bytes refined the spelling. Both were needed.

## 4. What is still not known

* **How `T` reaches a shop.** Tested three times on 2026-10-22 in sector 31 at (52,27),
  directly below the `MC DONALLS` sign. The screenshot now shows the game's own verdict:
  **`CMD: TRANSACT-PASS`** — the key was received, `cmd_T` ran, and the game chose to do
  nothing. No shop code executed.
* **And the facing hypothesis was never actually tested.** The screen also revealed
  `CMD: - ILLEGAL COMMAND!` for every arrow key sent, so **the player never moved** in any
  of these runs. All three attempts were "teleported to a tile, press `T`", which is not
  the same experiment. Work out the real movement keys first; until then no
  position-dependent result from a seeded save should be trusted.
* **Which sector is which named town.** Sector 31 is Port Boniface because the sign is
  *in* it, but that is one data point. The `tlkx` files are keyed by sector and the names
  are keyed by sector, so the mapping is available — it just has not been assembled.

## 5. A claim I am withdrawing

Earlier today I wrote in `docs/commerce.md` § 5 that the shop is selected by the player's
**region within the sector** plus the site kind, citing `asm/1590`–`asm/15D0` as
trampolines. **This capture disproves the mechanism as stated:** none of those addresses
executed when `T` was pressed. They sit immediately before `asm/15E1_tavern_menu` and are
at least as likely to be tavern plumbing as shop dispatch. The `DS:4A == 2` test in
`asm/15BA` is real, but what it dispatches is unproven. Corrected in `commerce.md`.

Same shape as everything else this session: two adjacent fragments that look like a
dispatch, described as one without evidence.
