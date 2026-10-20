# str_out_at — string display at cursor position: stores DI/SI to DS:002E/002F then prints
# name-evidence: saves di/si to the cursor vars, tail-calls str_out_core; 27 call sites
# func 51EB..51FA  len 0010 B  evidence: seed+call+reko
# calls: L_0053fd
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
str_out_at:
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
