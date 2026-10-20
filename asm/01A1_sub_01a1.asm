# sub_01a1 — mechanical clean (bulk wave); behavior not yet reviewed
# func 01A1..01BA  len 001A B  evidence: seed+reko
# strings: "OF THE #1 BEST SELLING"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_01a1:
L_0003a1:
        call L_0051df
        db "OF THE #1 BEST SELLING",0x00        # string
