# sub_3596 — mechanical clean (bulk wave); behavior not yet reviewed
# func 3596..35C0  len 002B B  evidence: reko
# strings: "ANOS: 1990 A.D."
# calls: L_000c33, L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_3596:
L_003796:
        inc    %di
L_003797:
        sbb    0x4e(%bx,%di),%al
L_00379a:
        dec    %di
L_00379b:
        push   %bx
L_00379c:
        cmp    (%bx,%si),%ah
L_00379e:
        xor    %si,(%si)
L_0037a0:
        xor    (%bp,%di),%dh
L_0037a2:
        and    %al,0x2e(%bp,%si)
L_0037a5:
        inc    %bx
L_0037a6:
        cs add %ch,%cl
L_0037a9:
        mov    %dl,%ah
L_0037ab:
        call L_0051df
        db "ANOS: 1990 A.D.",0x00        # string
L_0037be:
        jmp L_000c33
