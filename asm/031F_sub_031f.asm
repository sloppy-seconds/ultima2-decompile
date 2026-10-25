# sub_031f — mechanical clean (bulk wave); behavior not yet reviewed
# func 031F..0349  len 002B B  evidence: reko
# strings: "'P' - PLAY A GAME OF ULTIMA ]["
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
# body corrected: 2026-10-28d -- evidence: bytes 031F..0322 are `06 2f 00 0f`, the tail of
#           `movb $0xf,0x2f` whose opcode 0xc6 is the forced-keep in asm/031E.
sub_031f:
L_00051f:
        .byte 0x06, 0x2f, 0x00, 0x0f   # tail of `movb $0xf,0x2f` started at asm/031E
L_000523:
        mov    $0x6,%al
L_000525:
        mov    %al,0x2e
L_000528:
        call L_0051df
        db "'P' - PLAY A GAME OF ULTIMA ][",0x00        # string
