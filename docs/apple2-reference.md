# Apple II reference disks (UCSD p-System volume set)

Owner added `references/apple/Ultima II (4am crack)/*.dsk` alongside `references/ultima3/`.
Nothing in this tree referenced them until the session that produced this file, when they
were read, parsed and extracted.

They matter because they are the **other half of the lineage claim** in `AGENTS.md` § 1.
That section asserted the DOS port is a translation of Garriott's 6502. Until now that
was an assumption carried in prose. It is now something we can test byte by byte, which
changes Step 3 of gameplay-logic work from "guess at 6502 idioms" to "read the 6502".

## 1. What the images actually are

Three 140 KB unadorned images. `cp2` identifies disk 1 as:

```
Disk image (Unadorned, order=dos/sect) - 140KB ProDOS "ULTIMA2", 17 blocks free
```

Two things that cost time, recorded so nobody pays them twice:

* **`order=dos/sect`.** The `.dsk` is in DOS sector order, not ProDOS block order. A
  linear byte read across the image crosses the physical-to-logical sector skew, so the
  39-byte directory records split out of sequence. Hand-deriving the skew produced a grid
  that looked right and was off by exactly one record, which mislabelled every file after
  the first: it reported `ULTIMA.II.OBJ` as 1597 bytes when it is 13961. The parse was
  plausible and wrong, which is the shape `AGENTS.md` warns about. Use the tool.
* **The volume carries a UCSD p-System runtime** (`MI.SYSTEM`, `MI.HELLO`, `CREATE`,
  `STD.SUBS.OBJ`, `UPDATE.OBJ`, `BIOS.SUBS`, and a `PRODOS` boot file). That scaffolding is
  *not* the game and is not p-code. The game itself is native 6502 machine code in `BIN`
  files. Do not conclude "the Apple version is p-code" from the file names.

## 2. Extraction

`tools/ciderpress2/` holds the CiderPress2 `cp2` CLI, v1.2.0, linux-x64 self-contained.
It is GPL-3.0, vendored and gitignored exactly like `tools/spice86/` and `tools/reko/`:
infrastructure, re-fetchable, never committed.

```bash
D="references/apple/Ultima II (4am crack)/Ultima II (4am crack) disk 1 - program.dsk"
./tools/ciderpress2/cp2 catalog "$D"          # types, aux, sizes
./tools/ciderpress2/cp2 extract --exdir=decompiled/apple2 "$D"
```

`extract` is the verb, not `export`; `--exdir` is the destination. `BIN` files come out as
the raw memory image at their load address, no header to strip.

Output goes under `decompiled/`, which is gitignored. **The extracted blobs are copyrighted
game content and must never be committed**, same rule as `original/` and `references/`.
`references/` stays read-only; `cp2` is only ever pointed at it for reads.

## 3. File map, disk 1

Aux type on a `BIN` under ProDOS is the 6502 load address, so this table is a memory map.

| file | load | bytes | reading |
| --- | --- | --- | --- |
| `ULTIMA.II.OBJ` | `$5000` | 13961 | the world. 229 `JSR $4006` calls, 265 inline strings |
| `CREATE` | `$6000` | 1597 | character creation overlay (overlaps `ULTIMA.II.OBJ`, so it is an overlay) |
| `DNGDRAW.OBJ` | `$8900` | 1813 | dungeon wireframe renderer, holds the shape tables |
| `SHAPES` | `$0800` | 2048 | vector shape data for the dungeon view |
| `TABLES.903C.OBJ` | `$903C` | 1220 | filename is its own load address; opens `01 02 04 08 10 20 40`, the HGR bit table |
| `BIOS.SUBS` | `$9700` | 2592 | I/O and status-line subs, opens with a `JMP` vector table |
| `STD.SUBS.OBJ` | `$4000` | 2787 | runtime library, opens with a `JMP` vector table. **`$4006` is one of those vectors, not code** |
| `FL`, `II`, `WII`, `UL` | `$4000` | 2981/1419/734/2617 | unresolved; `$4000` again, so overlays or data |
| `PIC.CAS/DNG/MIN/OUT/RUS/SPA/TWN` | `$2000` | 8184 each | double hi-res pictures, one per scenario |
| `HTXT` | `$5000` | 2048 | hi-res text page |

