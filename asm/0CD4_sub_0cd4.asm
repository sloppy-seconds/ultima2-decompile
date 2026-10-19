# sub_0cd4 — mechanical clean (bulk wave); behavior not yet reviewed
# func 0CD4..0CD8  len 0005 B  evidence: seed+reko
# calls: L_000edc
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0cd4:
L_000ed4:
        and    $0x3f,%al
L_000ed6:
        jmp L_000edc
L_000ed8:
        nop
