# sub_0a83 — mechanical clean (bulk wave); behavior not yet reviewed
# func 0A83..0AA0  len 001E B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0a83:
L_000c83:
        mov    0x26,%al
L_000c86:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_000c88:
        jns L_000ca7
L_000c8a:
        mov    0x197(%di),%al
L_000c8e:
        cmp    $0x48,%al
L_000c90:
        je L_000ca7
L_000c92:
        cmp    $0x3c,%al
L_000c94:
        je L_000ca7
L_000c96:
        cmp    $0x2c,%al
L_000c98:
        je L_000ca7
L_000c9a:
        mov    0x13,%al
L_000c9d:
        cmp    $0x22,%al
L_000c9f:
        jne L_000ca7
