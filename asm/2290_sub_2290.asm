# sub_2290 — mechanical clean (bulk wave); behavior not yet reviewed
# func 2290..22BE  len 002F B  evidence: seed+call+reko
# calls: L_0054ca
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2290:
L_002490:
        clc
L_002491:
        mov    0x49,%al
L_002494:
        adc    $0x30,%al
L_002496:
        mov    %al,%cs:0x22bb
L_00249a:
        mov    %al,%cs:0x22cd
L_00249e:
        mov    0x4a,%al
L_0024a1:
        adc    $0x30,%al
L_0024a3:
        mov    %al,%cs:0x22bc
L_0024a7:
        mov    %al,%cs:0x22ce
L_0024ab:
        mov    $0x27,%ah
L_0024ad:
        mov    $0x1000,%cx
L_0024b0:
        mov    0x472,%dx
L_0024b4:
        call L_0054ca
L_0024b7:
        dec    %bp
L_0024b8:
        inc    %cx
L_0024b9:
        push   %ax
L_0024ba:
        pop    %ax
L_0024bb:
        inc    %si
L_0024bc:
        inc    %si
L_0024bd:
        and    %ah,(%bx,%si)
