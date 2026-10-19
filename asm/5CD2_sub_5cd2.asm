# sub_5cd2 — mechanical clean (bulk wave); behavior not yet reviewed
# func 5CD2..5CD9  len 0008 B  evidence: seed+call+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5cd2:
L_005ed2:
        .byte 0x8b,0xc3  # forced-kept: gas re-encodes 'mov    %bx,%ax' differently
L_005ed4:
        out    %al,$0x42
L_005ed6:
        .byte 0x8a,0xc4  # forced-kept: gas re-encodes 'mov    %ah,%al' differently
L_005ed8:
        out    %al,$0x42
