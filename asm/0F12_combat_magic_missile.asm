# combat_magic_missile — magic-missile combat spell event
# name-evidence: string 'MAGIC MISSILE!'
# func 0F12..0F47  len 0036 B  evidence: call+reko
# strings: "MAGIC MISSILE!"
# calls: L_004d26, L_0051df (str_out), L_0061c3
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
combat_magic_missile:
L_001112:
        call L_0051df
        db "MAGIC MISSILE!",0x0d,0x00        # string
L_001125:
        call L_004d26
L_001128:
        call L_0061c3
L_00112b:
        call L_004d26
L_00112e:
        incb   0x20
L_001132:
        incb   0x20
L_001136:
        incb   0x21
L_00113a:
        incb   0x21
L_00113e:
        .byte 0xf8  # forced-kept: gas re-encodes 'clc' differently
L_00113f:
        .byte 0xa0,0x22,0x00  # forced-kept: gas re-encodes 'mov    0x22,%al' differently
L_001142:
        .byte 0x14,0x40  # forced-kept: gas re-encodes 'adc    $0x40,%al' differently
L_001144:
        .byte 0xa2,0x22,0x00  # forced-kept: gas re-encodes 'mov    %al,0x22' differently
L_001147:
        .byte 0xc3  # forced-kept: gas re-encodes 'ret' differently
