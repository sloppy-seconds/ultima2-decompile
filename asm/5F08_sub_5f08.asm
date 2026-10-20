# sub_5f08 — mechanical clean (bulk wave); behavior not yet reviewed
# func 5F08..5FA5  len 009E B  evidence: seed+reko
# calls: L_000911, L_005eed, L_0061a0, L_0061a5
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5f08:
L_006108:
        pop    %dx
L_006109:
        pop    %cx
L_00610a:
        pop    %bx
L_00610b:
        pop    %ax
L_00610c:
        ret
L_00610d:
        cmpb   $0x0,0x54d
L_006112:
        je L_006117
L_006114:
        jmp L_0061a5
L_006117:
        push   %ax
L_006118:
        push   %bx
L_006119:
        push   %cx
L_00611a:
        push   %dx
L_00611b:
        push   %bp
L_00611c:
        mov    %bx,%cs:0x5c91
L_006121:
        .byte 0x8b,0xc1  # forced-kept: gas re-encodes 'mov    %cx,%ax' differently
L_006123:
        mulw   0x74
L_006127:
        divw   0x554
L_00612b:
        mulw   0x74
L_00612f:
        divw   0x554
L_006133:
        mov    %ax,%cs:0x5c93
L_006137:
        cmpw   $0x1800,0x74
L_00613d:
        jb L_006156
L_00613f:
        .byte 0x8b,0xd0  # forced-kept: gas re-encodes 'mov    %ax,%dx' differently
L_006141:
        mov    $0x0,%ax
L_006144:
        mov    $0x1388,%bx
L_006147:
        div    %bx
L_006149:
        mov    $0x1e,%bx
L_00614c:
        mov    %ax,0x580(%bx)
L_006150:
        call L_000911
L_006153:
        jmp L_0061a0
L_006155:
        nop
L_006156:
        mov    $0x1,%bp
L_006159:
        mov    %cs:0x5c93,%dx
L_00615e:
        .byte 0x8b,0xcd  # forced-kept: gas re-encodes 'mov    %bp,%cx' differently
L_006160:
        mov    $0x3000,%bx
L_006163:
        call L_005eed
L_006166:
        mov    $0xa,%ax
L_006169:
        add    %cs:0x5c91,%ax
L_00616e:
        .byte 0x2b,0xc5  # forced-kept: gas re-encodes 'sub    %bp,%ax' differently
L_006170:
        dec    %ax
L_006171:
        jne L_006170
L_006173:
        dec    %dx
L_006174:
        jne L_00615e
L_006176:
        add    $0x1,%bp
L_006179:
        cmp    $0xa,%bp
L_00617c:
        jbe L_006159
L_00617e:
        mov    %cs:0x5c93,%dx
L_006183:
        .byte 0x8b,0xcd  # forced-kept: gas re-encodes 'mov    %bp,%cx' differently
L_006185:
        mov    $0x3000,%bx
L_006188:
        call L_005eed
L_00618b:
        mov    $0xa,%ax
L_00618e:
        add    %cs:0x5c91,%ax
L_006193:
        .byte 0x2b,0xc5  # forced-kept: gas re-encodes 'sub    %bp,%ax' differently
L_006195:
        dec    %ax
L_006196:
        jne L_006195
L_006198:
        dec    %dx
L_006199:
        jne L_006183
L_00619b:
        sub    $0x1,%bp
L_00619e:
        jne L_00617e
L_0061a0:
        pop    %bp
L_0061a1:
        pop    %dx
L_0061a2:
        pop    %cx
L_0061a3:
        pop    %bx
L_0061a4:
        pop    %ax
L_0061a5:
        ret
