# sub_5df3 — mechanical clean (bulk wave); behavior not yet reviewed
# func 5DF3..5E06  len 0014 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5df3:
L_005ff3:
        mov    %cs:0x5da7,%ax
L_005ff7:
        add    %cs:0x5da5,%ax
L_005ffc:
        mov    %ax,%cs:0x5da7
L_006000:
        cmp    %cs:0x5da3,%ax
L_006005:
        jb L_005fe6