The overlay structure is itself a finding: `CREATE` at `$6000` and `ULTIMA.II.OBJ` at
`$5000` overlap, so the game swaps segments rather than living in one flat image.

## 4. Cross-ISA anchors

35 strings appear verbatim in `original/ultimaii.exe` and in an Apple `BIN`, the Apple side
with the high bit set per character. They are not scattered, they cluster into the same
tables on both sides, which is the evidence that this is a translation and not a rewrite:

| DOS string | DOS file off | Apple address |
| --- | --- | --- |
| `ANOS: LEGENDS!` … `ANOS: 2112 A.D.` | 14162-14254 | `ULTIMA.II.OBJ` `$77A2`-`$77E8` |
| `STEAL FOOD!` / `STEAL ARMOUR!` / `STEAL WEAPONS!` | 16864 / 16893 / 16936 | `$8136` / `$8153` / `$8179` |
| `FIELD CAUSES 1000 DAMAGE!` | 9956 | `$6A6A` |
| `ARGH! A TRAP!` | 10942 | `$6D7C` |
| `MAGIC MISSILE` | 4373 | `$561F` |
| `YOU MUST HAVE AN ANKH!` | 13018 | `$73D2` |
| `SHIP INCAPABLE OF LAUNCH!` | 15110 | `$7AF6` |
| `THE RING IS YOURS!` / `ENILNO IS YOURS!` | 16183 / 16119 | `$7ECA` / `$7E8E` |
| ` ARMOUR` / ` WEAPON` | 7977 / 8280 | `BIOS.SUBS` `$9E7D` / `$9E50` |
| dungeon shape blobs (`w[MFB@@@gSIDB@@@`) | 25634-25714 | `DNGDRAW.OBJ` `$8A85`-`$8AD5` |

Order is preserved on both sides in every cluster. That is the anchor: a routine that prints
`STEAL ARMOUR!` in the DOS tree and the same bytes at `$8153` in the Apple tree is the same
routine, and the 6502 around it is the specification the 8086 was translated from.

`JSR $4006` occurs 253 times across the volume, 229 of them in `ULTIMA.II.OBJ`. It is the
same idiom as the DOS `str_out`: `JSR` to the printer, inline high-bit-set string, `00`
terminator.

### The string printer, in full

This is the first routine the cross-reference settled, and it is worth writing out because it
fixes the calling convention every other anchored routine will be read against. `$4006` is a
vector: `4C 80 40` = `JMP $4080`. The body is at `$4080` in `STD.SUBS.OBJ`:

```asm
$4080: 68        PLA           ; pull the JSR return address: it IS the string pointer
$4081: 85 FE     STA $FE
$4083: 68        PLA
$4084: 85 FF     STA $FF
$4086: A0 00     LDY #$00
$4088: E6 FE     INC $FE       ; 16-bit advance: INC lo, and INC hi only if lo wrapped
$408A: D0 02     BNE $408E
$408C: E6 FF     INC $FF
$408E: B1 FE     LDA ($FE),Y
$4090: F0 08     BEQ $409A     ; $00 terminator ends the string
$4092: 09 80     ORA #$80      ; text is stored plain, emitted with the high bit set
$4094: 20 12 97  JSR $9712     ; char out, in BIOS.SUBS
$4097: 4C 88 40  JMP $4088
$409A: A5 FF     LDA $FF
$409C: 48        PHA           ; push the resume address back ...
$409D: A5 FE     LDA $FE
$409F: 48        PHA
$40A0: 60        RTS           ; ... so RTS lands on the byte after the terminator
```

