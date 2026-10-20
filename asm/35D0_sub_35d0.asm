# sub_35d0 — mechanical clean (bulk wave); behavior not yet reviewed
# func 35D0..35DA  len 000B B  evidence: seed+reko
# strings: " WHAT?"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_35d0:
L_0037d0:
        call L_0051df
        db " WHAT?",0x00        # string
L_0037da:
        .byte 0xe9  # forced-kept: stop-trunc jmp    0xc30
