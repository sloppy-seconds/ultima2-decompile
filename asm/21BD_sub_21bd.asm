# sub_21bd — mechanical clean (bulk wave); behavior not yet reviewed
# func 21BD..21C4  len 0008 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_21bd:
L_0023bd:
        nop
L_0023be:
        mov    0x1f,%al
L_0023c1:
        cmp    $0x10,%al
L_0023c3:
        je L_0023fc
