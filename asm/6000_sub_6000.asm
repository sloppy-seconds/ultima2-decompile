# sub_6000 — mechanical clean (bulk wave); behavior not yet reviewed
# func 6000..6077  len 0078 B  evidence: reko
# calls: L_006278, L_006344, L_006ac0, L_006aed
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_6000:
L_006200:
        nop
L_006201:
        mov    0x2,%al
L_006204:
        mov    %al,0x483
L_006207:
        mov    0x3,%al
L_00620a:
        mov    %al,0x484
L_00620d:
        cmpb   $0x0,0x26
L_006212:
        je L_00621d
L_006214:
        call L_006278
L_006217:
        call L_006344
L_00621a:
        call L_006aed
L_00621d:
        mov    0x2,%al
L_006220:
        mov    %al,0x483
L_006223:
        mov    0x3,%al
L_006226:
        mov    %al,0x484
L_006229:
        mov    0x0,%al
L_00622c:
        mov    %al,0x23
L_00622f:
        mov    0x1,%al
L_006232:
        mov    %al,0x24
L_006235:
        call L_006ac0
L_006238:
        mov    %al,0x14
L_00623b:
        mov    0x0,%al
L_00623e:
        clc
L_00623f:
        adc    0x483,%al
L_006243:
        mov    %al,0x23
L_006246:
        mov    0x1,%al
L_006249:
        clc
L_00624a:
        adc    0x484,%al
L_00624e:
        mov    %al,0x24
L_006251:
        call L_006ac0
L_006254:
        mov    %al,0x15
L_006257:
        mov    0x0,%al
L_00625a:
        stc
L_00625b:
        cmc
L_00625c:
        sbb    0x483,%al
L_006260:
        cmc
L_006261:
        mov    %al,0x23
L_006264:
        mov    0x1,%al
L_006267:
        stc
L_006268:
        cmc
L_006269:
        sbb    0x484,%al
L_00626d:
        cmc
L_00626e:
        mov    %al,0x24
L_006271:
        call L_006ac0
L_006274:
        mov    %al,0x16
L_006277:
        ret
