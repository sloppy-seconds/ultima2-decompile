# sub_0c09 — mechanical clean (bulk wave); behavior not yet reviewed
# func 0C09..0C1B  len 0013 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0c09:
L_000e09:
        mov    %al,0x22
L_000e0c:
        stc
L_000e0d:
        mov    0x51,%al
L_000e10:
        cmc
L_000e11:
        sbb    0x22,%al
L_000e15:
        das
L_000e16:
        cmc
L_000e17:
        mov    %al,0x51
L_000e1a:
        jae L_000e62
