# sub_0a7c — sweep gate, first clause: if DS:13 != 0x22 the creature gets its turn.
#           DS:13 == 0x22 is the riding state for a horse: asm/2FD6_vehicle_horse stores
#           0x22 into DS:13, and [DS:13] was measured live as 0x22 on a horse and 0x26 in
#           the plane (asm/2FAD_vehicle_board_dispatch). So this clause is "on foot, go".
# func 0A7C..0A82  len 0007 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0a7c:
L_000c7c:
        mov    0x13,%al
L_000c7f:
        cmp    $0x22,%al
L_000c81:
        jne L_000ca7
