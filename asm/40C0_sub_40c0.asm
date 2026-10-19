# sub_40c0 — mechanical clean (bulk wave); behavior not yet reviewed
# func 40C0..40C7  len 0008 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_40c0:
L_0042c0:
        mov    0x1d7(%di),%al
L_0042c4:
        cmp    $0x80,%al
L_0042c6:
        jb L_0042cb
