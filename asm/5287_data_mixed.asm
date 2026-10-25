# data_5287_mixed — a `ret` and then a data table whose address is taken two instructions earlier
# name-evidence: asm/527F ends `lea %cs:0x5288,%cx ; call L_004e1e`, so 5288 is the address of a
#           block passed as an argument, not a routine. asm/4C1E receives it in %cx, moves it to
#           %si and indexes it (`shr $1,%ax` twice, `shl $1,%bx`, `add $0x2,%si`), which is a
#           table walk, not a call target. And asm/52CA is a proven entry point — `call L_0054ca`
#           appears in asm/310B, asm/020F, asm/0796, asm/07F3, asm/2290, asm/22BF — so the byte
#           before it cannot be mid-instruction, which is what the old `lock add
#           %bl,-0x7d(%bp,%di)` at 52C8 implied.
# RENAMED 2026-10-28e from sub_5287: the span is not a function. The whole body was a run of
#           forced-keeps whose decodes were `lock aas`, `ud0 %di,%di` and `(bad)` — the same
#           absurd-instruction signature that got 47BD/4815/486D adjudicated as data islands.
# func 5287..52C9  len 0043 B  evidence: seed+reko
# provenance: static
#           no live capture is needed for the claim made here: the `lea %cs:0x5288,%cx` at
#           asm/527F and the six `call L_0054ca` sites are all readable in the bytes, and
#           tools/provenance_from_traces.py records nothing for 5287 because no routine there is
#           ever entered.
# confidence: high that 5288 is data and that 52CA is an entry point; low on what the table means
# label: kept as sub_5287 on purpose (CP0 treats label lines as body; renaming it is a separate
#           ruling, and the header and filename carry the correction).
# body corrected: 2026-10-28e -- evidence: 5287 is `c3` = `ret`, the tail of the routine that
#           ends at 5286, and gas encodes it exactly, so the `gas re-encodes 'ret' differently`
#           marker was false. Everything from 5288 is the table asm/527F passes to asm/4C1E: 66
#           bytes, structurally a repeated 4-byte record (`3f ff ff fc` six times in the middle)
#           inside a roughly mirrored frame. The per-byte forced-keeps were objdump's linear pass
#           reading table bytes as instructions, and the last of them claimed a four-byte
#           instruction starting at 52C8 — which would have swallowed the first byte of a routine
#           called from six places. Found by tools/forced_keep_audit.py and settled by the call
#           sites above.
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5287:
L_005487:
        ret
        db 0x04, 0x10, 0x00, 0x0f, 0xf0, 0x00, 0x00, 0xff, 0xff, 0x00, 0x03, 0xff, 0xff, 0xc0, 0x0f, 0xff, 0xff, 0xf0, 0x0f, 0xff, 0xff, 0xf0, 0x3f, 0xff, 0xff, 0xfc, 0x3f, 0xff, 0xff, 0xfc, 0x3f, 0xff, 0xff, 0xfc, 0x3f, 0xff, 0xff, 0xfc, 0x3f, 0xff, 0xff, 0xfc, 0x3f, 0xff, 0xff, 0xfc, 0x0f, 0xff, 0xff, 0xf0, 0x0f, 0xff, 0xff, 0xf0, 0x03, 0xff, 0xff, 0xc0, 0x00, 0xff, 0xff, 0x00, 0x00, 0x0f, 0xf0, 0x00        # table at 5288: shape measured, meaning not interpreted
