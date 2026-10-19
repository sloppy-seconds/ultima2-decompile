# sub_20d7 — mechanical clean (bulk wave); behavior not yet reviewed
# func 20D7..20EA  len 0014 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_20d7:
L_0022d7:
        mov    0x20,%al
L_0022da:
        .byte 0x8b,0xde  # forced-kept: gas re-encodes 'mov    %si,%bx' differently
L_0022dc:
        mov    %bl,0x20
L_0022e0:
        stc
L_0022e1:
        cmc
L_0022e2:
        sbb    0x20,%al
L_0022e6:
        cmc
L_0022e7:
        mov    $0x0,%ah
L_0022e9:
        .byte 0x8b,0xf8  # forced-kept: gas re-encodes 'mov    %ax,%di' differently
