# sub_2e13 — mechanical clean (bulk wave); behavior not yet reviewed
# func 2E13..2E39  len 0027 B  evidence: seed+reko
# calls: L_000c33, L_001651, L_0061e0
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2e13:
L_003013:
        jmp L_000c33
L_003016:
        nop
L_003017:
        call L_0061e0
L_00301a:
        mov    0x0,%al
L_00301d:
        clc
L_00301e:
        adc    0x2,%al
L_003022:
        mov    %al,0x23
L_003025:
        mov    0x1,%al
L_003028:
        clc
L_003029:
        adc    0x3,%al
L_00302d:
        mov    %al,0x24
L_003030:
        mov    0x25,%al
L_003033:
        call L_001651
L_003036:
        and    $0x7,%al
L_003038:
        jne L_00303d
