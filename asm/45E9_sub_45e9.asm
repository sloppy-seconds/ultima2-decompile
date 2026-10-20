# sub_45e9 — mechanical clean (bulk wave); behavior not yet reviewed
# func 45E9..45F4  len 000C B  evidence: seed+reko
# strings: "TORCHES-"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_45e9:
L_0047e9:
        call L_0051df
        db "TORCHES-",0x00        # string
