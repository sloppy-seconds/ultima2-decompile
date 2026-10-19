# sub_2216 — mechanical clean (bulk wave); behavior not yet reviewed
# func 2216..2232  len 001D B  evidence: seed+reko
# calls: L_0052b3
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2216:
L_002416:
        mov    0x23,%al
L_002419:
        mov    %al,0x27
L_00241c:
        mov    0x24,%al
L_00241f:
        mov    %al,0x28
L_002422:
        mov    0x137(%di),%al
L_002426:
        mov    %al,0x23
L_002429:
        mov    0x157(%di),%al
L_00242d:
        mov    %al,0x24
L_002430:
        call L_0052b3
