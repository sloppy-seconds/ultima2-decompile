# sub_4abb — mechanical clean (bulk wave); behavior not yet reviewed
# func 4ABB..4AC2  len 0008 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4abb:
L_004cbb:
        mov    0x272(%si),%cl
L_004cbf:
        .byte 0x0a,0xc9  # forced-kept: gas re-encodes 'or     %cl,%cl' differently
L_004cc1:
        js L_004cce
