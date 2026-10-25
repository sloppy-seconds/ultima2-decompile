# sub_02f8 — mechanical clean (bulk wave); behavior not yet reviewed
# func 02F8..031D  len 0026 B  evidence: reko
# strings: "'D' - FOR A DEMONSTRATION"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
# body corrected: 2026-10-28d -- evidence: bytes 02F8..02FB are `06 2f 00 0d`, the tail of
#           `movb $0xd,0x2f` whose opcode 0xc6 is the forced-keep in asm/02F7.
sub_02f8:
L_0004f8:
        .byte 0x06, 0x2f, 0x00, 0x0d   # tail of `movb $0xd,0x2f` started at asm/02F7
L_0004fc:
        mov    $0x6,%al
L_0004fe:
        mov    %al,0x2e
L_000501:
        call L_0051df
        db "'D' - FOR A DEMONSTRATION",0x00        # string
