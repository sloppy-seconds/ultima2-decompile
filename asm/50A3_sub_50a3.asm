# sub_50a3 — mechanical clean (bulk wave); behavior not yet reviewed
# func 50A3..50AC  len 000A B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_50a3:
L_0052a3:
        inc    %di
L_0052a4:
        mov    %cs:0x4c60(%di),%al
L_0052a9:
        cmp    $0x0,%al
L_0052ab:
        je L_0052b2
