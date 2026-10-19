# sub_4ac3 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4AC3..4ACD  len 000B B  evidence: seed+reko
# calls: L_004c74
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4ac3:
L_004cc3:
        mov    $0x0,%ch
L_004cc5:
        .byte 0x8b,0xf9  # forced-kept: gas re-encodes 'mov    %cx,%di' differently
L_004cc7:
        mov    0x5b0(%di),%cx
L_004ccb:
        call L_004c74
