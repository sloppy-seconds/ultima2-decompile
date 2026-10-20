# show_year_2112 — date-display branch for ANOS 2112 A.D. (time-period text)
# name-evidence: string 'ANOS: 2112 A.D.'; body is a dispatch chain, calendar-write not proven
# func 3546..3564  len 001F B  evidence: seed+reko
# strings: "ANOS: 2112 A.D."
# calls: L_000c33, L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
set_year_2112:
L_003746:
        dec    %di
L_003747:
        je L_00377a
L_003749:
        dec    %di
L_00374a:
        je L_003795
L_00374c:
        dec    %di
L_00374d:
        je L_0037ab
L_00374f:
        call L_0051df
        db "ANOS: 2112 A.D.",0x00        # string
L_003762:
        jmp L_000c33
