# sub_53d0 — mechanical clean (bulk wave); behavior not yet reviewed
# func 53D0..53D8  len 0009 B  evidence: call+reko
# calls: L_00514d
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_53d0:
L_0055d0:
        call L_00514d
L_0055d3:
        cmp    $0xff,%ah
L_0055d6:
        jne L_0055d0
L_0055d8:
        ret
