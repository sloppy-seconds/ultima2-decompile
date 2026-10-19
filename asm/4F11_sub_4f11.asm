# sub_4f11 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4F11..4F1F  len 000F B  evidence: seed+call+reko
# calls: L_0052d8
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4f11:
L_005111:
        stc
L_005112:
        mov    0x0,%al
L_005115:
        sub    0x137(%di),%al
L_005119:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_00511b:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_00511d:
        call L_0052d8
