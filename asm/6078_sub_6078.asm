# sub_6078 — mechanical clean (bulk wave); behavior not yet reviewed
# func 6078..6143  len 00CC B  evidence: call+reko
# calls: L_0062b4, L_006ac0
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_6078:
L_006278:
        clc
L_006279:
        mov    0x0,%al
L_00627c:
        mov    %al,0x47b
L_00627f:
        adc    0x484,%al
L_006283:
        mov    %al,0x479
L_006286:
        stc
L_006287:
        mov    0x1,%al
L_00628a:
        mov    %al,0x47c
L_00628d:
        cmc
L_00628e:
        sbb    0x483,%al
L_006292:
        cmc
L_006293:
        mov    %al,0x47a
L_006296:
        stc
L_006297:
        mov    0x0,%al
L_00629a:
        cmc
L_00629b:
        sbb    0x484,%al
L_00629f:
        cmc
L_0062a0:
        mov    %al,0x47d
L_0062a3:
        clc
L_0062a4:
        mov    0x1,%al
L_0062a7:
        adc    0x483,%al
L_0062ab:
        mov    %al,0x47e
L_0062ae:
        mov    $0x0,%bh
L_0062b0:
        mov    $0x0,%bl
L_0062b2:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_0062b4:
        mov    0x479,%al
L_0062b7:
        and    $0x3f,%al
L_0062b9:
        mov    %al,0x23
L_0062bc:
        clc
L_0062bd:
        adc    0x483,%al
L_0062c1:
        mov    %al,0x479
L_0062c4:
        mov    0x47a,%al
L_0062c7:
        and    $0x3f,%al
L_0062c9:
        mov    %al,0x24
L_0062cc:
        clc
L_0062cd:
        adc    0x484,%al
L_0062d1:
        mov    %al,0x47a
L_0062d4:
        call L_006ac0
L_0062d7:
        and    $0xf0,%al
L_0062d9:
        mov    %al,0x48f(%di)
L_0062dd:
        mov    0x47b,%al
L_0062e0:
        and    $0x3f,%al
L_0062e2:
        mov    %al,0x23
L_0062e5:
        clc
L_0062e6:
        adc    0x483,%al
L_0062ea:
        mov    %al,0x47b
L_0062ed:
        mov    0x47c,%al
L_0062f0:
        and    $0x3f,%al
L_0062f2:
        mov    %al,0x24
L_0062f5:
        clc
L_0062f6:
        adc    0x484,%al
L_0062fa:
        mov    %al,0x47c
L_0062fd:
        call L_006ac0
L_006300:
        and    $0xf0,%al
L_006302:
        mov    %al,0x497(%di)
L_006306:
        call L_006ac0
L_006309:
        and    $0x7,%al
L_00630b:
        mov    %al,0x4af(%di)
L_00630f:
        mov    0x47d,%al
L_006312:
        and    $0x3f,%al
L_006314:
        mov    %al,0x23
L_006317:
        clc
L_006318:
        adc    0x483,%al
L_00631c:
        mov    %al,0x47d
L_00631f:
        mov    0x47e,%al
L_006322:
        and    $0x3f,%al
L_006324:
        mov    %al,0x24
L_006327:
        clc
L_006328:
        adc    0x484,%al
L_00632c:
        mov    %al,0x47e
L_00632f:
        call L_006ac0
L_006332:
        and    $0xf0,%al
L_006334:
        mov    %al,0x49f(%di)
L_006338:
        inc    %di
L_006339:
        .byte 0x8b,0xdf  # forced-kept: gas re-encodes 'mov    %di,%bx' differently
L_00633b:
        cmp    $0x8,%bl
L_00633e:
        jae L_006343
L_006340:
        jmp L_0062b4
L_006343:
        ret
