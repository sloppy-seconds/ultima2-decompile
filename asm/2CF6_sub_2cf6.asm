# sub_2cf6 — mechanical clean (bulk wave); behavior not yet reviewed
# func 2CF6..2CFF  len 000A B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2cf6:
L_002ef6:
        clc
L_002ef7:
        mov    0x66,%al
L_002efa:
        adc    $0x1,%al
L_002efc:
        daa
L_002efd:
        mov    %al,0x66
