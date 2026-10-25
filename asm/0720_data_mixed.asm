# data_0720_mixed — a `ret` that is a jump target, then a table
# name-evidence: 0720 is entered, not fallen into — asm/0715 is `dec %bx ; js L_000920`, a
#           decrement-and-exit-if-negative, and its `js` lands on the `c3` here. 0764 is also a
#           proven boundary: asm/07E3 does `jmp L_000964` and asm/03AC does `call L_000964`. So
#           the 67 bytes between two proven instruction boundaries are not reachable as code, and
#           they do not decode as code either: the old body was a run of forced-keeps whose
#           objdump readings were `int1`, `fdivl (%bx)`, `repz inc %bx`, `aam $0x44` and
#           `xorb $0x94,(%bx)` — the absurd-instruction signature this tree already uses to
#           adjudicate data islands (47BD, 4815, 486D, and now 5287).
# RENAMED 2026-10-28e from sub_0720: the span is not a routine.
# func 0720..0763  len 0044 B  evidence: seed+reko
# provenance: static
#           the claim rests on the `js` and `call` sites above, which are readable in the bytes;
#           no live capture is needed and tools/provenance_from_traces.py records nothing here.
# confidence: high that 0721..0763 is data and that both ends are instruction boundaries; low on
#           what the table means. Shape: fourteen 0x00 bytes, then a run in which one operand
#           ascends monotonically (0x35, 0x36, 0x37 ... 0x45) between other bytes — a lookup
#           table of some kind, not interpreted here.
# label: kept as sub_0720 on purpose (CP0 treats label lines as body; renaming one is a separate
#           ruling, and the header and filename carry the correction).
# body corrected: 2026-10-28e -- evidence: 0720 is `c3` = `ret` and gas encodes it exactly, so
#           the `gas re-encodes 'ret' differently` marker was false; the rest is the table above.
#           The audit's claim that a three-byte instruction started at 0762 was objdump's linear
#           pass reading table bytes as code, and it was impossible on its face: it would have
#           swallowed the first byte of a routine entered from two places. Found by
#           tools/forced_keep_audit.py and settled by the call sites above.
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0720:
L_000920:
        ret
db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x8f, 0x2b, 0x6f, 0x2f, 0x0b, 0x31, 0x4d, 0x33, 0x89, 0x33, 0xc1, 0x35, 0x3b, 0x36, 0x82, 0x37, 0x94, 0x37, 0xdc, 0x37, 0xf1, 0x37, 0xb0, 0x38, 0x92, 0x3b, 0xce, 0x3b, 0x2e, 0x3c, 0xbc, 0x3d, 0xc7, 0x3d, 0x50, 0x3e, 0x25, 0x3f, 0x50, 0x40, 0xf1, 0x42, 0x7e, 0x43, 0xf3, 0x43, 0xd4, 0x44, 0x42, 0x45, 0x68, 0x45        # table at 0721
