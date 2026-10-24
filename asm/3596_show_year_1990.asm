# show_year_1990 — date-display branch for ANOS 1990 A.D. (time-period text)
# name-evidence: string 'ANOS: 1990 A.D.'; body is a dispatch chain, calendar-write not proven
# func 3596..35C0  len 002B B  evidence: reko
# strings: "ANOS: 1990 A.D."
# RENDERING GAP: this file's declared range also contains 'ANOS: 1423 B.C.' at file 0x03798,
#           which it renders as instructions — so the atlas sees that one only through the
#           str_out contract. The declared end (35C0) sits past a neighbouring era entry, which
#           is how a range can swallow a table. Listed in disasm/str-out-rendering-gap.tsv.
# calls: L_000c33, L_0051df (str_out)
# provenance: static
#           entry never appears in ExecutedInstructions of any of the 60 harvests; derived by tools/provenance_from_traces.py
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
set_year_1990:
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
