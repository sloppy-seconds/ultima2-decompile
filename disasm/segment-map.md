# Segment Map & Memory-Dump Inventory (CP3)

Values cross-checked against `captures/README.md` and re-verified against
`captures/spice86/spice86-cfg.json` and `original/ultimaii.exe`.

## Runtime segment map

| Register | Runtime value | Evidence |
| --- | --- | --- |
| CS | `0x017D` | 796/845 CFG blocks carry entry segment `017D` (game code) |
| DS | `0x08BE` | captured data segment; player name `TEST` visible at `DS:0x36` in `live-ds-4f4d.bin` |

### Relocation caveat (important for byte-checking)

The MZ loader applies a relocation fixup at load time: the file's initialising immediate at
file `0x0300` is `0x0741` (`b8 41 07` = `mov ax,0x0741`), but the running program executes
`mov ax,0x08BE` (`B8BE08` in the CFG, block 96 @ `017D:0100`). Consistency:
`DS - file_immediate = 0x08BE - 0x0741 = 0x017D = CS`.

Consequence: runtime-captured bytes differ from file bytes wherever a fixup applies — expect
this near the entry point; it is not an error in either source.

### File mapping

```
file_offset = cs_offset + 0x200        (code segment 017D)
```

Verified on 692/693 CP1 entries (first-opcode bytes match; the one exception is the fixup
block above). Notation equivalence: CFG `017D:XXXX` = Ghidra `1000:XXXX` = Reko `0800:XXXX` =
file `XXXX+0x200`.

## Memory-dump inventory: `captures/spice86/live-ds-4f4d.bin`

- Size: **4,096 bytes**, captured from `DS:0000` onward (DS = `0x08BE`, physical
  `0x08BE*16 + 0`).
- First 64 bytes:

```
00000000: 2117 1812 000a eb1e 0000 0000 0000 0000  !...............
00000010: 0000 ff78 0400 0084 0001 0100 0000 001e  ...x............
00000020: 0068 c312 1800 0009 0e1f 0086 0800 0517  .h..............
00000030: 001d 0000 0000 5445 5354 0000 0000 0000  ......TEST......
```

- Obvious structure (per the layout table in `captures/README.md`; no further interpretation —
  struct recovery is Phase 3):
  - `0x00`,`0x01` = `21 17` — player x,y (low page, not in save file).
  - `0x36..` = `TEST` — player name, confirming the documented player-record base `DS:0x36`
    and hence the DS value itself.
- Reminder from `captures/README.md`: counters in these structures are **packed BCD**, not
  binary.
