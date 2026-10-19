# Entry Points (CP1)

**Source:** `captures/spice86/spice86-cfg.json` (Spice86 runtime CFG, one playthrough).
**Extractor:** `tools/extract_entry_points.py` (re-runnable from project root).
**Output:** `disasm/entry-points.txt` — one 4-hex-digit offset per line, `XXXX  # block=<id>`.

## Filter rule

1. Keep blocks whose `entry` segment is `017D` (game code segment). `F000` (48 blocks) and
   `0A29` (1 block) are BIOS/ROM and dropped.
2. A block flagged `dead` is dropped **only if** none of its `pred` blocks is live (non-dead);
   otherwise kept (dead ≠ not-an-entry).
3. Dedup by offset (none found), sort ascending.

## Counts (measured)

| Metric | Value |
| --- | --- |
| Total CFG blocks | 845 |
| Blocks in `017D` | 796 |
| Dead blocks in `017D` | 181 |
| Dead kept (≥1 live pred) | 78 |
| Dead dropped (all preds dead) | 103 |
| **Unique entry offsets emitted** | **693** |
| Duplicates removed | 0 |

Note: the plan expected the count "within a few of 796 (dedup may reduce it)"; the actual
reduction (693) comes from the plan's own dead-drop rule, not dedup. The plan's on-failure note
anticipates this ("197 blocks marked dead ... do not pad the list"). All `pred` ids resolved;
no block had an empty pred list.

## Address mapping (from plan §1 — all notations name the same byte)

| Notation | Form | File offset |
| --- | --- | --- |
| Runtime CFG block | `017D:XXXX` | `XXXX + 0x200` |
| Ghidra address | `1000:XXXX` | `XXXX + 0x200` |
| Reko address | `0800:XXXX` | `XXXX + 0x200` |
| `objdump -b binary` | prints file offset | as-is |

The `entries=` file for `DecompileMz.java` takes the bare `XXXX` (no segment, no `0x200` bias).

## Verification

**Full first-opcode check (all 693):** for every entry, the first opcode bytes recorded in the
CFG `asm` were compared against `original/ultimaii.exe` at `XXXX+0x200`. **692/693 match.**
The single mismatch is block 96 at `0100` (file `0x300`): CFG records runtime `B8BE08`
(`mov ax,0x08BE`), file holds `b8 41 07` (`mov ax,0x0741`) — the documented MZ relocation
fixup (see `captures/README.md`), expected, not an error.

**objdump spot-checks (3 random entries, seed=1).** Note: binutils 2.46 requires `-j .data`
for `objdump -d -b binary --start-address=...` to emit instructions (see implementation log).

```
== entry 0962 -> file 0xb62
     b62:  a0 15 00     mov    0x15,%al
     b65:  e8 bb 1a     call   0x2623
== entry 5188 -> file 0x5388
    5388:  a0 58 00     mov    0x58,%al
    538b:  b7 00        mov    $0x0,%bh
    538d:  8a           mov    0x59,%bl   (truncated 6-byte window)
== entry 06AC -> file 0x8ac
     8ac:  b4 00        mov    $0x0,%ah
     8ae:  cd 1a        int    0x1a
```

All three decode as plausible routine starts (absolute `mov`, register init, DOS `int 0x1a`),
not mid-string garbage.
