# sub_26a8 — mechanical clean (bulk wave); behavior not yet reviewed
# func 26A8..26B6  len 000F B  evidence: seed+reko
# calls: L_0024fd
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_26a8:
L_0028a8:
        mov    0x0,%al
L_0028ab:
        mov    %al,0x5a
L_0028ae:
        mov    0x1,%al
L_0028b1:
        mov    %al,0x5b
L_0028b4:
        call L_0024fd
