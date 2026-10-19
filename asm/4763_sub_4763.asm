# sub_4763 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4763..4770  len 000E B  evidence: seed+reko
# calls: L_00528c
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4763:
L_004963:
        .byte 0x8b,0xdf  # forced-kept: gas re-encodes 'mov    %di,%bx' differently
L_004965:
        mov    %bl,0x1f
L_004969:
        .byte 0x8b,0xc7  # forced-kept: gas re-encodes 'mov    %di,%ax' differently
L_00496b:
        clc
L_00496c:
        adc    $0x13,%al
L_00496e:
        call L_00528c
