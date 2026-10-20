# sub_3566 — mechanical clean (bulk wave); behavior not yet reviewed
# func 3566..3576  len 0011 B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_3566:
L_003766:
        ja L_003782
L_003768:
        inc    %cx
L_003769:
        dec    %si
L_00376a:
        dec    %di
L_00376b:
        push   %bx
L_00376c:
        cmp    (%bx,%si),%ah
L_00376e:
        dec    %sp
L_00376f:
        inc    %bp
L_003770:
        inc    %di
L_003771:
        inc    %bp
L_003772:
        dec    %si
L_003773:
        inc    %sp
L_003774:
        push   %bx
L_003775:
        and    %ax,(%bx,%si)
