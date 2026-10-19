# sub_215c — mechanical clean (bulk wave); behavior not yet reviewed
# func 215C..2165  len 000A B  evidence: seed+reko
# calls: L_0052b3
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_215c:
L_00235c:
        mov    0x137(%di),%al
L_002360:
        mov    %al,0x23
L_002363:
        call L_0052b3
