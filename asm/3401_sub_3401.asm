# sub_3401 — mechanical clean (bulk wave); behavior not yet reviewed
# func 3401..340E  len 000E B  evidence: seed+reko
# strings: " WHAT?"
# calls: L_000c33, L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_3401:
L_003601:
        nop
L_003602:
        call L_0051df
        db " WHAT?",0x00        # string
L_00360c:
        jmp L_000c33
