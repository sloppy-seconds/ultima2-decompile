# sub_433e — mechanical clean (bulk wave); behavior not yet reviewed
# func 433E..4344  len 0007 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_433e:
L_00453e:
        mov    0x65,%al
L_004541:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_004543:
        jne L_00455e
