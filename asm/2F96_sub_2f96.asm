# sub_2f96 — mechanical clean (bulk wave); behavior not yet reviewed
# func 2F96..2F9D  len 0008 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2f96:
L_003196:
        nop
L_003197:
        mov    0x13,%al
L_00319a:
        cmp    $0x78,%al
L_00319c:
        jb L_00317f
