# sub_1142 — mechanical clean (bulk wave); behavior not yet reviewed
# func 1142..1149  len 0008 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_1142:
L_001342:
        mov    $0x0,%bh
L_001344:
        mov    $0x7,%bl
L_001346:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_001348:
        mov    $0x1,%al
