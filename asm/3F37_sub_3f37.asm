# sub_3f37 — mechanical clean (bulk wave); behavior not yet reviewed
# func 3F37..3F58  len 0022 B  evidence: reko
# calls: L_0052b3, L_0055f4
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_3f37:
L_004137:
        sub    %sp,%sp
L_004139:
        clc
L_00413a:
        mov    0x0,%al
L_00413d:
        adc    0x19,%al
L_004141:
        mov    %al,0x23
L_004144:
        clc
L_004145:
        mov    0x1,%al
L_004148:
        adc    0x1a,%al
L_00414c:
        mov    %al,0x24
L_00414f:
        mov    $0x8d,%al
L_004151:
        call L_0055f4
L_004154:
        call L_0052b3
L_004157:
        js L_00415d
