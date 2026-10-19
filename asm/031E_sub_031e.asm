# sub_031e — mechanical clean (bulk wave); behavior not yet reviewed
# func 031E..031E  len 0001 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_031e:
L_00051e:
        .byte 0xc6  # forced-kept: gas re-encodes 'movb   $0xf,0x2f' differently
