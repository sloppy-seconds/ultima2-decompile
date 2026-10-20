# sub_5e3a — mechanical clean (bulk wave); behavior not yet reviewed
# func 5E3A..5E82  len 0049 B  evidence: seed+reko
# calls: L_005eb2, L_005ed2, L_005ee4, L_005fa9
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5e3a:
L_00603a:
        ret
L_00603b:
        push   %ax
L_00603c:
        push   %bx
L_00603d:
        push   %cx
L_00603e:
        push   %dx
L_00603f:
        mov    $0x100,%ax
L_006042:
        mov    $0x4000,%bx
L_006045:
        mov    $0x1,%cx
L_006048:
        mov    $0x1000,%dx
L_00604b:
        mov    $0x80,%bp
L_00604e:
        call L_005fa9
L_006051:
        pop    %dx
L_006052:
        pop    %cx
L_006053:
        pop    %bx
L_006054:
        pop    %ax
L_006055:
        ret
L_006056:
        cmpb   $0x0,0x54d
L_00605b:
        jne L_006082
L_00605d:
        push   %ax
L_00605e:
        push   %bx
L_00605f:
        push   %cx
L_006060:
        push   %dx
L_006061:
        mov    $0x400,%dx
L_006064:
        mov    $0x600,%bx
L_006067:
        call L_005eb2
L_00606a:
        .byte 0x8b,0xca  # forced-kept: gas re-encodes 'mov    %dx,%cx' differently
L_00606c:
        call L_005ed2
L_00606f:
        add    $0x40,%bx
L_006072:
        sub    $0x20,%dx
L_006075:
        cmp    $0x100,%dx
L_006079:
        ja L_00606a
L_00607b:
        call L_005ee4
L_00607e:
        pop    %dx
L_00607f:
        pop    %cx
L_006080:
        pop    %bx
L_006081:
        pop    %ax
L_006082:
        ret
