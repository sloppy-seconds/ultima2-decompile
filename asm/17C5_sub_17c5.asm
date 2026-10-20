# sub_17c5 — mechanical clean (bulk wave); behavior not yet reviewed
# func 17C5..17DC  len 0018 B  evidence: seed+reko
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_17c5:
L_0019c5:
        call L_0051df
        db 0x8d,"PER 100, WANT ONE? ",0x00        # string
