# sub_330c — mechanical clean (bulk wave); behavior not yet reviewed
# func 330C..334C  len 0041 B  evidence: call
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_330c:
L_00350c:
        mov    $0x0,%bh
L_00350e:
        mov    $0x1f,%bl
L_003510:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_003512:
        mov    0x197(%di),%al
L_003516:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_003518:
        jne L_003522
L_00351a:
        dec    %di
L_00351b:
        jne L_003512
L_00351d:
        mov    $0x0,%al
L_00351f:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_003521:
        ret
L_003522:
        mov    0x1b7(%di),%al
L_003526:
        cmp    0x25,%al
L_00352a:
        jne L_00351a
L_00352c:
        mov    0x0,%al
L_00352f:
        clc
L_003530:
        adc    0x2,%al
L_003534:
        cmp    0x137(%di),%al
L_003538:
        jne L_00351a
L_00353a:
        mov    0x1,%al
L_00353d:
        clc
L_00353e:
        adc    0x3,%al
L_003542:
        cmp    0x157(%di),%al
L_003546:
        jne L_00351a
L_003548:
        .byte 0x8b,0xc7  # forced-kept: gas re-encodes 'mov    %di,%ax' differently
L_00354a:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_00354c:
        ret
