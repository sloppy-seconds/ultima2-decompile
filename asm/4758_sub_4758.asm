# sub_4758 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4758..475A  len 0003 B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4758:
L_004958:
        .byte 0x01,0x8b,0xfb  # forced-kept: gas re-encodes 'add    %cx,-0x7505(%bp,%di)' differently
