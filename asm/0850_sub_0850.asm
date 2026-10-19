# sub_0850 — mechanical clean (bulk wave); behavior not yet reviewed
# func 0850..0858  len 0009 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0850:
L_000a50:
        nop
L_000a51:
        mov    $0x0,%bh
L_000a53:
        mov    $0xff,%bl
L_000a55:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_000a57:
        mov    $0xff,%al
