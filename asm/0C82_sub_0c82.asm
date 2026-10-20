# sub_0c82 — mechanical clean (bulk wave); behavior not yet reviewed
# func 0C82..0C88  len 0007 B  evidence: seed+reko
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0c82:
L_000e82:
        call L_0051df
        db 0x8d,0x8d,0x8d,0x00        # string
