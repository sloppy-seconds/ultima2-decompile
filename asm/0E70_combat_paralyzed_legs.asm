# combat_paralyzed_legs — leg-paralysis combat event (magic boots save)
# name-evidence: strings 'LEGS PARALIZED!' / 'SAVED BY MAGICAL BOOTS!'
# func 0E70..0EC1  len 0052 B  evidence: call+reko
# strings: "LEGS PARALIZED!"; "SAVED BY MAGICAL BOOTS!"
# calls: L_004d26, L_0051df (str_out), L_005417, L_0061c3
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
combat_paralyzed_legs:
L_001070:
        call L_0051df
        db "LEGS PARALIZED!",0x0d,0x00        # string
L_001084:
        call L_004d26
L_001087:
        call L_0061c3
L_00108a:
        call L_004d26
L_00108d:
        .byte 0x80,0x3e,0xd9,0x00,0x00  # forced-kept: gas re-encodes 'cmpb   $0x0,0xd9' differently
L_001092:
        je L_0010b8
L_001094:
        call L_005417
L_001097:
        cmp    $0x40,%al
L_001099:
        jb L_0010b8
L_00109b:
        call L_0051df
        db "SAVED BY MAGICAL BOOTS!",0x8d,0x00        # string
L_0010b7:
        ret
L_0010b8:
        nop
L_0010b9:
        call L_005417
L_0010bc:
        and    $0xf,%al
L_0010be:
        mov    %al,0x26b
L_0010c1:
        ret
