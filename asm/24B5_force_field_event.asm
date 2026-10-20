# force_field_event — dungeon force-field damage (ring protects)
# name-evidence: strings 'RING PROTECTS FROM FIELD!' / 'FIELD CAUSES 1000 DAMAGE!'
# func 24B5..251F  len 006B B  evidence: seed+reko
# calls: L_000e62, L_002720, L_0051df (str_out), L_00543e, L_0060f2
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
force_field_event:
L_0026b5:
        mov    0xd6,%al
L_0026b8:
        cmp    $0x0,%al
L_0026ba:
        je L_0026e0
L_0026bc:
        call L_0051df
        db 0x8d,"RING PROTECTS FROM FIELD!",0x00        # string
L_0026da:
        call L_0060f2
L_0026dd:
        jmp L_002720
L_0026df:
        nop
L_0026e0:
        call L_0051df
        db 0x8d,"FIELD CAUSES 1000 DAMAGE!",0x00        # string
L_0026fe:
        mov    $0x0,%al
L_002700:
        mov    %al,0x19
L_002703:
        mov    %al,0x1a
L_002706:
        call L_00543e
L_002709:
        call L_0060f2
L_00270c:
        call L_00543e
L_00270f:
        mov    0x51,%al
L_002712:
        stc
L_002713:
        cmc
L_002714:
        sbb    $0x10,%al
L_002716:
        das
L_002717:
        cmc
L_002718:
        mov    %al,0x51
L_00271b:
        jb L_002720
L_00271d:
        jmp L_000e62
