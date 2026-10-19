# sub_2052 — mechanical clean (bulk wave); behavior not yet reviewed
# func 2052..206F  len 001E B  evidence: seed+call+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2052:
L_002252:
        nop
L_002253:
        stc
L_002254:
        mov    0x59,%al
L_002257:
        cmc
L_002258:
        sbb    0x28,%al
L_00225c:
        das
L_00225d:
        cmc
L_00225e:
        mov    %al,0x59
L_002261:
        mov    0x58,%al
L_002264:
        cmc
L_002265:
        sbb    0x27,%al
L_002269:
        das
L_00226a:
        cmc
L_00226b:
        mov    %al,0x58
L_00226e:
        jb L_0022a7
