# sub_4b76 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4B76..4BA9  len 0034 B  evidence: call+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4b76:
L_004d76:
        push   %es
L_004d77:
        mov    $0x0,%ah
L_004d79:
        mov    0x479,%al
L_004d7c:
        add    0x4bf,%ax
L_004d80:
        .byte 0x8b,0xf8  # forced-kept: gas re-encodes 'mov    %ax,%di' differently
L_004d82:
        mov    $0x0,%ah
L_004d84:
        mov    0x47a,%al
L_004d87:
        add    0x4c1,%ax
L_004d8b:
        .byte 0x8b,0xf0  # forced-kept: gas re-encodes 'mov    %ax,%si' differently
L_004d8d:
        .byte 0x8b,0xdf  # forced-kept: gas re-encodes 'mov    %di,%bx' differently
L_004d8f:
        .byte 0x81,0xe3,0x03,0x00  # forced-kept: gas re-encodes 'and    $0x3,%bx' differently
L_004d93:
        shr    $1,%di
L_004d95:
        shr    $1,%di
L_004d97:
        shl    $1,%si
L_004d99:
        mov    %cs:0x48dc(%si),%ax
L_004d9e:
        mov    %ax,%es
L_004da0:
        mov    %cs:0x48d0(%bx),%al
L_004da5:
        or     %al,%es:(%di)
L_004da8:
        pop    %es
L_004da9:
        ret
