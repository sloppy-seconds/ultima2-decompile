# sub_0b07 — mechanical clean (bulk wave); behavior not yet reviewed
# func 0B07..0B0E  len 0008 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0b07:
L_000d07:
        mov    0x177(%di),%al
L_000d0b:
        cmp    $0xf,%al
L_000d0d:
        jae L_000d25
