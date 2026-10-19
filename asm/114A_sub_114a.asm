# sub_114a — mechanical clean (bulk wave); behavior not yet reviewed
# func 114A..1150  len 0007 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_114a:
L_00134a:
        mov    %al,0x1d7(%di)
L_00134e:
        dec    %di
L_00134f:
        jns L_00134a
