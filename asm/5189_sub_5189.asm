# sub_5189 — mechanical clean (bulk wave); behavior not yet reviewed
# func 5189..5195  len 000D B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5189:
L_005389:
        .byte 0x58  # forced-kept: gas re-encodes 'pop    %ax' differently
L_00538a:
        .byte 0x00,0xb7,0x00,0x8a  # forced-kept: gas re-encodes 'add    %dh,-0x7600(%bx)' differently
L_00538e:
        .byte 0x1e  # forced-kept: gas re-encodes 'push   %ds' differently
L_00538f:
        .byte 0x59  # forced-kept: gas re-encodes 'pop    %cx' differently
L_005390:
        .byte 0x00,0x8b,0xfb,0xe8  # forced-kept: gas re-encodes 'add    %cl,-0x1705(%bp,%di)' differently
L_005394:
        .byte 0x0f,0x00  # forced-kept: gas re-encodes '(bad)' differently
