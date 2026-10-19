# sub_4a74 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4A74..4A88  len 0015 B  evidence: seed+call+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4a74:
L_004c74:
        push   %ax
L_004c75:
        push   %bx
L_004c76:
        push   %dx
L_004c77:
        push   %di
L_004c78:
        push   %si
L_004c79:
        push   %es
L_004c7a:
        .byte 0x8b,0xf1  # forced-kept: gas re-encodes 'mov    %cx,%si' differently
L_004c7c:
        shr    $1,%ax
L_004c7e:
        shr    $1,%ax
L_004c80:
        .byte 0x8b,0xf8  # forced-kept: gas re-encodes 'mov    %ax,%di' differently
L_004c82:
        shl    $1,%bx
L_004c84:
        mov    $0x10,%dl
L_004c86:
        add    $0x2,%si
