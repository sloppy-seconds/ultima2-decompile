# sub_3c04 — mechanical clean (bulk wave); behavior not yet reviewed
# func 3C04..3C2D  len 002A B  evidence: seed+reko
# calls: L_000c33, L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_3c04:
L_003e04:
        .byte 0xf9  # forced-kept: gas re-encodes 'stc' differently
L_003e05:
        .byte 0xa0,0xe3,0x00  # forced-kept: gas re-encodes 'mov    0xe3,%al' differently
L_003e08:
        .byte 0xf5  # forced-kept: gas re-encodes 'cmc' differently
L_003e09:
        .byte 0x1c,0x01  # forced-kept: gas re-encodes 'sbb    $0x1,%al' differently
L_003e0b:
        .byte 0x2f  # forced-kept: gas re-encodes 'das' differently
L_003e0c:
        .byte 0xf5  # forced-kept: gas re-encodes 'cmc' differently
L_003e0d:
        .byte 0xa2,0xe3,0x00  # forced-kept: gas re-encodes 'mov    %al,0xe3' differently
L_003e10:
        call L_0051df
        db 0x8d,"YOU RUB A COIN...",0x00        # string
L_003e26:
        .byte 0xb0,0x14  # forced-kept: gas re-encodes 'mov    $0x14,%al' differently
L_003e28:
        .byte 0xa2,0x6a,0x02  # forced-kept: gas re-encodes 'mov    %al,0x26a' differently
L_003e2b:
        jmp L_000c33
