# sub_0b9b — mechanical clean (bulk wave); behavior not yet reviewed
# func 0B9B..0B9C  len 0002 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0b9b:
L_000d9b:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
