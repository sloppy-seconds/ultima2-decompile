# sub_0375 — mechanical clean (bulk wave); behavior not yet reviewed
# func 0375..0388  len 0014 B  evidence: reko
# strings: "CHOICE:"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
# body corrected: 2026-10-28d -- evidence: bytes 0375..0378 are `06 2f 00 13`, the tail of
#           `movb $0x13,0x2f` whose opcode 0xc6 is the forced-keep in asm/0374.
sub_0375:
L_000575:
        .byte 0x06, 0x2f, 0x00, 0x13   # tail of `movb $0x13,0x2f` started at asm/0374
L_000579:
        mov    $0x5,%al
L_00057b:
        mov    %al,0x2e
L_00057e:
        call L_0051df
        db "CHOICE:",0x00        # string
