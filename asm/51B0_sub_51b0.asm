# sub_51b0 — mechanical clean (bulk wave); behavior not yet reviewed
# func 51B0..51EA  len 003B B  evidence: call+reko
# calls: L_00514d, L_005203
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_51b0:
L_0053b0:
        call L_00514d
L_0053b3:
        cmp    $0xff,%ah
L_0053b6:
        jne L_0053b0
L_0053b8:
        cmp    $0x30,%al
L_0053ba:
        jb L_0053b0
L_0053bc:
        cmp    $0x39,%al
L_0053be:
        ja L_0053b0
L_0053c0:
        call L_005203
L_0053c3:
        sub    $0x30,%al
L_0053c5:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_0053c7:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_0053c9:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_0053cb:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_0053cd:
        mov    %al,0x27
L_0053d0:
        call L_00514d
L_0053d3:
        cmp    $0xff,%ah
L_0053d6:
        jne L_0053d0
L_0053d8:
        cmp    $0x30,%al
L_0053da:
        jb L_0053d0
L_0053dc:
        cmp    $0x39,%al
L_0053de:
        ja L_0053d0
L_0053e0:
        call L_005203
L_0053e3:
        sub    $0x30,%al
L_0053e5:
        clc
L_0053e6:
        adc    0x27,%al
L_0053ea:
        ret
