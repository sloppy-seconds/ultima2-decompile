# sub_2048 — mechanical clean (bulk wave); behavior not yet reviewed
# func 2048..204C  len 0005 B  evidence: seed+reko
# calls: L_0055f4
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2048:
L_002248:
        mov    $0x8d,%al
L_00224a:
        call L_0055f4
