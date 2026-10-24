# sub_02a3 — mechanical clean (bulk wave); behavior not yet reviewed
# func 02A3..02CA  len 0028 B  evidence: reko
# RENDERING GAP: prints '(C)-1983,1989 BY LORD BRITISH' at file 0x004AD, but these bytes are
#           rendered as instructions, so the atlas knows the message only from the str_out
#           calling convention. Listed in disasm/str-out-rendering-gap.tsv; the fix is a body
#           edit, which engine/tests/asm_body_guard.py forbids — see disasm/defects.md.
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_02a3:
L_0004a3:
        das
L_0004a4:
        add    %dh,-0x5dfa(%bx,%si)
L_0004a8:
        cs add %ch,%al
L_0004ab:
        xor    0x28(%di),%cl
L_0004ae:
        inc    %bx
L_0004af:
        sub    %bp,(%di)
L_0004b1:
        xor    %di,(%bx,%di)
L_0004b3:
        cmp    %dh,(%bp,%di)
L_0004b5:
        sub    $0x31,%al
L_0004b7:
        cmp    %di,(%bx,%si)
L_0004b9:
        cmp    %sp,(%bx,%si)
L_0004bb:
        inc    %dx
L_0004bc:
        pop    %cx
L_0004bd:
        and    %cl,0x4f(%si)
L_0004c0:
        push   %dx
L_0004c1:
        inc    %sp
L_0004c2:
        and    %al,0x52(%bp,%si)
L_0004c5:
        dec    %cx
L_0004c6:
        push   %sp
L_0004c7:
        dec    %cx
L_0004c8:
        push   %bx
L_0004c9:
        dec    %ax
        db 0x00        # tail-pad
