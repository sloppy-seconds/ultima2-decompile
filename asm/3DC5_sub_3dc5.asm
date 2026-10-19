# sub_3dc5 — mechanical clean (bulk wave); behavior not yet reviewed
# func 3DC5..3DC6  len 0002 B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_3dc5:
L_003fc5:
        insb   (%dx),%es:(%di)
L_003fc6:
        int3
