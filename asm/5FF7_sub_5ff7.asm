# sub_5ff7 — mechanical clean (bulk wave); behavior not yet reviewed
# func 5FF7..5FFF  len 0009 B  evidence: seed+reko
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_5ff7:
L_0061f7:
        pop    %bp
L_0061f8:
        pop    %dx
L_0061f9:
        pop    %cx
L_0061fa:
        pop    %bx
L_0061fb:
        pop    %ax
L_0061fc:
        ret
L_0061fd:
        add    %al,(%bx,%si)
        db 0x00        # tail-pad
