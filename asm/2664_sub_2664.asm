# sub_2664 — mechanical clean (bulk wave); behavior not yet reviewed
# func 2664..2676  len 0013 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2664:
L_002864:
        mov    0x0,%al
L_002867:
        and    $0x3f,%al
L_002869:
        mov    %al,0x0
L_00286c:
        mov    0x1,%al
L_00286f:
        and    $0x3f,%al
L_002871:
        mov    %al,0x1
L_002874:
        mov    $0x0,%al
L_002876:
        ret
