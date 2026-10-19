# sub_0896 — mechanical clean (bulk wave); behavior not yet reviewed
# func 0896..08A6  len 0011 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0896:
L_000a96:
        mov    $0x0,%al
L_000a98:
        mov    %al,0x21
L_000a9b:
        mov    $0xc0,%al
L_000a9d:
        mov    %al,0x22
L_000aa0:
        mov    0x26d,%al
L_000aa3:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_000aa5:
        je L_000ac8
