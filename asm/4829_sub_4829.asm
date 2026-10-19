# sub_4829 — mechanical clean (bulk wave); behavior not yet reviewed
# func 4829..4836  len 000E B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_4829:
L_004a29:
        add    %cl,0x1f1e(%bp,%si)
L_004a2d:
        add    %cl,-0x7505(%bp,%di)
L_004a31:
        test   %si,-0x1800(%bp)
L_004a35:
        jle L_004a42
