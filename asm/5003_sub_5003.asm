# sub_5003 — mechanical clean (bulk wave); behavior not yet reviewed
# func 5003..500C  len 000A B  evidence: seed+call+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5003:
L_005203:
        push   %bx
L_005204:
        push   %cx
L_005205:
        push   %dx
L_005206:
        push   %ax
L_005207:
        and    $0x7f,%al
L_005209:
        cmp    $0xd,%al
L_00520b:
        jne L_005216
