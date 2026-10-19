# sub_2cd8 — mechanical clean (bulk wave); behavior not yet reviewed
# func 2CD8..2CE4  len 000D B  evidence: seed+reko
# calls: L_002f8c
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2cd8:
L_002ed8:
        clc
L_002ed9:
        mov    0x65,%al
L_002edc:
        adc    $0x2,%al
L_002ede:
        daa
L_002edf:
        mov    %al,0x65
L_002ee2:
        jmp L_002f8c
