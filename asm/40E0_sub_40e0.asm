# sub_40e0 — mechanical clean (bulk wave); behavior not yet reviewed
# func 40E0..4100  len 0021 B  evidence: seed+reko
# strings: "A GUARD SAYS:"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_40e0:
L_0042e0:
        call L_0051df
        db "A GUARD SAYS:",0x0d,"PAY YOUR TAXES!",0x00        # string
