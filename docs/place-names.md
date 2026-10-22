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

237 letter runs of 3+ tiles across 15 sectors. **Corrected 2026-10-23:** the sweep
never required 3 — `tools/map_signs.py` has emitted runs of 2 or more throughout, and
the regenerated inventory in `disasm/map-signs.txt` now says so. The count that matters
is § 2b: fifteen sectors carry signs, and they are exactly the fifteen with dialogue. Readable names:

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

## 2b. The vertical sweep — measured, and the answer is no

The first sweep read rows only, so `tools/map_signs.py` was extended to scan columns as
well and to classify every column run it finds. **There is no vertical signage in this
game.** Every column run of two or more letters in all 33 sectors falls into one of two
explained buckets:

* **two horizontal signs printed on neighbouring rows.** `REST` over `ROOM` at (50,13)
  in sector 31, `BARADINS` over `TOWN` at (28,35) in sector 11, `TIME` over `ZONE` at
  (15,29) in sector 03, `MESS` over `HALL`, `THE` over `ARMOURY`, `YOUR` over `CHEF`,
  `TOMMERSVILLE` over `CORNER`. Read down the columns these produce nonsense like
  `RR EO SO TM`, which is what a naive vertical sweep would have reported as signs.
* **the lone-`I` graphic.** `I` (byte `0xA0`) is used as a small mark on town structures
  and not only as a letter: **94 of its 169 shipped occurrences (55.6 %) sit outside any
  word**, four times the lone-rate of any other non-`A`/`Y` letter, and they sit in dot
  patterns (sector 03 at (4,2),(8,2),(4,6),(8,6); sector 92 at the map edges (0,31),
  (63,31),(0,32),(63,32)) rather than in columns. Four column runs were left over once
  the first bucket was removed and all four are this: `II` at (5,21) in sector 41, `II`
  at (0,31) and (63,31) in sector 92, `BI` at (33,3) in sector 93.

The classifier is not taken on trust. `python3 tools/map_signs.py --selftest` builds a
synthetic sector holding a genuine downward sign `BAR`, a stacked `REST`/`REST` pair,
a lone-`I` column, and a flooded sector that also spells a sign, and asserts each lands
in the right bucket. Inverting either the `VERTICAL` branch or the `graphic-I` branch
makes it exit non-zero, which is the check that it can fail.

**What the first pass actually missed, therefore, was not vertical text.** It was that a
sign can occupy two rows, so eight two-line signs were recorded as sixteen unrelated
names. And the eight A/Y sectors — `mapx15/24/25/34/35/44/45/85` — produced 1556 of the
1731 lines the first pass emitted, every one of them `AAA` or `AYAYA`. They are now
summarised rather than dumped, on a measured rule rather than a threshold guess: in
those eight sectors **100.0 % of the letter tiles are A or Y**, while the highest
non-structural sector reaches 15.7 % (sector 93). The populations do not overlap.

## 2c. Sector to town — the join

The question § 4 left open ("which sector is which named town") closes, and the
invariant the queue asked for holds exactly:

> **The 15 sectors that carry readable signs are precisely the 15 sectors that ship a
> `tlkx` dialogue file.** Measured over `original/mapx*` and `original/tlkx*`; the two
> sets are equal, all fifteen have ones digit 1, 2 or 3, and none of the ones-digit
> 0/4/5 sectors has either. Two independent data channels — terrain and dialogue —
> agree on the same sector list, which is stronger evidence than either alone.

