# sub_3be4 — mechanical clean (bulk wave); behavior not yet reviewed
# func 3BE4..3C00  len 001D B  evidence: seed+reko
# strings: " HOW?"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_3be4:
L_003de4:
        call L_0051df
        db " HOW?",0x8d,"YOU'RE NOT EINSTEIN",0x00        # string
