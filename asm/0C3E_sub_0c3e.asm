# sub_0c3e — mechanical clean (bulk wave); behavior not yet reviewed
# func 0C3E..0C44  len 0007 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0c3e:
L_000e3e:
        mov    0x26c,%al
L_000e41:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_000e43:
        je L_000e49
