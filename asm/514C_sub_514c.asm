# sub_514c — mechanical clean (bulk wave); behavior not yet reviewed
# func 514C..514D  len 0002 B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_514c:
L_00534c:
        xchg   %ax,%cx
L_00534d:
        .byte 0x02  # forced-kept: gas re-encodes 'add    %al,%ch' differently
