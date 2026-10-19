# sub_07f3 — mechanical clean (bulk wave); behavior not yet reviewed
# func 07F3..0806  len 0014 B  evidence: seed+reko
# calls: L_0054ca
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_07f3:
L_0009f3:
        mov    $0x800,%cx
L_0009f6:
        mov    0x474,%dx
L_0009fa:
        mov    $0x27,%ah
L_0009fc:
        call L_0054ca
L_0009ff:
        dec    %bp
L_000a00:
        dec    %di
L_000a01:
        dec    %si
L_000a02:
        push   %bx
L_000a03:
        push   %sp
L_000a04:
        inc    %bp
L_000a05:
        push   %dx
L_000a06:
        push   %bx