Three consequences for the reconstruction:

* The call chain is three tiers, `ULTIMA.II.OBJ` -> `JSR $4006` -> `JMP $4080` -> `JSR $9712`.
  A harness that treats the vector as the function will mis-scope every caller.
* The printer **consumes and rewrites the return address**, so the caller's `JSR` is really a
  "pass the address of the following bytes" mechanism. This is the same contract the DOS tree
  records for `str_out`, which is the strongest single piece of evidence that the two binaries
  share ancestry rather than merely sharing assets.
* The string pool is stored **high-bit-set on disk**, verified at the byte level: `$561F` holds
  `cd c1 c7 c9 c3 a0 ... a1 0d 00` = `MAGIC MISSILE!` + CR + `$00`. So `ORA #$80` in the
  printer is redundant for these strings and exists to let the same routine emit plain text as
  well. This differs from the earlier assumption worth stating plainly, because `tlkxNN` on the
  DOS side is also high-bit-set: here the convention is on disk *and* at emit, and the
  terminator is a plain `$00` while the preceding CR is a plain `$0D`.

## 5. 6502 idioms confirmed in place

Observed directly, each one a claim the working brief made on assumption:

* zero-page globals with boundary checks: `A5 01 C9 20 B0` = `LDA $01; CMP #$20; BCS`
* `$4Exx` global tables: `AD 14 4E` = `LDA $4E14`; fill loop `A2 07 A9 01 9D A0 4D CA 10 FA`
* 8-bit carry arithmetic on multi-byte counters: `AD 1D 4E 69 01 8D 1D 4E`, and the indexed
  form `BD 60 4E 69 01 9D 60 4E`
* BCD: `F8`/`18` = `SED`/`CLD` bracketing decimal adds, which independently corroborates the
  `cmc; sbb; das; cmc` idiom already recorded on the DOS side

## 6. Limits on what this evidence may prove

* **This is the 1989 Origin re-release, not the 1982 original.** Disk dates are Nov 1988 to
  Feb 1989. It is a sibling or a descendant of the shipped Apple build, not necessarily the
  build the DOS port was made from. Where the two disagree, `original/ultimaii.exe` stays
  ground truth for this project and the Apple side is evidence about intent.
* **No Apple-derived name goes into an `asm/` filename.** `AGENTS.md` requires a discovered
  name to be evidenced by *this* binary. A 6502 routine that looks like the same function
  supports a hypothesis and a `# name-evidence:` line; it does not on its own rename a file.
* **Shared text does not mean shared behaviour, and the first probe already says so.**
  `--INVALID MOVE!`, the DOS reject echo at `asm/0A02_invalid_move_msg.asm`, **does not exist
  anywhere in the Apple build** — searched plain and high-bit-set across every resident
  segment. The era table and `ANKH` are present, so this is not a search artefact. Either the
  DOS port added the reject message, or the Apple build rejects a move silently or words it
  differently. Until that is settled, the walk loop cannot be aligned by message anchor, and
  no contract for movement may cite an Apple routine as the origin of the DOS reject path.
* **Dungeons stay parked.** `DNGDRAW.OBJ` and `SHAPES` are the first-person wireframe, and
  nothing in them settles how the overworld or a town draws or stamps anything.
* The "287 of 288 Apple-only strings" figure from the first anchor pass is an artefact: the
  regex caught hi-res bitmap noise, not text. Do not cite it.

## 7. Disks 2 and 3: the data correspondence

Disk 2 is volume `PLAYER`, disk 3 is volume `GALACTIC`. Both hold a subdirectory `M` of
per-sector files, and the naming maps onto the DOS side one-for-one:

| Apple | bytes | DOS | bytes | relation |
| --- | --- | --- | --- | --- |
| `M/AP.NN` | 4096 | `mapxNN` | 4224 | **first 4096 bytes identical** on 31 of 33 sectors |
| `M/ON.NN` | 256 | `monxNN` | 384 | **first 256 bytes identical**, tested 5 of 5 |
| `TLK.NN` | 256 | `tlkxNN` | 384 | same shape, content differs (~100/256 equal) |

