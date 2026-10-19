# sub_0b65 — mechanical clean (bulk wave); behavior not yet reviewed
# func 0B65..0B70  len 000C B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0b65:
L_000d65:
        mov    $0x0,%bh
L_000d67:
        mov    0x27,%bl
L_000d6b:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_000d6d:
        cmp    $0x0,%al
L_000d6f:
        js L_000da0
