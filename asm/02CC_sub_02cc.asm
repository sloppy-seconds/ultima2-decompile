# sub_02cc — mechanical clean (bulk wave); behavior not yet reviewed
# func 02CC..02E2  len 0017 B  evidence: reko
# strings: "AND ORIGIN"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
# body corrected: 2026-10-28d -- evidence: bytes 02CC..02CF are `06 2f 00 17`, the tail of
#           `movb $0x17,0x2f` whose opcode 0xc6 is the forced-keep in asm/02CB.
sub_02cc:
L_0004cc:
        .byte 0x06, 0x2f, 0x00, 0x17   # tail of `movb $0x17,0x2f` started at asm/02CB
L_0004d0:
        mov    $0xf,%al
L_0004d2:
        mov    %al,0x2e
L_0004d5:
        call L_0051df
        db "AND ORIGIN",0x00        # string
