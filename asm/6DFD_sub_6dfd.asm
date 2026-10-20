# sub_6dfd — mechanical clean (bulk wave); behavior not yet reviewed
# func 6DFD..6FA2  len 01A6 B  evidence: call+reko
# strings: "HYPERWARP ENGAGED!"; "SHIP OFF COURSE!"; "NO FUEL!"; "HYPERWARP TO:" (+2 more)
# calls: L_000911, L_00514d, L_0051df (str_out), L_0055f4, L_006c79, L_006d3d, L_006ec4, L_006f5b (+6 more)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_6dfd:
L_006ffd:
        call L_0051df
        db "HYPERWARP ENGAGED!",0x8d,0x00        # string
L_007014:
        mov    $0x80,%al
L_007016:
        mov    %al,0x4c8
L_007019:
        .byte 0xb0,0x00  # forced-kept: gas re-encodes 'mov    $0x0,%al' differently
L_00701b:
        mov    %al,0x4c7
L_00701e:
        call L_006f5b
L_007021:
        mov    $0x2200,%bx
L_007024:
        mov    %bx,%cs:0x6990
L_007029:
        movw   $0xffff,%cs:0x6992
L_007030:
        call L_007476
L_007033:
        call L_006d3d
L_007036:
        mov    $0x16,%bx
L_007039:
        call L_000911
L_00703c:
        decb   0x4c8
L_007040:
        jne L_007033
L_007042:
        mov    $0x80,%al
L_007044:
        mov    %al,0x4c8
L_007047:
        mov    $0x1,%al
L_007049:
        mov    %al,0x4c7
L_00704c:
        call L_0071a3
L_00704f:
        call L_006f5b
L_007052:
        movw   $0x1,%cs:0x6992
L_007059:
        call L_006d3d
L_00705c:
        mov    $0x16,%bx
L_00705f:
        call L_000911
L_007062:
        decb   0x4c8
L_007066:
        jne L_007059
L_007068:
        incb   0x4c7
L_00706c:
        movw   $0x1,%cs:0x6994
L_007073:
        call L_006d3d
L_007076:
        mov    $0x18,%bx
L_007079:
        call L_000911
L_00707c:
        incb   0x4c7
L_007080:
        incb   0x4c7
L_007084:
        jns L_007073
L_007086:
        mov    0xe5,%al
L_007089:
        clc
L_00708a:
        rcr    $1,%al
L_00708c:
        jae L_0070c0
L_00708e:
        clc
L_00708f:
        rcr    $1,%al
L_007091:
        jae L_0070c0
L_007093:
        call L_0051df
        db "SHIP OFF COURSE!",0x8d,0x00        # string
L_0070a8:
        call L_006f68
L_0070ab:
        and    $0x7,%al
L_0070ad:
        mov    %al,0x4ca
L_0070b0:
        call L_006f68
L_0070b3:
        and    $0x7,%al
L_0070b5:
        mov    %al,0x4cb
L_0070b8:
        call L_006f68
L_0070bb:
        and    $0x7,%al
L_0070bd:
        mov    %al,0x4cc
L_0070c0:
        nop
L_0070c1:
        call L_007230
L_0070c4:
        ret
L_0070c5:
        mov    0xe5,%al
L_0070c8:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_0070ca:
        jne L_0070dc
L_0070cc:
        call L_0051df
        db "NO FUEL!",0x8d,0x00        # string
L_0070d9:
        jmp L_006c79
L_0070dc:
        stc
L_0070dd:
        cmc
L_0070de:
        sbb    $0x1,%al
L_0070e0:
        das
L_0070e1:
        cmc
L_0070e2:
        mov    %al,0xe5
L_0070e5:
        call L_006ec4
L_0070e8:
        mov    $0x80,%al
L_0070ea:
        mov    %al,0x47b
L_0070ed:
        mov    $0x40,%al
L_0070ef:
        mov    %al,0x47c
L_0070f2:
        call L_0051df
        db "HYPERWARP TO:",0x8d,"XENO=",0x00        # string
L_007109:
        call L_00717f
L_00710c:
        mov    %al,0x4ca
L_00710f:
        call L_0051df
        db " YAKO=",0x00        # string
L_007119:
        call L_00717f
L_00711c:
        mov    %al,0x4cb
L_00711f:
        call L_0051df
        db " ZABO=",0x00        # string
L_007129:
        call L_00717f
L_00712c:
        mov    %al,0x4cc
L_00712f:
        call L_0051df
        db 0x8d,"PREPARE FOR HYPERWARP!",0x8d,0x00        # string
L_00714b:
        call L_006f5b
L_00714e:
        call L_006d3d
L_007151:
        mov    $0x1a,%bx
L_007154:
        call L_000911
L_007157:
        decb   0x4c7
L_00715b:
        mov    0x4c7,%al
L_00715e:
        cmp    $0x2,%al
L_007160:
        jne L_00714e
L_007162:
        mov    $0x40,%al
L_007164:
        mov    %al,0x4c8
L_007167:
        call L_006f5b
L_00716a:
        call L_006d3d
L_00716d:
        mov    $0x1a,%bx
L_007170:
        call L_000911
L_007173:
        decb   0x4c8
L_007177:
        jne L_00716a
L_007179:
        call L_006ffd
L_00717c:
        jmp L_006c79
L_00717f:
        call L_006d3d
L_007182:
        mov    $0x14,%bx
L_007185:
        call L_000911
L_007188:
        call L_00514d
L_00718b:
        cmp    $0xff,%ah
L_00718e:
        jne L_00717f
L_007190:
        cmp    $0x30,%al
L_007192:
        jb L_00717f
L_007194:
        cmp    $0x39,%al
L_007196:
        ja L_00717f
L_007198:
        push   %ax
L_007199:
        call L_0055f4
L_00719c:
        pop    %ax
L_00719d:
        stc
L_00719e:
        cmc
L_00719f:
        sbb    $0x30,%al
L_0071a1:
        cmc
L_0071a2:
        ret
