# sub_5121 — mechanical clean (bulk wave); behavior not yet reviewed
# func 5121..5122  len 0002 B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5121:
L_005321:
        .byte 0xbc,0x02  # forced-kept: gas re-encodes 'mov    $0xe802,%sp' differently
