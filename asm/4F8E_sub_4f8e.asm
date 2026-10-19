# sub_4f8e — mechanical clean (bulk wave); behavior not yet reviewed
# func 4F8E..4F9F  len 0012 B  evidence: seed+reko
# calls: L_0051b3
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4f8e:
L_00518e:
        mov    0x74,%ax
L_005191:
        sub    $0x200,%ax
L_005194:
        cmp    0x554,%ax
L_005198:
        jb L_0051b6
L_00519a:
        mov    %ax,0x74
L_00519d:
        jmp L_0051b3
L_00519f:
        nop
