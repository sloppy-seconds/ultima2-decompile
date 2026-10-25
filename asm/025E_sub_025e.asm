# sub_025e — mechanical clean (bulk wave); behavior not yet reviewed
# func 025E..0271  len 0014 B  evidence: reko
# strings: "REVENGE"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
# body corrected: 2026-10-28d -- evidence: bytes 025E..0261 are `06 2f 00 03`, the tail of
#           `movb $0x3,0x2f` whose opcode 0xc6 is the forced-keep in asm/025D. The three
#           mnemonics this file showed (push %es, das, add %al,(%bp,%di)) were those four
#           bytes decoded as code. Found by tools/forced_keep_audit.py.
sub_025e:
L_00045e:
        .byte 0x06, 0x2f, 0x00, 0x03   # tail of `movb $0x3,0x2f` started at asm/025D
L_000462:
        mov    $0x10,%al
L_000464:
        mov    %al,0x2e
L_000467:
        call L_0051df
        db "REVENGE",0x00        # string
