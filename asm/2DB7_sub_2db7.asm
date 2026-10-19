# sub_2db7 — mechanical clean (bulk wave); behavior not yet reviewed
# func 2DB7..2DC0  len 000A B  evidence: seed+reko
# calls: L_0055b5
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2db7:
L_002fb7:
        and    $0x17,%al
L_002fb9:
        or     $0x1,%al
L_002fbb:
        mov    %al,0x1f
L_002fbe:
        call L_0055b5
