# sub_020f — mechanical clean (bulk wave); behavior not yet reviewed
# func 020F..0221  len 0013 B  evidence: seed+reko
# calls: L_0054ca
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_020f:
L_00040f:
        mov    $0x27,%ah
L_000411:
        mov    $0x4000,%cx
L_000414:
        mov    $0x0,%dx
L_000417:
        call L_0054ca
L_00041a:
        push   %ax
L_00041b:
        dec    %cx
L_00041c:
        inc    %bx
L_00041d:
        inc    %sp
L_00041e:
        push   %dx
L_00041f:
        inc    %cx
L_000420:
        and    %ah,(%bx,%si)
