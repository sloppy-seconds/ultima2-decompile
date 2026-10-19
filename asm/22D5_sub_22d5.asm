# sub_22d5 — mechanical clean (bulk wave); behavior not yet reviewed
# func 22D5..22FB  len 0027 B  evidence: seed+call+reko
# calls: L_0054ca
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_22d5:
L_0024d5:
        clc
L_0024d6:
        mov    0x49,%al
L_0024d9:
        adc    $0x30,%al
L_0024db:
        mov    %al,%cs:0x22f8
L_0024df:
        mov    0x4a,%al
L_0024e2:
        adc    $0x30,%al
L_0024e4:
        mov    %al,%cs:0x22f9
L_0024e8:
        mov    $0x27,%ah
L_0024ea:
        mov    $0x100,%cx
L_0024ed:
        mov    0x476,%dx
L_0024f1:
        call L_0054ca
L_0024f4:
        push   %sp
L_0024f5:
        dec    %sp
L_0024f6:
        dec    %bx
L_0024f7:
        pop    %ax
L_0024f8:
        inc    %si
L_0024f9:
        inc    %si
L_0024fa:
        and    %ah,(%bx,%si)
