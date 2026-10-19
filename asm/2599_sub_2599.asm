# sub_2599 — mechanical clean (bulk wave); behavior not yet reviewed
# func 2599..25BC  len 0024 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2599:
L_002799:
        stc
L_00279a:
        mov    0x55,%al
L_00279d:
        cmc
L_00279e:
        sbb    $0x19,%al
L_0027a0:
        das
L_0027a1:
        cmc
L_0027a2:
        mov    %al,0x55
L_0027a5:
        mov    0x54,%al
L_0027a8:
        cmc
L_0027a9:
        sbb    $0x0,%al
L_0027ab:
        das
L_0027ac:
        cmc
L_0027ad:
        mov    %al,0x54
L_0027b0:
        mov    0x53,%al
L_0027b3:
        cmc
L_0027b4:
        sbb    $0x0,%al
L_0027b6:
        das
L_0027b7:
        cmc
L_0027b8:
        mov    %al,0x53
L_0027bb:
        jb L_0027c0
