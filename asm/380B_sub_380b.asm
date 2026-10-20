# sub_380b — mechanical clean (bulk wave); behavior not yet reviewed
# func 380B..3811  len 0007 B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_380b:
L_003a0b:
        inc    %cx
L_003a0c:
        push   %sp
L_003a0d:
        aas
L_003a0e:
        add    %ch,%cl
L_003a10:
        and    %dx,%dx
