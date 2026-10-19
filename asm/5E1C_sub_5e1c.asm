# sub_5e1c — mechanical clean (bulk wave); behavior not yet reviewed
# func 5E1C..5E2F  len 0014 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5e1c:
L_00601c:
        mov    %cs:0x5da7,%ax
L_006020:
        sub    %cs:0x5da5,%ax
L_006025:
        mov    %ax,%cs:0x5da7
L_006029:
        cmp    %cs:0x5da1,%ax
L_00602e:
        ja L_00600f
