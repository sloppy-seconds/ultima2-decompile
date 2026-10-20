# sub_428e — mechanical clean (bulk wave); behavior not yet reviewed
# func 428E..42A9  len 001C B  evidence: seed+reko
# strings: "AND FOR IT I RAISE THEE "
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_428e:
L_00448e:
        call L_0051df
        db "AND FOR IT I RAISE THEE ",0x00        # string
