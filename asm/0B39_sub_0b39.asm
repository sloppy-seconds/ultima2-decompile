# sub_0b39 — mechanical clean (bulk wave); behavior not yet reviewed
# func 0B39..0B49  len 0011 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0b39:
L_000d39:
        clc
L_000d3a:
        mov    0x157(%di),%al
L_000d3e:
        adc    0x1a,%al
L_000d42:
        and    $0x3f,%al
L_000d44:
        cmp    0x1,%al
L_000d48:
        je L_000d4d
