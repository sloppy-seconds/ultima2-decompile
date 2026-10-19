# sub_0100 — mechanical clean (bulk wave); behavior not yet reviewed
# func 0100..0132  len 0033 B  evidence: seed+call+reko
# calls: L_004c1c
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0100:
L_000300:
        mov    $0x741,%ax
L_000303:
        mov    %ax,%ds
L_000305:
        add    $0x310,%ax
L_000308:
        mov    %ax,%ss
L_00030a:
        mov    $0x100,%sp
L_00030d:
        mov    $0x40,%ax
L_000310:
        mov    %ax,%es
L_000312:
        mov    %es:0x6c,%al
L_000316:
        mov    %al,0x23f
L_000319:
        mov    %al,0x240
L_00031c:
        mov    %al,0x241
L_00031f:
        mov    %al,0x242
L_000322:
        mov    %al,0x243
L_000325:
        mov    %al,0x244
L_000328:
        incb   0x23f
L_00032c:
        incb   0x240
L_000330:
        call L_004c1c
