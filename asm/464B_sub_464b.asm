# sub_464b — mechanical clean (bulk wave); behavior not yet reviewed
# func 464B..464C  len 0002 B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_464b:
L_00484b:
        sahf
L_00484c:
        .byte 0x0b  # forced-kept: gas re-encodes 'or     %ax,%bp' differently
