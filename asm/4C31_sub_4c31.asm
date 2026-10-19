# sub_4c31 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4C31..4C4F  len 001F B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4c31:
L_004e31:
        mov    %cs:0x48dc(%bx),%ax
L_004e36:
        mov    %ax,%es
L_004e38:
        mov    %cs:(%si),%ax
L_004e3b:
        xor    %ax,%es:(%di)
L_004e3e:
        mov    %cs:0x2(%si),%ax
L_004e42:
        xor    %ax,%es:0x2(%di)
L_004e46:
        add    $0x4,%si
L_004e49:
        add    $0x2,%bx
L_004e4c:
        dec    %dl
L_004e4e:
        jne L_004e31
