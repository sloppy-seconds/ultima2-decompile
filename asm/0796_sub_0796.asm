# sub_0796 — mechanical clean (bulk wave); behavior not yet reviewed
# func 0796..07A9  len 0014 B  evidence: seed+reko
# calls: L_0054ca
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0796:
L_000996:
        mov    $0x100,%cx
L_000999:
        lea    0x36,%dx
L_00099d:
        mov    $0x27,%ah
L_00099f:
        call L_0054ca
L_0009a2:
        push   %ax
L_0009a3:
        dec    %sp
L_0009a4:
        inc    %cx
L_0009a5:
        pop    %cx
L_0009a6:
        inc    %bp
L_0009a7:
        push   %dx
L_0009a8:
        and    %ah,(%bx,%si)
