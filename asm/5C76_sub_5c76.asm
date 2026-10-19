# sub_5c76 — mechanical clean (bulk wave); behavior not yet reviewed
# func 5C76..5C87  len 0012 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5c76:
L_005e76:
        mov    0x272(%di),%al
L_005e7a:
        and    $0x7f,%al
L_005e7c:
        mov    %al,0x372(%di)
L_005e80:
        inc    %di
L_005e81:
        .byte 0x8b,0xdf  # forced-kept: gas re-encodes 'mov    %di,%bx' differently
L_005e83:
        cmp    $0xf0,%bl
L_005e86:
        jne L_005e76
