# sub_240a — mechanical clean (bulk wave); behavior not yet reviewed
# func 240A..2413  len 000A B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_240a:
L_00260a:
        mov    0x137(%di),%al
L_00260e:
        cmp    0x23,%al
L_002612:
        jne L_00261f
