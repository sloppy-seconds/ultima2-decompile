# sub_7242 — mechanical clean (bulk wave); behavior not yet reviewed
# func 7242..7275  len 0034 B  evidence: call+reko
# calls: L_005417, L_005ed2, L_007475, L_007476, L_007489
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_7242:
L_007442:
        nop
L_007443:
        cmpb   $0xff,%cs:0x6998
L_007449:
        je L_007458
L_00744b:
        call L_007489
L_00744e:
        movw   $0xe0,%cs:0x6994
L_007455:
        jmp L_007475
L_007457:
        nop
L_007458:
        call L_005417
L_00745b:
        .byte 0x8a,0xe0  # forced-kept: gas re-encodes 'mov    %al,%ah' differently
L_00745d:
        and    $0x1f00,%ax
L_007460:
        add    $0x100,%ax
L_007463:
        .byte 0x8b,0xd8  # forced-kept: gas re-encodes 'mov    %ax,%bx' differently
L_007465:
        mov    $0x1,%cx
L_007468:
        call L_007476
L_00746b:
        call L_005ed2
L_00746e:
        movw   $0x18,%cs:0x6994
L_007475:
        ret
