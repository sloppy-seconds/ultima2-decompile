# sub_2340 — mechanical clean (bulk wave); behavior not yet reviewed
# func 2340..2351  len 0012 B  evidence: seed+reko
# calls: L_0054ca
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2340:
L_002540:
        mov    $0x100,%cx
L_002543:
        lea    0x137,%dx
L_002547:
        call L_0054ca
L_00254a:
        dec    %bp
L_00254b:
        dec    %di
L_00254c:
        dec    %si
L_00254d:
        pop    %ax
L_00254e:
        inc    %si
L_00254f:
        inc    %si
L_002550:
        and    %ah,(%bx,%si)
