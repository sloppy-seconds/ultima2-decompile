# sub_415f — mechanical clean (bulk wave); behavior not yet reviewed
# func 415F..4180  len 0022 B  evidence: seed+reko
# strings: "A FIGHTER SAYS:"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_415f:
L_00435f:
        call L_0051df
        db "A FIGHTER SAYS:",0x0d,"UGH, ME TOUGH!",0x00        # string
