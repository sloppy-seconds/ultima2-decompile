# sub_0288 — mechanical clean (bulk wave); behavior not yet reviewed
# func 0288..029F  len 0018 B  evidence: reko
# strings: "ENCHANTRESS"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
# body corrected: 2026-10-28d -- evidence: bytes 0288..028b are `06 2f 00 07`, the tail of
#           `movb $0x7,0x2f` whose opcode 0xc6 is the forced-keep in asm/0287.
sub_0288:
L_000488:
        .byte 0x06, 0x2f, 0x00, 0x07   # tail of `movb $0x7,0x2f` started at asm/0287
L_00048c:
        mov    $0xe,%al
L_00048e:
        mov    %al,0x2e
L_000491:
        call L_0051df
        db "ENCHANTRESS",0x00        # string
