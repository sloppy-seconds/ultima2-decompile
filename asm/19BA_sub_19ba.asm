# sub_19ba — mechanical clean (bulk wave); behavior not yet reviewed
# func 19BA..19D3  len 001A B  evidence: seed+reko
# strings: " YOU ARE NOT A WIZARD!"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_19ba:
L_001bba:
        call L_0051df
        db " YOU ARE NOT A WIZARD!",0x00        # string
