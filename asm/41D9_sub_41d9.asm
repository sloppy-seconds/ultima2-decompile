# sub_41d9 — mechanical clean (bulk wave); behavior not yet reviewed
# func 41D9..4205  len 002D B  evidence: seed+reko
# strings: "A THIEF SAYS:"
# calls: L_000c33, L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_41d9:
L_0043d9:
        call L_0051df
        db "A THIEF SAYS:",0x0d,"PSST, WANNA BUY A WATCH?",0x00        # string
L_004403:
        jmp L_000c33
