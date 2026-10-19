# sub_53c5 — mechanical clean (bulk wave); behavior not yet reviewed
# func 53C5..53CD  len 0009 B  evidence: seed+reko
# calls: L_005203
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_53c5:
L_0055c5:
        .byte 0x8a,0xc4  # forced-kept: gas re-encodes 'mov    %ah,%al' differently
L_0055c7:
        and    $0xf,%al
L_0055c9:
        or     $0x30,%al
L_0055cb:
        call L_005203
