# sub_4778 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4778..4785  len 000E B  evidence: reko
# calls: L_0055b5
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4778:
L_004978:
        add    %cl,0x1f1e(%bp,%si)
L_00497c:
        add    %cl,-0x7505(%bp,%di)
L_004980:
        test   %si,0x0(%bp)
L_004983:
        call L_0055b5
