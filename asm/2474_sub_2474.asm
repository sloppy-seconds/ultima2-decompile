# sub_2474 — mechanical clean (bulk wave); behavior not yet reviewed
# func 2474..2487  len 0014 B  evidence: seed+reko
# calls: L_0054ca
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2474:
L_002674:
        mov    $0x28,%ah
L_002676:
        mov    $0x100,%cx
L_002679:
        lea    0x36,%dx
L_00267d:
        call L_0054ca
L_002680:
        push   %ax
L_002681:
        dec    %sp
L_002682:
        inc    %cx
L_002683:
        pop    %cx
L_002684:
        inc    %bp
L_002685:
        push   %dx
L_002686:
        and    %ah,(%bx,%si)
