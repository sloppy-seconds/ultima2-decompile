# sub_50e3 — mechanical clean (bulk wave); behavior not yet reviewed
# func 50E3..50EE  len 000C B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_50e3:
L_0052e3:
        ret
L_0052e4:
        cmp    $0x0,%al
L_0052e6:
        je L_0052e3
L_0052e8:
        cmp    $0x20,%al
L_0052ea:
        jb L_0052e1
L_0052ec:
        mov    $0xff,%al
L_0052ee:
        ret
