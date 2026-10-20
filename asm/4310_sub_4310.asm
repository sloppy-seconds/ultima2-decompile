# sub_4310 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4310..4325  len 0016 B  evidence: seed+reko
# calls: L_000c30, L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4310:
L_004510:
        call L_0051df
        db 0x8d,"NO DOOR THERE!",0x00        # string
L_004523:
        jmp L_000c30
