# sub_52e7 — mechanical clean (bulk wave); behavior not yet reviewed
# func 52E7..52EE  len 0008 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_52e7:
L_0054e7:
        movb   $0x0,0x245(%si)
L_0054ec:
        dec    %si
L_0054ed:
        jns L_0054e7
