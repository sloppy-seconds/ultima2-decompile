# sub_225a — mechanical clean (bulk wave); behavior not yet reviewed
# func 225A..226E  len 0015 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_225a:
L_00245a:
        mov    %al,0x1b7(%di)
L_00245e:
        mov    0x197(%di),%al
L_002462:
        mov    0x6,%bx
L_002466:
        mov    %al,(%bx,%si)
L_002468:
        mov    0x4a,%al
L_00246b:
        cmp    $0x0,%al
L_00246d:
        je L_002472
