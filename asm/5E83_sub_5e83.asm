# sub_5e83 — mechanical clean (bulk wave); behavior not yet reviewed
# func 5E83..5EAB  len 0029 B  evidence: call
# calls: L_005eb2, L_005ed2, L_005ee4
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5e83:
L_006083:
        cmpb   $0x0,0x54d
L_006088:
        jne L_0060ab
L_00608a:
        push   %ax
L_00608b:
        push   %bx
L_00608c:
        push   %cx
L_00608d:
        push   %dx
L_00608e:
        mov    $0x800,%bx
L_006091:
        call L_005eb2
L_006094:
        mov    $0x100,%dx
L_006097:
        .byte 0x8b,0xca  # forced-kept: gas re-encodes 'mov    %dx,%cx' differently
L_006099:
        call L_005ed2
L_00609c:
        sub    $0x2,%dx
L_00609f:
        sub    $0x40,%bx
L_0060a2:
        jns L_006097
L_0060a4:
        call L_005ee4
L_0060a7:
        pop    %dx
L_0060a8:
        pop    %cx
L_0060a9:
        pop    %bx
L_0060aa:
        pop    %ax
L_0060ab:
        ret
