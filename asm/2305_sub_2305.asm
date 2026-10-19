# sub_2305 — mechanical clean (bulk wave); behavior not yet reviewed
# func 2305..233F  len 003B B  evidence: seed+reko
# calls: L_0054ca
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_2305:
L_002505:
        clc
L_002506:
        mov    0x49,%al
L_002509:
        adc    $0x30,%al
L_00250b:
        mov    %al,%cs:0x233c
L_00250f:
        mov    %al,%cs:0x234e
L_002513:
        mov    0x4a,%al
L_002516:
        adc    $0x30,%al
L_002518:
        mov    %al,%cs:0x233d
L_00251c:
        mov    %al,%cs:0x234f
L_002520:
        mov    0x0,%al
L_002523:
        mov    %al,0x5a
L_002526:
        mov    0x1,%al
L_002529:
        mov    %al,0x5b
L_00252c:
        mov    $0x28,%ah
L_00252e:
        mov    $0x1000,%cx
L_002531:
        mov    0x472,%dx
L_002535:
        call L_0054ca
L_002538:
        dec    %bp
L_002539:
        inc    %cx
L_00253a:
        push   %ax
L_00253b:
        pop    %ax
L_00253c:
        inc    %si
L_00253d:
        inc    %si
L_00253e:
        and    %ah,(%bx,%si)
