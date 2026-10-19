# sub_2039 — mechanical clean (bulk wave); behavior not yet reviewed
# func 2039..2047  len 000F B  evidence: seed+reko
# calls: L_0055f4
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2039:
L_002239:
        stc
L_00223a:
        cmc
L_00223b:
        sbb    $0x30,%al
L_00223d:
        cmc
L_00223e:
        mov    $0x0,%ah
L_002240:
        .byte 0x8b,0xf8  # forced-kept: gas re-encodes 'mov    %ax,%di' differently
L_002242:
        clc
L_002243:
        adc    $0x30,%al
L_002245:
        call L_0055f4
