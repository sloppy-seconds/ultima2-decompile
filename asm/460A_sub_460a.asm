# sub_460a — mechanical clean (bulk wave); behavior not yet reviewed
# func 460A..4616  len 000D B  evidence: seed+reko
# strings: "  ARMOUR-"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_460a:
L_00480a:
        call L_0051df
        db "  ARMOUR-",0x00        # string
