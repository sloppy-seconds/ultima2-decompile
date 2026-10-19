# sub_34c3 — mechanical clean (bulk wave); behavior not yet reviewed
# func 34C3..34CE  len 000C B  evidence: reko
# calls: L_0024fd
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_34c3:
L_0036c3:
        mov    %al,0x5a
L_0036c6:
        mov    0x1,%al
L_0036c9:
        mov    %al,0x5b
L_0036cc:
        call L_0024fd
