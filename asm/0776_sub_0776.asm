# sub_0776 — mechanical clean (bulk wave); behavior not yet reviewed
# func 0776..0795  len 0020 B  evidence: seed+reko
# calls: L_000996, L_00514d
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_0776:
L_000976:
        jmp L_000996
L_000978:
        dec    %ax
L_000979:
        sub    %cl,0x4e(%bx,%di)
L_00097c:
        push   %bx
L_00097d:
        inc    %bp
L_00097e:
        push   %dx
L_00097f:
        push   %sp
L_000980:
        and    %dl,0x4c(%bx,%si)
L_000983:
        inc    %cx
L_000984:
        pop    %cx
L_000985:
        inc    %bp
L_000986:
        push   %dx
L_000987:
        and    %al,0x49(%si)
L_00098a:
        push   %bx
L_00098b:
        dec    %bx
L_00098c:
        sub    %ax,(%bx,%si)
L_00098e:
        call L_00514d
L_000991:
        cmp    $0xff1b,%ax
L_000994:
        jne L_00098e
