# sub_20cf — mechanical clean (bulk wave); behavior not yet reviewed
# func 20CF..20D6  len 0008 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_20cf:
L_0022cf:
        inc    %si
L_0022d0:
        clc
L_0022d1:
        rcr    $1,%al
L_0022d3:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_0022d5:
        jne L_0022cf
