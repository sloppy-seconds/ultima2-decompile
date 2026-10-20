# sub_47fa — mechanical clean (bulk wave); behavior not yet reviewed
# func 47FA..4805  len 000C B  evidence: seed+reko
# strings: "SPELLS: "
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_47fa:
L_0049fa:
        call L_0051df
        db "SPELLS: ",0x00        # string
