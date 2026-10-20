# combat_thief_steal — thief steals something mid-combat
# name-evidence: string 'A THIEF STOLE SOMETHING!'
# func 0FCD..1012  len 0046 B  evidence: call+reko
# strings: "A THIEF STOLE SOMETHING!"
# calls: L_0051df (str_out), L_005417
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
combat_thief_steal:
L_0011cd:
        nop
L_0011ce:
        call L_005417
L_0011d1:
        cmp    $0x40,%al
L_0011d3:
        jb L_0011d6
L_0011d5:
        ret
L_0011d6:
        nop
L_0011d7:
        call L_005417
L_0011da:
        .byte 0x25,0x0f,0x00  # forced-kept: gas re-encodes 'and    $0xf,%ax' differently
L_0011dd:
        .byte 0x8b,0xf8  # forced-kept: gas re-encodes 'mov    %ax,%di' differently
L_0011df:
        mov    0xd6(%di),%al
L_0011e3:
        .byte 0x0a,0xc0  # forced-kept: gas re-encodes 'or     %al,%al' differently
L_0011e5:
        je L_001212
L_0011e7:
        stc
L_0011e8:
        mov    0xd6(%di),%al
L_0011ec:
        cmc
L_0011ed:
        sbb    $0x1,%al
L_0011ef:
        das
L_0011f0:
        cmc
L_0011f1:
        mov    %al,0xd6(%di)
L_0011f5:
        call L_0051df
        db "A THIEF STOLE SOMETHING!",0x8d,0x00        # string
L_001212:
        ret
