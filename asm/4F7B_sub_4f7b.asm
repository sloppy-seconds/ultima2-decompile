# sub_4f7b — mechanical clean (bulk wave); behavior not yet reviewed
# func 4F7B..4F84  len 000A B  evidence: seed+reko
# calls: L_0051dd
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4f7b:
L_00517b:
        xorb   $0xff,0x54d
L_005180:
        mov    $0x0,%ah
L_005182:
        jmp L_0051dd
L_005184:
        nop
