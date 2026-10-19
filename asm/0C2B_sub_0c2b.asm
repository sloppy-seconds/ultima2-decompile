# sub_0c2b — mechanical clean (bulk wave); behavior not yet reviewed
# func 0C2B..0C32  len 0008 B  evidence: seed+reko
# calls: L_0028f9
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0c2b:
L_000e2b:
        mov    $0xff,%al
L_000e2d:
        mov    %al,0x12
L_000e30:
        call L_0028f9
