# sub_212e — stage the DIAGONAL candidate cell: (mon_x+DS:19, mon_y+DS:1A) & 0x3F, then fetch
#           its tile. DS:19/DS:1A hold the clamped unit step from asm/4F11_monster_step_vector,
#           not the raw pursuit delta from asm/4F36.
# func 212E..214C  len 001F B  evidence: seed+reko
# calls: L_0052b3
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_212e:
L_00232e:
        clc
L_00232f:
        mov    0x137(%di),%al
L_002333:
        adc    0x19,%al
L_002337:
        and    $0x3f,%al
L_002339:
        mov    %al,0x23
L_00233c:
        clc
L_00233d:
        mov    0x157(%di),%al
L_002341:
        adc    0x1a,%al
L_002345:
        and    $0x3f,%al
L_002347:
        mov    %al,0x24
L_00234a:
        call L_0052b3
