# sub_0f48 — mechanical clean (bulk wave); behavior not yet reviewed
# func 0F48..0F8D  len 0046 B  evidence: call+reko
# strings: "SLEEP SPELL!"; "SAVED BY IDOL!"
# calls: L_004d26, L_0051df (str_out), L_005417, L_0061c3
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0f48:
L_001148:
        call L_0051df
        db "SLEEP SPELL!",0x0d,0x00        # string
L_001159:
        call L_004d26
L_00115c:
        call L_0061c3
L_00115f:
        call L_004d26
L_001162:
        mov    0xe4,%al
L_001165:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_001167:
        je L_001184
L_001169:
        call L_005417
L_00116c:
        cmp    $0x40,%al
L_00116e:
        jb L_001184
L_001170:
        call L_0051df
        db "SAVED BY IDOL!",0x8d,0x00        # string
L_001183:
        ret
L_001184:
        nop
L_001185:
        call L_005417
L_001188:
        and    $0xf,%al
L_00118a:
        mov    %al,0x26d
L_00118d:
        ret
