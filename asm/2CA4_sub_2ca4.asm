# sub_2ca4 — mechanical clean (bulk wave); behavior not yet reviewed
# func 2CA4..2CB4  len 0011 B  evidence: seed+reko
# calls: L_0052b3
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2ca4:
L_002ea4:
        mov    0x137(%di),%al
L_002ea8:
        mov    %al,0x23
L_002eab:
        mov    0x157(%di),%al
L_002eaf:
        mov    %al,0x24
L_002eb2:
        call L_0052b3
