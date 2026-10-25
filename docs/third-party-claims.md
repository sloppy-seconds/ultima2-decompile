# Third-party claims: the Adric/Alzurian cheat sheet

**Grade: third-party hypothesis. The bytes get veto.** This file exists so a period walkthrough
can be *tested* against `asm/` rather than absorbed into it. Nothing here is a finding about this
binary unless a byte citation says so, and `AGENTS.md` § 3 is explicit that a third-party name
never gets promoted into an `asm/` filename on the strength of being third-party.

Source: "Ultima II: Revenge of the Enchantress — Cheat Sheet by Adric, Alzurian, with help from
Michael Stringer and The Beckster", a BBS-era walkthrough supplied by the owner 2026-10-28e.
Two other third-party items already on record: the grocery table (same day) and `bestiary/`.

Why it is worth a file rather than a paragraph: it names **concrete item gates for three of the
four command handlers this project parked as unproven**, which converts "needs a capture to find
out" into "needs a capture to confirm a specific prediction". That is a much cheaper experiment,
and a prediction that fails is a finding in its own right.

## 1. Claims already corroborated by bytes

| claim | byte evidence | grade |
| --- | --- | --- |
| `V` (View) requires a **helm** | `asm/437E_cmd_V.asm` prints `VIEW<0x8d>WITH MAGICAL HELM!` | corroborated — the string exists in the handler that the cheat sheet says needs the item |
| `L` (Launch) a plane requires a **brass button** | `asm/38B0_cmd_L.asm` prints `FUNNY THIS PLANE IS<0x8d>MISSING A BRASS BUTTON!` | corroborated — a refusal message for exactly that absence |
| `B` (Board) a frigate requires a **blue tassle** | `asm/4C50_plane_landing_site.asm` holds `db "UE TASSLE"` | corroborated *and* defective — see § 3 |
| `L` (Launch) a rocket consumes a **tri-lithium** | `asm/363B_cmd_G.asm` prints `TRI-LITHIUM!`; `asm/4C50` holds `db "I-LITHIUM"` | corroborated *and* defective — see § 3 |
| `W` (Wear) offers an armour menu with a strength gate | `asm/43F3_cmd_W.asm` prints `WEAR ARMOUR:` + `1-CLOTH, 2-LEATHER, 3-CHAIN, 4-PLATE, 5-RE...` | corroborated as a menu; the gate itself is the unresolved part (see `commands.c`) |
| the **force field** needs the ring | CP5 ticket C5: ring gate `[DS:D6]`, exactly −1000 via `stc; sbb al,0x10; das`, both branches executed in `captures/spice86/g29-field` | **proven**, and the cheat sheet independently agrees |
| Charisma affects **prices** | `asm/20AB_bcd_price_from_stats` derives a price from `[DS:50] + [DS:4E]`, and higher stats give a *lower* number; the grocery table's 52 gp is the 6th value the loop can produce | corroborated twice from two third-party sources; still not proof, and the `DS:4E` charisma-vs-wisdom dispute is untouched |
| **gremlins steal food** | `asm/12DB_dungeon_events.asm` prints `A GREMLIN STOLE SOME FOOD!` | site exists; the claimed *fixed 100 units* is unverified and is worth checking, because CP5 C6 already found one "fixed" theft in this game was really a rolled BCD decrement |

## 2. Claims the binary does not corroborate (yet)

- **"Negate Time needs a strange coin."** ~~No `STRANGE COIN` string exists anywhere in `asm/`~~
  **the absence is explained, 2026-10-25: the name is in the pool.** `STRANGE COIN` is entry 13
  of the extracted items table and `QUICK SWORD` entry 9 of the weapons table (both 0-based, as
  `extractor.py` emits them) of the indexed name pool that
  `docs/status-screen-z.md` § 7 describes — the region `asm/4C50_plane_landing_site.asm` renders
  as invented instructions, which is why neither string appears in `asm/` as a `db`. The pool is
  read by `engine/tools/extract/extractor.py` from the exe and asserted against the `HANDS == 19`
  anchor, so both names are binary text, not walkthrough paraphrase. **So this is not a
  refutation of the claim and never was.** What the claim still lacks is the other half: that
  `cmd_N` consults that item at all, which is the parked-handler question in
  `engine/src/game/commands.c`, and it needs a capture of `N` running (it is one of the four
  handlers with no execution evidence).
