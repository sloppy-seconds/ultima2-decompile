# sub_02a0 — mechanical clean (bulk wave); behavior not yet reviewed
# func 02A0..02A2  len 0003 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_02a0:
L_0004a0:
        mov    $0x16,%al
L_0004a2:
        .byte 0xa2  # forced-kept: gas re-encodes 'mov    %al,0x2f' differently
