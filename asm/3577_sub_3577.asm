# sub_3577 — mechanical clean (bulk wave); behavior not yet reviewed
# func 3577..3581  len 000B B  evidence: seed+reko
# strings: "ANOS:"
# calls: L_000c33, L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# body corrected: 2026-10-28e -- evidence: era-table entry three of five at asm/3546, the same
#           `call str_out / db text / jmp dispatcher` shape. The four mnemonics after the call
#           were the first five bytes of `ANOS: 9,000,000 B.C.` read as code, and the
#           forced-keep at 3581 (`cmp (%bx,%si),%ah`) was the `3a` of "ANOS:" — the string
#           continues at asm/3582 because the map boundary falls in the middle of it. Found by
#           tools/forced_keep_audit.py and tools/str_out_audit.py.
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_3577:
L_003777:
        jmp L_000c33
L_00377a:
        call L_0051df          # str_out — prints the inline string below
L_00377d:
        db "ANOS:"        # first half; ` 9,000,000 B.C.` and the NUL are at asm/3582
