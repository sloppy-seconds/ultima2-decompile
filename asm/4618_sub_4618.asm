# sub_4618 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4618..461F  len 0008 B  evidence: reko
# calls: L_00528c
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4618:
L_004818:
        bound  %ax,(%bx,%si)
L_00481a:
        clc
L_00481b:
        adc    $0x1d,%al
L_00481d:
        call L_00528c
