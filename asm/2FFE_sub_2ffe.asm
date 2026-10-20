# sub_2ffe — mechanical clean (bulk wave); behavior not yet reviewed
# func 2FFE..3034  len 0037 B  evidence: seed+reko
# strings: " SHIP"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2ffe:
L_0031fe:
        call L_0051df
        db " SHIP",0x8d,"THE CREW OF THIS SHIP",0x8d,"WILL NOT LET YOU BOARD!",0x00        # string
