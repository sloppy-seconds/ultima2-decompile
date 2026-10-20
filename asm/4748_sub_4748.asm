# sub_4748 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4748..4754  len 000D B  evidence: seed+reko
# strings: "WEAPONS: "
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4748:
L_004948:
        call L_0051df
        db "WEAPONS: ",0x00        # string
