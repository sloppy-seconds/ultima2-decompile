# sub_102b — mechanical clean (bulk wave); behavior not yet reviewed
# func 102B..1032  len 0008 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_102b:
L_00122b:
        mov    0x1d7(%di),%al
L_00122f:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_001231:
        je L_001240
