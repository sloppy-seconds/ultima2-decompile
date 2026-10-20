# sub_3f5d — mechanical clean (bulk wave); behavior not yet reviewed
# func 3F5D..404F  len 00F3 B  evidence: reko
# strings: "NO LUCK!"; "STEAL FOOD!"; "STEAL ARMOUR!"; "STEAL WEAPONS!"
# calls: L_000c33, L_00133a, L_004198, L_004224, L_0051df (str_out), L_0052b3, L_005417
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_3f5d:
L_00415d:
        nop
L_00415e:
        clc
L_00415f:
        mov    0x23,%al
L_004162:
        adc    0x19,%al
L_004166:
        mov    %al,0x23
L_004169:
        clc
L_00416a:
        mov    0x24,%al
L_00416d:
        adc    0x1a,%al
L_004171:
        mov    %al,0x24
L_004174:
        call L_0052b3
L_004177:
        cmp    $0x68,%al
L_004179:
        jne L_00417e
L_00417b:
        jmp L_004198
L_00417d:
        nop
L_00417e:
        call L_0051df
        db "NO LUCK!",0x00        # string
L_00418a:
        call L_005417
L_00418d:
        and    $0x7,%al
L_00418f:
        jne L_004194
L_004191:
        call L_00133a
L_004194:
        nop
L_004195:
        jmp L_000c33
L_004198:
        nop
L_004199:
        mov    0x47,%al
L_00419c:
        cmp    $0x3,%al
L_00419e:
        je L_0041a5
L_0041a0:
        call L_005417
L_0041a3:
        js L_00417e
L_0041a5:
        nop
L_0041a6:
        call L_005417
L_0041a9:
        js L_00417e
L_0041ab:
        mov    0x1d7,%al
L_0041ae:
        cmp    $0x1,%al
L_0041b0:
        je L_00417e
L_0041b2:
        mov    0x4a,%al
L_0041b5:
        cmp    $0x1,%al
L_0041b7:
        je L_0041ce
L_0041b9:
        cmp    $0x2,%al
L_0041bb:
        jne L_00417e
L_0041bd:
        mov    0x1,%al
L_0041c0:
        cmp    $0x20,%al
L_0041c2:
        jae L_00417e
L_0041c4:
        mov    0x0,%al
L_0041c7:
        cmp    $0x20,%al
L_0041c9:
        jae L_0041f9
L_0041cb:
        jmp L_004224
L_0041cd:
        nop
L_0041ce:
        mov    0x1,%al
L_0041d1:
        cmp    $0x20,%al
L_0041d3:
        jae L_00417e
L_0041d5:
        mov    0x0,%al
L_0041d8:
        cmp    $0x20,%al
L_0041da:
        jb L_00417e
L_0041dc:
        nop
L_0041dd:
        call L_0051df
        db "STEAL FOOD!",0x00        # string
L_0041ec:
        clc
L_0041ed:
        mov    0x53,%al
L_0041f0:
        adc    $0x1,%al
L_0041f2:
        daa
L_0041f3:
        mov    %al,0x53
L_0041f6:
        jmp L_000c33
L_0041f9:
        nop
L_0041fa:
        call L_0051df
        db "STEAL ARMOUR!",0x00        # string
L_00420b:
        call L_005417
L_00420e:
        and    $0x3,%al
L_004210:
        mov    $0x0,%ah
L_004212:
        .byte 0x8b,0xf8  # forced-kept: gas re-encodes 'mov    %ax,%di' differently
L_004214:
        inc    %di
L_004215:
        clc
L_004216:
        mov    0x96(%di),%al
L_00421a:
        adc    $0x1,%al
L_00421c:
        daa
L_00421d:
        mov    %al,0x96(%di)
L_004221:
        jmp L_000c33
L_004224:
        nop
L_004225:
        call L_0051df
        db "STEAL WEAPONS!",0x00        # string
L_004237:
        call L_005417
L_00423a:
        and    $0x7,%al
L_00423c:
        mov    $0x0,%ah
L_00423e:
        .byte 0x8b,0xf8  # forced-kept: gas re-encodes 'mov    %ax,%di' differently
L_004240:
        inc    %di
L_004241:
        clc
L_004242:
        .byte 0x8a,0x85,0x76,0x00  # forced-kept: gas re-encodes 'mov    0x76(%di),%al' differently
L_004246:
        adc    $0x1,%al
L_004248:
        daa
L_004249:
        .byte 0x88,0x85,0x76,0x00  # forced-kept: gas re-encodes 'mov    %al,0x76(%di)' differently
L_00424d:
        jmp L_000c33
