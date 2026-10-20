# sub_3795 — mechanical clean (bulk wave); behavior not yet reviewed
# func 3795..37A3  len 000F B  evidence: reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_3795:
L_003995:
        dec    %ax
L_003996:
        sbb    %cl,0x47(%bx,%di)
L_003999:
        dec    %si
L_00399a:
        dec    %cx
L_00399b:
        push   %sp
L_00399c:
        inc    %bp
L_00399d:
        and    %dl,0x4f(%si)
L_0039a0:
        push   %dx
L_0039a1:
        inc    %bx
L_0039a2:
        dec    %ax
        db 0x00        # tail-pad
