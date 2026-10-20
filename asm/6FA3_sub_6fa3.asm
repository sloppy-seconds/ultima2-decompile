# sub_6fa3 — mechanical clean (bulk wave); behavior not yet reviewed
# func 6FA3..702F  len 008D B  evidence: call+reko
# calls: L_0053eb, L_0055b5
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_6fa3:
L_0071a3:
        nop
L_0071a4:
        mov    $0x28,%al
L_0071a6:
        mov    %al,0x31
L_0071a9:
        mov    $0x0,%bh
L_0071ab:
        mov    $0x25,%bl
L_0071ad:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_0071af:
        mov    $0x0,%bh
L_0071b1:
        mov    $0x14,%bl
L_0071b3:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_0071b5:
        call L_0053eb
L_0071b8:
        mov    0xe5,%al
L_0071bb:
        call L_0055b5
L_0071be:
        mov    $0x0,%bh
L_0071c0:
        mov    $0x25,%bl
L_0071c2:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_0071c4:
        mov    $0x0,%bh
L_0071c6:
        mov    $0x15,%bl
L_0071c8:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_0071ca:
        call L_0053eb
L_0071cd:
        mov    0x4ca,%al
L_0071d0:
        call L_0055b5
L_0071d3:
        mov    $0x0,%bh
L_0071d5:
        mov    $0x25,%bl
L_0071d7:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_0071d9:
        mov    $0x0,%bh
L_0071db:
        mov    $0x16,%bl
L_0071dd:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_0071df:
        call L_0053eb
L_0071e2:
        mov    0x4cb,%al
L_0071e5:
        call L_0055b5
L_0071e8:
        mov    $0x0,%bh
L_0071ea:
        mov    $0x25,%bl
L_0071ec:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_0071ee:
        mov    $0x0,%bh
L_0071f0:
        mov    $0x17,%bl
L_0071f2:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_0071f4:
        call L_0053eb
L_0071f7:
        mov    0x4cc,%al
L_0071fa:
        call L_0055b5
L_0071fd:
        mov    $0x1f,%al
L_0071ff:
        mov    %al,0x31
L_007202:
        mov    $0x0,%bh
L_007204:
        mov    $0x0,%bl
L_007206:
        .byte 0x8b,0xfb  # forced-kept: gas re-encodes 'mov    %bx,%di' differently
L_007208:
        mov    $0x0,%bh
L_00720a:
        mov    $0x17,%bl
L_00720c:
        .byte 0x8b,0xf3  # forced-kept: gas re-encodes 'mov    %bx,%si' differently
L_00720e:
        call L_0053eb
L_007211:
        ret
L_007212:
        push   %es
L_007213:
        add    $0x603,%ax
L_007216:
        add    %ax,(%bp,%si)
L_007218:
        or     %ax,(%si)
L_00721a:
        add    %cl,(%bx,%di)
L_00721c:
        push   %es
L_00721d:
        add    $0x3,%al
L_00721f:
        add    (%bp,%di),%al
L_007221:
        or     %al,(%si)
L_007223:
        add    %al,(%bx,%di)
L_007225:
        or     %ax,0x405
L_007229:
        add    (%si),%ax
L_00722b:
        add    $0x506,%ax
L_00722e:
        add    $0x9,%al
