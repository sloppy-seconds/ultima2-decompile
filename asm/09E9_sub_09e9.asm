# sub_09e9 — mechanical clean (bulk wave); behavior not yet reviewed
# func 09E9..09F3  len 000B B  evidence: seed+reko
# calls: L_000c33
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_09e9:
L_000be9:
        mov    0x26,%al
L_000bec:
        xor    $0xff,%al
L_000bee:
        mov    %al,0x26
L_000bf1:
        jmp L_000c33
L_000bf3:
        nop
