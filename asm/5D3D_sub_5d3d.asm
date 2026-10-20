# sub_5d3d — mechanical clean (bulk wave); behavior not yet reviewed
# func 5D3D..5D4F  len 0013 B  evidence: seed+reko
# calls: L_005eb2, L_005ee4
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5d3d:
L_005f3d:
        call L_005ee4
L_005f40:
        mov    0x58c,%ax
L_005f43:
        dec    %ax
L_005f44:
        jns L_005f43
L_005f46:
        dec    %cx
L_005f47:
        jne L_005f40
L_005f49:
        mov    %cs:0x4(%bp),%bx
L_005f4d:
        call L_005eb2
