# sub_015e — mechanical clean (bulk wave); behavior not yet reviewed
# func 015E..0171  len 0014 B  evidence: seed+reko
# strings: "PROUDLY PRESENTS"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_015e:
L_00035e:
        call L_0051df
        db "PROUDLY PRESENTS",0x00        # string
