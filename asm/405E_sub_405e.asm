# sub_405e — mechanical clean (bulk wave); behavior not yet reviewed
# func 405E..405F  len 0002 B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_405e:
L_00425e:
        .byte 0x02,0xe3  # forced-kept: gas re-encodes 'add    %bl,%ah' differently
