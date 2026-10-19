# sub_406e — mechanical clean (bulk wave); behavior not yet reviewed
# func 406E..4074  len 0007 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_406e:
L_00426e:
        mov    0x4a,%al
L_004271:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_004273:
        je L_0042a6
