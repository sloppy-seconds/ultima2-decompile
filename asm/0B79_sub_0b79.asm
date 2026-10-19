# sub_0b79 — mechanical clean (bulk wave); behavior not yet reviewed
# func 0B79..0B9A  len 0022 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0b79:
L_000d79:
        incb   0x21
L_000d7d:
        mov    0x177(%di),%al
L_000d81:
        clc
L_000d82:
        rcr    $1,%al
L_000d84:
        clc
L_000d85:
        rcr    $1,%al
L_000d87:
        stc
L_000d88:
        adc    0x22,%al
L_000d8c:
        mov    $0x0,%bh
L_000d8e:
        mov    0x14,%bl
L_000d92:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_000d94:
        .byte 0x8b,0xde  # forced-kept: gas re-encodes 'mov    %si,%bx' differently
L_000d96:
        cmp    $0x6,%bl
L_000d99:
        jne L_000d9d
