# sub_2352 — mechanical clean (bulk wave); behavior not yet reviewed
# func 2352..2360  len 000F B  evidence: seed+reko
# calls: L_0054ca
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2352:
L_002552:
        lea    0x36,%dx
L_002556:
        call L_0054ca
L_002559:
        push   %ax
L_00255a:
        dec    %sp
L_00255b:
        inc    %cx
L_00255c:
        pop    %cx
L_00255d:
        inc    %bp
L_00255e:
        push   %dx
L_00255f:
        and    %ah,(%bx,%si)
