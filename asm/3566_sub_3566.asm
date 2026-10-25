# sub_3566 — mechanical clean (bulk wave); behavior not yet reviewed
# func 3566..3576  len 0011 B  evidence: reko
# strings: "ANOS: LEGENDS!"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# body corrected: 2026-10-28e -- evidence: this is the second of five era-table entries at
#           asm/3546, and the table is `call str_out / db text / jmp dispatcher` with no
#           padding. The map boundary cut the `call` at asm/3565 after its opcode, so this
#           fragment opened on `77 1a` decoded as `ja`, and every line after it was the string
#           `ANOS: LEGENDS!` read as code. Re-cut from the call target (file 004FDF, str_out)
#           and the NUL terminator, which fix both ends exactly. Found by
#           tools/forced_keep_audit.py and tools/str_out_audit.py.
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_3566:
L_003766:
        .byte 0x77, 0x1a   # tail of `call L_0051df` (stop-trunc) started at asm/3565
L_003768:
        db "ANOS: LEGENDS!",0x00        # string
