# sub_45f6 — mechanical clean (bulk wave); behavior not yet reviewed
# func 45F6..45FA  len 0005 B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_45f6:
L_0047f6:
        fs add %ch,%al
L_0047f9:
        .byte 0xba,0x0d  # forced-kept: gas re-encodes 'mov    $0xb70d,%dx' differently
