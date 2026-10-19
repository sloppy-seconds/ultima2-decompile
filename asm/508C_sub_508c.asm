# sub_508c — mechanical clean (bulk wave); behavior not yet reviewed
# func 508C..5092  len 0007 B  evidence: seed+call+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_508c:
L_00528c:
        mov    $0x0,%ah
L_00528e:
        .byte 0x8b,0xf0  # forced-kept: gas re-encodes 'mov    %ax,%si' differently
L_005290:
        mov    $0x0,%di
