# sub_5b4d — mechanical clean (bulk wave); behavior not yet reviewed
# func 5B4D..5B5C  len 0010 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5b4d:
L_005d4d:
        mov    %al,0x272(%di)
L_005d51:
        inc    %di
L_005d52:
        incb   0x4
L_005d56:
        mov    0x4,%al
L_005d59:
        cmp    $0x14,%al
L_005d5b:
        jne L_005ce1
