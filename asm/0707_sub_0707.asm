# sub_0707 — mechanical clean (bulk wave); behavior not yet reviewed
# func 0707..070F  len 0009 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0707:
L_000907:
        mov    %ax,0x580(%bx)
L_00090b:
        sub    $0x2,%bx
L_00090e:
        jae L_0008f0
