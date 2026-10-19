# sub_5168 — mechanical clean (bulk wave); behavior not yet reviewed
# func 5168..5174  len 000D B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5168:
L_005368:
        push   %si
L_005369:
        add    %dh,-0x7600(%bx)
L_00536d:
        push   %ds
L_00536e:
        push   %di
L_00536f:
        add    %cl,-0x1705(%bp,%di)
L_005373:
        xor    %al,(%bx,%si)
