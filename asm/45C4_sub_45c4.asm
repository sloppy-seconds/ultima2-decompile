# sub_45c4 — mechanical clean (bulk wave); behavior not yet reviewed
# func 45C4..45D0  len 000D B  evidence: seed+reko
# strings: "  WEAPON-"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_45c4:
L_0047c4:
        call L_0051df
        db "  WEAPON-",0x00        # string
