# sub_2423 — mechanical clean (bulk wave); behavior not yet reviewed
# func 2423..242C  len 000A B  evidence: seed+call+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2423:
L_002623:
        mov    %al,0x29
L_002626:
        mov    0x4a,%al
L_002629:
        cmp    $0x0,%al
L_00262b:
        je L_00268b
