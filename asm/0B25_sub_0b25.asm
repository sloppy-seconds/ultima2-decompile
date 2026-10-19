# sub_0b25 — mechanical clean (bulk wave); behavior not yet reviewed
# func 0B25..0B35  len 0011 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0b25:
L_000d25:
        clc
L_000d26:
        mov    0x137(%di),%al
L_000d2a:
        adc    0x19,%al
L_000d2e:
        and    $0x3f,%al
L_000d30:
        cmp    0x0,%al
L_000d34:
        je L_000d39
