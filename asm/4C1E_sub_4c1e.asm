# sub_4c1e — mechanical clean (bulk wave); behavior not yet reviewed
# func 4C1E..4C30  len 0013 B  evidence: seed+call+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4c1e:
L_004e1e:
        push   %dx
L_004e1f:
        push   %di
L_004e20:
        push   %si
L_004e21:
        push   %es
L_004e22:
        .byte 0x8b,0xf1  # forced-kept: gas re-encodes 'mov    %cx,%si' differently
L_004e24:
        shr    $1,%ax
L_004e26:
        shr    $1,%ax
L_004e28:
        .byte 0x8b,0xf8  # forced-kept: gas re-encodes 'mov    %ax,%di' differently
L_004e2a:
        shl    $1,%bx
L_004e2c:
        mov    $0x10,%dl
L_004e2e:
        add    $0x2,%si
