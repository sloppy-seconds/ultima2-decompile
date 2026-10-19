# sub_0a38 — mechanical clean (bulk wave); behavior not yet reviewed
# func 0A38..0A49  len 0012 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0a38:
L_000c38:
        mov    $0x0,%al
L_000c3a:
        mov    %al,0x22
L_000c3d:
        mov    %al,0x20
L_000c40:
        mov    %al,0x21
L_000c43:
        mov    0x4a,%al
L_000c46:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_000c48:
        je L_000c6d
