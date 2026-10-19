# sub_2dee — mechanical clean (bulk wave); behavior not yet reviewed
# func 2DEE..2E05  len 0018 B  evidence: seed+reko
# calls: L_00543e
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2dee:
L_002fee:
        clc
L_002fef:
        mov    0x57,%al
L_002ff2:
        adc    0x1f,%al
L_002ff6:
        daa
L_002ff7:
        mov    %al,0x57
L_002ffa:
        mov    0x56,%al
L_002ffd:
        adc    $0x0,%al
L_002fff:
        daa
L_003000:
        mov    %al,0x56
L_003003:
        call L_00543e