Every DOS file is exactly 128 bytes longer than its Apple counterpart, and in all three
families the extra block begins with `0x1A`. See `docs/map-format.md` § 2 for what that
proves about the tail and what it does not.

Two things to know before using these as evidence:

* **Sector numbers are not unique across disks.** `AP.10` and `AP.15` exist on both disk 2 and
  disk 3 with completely different content (44.8% and 35.4% of cells differ). The disk selects
  the scenario set; the two digits do not identify a world on their own. The DOS build carries
  one flat `mapxNN` set, so where the two Apple disks disagree, disk 2 is the one that matches
  DOS.
* **`TLK` content genuinely differs between platforms**, unlike `AP` and `ON`. Do not treat
  Apple dialogue data as a cross-check on `tlkxNN` until that difference is explained.

Also on these disks and not yet examined: `MONSTERS.` (2048, note the trailing dot),
`PLAYER` (256), `STARS.OBJ` (1899, loads `$1000`), `STARTUP` (1303), `END` (316), and
`SHAPES`/`DNGDRAW.OBJ` duplicated from disk 1.

## 8. Ghidra 6502 import

Working, and the decompiler reproduces what the hand disassembly says, which is the point of
doing it this way:

```bash
source tools/env.sh
python3 tools/apple2_image.py -o /var/tmp/u2_6502.bin
WORK=$(mktemp -d /var/tmp/u2-ghidra-6502.XXXXXX); mkdir -p "$WORK/proj"
"$GHIDRA_HOME/support/analyzeHeadless" "$WORK/proj" u2apple -deleteProject \
    -import /var/tmp/u2_6502.bin \
    -loader BinaryLoader -loader-baseAddr 0x4000 \
    -processor "6502:LE:16:default" \
    -scriptPath tools/ghidra \
    -postScript Seed6502.java seeds=<seeds.txt> \
    -postScript DecompileAll.java out=/var/tmp/u2_6502.c index=/var/tmp/u2_6502.tsv
```

Three things that are not obvious:

* **The flag is `-processor`, not `-language`.** `analyzeHeadless` rejects `-language` with
  `Bad argument`; the language spec goes in `-processor "6502:LE:16:default"`.
* **A raw image yields zero functions.** Ghidra has no entry point to start from, so
  auto-analysis finds nothing at all. `Seed6502.java` creates functions from a list of JSR/JMP
  absolute targets. That scan is byte-granular, so a handful of seeds land inside an operand
  and Ghidra reports `Unable to resolve constructor` for them. 328 seeds gave 328 functions
  with a few junk ones, which is a good trade against analysing nothing.
* **`tools/apple2_image.py` refuses overlapping segments.** `CREATE` loads at `$6000` inside
  `ULTIMA.II.OBJ`, so it is an overlay and is opt-in via `--with create` rather than silently
  stomping bytes. The manifest prints the zero-filled gaps, because zero is a legal 6502 opcode
  and an unloaded range must not look like code.

The decompiler's output for `$4080` matches the hand disassembly in behaviour, including
`unaff_retaddr` becoming the string pointer and the `| 0x80` at emit. A wrong load base would
not produce a coherent printer, so this is also the confirmation that the segment map is right.

## 9. Next

1. ~~Import `ULTIMA.II.OBJ` and `STD.SUBS.OBJ` into Ghidra~~ done, see § 8. Next there: prune
   the junk seed functions and name routines from the anchor table.
2. Resolve `FL`, `II`, `WII`, `UL`.
3. ~~Catalog disks 2 and 3~~ done, see § 7. Next there: explain the `0x1A` +128 block, and
   the sector `10`/`15` content deltas if they ever matter.
4. Then the actual deliverable: behavioural contracts, starting with the overworld movement
   tick and time-door spawning.
