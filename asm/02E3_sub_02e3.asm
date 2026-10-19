# sub_02e3 — mechanical clean (bulk wave); behavior not yet reviewed
# func 02E3..02E5  len 0003 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_02e3:
L_0004e3:
        mov    $0xb,%al
L_0004e5:
        .byte 0xa2  # forced-kept: gas re-encodes 'mov    %al,0x2f' differently
