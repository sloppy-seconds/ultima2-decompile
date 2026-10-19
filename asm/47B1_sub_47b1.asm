# sub_47b1 — mechanical clean (bulk wave); behavior not yet reviewed
# func 47B1..47B3  len 0003 B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_47b1:
L_0049b1:
        .byte 0x01,0x8b,0xfb  # forced-kept: gas re-encodes 'add    %cx,-0x7505(%bp,%di)' differently
