# sub_51eb — mechanical clean (bulk wave); behavior not yet reviewed
# func 51EB..51FA  len 0010 B  evidence: seed+call+reko
# calls: L_0053fd
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_51eb:
L_0053eb:
        push   %bx
L_0053ec:
        .byte 0x8b,0xdf  # forced-kept: gas re-encodes 'mov    %di,%bx' differently
L_0053ee:
        mov    %bl,0x2e
L_0053f2:
        .byte 0x8b,0xde  # forced-kept: gas re-encodes 'mov    %si,%bx' differently
L_0053f4:
        mov    %bl,0x2f
L_0053f8:
        call L_0053fd
