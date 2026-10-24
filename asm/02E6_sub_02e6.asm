# sub_02e6 — mechanical clean (bulk wave); behavior not yet reviewed
# func 02E6..02F6  len 0011 B  evidence: reko
# RENDERING GAP: prints 'TYPE -' at file 0x004F0, but these bytes are rendered as instructions,
#           so the atlas knows the message only from the str_out calling convention. Listed in
#           disasm/str-out-rendering-gap.tsv; the fix is a body edit, which
#           engine/tests/asm_body_guard.py forbids — see disasm/defects.md.
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_02e6:
L_0004e6:
        das
L_0004e7:
        add    %dh,-0x5dfb(%bx,%si)
L_0004eb:
        cs add %ch,%al
L_0004ee:
        out    %ax,(%dx)
L_0004ef:
        dec    %sp
L_0004f0:
        push   %sp
L_0004f1:
        pop    %cx
L_0004f2:
        push   %ax
L_0004f3:
        inc    %bp
L_0004f4:
        and    %ch,(%di)
        db 0x00        # tail-pad
