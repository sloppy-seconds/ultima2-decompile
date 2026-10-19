# sub_4f20 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4F20..4F31  len 0012 B  evidence: seed+reko
# calls: L_0052d8
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4f20:
L_005120:
        mov    %al,0x19
L_005123:
        stc
L_005124:
        mov    0x1,%al
L_005127:
        sub    0x157(%di),%al
L_00512b:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_00512d:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_00512f:
        call L_0052d8
