# sub_4282 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4282..428D  len 000C B  evidence: reko
# calls: L_002252
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4282:
L_004482:
        push   %ax
L_004483:
        mov    %al,0x28
L_004486:
        mov    $0x0,%al
L_004488:
        mov    %al,0x27
L_00448b:
        call L_002252
