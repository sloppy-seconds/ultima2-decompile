# sub_08dc — mechanical clean (bulk wave); behavior not yet reviewed
# func 08DC..08E2  len 0007 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_08dc:
L_000adc:
        mov    0x13,%al
L_000adf:
        cmp    $0x26,%al
L_000ae1:
        jne L_000ae6