| sector | kind | town name the signs spell | shop and place signs | `tlkx` speakers |
| --- | --- | --- | --- | --- |
| 03 | 3 | none — a castle, not a town | SHADOW GUARD, CHAMBER ONE, CHAMBER TWO, TIME ZONE, MUSEUM, TORTURE CHAMBER, APOTHECARY, THIEVES GUILD, MORGUE, DEVIL, WORSHIP | SHE CREATURE, HOMER THE SALESMAN, DAVID ALPERT, MINAX |
| 11 | 1 | **BARADINS** (`BARADINS` row 35, `TOWN` row 36) | ORACLE, THE DELI, MAGES, CLERGY, MAGIC | ASTRONAUT, DRUID, PHYLOSOPHER |
| 21 | 1 | none spelled | ALFREDS / FISH N CHIPS, GORKY, LE JESTER, WIZARDRY, HOLY SPELLS | GRENDEL THE BUM, ANDY GREENBERG, ROBERT WOODHEAD, CHASTE NUBILE NYMPH |
| 22 | 2 | **LINDA** (row 63 banner `TOWNE` + `LINDA`) | PUB DE VARG, THE ARMOURY, WEAPONS, TRANSPORT | ITHILIAN THE WENCH, JOHN MAYER, GERRY MAYER, KEITH |
| 23 | 3 | none spelled | VAULT, LORD BRITISH, KITCHEN, MESS HALL, PRISON, THE CHAPEL | BROTHER ANTOS, BISHOP BOB, ANDRE THE FRENCH CHEF, COMMANDER DECKER, WANDERING BARD |
| 31 | 1 | **PORT BONIFICE** (spelled twice, rows 30 and 57) | MC DONALLS, SEER, REST ROOM, TAKE OUT, CHAD, MADS, CHAPEL, ROAD | RONALL MC DONALL, LADY SHERRIE, SIGHTLESS SAGE, LADY MARY ELLEN, WANDERING BARD |
| 32 | 2 | **NEW SAN ANTONIO** (row 63 banner `NEW SAN` + `ANTONIO`) | AIR PORT, ARMOURY, THE HOTEL, PUB AND PIZZA, THE POOL, STABLES, CUSTOMS, PRISON, TRANSPORT, SWASHBUCKLERS, IOLO, GWEN, NEW SAN | SANTRE THE SWASHBUCKLER, OLD MAN, FLOPY FIGHTER, CLERK |
| 33 | 3 | none spelled | identical sign set to sector 23, same coordinates | BROTHER ANTOS, SISTER SLEDGE, ANDRE THE FRENCH CHEF, MERCHANT, SUBDUED BALRON |
| 41 | 1 | none spelled; `PIRATES COVE` and `RED LOBSTE` are the candidates | CCCP DEFENCE, DA KGB, CCCP TEST LAUNCH, CONTROL, MINIS_RY, PIRATES COVE, PROPAGA_DA, SEER IS OUT, TASS SKWARE, CATOLIK, MAGIC, HARBOUR | WAREN BEATTY, CHUCKLES THE BUMBLE, VILLAGE IDIOT, RED THE PIRATE |
| 61 | 1 | none spelled; `FOOLS` + `ISLAND` are the candidates | MONKEY, MORE, WARD, SEARS x3, TO GO, JACK IN DE BOX, BIG TOP, VISIT FOOLS, ISLAND, MAGIC IS FUN, DRUID, DARE THE SWAMP, IF YOU DARE, NEW JESTER | SWAMP JESTER, COURT JESTER, FRENCH JESTER, STONED JESTER |
| 71 | 1 | none spelled | CABIN ONE..NINE, CAMP, FIRE, SEER, COOK, MESS HALL, CRAFTS, POOR DEBBIES POOL, GOOD MAGIC, COMPUTER | DEBBIE THE LIFEGUARD, RICHARD GARRIOTT, HOWIE THE PEST, JOHNATHON BEN |
| 81 | 1 | **TOMMERSVILLE** (row 58, with `CORNER` above at row 56) | SOFTALK, YOUR CHEF, KURTS, CLERGY | MARGOT TOMMERVIK, AL TOMMERVIK, BIG BOB JAWS, BILL BRUISER |
| 82 | 2 | **MAKLER** (row 63 banner `TOWNE` + `MAKLER`) — weakest of the four | GEORGES ARMS, BETHS ARMOR, ADAMS PUB, HORSE MAKLER | SEAWORTHY PIRATE, BURLY PIRATE, UGLY SMELLY PIRATE, BIG BOUNCER |
| 92 | 2 | **BASKO** (row 63 banner `TOWNE` + `BASKO`) | WEAPONS LTD, OZY ARMOURY, TRANSPORT, NO MAGES, GET DRUNK AT OZYS, OFFENDERS, EXIT HERE | UGLY IRVING, KIETH ZABALAOUI, EXPERIENCED WARRIOR, WIMPY WARRIOR |
| 93 | 3 | none spelled; `BARATARIA` + `CASTLE` is the place | KUEEN SUSANS ROOM, KING OZYS ROOM, CASTLE, BARATARIA, JAIL, LE CHAPEL, KITCHEN, OZYS PLACE | FATHER ANTOS, SING LEE THE COOK, JUSTIN THE JAILER, QUEEN SUSAN |

**Grade.** The sign text and the speaker list are **observed** (decoded from
`original/mapx*` and `original/tlkx*`). Which run is the *town* name as opposed to a
shop is **inferred**, with one exception: the row-63 banner. Four sectors put a word at
x=24 and another at x=35 on the bottom row and nowhere else — `NEW SAN`+`ANTONIO`,
`TOWNE`+`LINDA`, `TOWNE`+`MAKLER`, `TOWNE`+`BASKO`, at identical coordinates. Sector 32
is the one that decodes cleanly, because sector 82's dialogue says *SEE THE CLERK IN
NEW SAN* and *NEW SAN. IS FULL OF MAGIC!*, so `NEW SAN ANTONIO` is a name and not two
signs. That is the only member of the four whose reading a second file confirms.

### The dialogue corroborates the signs, nine times

This is the part that makes the join more than a guess. In nine sectors a `tlkx` speaker
names, or is named by, a sign in the same sector's terrain:

