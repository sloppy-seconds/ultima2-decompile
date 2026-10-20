# sub_4baa — mechanical clean (bulk wave); behavior not yet reviewed
# func 4BAA..4BDF  len 0036 B  evidence: call+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4baa:
L_004daa:
        push   %es
L_004dab:
        mov    $0x0,%ah
L_004dad:
        mov    0x479,%al
L_004db0:
        add    0x4bf,%ax
L_004db4:
        .byte 0x8b,0xf8  # forced-kept: gas re-encodes 'mov    %ax,%di' differently
L_004db6:
        mov    $0x0,%ah
L_004db8:
        mov    0x47a,%al
L_004dbb:
        add    0x4c1,%ax
L_004dbf:
        .byte 0x8b,0xf0  # forced-kept: gas re-encodes 'mov    %ax,%si' differently
L_004dc1:
        .byte 0x8b,0xdf  # forced-kept: gas re-encodes 'mov    %di,%bx' differently
L_004dc3:
        .byte 0x81,0xe3,0x03,0x00  # forced-kept: gas re-encodes 'and    $0x3,%bx' differently
L_004dc7:
        shr    $1,%di
L_004dc9:
        shr    $1,%di
L_004dcb:
        shl    $1,%si
L_004dcd:
        mov    %cs:0x48dc(%si),%ax
L_004dd2:
        mov    %ax,%es
L_004dd4:
        mov    %cs:0x48d0(%bx),%al
L_004dd9:
        xor    $0xff,%al
L_004ddb:
        and    %al,%es:(%di)
L_004dde:
        pop    %es
L_004ddf:
        ret
