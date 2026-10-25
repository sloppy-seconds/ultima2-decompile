# sub_034b — mechanical clean (bulk wave); behavior not yet reviewed
# func 034B..0373  len 0029 B  evidence: reko
# strings: "'C' - CREATE A NEW CHARACTER"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
# body corrected: 2026-10-28d -- evidence: bytes 034B..034E are `06 2f 00 11`, the tail of
#           `movb $0x11,0x2f` whose opcode 0xc6 is the forced-keep in asm/034A.
sub_034b:
L_00054b:
        .byte 0x06, 0x2f, 0x00, 0x11   # tail of `movb $0x11,0x2f` started at asm/034A
L_00054f:
        mov    $0x6,%al
L_000551:
        mov    %al,0x2e
L_000554:
        call L_0051df
        db "'C' - CREATE A NEW CHARACTER",0x00        # string
