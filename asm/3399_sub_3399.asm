# sub_3399 — mechanical clean (bulk wave); behavior not yet reviewed
# func 3399..33A5  len 000D B  evidence: seed+reko
# strings: " WHAT?"
# calls: L_000c33, L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_3399:
L_003599:
        call L_0051df
        db " WHAT?",0x00        # string
L_0035a3:
        jmp L_000c33
