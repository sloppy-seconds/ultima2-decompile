# sub_4658 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4658..465F  len 0008 B  evidence: reko
# calls: L_00528c
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4658:
L_004858:
        arpl   %ax,(%bx,%si)
L_00485a:
        clc
L_00485b:
        adc    $0x24,%al
L_00485d:
        call L_00528c
