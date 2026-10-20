# combat_minax_attack — Minax boss attack event
# name-evidence: string 'MINAX CRIES: DIE FOOL!'
# func 0F8E..0FCC  len 003F B  evidence: call+reko
# strings: "MINAX CRIES: DIE FOOL!"
# calls: L_000e62, L_0051df (str_out), L_00543e, L_0060f2
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
combat_minax_attack:
L_00118e:
        nop
L_00118f:
        call L_0051df
        db "MINAX CRIES: DIE FOOL!",0x8d,0x00        # string
L_0011aa:
        .byte 0xb0,0x00  # forced-kept: gas re-encodes 'mov    $0x0,%al' differently
L_0011ac:
        .byte 0xa2,0x19,0x00  # forced-kept: gas re-encodes 'mov    %al,0x19' differently
L_0011af:
        mov    %al,0x1a
L_0011b2:
        call L_00543e
L_0011b5:
        call L_0060f2
L_0011b8:
        call L_00543e
L_0011bb:
        stc
L_0011bc:
        mov    0x51,%al
L_0011bf:
        cmc
L_0011c0:
        sbb    $0x1,%al
L_0011c2:
        das
L_0011c3:
        cmc
L_0011c4:
        mov    %al,0x51
L_0011c7:
        jb L_0011cc
L_0011c9:
        jmp L_000e62
L_0011cc:
        ret
