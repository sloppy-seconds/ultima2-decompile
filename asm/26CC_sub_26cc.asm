# sub_26cc — mechanical clean (bulk wave); behavior not yet reviewed
# func 26CC..26F1  len 0026 B  evidence: seed+reko
# calls: L_005cb1
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_26cc:
L_0028cc:
        clc
L_0028cd:
        mov    0x49,%al
L_0028d0:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_0028d2:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_0028d4:
        .byte 0x02,0xc0  # forced-kept: gas re-encodes 'add    %al,%al' differently
L_0028d6:
        adc    0x6e,%al
L_0028da:
        mov    $0x0,%ah
L_0028dc:
        .byte 0x8b,0xf8  # forced-kept: gas re-encodes 'mov    %ax,%di' differently
L_0028de:
        mov    %cs:0x2798(%di),%al
L_0028e3:
        mov    %al,0x0
L_0028e6:
        inc    %di
L_0028e7:
        mov    %cs:0x2798(%di),%al
L_0028ec:
        mov    %al,0x1
L_0028ef:
        call L_005cb1
