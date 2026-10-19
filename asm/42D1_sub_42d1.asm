# sub_42d1 — mechanical clean (bulk wave); behavior not yet reviewed
# func 42D1..42E1  len 0011 B  evidence: seed+reko
# calls: L_0053a5
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_42d1:
L_0044d1:
        .byte 0x8b,0xdf  # forced-kept: gas re-encodes 'mov    %di,%bx' differently
L_0044d3:
        mov    %bl,0x1f
L_0044d7:
        .byte 0x8b,0xc7  # forced-kept: gas re-encodes 'mov    %di,%ax' differently
L_0044d9:
        mov    $0x0,%bh
L_0044db:
        mov    $0x0,%bl
L_0044dd:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_0044df:
        call L_0053a5
