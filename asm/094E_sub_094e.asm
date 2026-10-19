# sub_094e — mechanical clean (bulk wave); behavior not yet reviewed
# func 094E..094E  len 0001 B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_094e:
L_000b4e:
        .byte 0xbd  # forced-kept: gas re-encodes 'mov    $0x63a,%bp' differently