- **"Launch a plane needs a skull key."** ~~not corroborated~~ **REFUTED AS A GAP — it is
  corroborated.** The first search looked for `SKULL KEY` (singular) and found nothing; the hint
  table says `AVIATORS USE SKULL KEYS!`. Recorded here because the miss was the search's, not the
  binary's, and because "absent from my grep" is not "absent from the game".
- **"The Quicksword is the only weapon that can kill Minax."** Not checked. It is a strong,
  cheap, falsifiable claim and `asm/2BA5_attack_arms_gate.asm` is the place to look.

## 3. The real find: an in-game hint table in the binary, and a decode defect on top of it

Chasing the cheat sheet's item names turned up a contiguous NUL-separated **hint table** in
`original/ultimaii.exe` at file `0x18xx..0x1990`, which states several of these requirements from
the binary itself rather than from a walkthrough:

```
SOME FIGHTERS WEAR MAGIC HELMS!
AVIATORS USE SKULL KEYS!
SAYLORS WEAR BLUE TASSLES!
MAGES CARRY WANDS OR STAFFS!
GUARDS CARRY KEYS!
ANKHS OPEN SPACE!
PLANES NEED BRASS BUTTONS!
```

That is seven in-game claims mapping onto the cheat sheet: helms for the view, skull keys and brass
buttons for launching a plane, blue tassles for a frigate, keys carried by guards (the cheat sheet
says exactly that: "to get keys, kill guards"), and ankhs opening space. It is the strongest
third-party-independent corroboration in this file, because the strings are the game's own.

**And the defect, stated correctly after a first version of this section got it wrong.** The
strings are complete in the binary. What is broken is the reconstruction: `asm/4C50_plane_landing_site.asm`
renders this region as alternating `db` fragments with **invented instructions between them** —

```
L_00506f:  add    %al,0x4c(%bp,%si)      # these are string bytes, not code
L_005072:  db "UE TASSLE"                # tail of "SAYLORS WEAR BLUE TASSLES!"
...
L_005093:  add    %dl,0x52(%si)          # also string bytes
L_005096:  db "I-LITHIUM"
```

— so the clean wave decoded text as machine code and cut the strings mid-word. `asm/4C50`'s own
`# strings:` line already admits fragments like `"GGER"`, `"CE"`, `"ORD"` alongside 48 others.
This is the same class as the G22 splits and the `asm/353A`/`asm/353D` forced-keep swallow, and it
means `asm/4C50`'s span is not trustworthy as code. `tools/fragment_splits.py` nominates it;
`tools/recut_bytes.py` can re-cut once the boundary is agreed. **A walkthrough read led to a
decode-tree bug** — a route nobody here had tried.

## 4. Claims that are out of scope or parked

Dungeons (`food declines in dungeons`, the dungeon light timer, the wireframe view) are parked per
`AGENTS.md` § 3. Planet coordinates (X = 9-9-9, Earth = 6-6-6), the time-door network, Minax's
teleport at low HP, and the specific NPC scripts (Lord British's 50-gold-for-300-HP, the Hotel
California merchant's random +4 attribute, Father Antos's blessing, the old man's 900 gold for
the ring) are all town/NPC behaviour, which is CP6 and needs the town command set first.

One of them deserves flagging because it contradicts a measured finding rather than an open
question: the cheat sheet distinguishes **non-diagonal and diagonal versions of the game** and
gives different routes for each. This project measured a diagonal step at `asm/212e` and recorded
it as simply how creatures move. If diagonals are a *version* difference, that measurement is
build-specific and the engine may be modelling a variant. Worth a look before CP6 hard-codes it.

## 5. How to use this file

Treat every row as a prediction with a named place to test it. When a capture or a byte settles
one, the finding goes in `asm/`'s header or `docs/spice86-live-findings.md` — **not here**. This
file is the intake queue, and a row that has been settled should be replaced by a pointer to where
the answer now lives, so there is never a second copy of a conclusion.