| sector | sign | speaker |
| --- | --- | --- |
| 31 | `MC DONALLS` | **RONALL MC DONALL** SINGS: TRY OUR NEW RIDE THROUGH! |
| 32 | `SWASHBUCKLERS` | **SANTRE THE SWASHBUCKLER** WARNS: BEWARE, I'VE A QUICK BLADE! |
| 71 | `POOR DEBBIES POOL` | **DEBBIE THE LIFEGUARD** YELLS: GET A BIG GRIP! |
| 81 | `TOMMERSVILLE` | **MARGOT TOMMERVIK**, **AL TOMMERVIK** |
| 92 | `NO` `MAGES` | UGLY IRVING STATES: **NO MAGES ALLOWED!** |
| 93 | `KUEEN SUSANS ROOM` | **QUEEN SUSAN** SAYS: FATHER ANTOS AWAITS YOU! |
| 93 | `JAIL` | **JUSTIN THE JAILER** WARNS: I WOULDN'T GO IN THERE! |
| 23/33 | `KITCHEN` | **ANDRE THE FRENCH CHEF** |
| 41 | `PIRATES COVE`, `RED  LOBSTE`, `DA RED` | **RED THE PIRATE** BOASTS: I'VE A BROKEN ULTIMA ]I[, WANT ONE? |

A sector's dialogue and a sector's terrain were authored together, and this is the
mechanism. It also means the `tlkx` files are a second, independent copy of the same
name inventory — which is how `NEW SAN` in sector 82's dialogue identifies sector 32.

### Two things the join exposes

* **`mapx23` and `mapx33` carry byte-identical sign layouts at identical coordinates,
  yet `tlkx23` and `tlkx33` are different files.** So the same town plan is re-used with
  different residents. Sector 33's dialogue adds BROTHER ANTOS INQUIRES, SISTER SLEDGE,
  THE MERCHANT and THE SUBDUED BALRON where sector 23 has BISHOP BOB and COMMANDER
  DECKER. This is the same shape as the already-known `mapx25`/`35`/`45` triple, which
  are byte-identical outright — but here the maps differ in terrain while agreeing in
  text, which is a subtler coincidence and worth not glossing.
* **`tlkx` files hold leftover records.** Every file ends with two or three fragments
  that are the tails of earlier lines (`A BAD THING...` in sector 03, `AN JOSE?` in
  sectors 33 and 41, `T HERE!` in sectors 61 and 71). They are not dialogue. The
  decode in `tools/tlkx_decode.py` prints them rather than hiding them, because a
  filter that silently drops records is how a real line gets lost.

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

* **How `T` reaches a shop — SOLVED, by the owner driving over VNC.** The mechanism is
  `T` immediately followed by a direction, both queued together
  (`spice86_type.py --keys T,Up --delay 0.02`), and arrow keys require launching with
  `--patch-arrows`. The owner talked to a **Fighter** and bought food; the harvest shows
  461 never-before-executed addresses including the food routine at `179B`–`1826`. Full
  detail in `docs/commerce.md` § 3.
* **The jester does not respond to `T`.** Confirmed twice: once by my automated attempt
  (`TRANSACT-NORTH`, no reply) and once by the owner driving directly. The **Fighter**
  does: `A FIGHTER SAYS: UGH, ME TOUGH!` (`asm/415F_street_fighter`). So `docs/place-names.md`
  should not be read as "the nearest NPC is the shopkeeper" — the NPC type matters.
* **And the facing hypothesis was never actually tested.** The screen also revealed
  `CMD: - ILLEGAL COMMAND!` for every arrow key sent, so **the player never moved** in any
  of these runs. All three attempts were "teleported to a tile, press `T`", which is not
  the same experiment. Work out the real movement keys first; until then no
  position-dependent result from a seeded save should be trusted.
* **Which sector is which named town — ANSWERED 2026-10-23, see § 2c.** The fifteen
  sign-bearing sectors are exactly the fifteen with a `tlkx`, and the dialogue names
  nine of the signs outright. Four sectors spell a town name on a row-63 banner
  (`NEW SAN ANTONIO`, `LINDA`, `MAKLER`, `BASKO`) and two more spell one anywhere in the
  sector (`BARADINS`, `TOMMERSVILLE`, `PORT BONIFICE`). What is *not* settled is which
  shop stocks what — that is `docs/commerce.md` and ticket G21.

## 5. A claim I am withdrawing

Earlier today I wrote in `docs/commerce.md` § 5 that the shop is selected by the player's
**region within the sector** plus the site kind, citing `asm/1590`–`asm/15D0` as
trampolines. **This capture disproves the mechanism as stated:** none of those addresses
executed when `T` was pressed. They sit immediately before `asm/15E1_tavern_menu` and are
at least as likely to be tavern plumbing as shop dispatch. The `DS:4A == 2` test in
`asm/15BA` is real, but what it dispatches is unproven. Corrected in `commerce.md`.

Same shape as everything else this session: two adjacent fragments that look like a
dispatch, described as one without evidence.
