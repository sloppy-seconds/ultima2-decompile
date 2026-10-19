# sub_475b — mechanical clean (bulk wave); behavior not yet reviewed
# func 475B..475B  len 0001 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_475b:
L_00495b:
        .byte 0x8a  # forced-kept: gas re-encodes 'mov    0x76(%di),%al' differently
