# sub_4ff0 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4FF0..4FFA  len 000B B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4ff0:
L_0051f0:
        mov    0x2b,%bx
L_0051f4:
        mov    %cs:(%bx,%si),%al
L_0051f7:
        cmp    $0x0,%al
L_0051f9:
        je L_005200
