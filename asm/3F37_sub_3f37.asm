# sub_3f37 — mechanical clean (bulk wave); behavior not yet reviewed
# func 3F37..3F58  len 0022 B  evidence: reko
# calls: L_0052b3, L_0055f4
# confidence: low (bytes proven by check_func.py)
# body corrected: 2026-10-28e -- evidence: the first two bytes are the operand of `call L_002562`
#           (`e8 29 e4`) whose opcode the map left at asm/3F36; `sub %sp,%sp` was that operand
#           read as an instruction. Everything from `clc` onward was already aligned and is
#           unchanged. Found by tools/forced_keep_audit.py.
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_3f37:
L_004137:
        .byte 0x29, 0xe4   # tail of `call L_002562` (stop-trunc) started at asm/3F36
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
