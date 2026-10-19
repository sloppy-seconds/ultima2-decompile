# sub_22bf — mechanical clean (bulk wave); behavior not yet reviewed
# func 22BF..22D0  len 0012 B  evidence: seed+reko
# calls: L_0054ca
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_22bf:
L_0024bf:
        mov    $0x100,%cx
L_0024c2:
        lea    0x137,%dx
L_0024c6:
        call L_0054ca
L_0024c9:
        dec    %bp
L_0024ca:
        dec    %di
L_0024cb:
        dec    %si
L_0024cc:
        pop    %ax
L_0024cd:
        inc    %si
L_0024ce:
        inc    %si
L_0024cf:
        and    %ah,(%bx,%si)
