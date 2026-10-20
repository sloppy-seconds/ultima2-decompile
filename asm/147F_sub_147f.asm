# sub_147f — mechanical clean (bulk wave); behavior not yet reviewed
# func 147F..152D  len 00AF B  evidence: call+reko
# calls: L_00164c, L_001694, L_005417
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_147f:
L_00167f:
        nop
L_001680:
        mov    $0x0,%bh
L_001682:
        mov    $0x1f,%bl
L_001684:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_001686:
        .byte 0x8b,0xdf  # forced-kept: gas re-encodes 'mov    %di,%bx' differently
L_001688:
        mov    %bl,0x1f
L_00168c:
        mov    0x197(%di),%al
L_001690:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_001692:
        je L_0016a0
L_001694:
        mov    $0x0,%bh
L_001696:
        mov    0x1f,%bl
L_00169a:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_00169c:
        dec    %di
L_00169d:
        jne L_001686
L_00169f:
        ret
L_0016a0:
        nop
L_0016a1:
        call L_005417
L_0016a4:
        mov    $0x0,%bh
L_0016a6:
        mov    0x1f,%bl
L_0016aa:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_0016ac:
        and    $0x7,%al
L_0016ae:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_0016b0:
        or     $0x1,%al
L_0016b2:
        mov    %al,0x137(%di)
L_0016b6:
        mov    %al,0x23
L_0016b9:
        call L_005417
L_0016bc:
        mov    $0x0,%bh
L_0016be:
        mov    0x1f,%bl
L_0016c2:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_0016c4:
        and    $0x7,%al
L_0016c6:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_0016c8:
        or     $0x1,%al
L_0016ca:
        mov    %al,0x157(%di)
L_0016ce:
        mov    %al,0x24
L_0016d1:
        .byte 0x8b,0xc7  # forced-kept: gas re-encodes 'mov    %di,%ax' differently
L_0016d3:
        clc
L_0016d4:
        rcr    $1,%al
L_0016d6:
        mov    %al,0x1b7(%di)
L_0016da:
        call L_00164c
L_0016dd:
        jne L_001694
L_0016df:
        call L_005417
L_0016e2:
        mov    $0x0,%bh
L_0016e4:
        mov    0x1f,%bl
L_0016e8:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_0016ea:
        and    $0x7,%al
L_0016ec:
        cmp    $0x7,%al
L_0016ee:
        je L_0016fa
L_0016f0:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_0016f2:
        cmp    0x1b7(%di),%al
L_0016f6:
        je L_0016fc
L_0016f8:
        jb L_0016fc
L_0016fa:
        jmp L_001694
L_0016fc:
        nop
L_0016fd:
        clc
L_0016fe:
        rcr    $1,%al
L_001700:
        adc    $0x1,%al
L_001702:
        mov    %al,0x197(%di)
L_001706:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_001708:
        adc    0x1b7(%di),%al
L_00170c:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_00170e:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_001710:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_001712:
        or     $0x10,%al
L_001714:
        mov    %al,0x177(%di)
L_001718:
        call L_00164c
L_00171b:
        mov    0x8,%bx
L_00171f:
        mov    (%bx,%si),%al
L_001721:
        or     0x197(%di),%al
L_001725:
        mov    0x8,%bx
L_001729:
        mov    %al,(%bx,%si)
L_00172b:
        jmp L_001694
