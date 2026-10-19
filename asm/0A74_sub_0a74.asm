# sub_0a74 — mechanical clean (bulk wave); behavior not yet reviewed
# func 0A74..0A7B  len 0008 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0a74:
L_000c74:
        mov    0x197(%di),%al
L_000c78:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_000c7a:
        je L_000ca1
