# sub_4861 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4861..4863  len 0003 B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4861:
L_004a61:
        .byte 0x00,0x8b,0xfb  # forced-kept: gas re-encodes 'add    %cl,-0x7505(%bp,%di)' differently
