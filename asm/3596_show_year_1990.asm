# show_year_1990 — date-display branch for ANOS 1990 A.D. (time-period text)
# name-evidence: string 'ANOS: 1990 A.D.'; body is a dispatch chain, calendar-write not proven
# func 3596..35C0  len 002B B  evidence: reko
# strings: "ANOS: 1423 B.C.", "ANOS: 1990 A.D."
# calls: L_000c33, L_0051df (str_out)
# provenance: static
#           entry never appears in ExecutedInstructions of any of the 60 harvests; derived by tools/provenance_from_traces.py
# confidence: low (bytes proven by check_func.py)
# body corrected: 2026-10-28e -- evidence: the declared end (35C0) sits past a neighbouring era
#           entry, which is how a range can swallow a table: this fragment holds the tail of the
#           `call` whose opcode is at asm/3595, the whole string `ANOS: 1423 B.C.` (the message
#           this header used to declare a rendering gap), a jmp to the dispatcher, and only then
#           the 1990 entry it is named for. Every line before the 1990 call was string text
#           decoded as code. Re-cut from the NUL terminators and the dispatcher target, which
#           fix every boundary in the span. Found by tools/forced_keep_audit.py and
#           tools/str_out_audit.py.
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
set_year_1990:
L_003796:
        .byte 0x47, 0x1a   # tail of `call L_0051df` (stop-trunc) started at asm/3595
L_003798:
        db "ANOS: 1423 B.C.",0x00        # string
L_0037a8:
        jmp L_000c33           # return to dispatcher
L_0037ab:
        call L_0051df          # str_out — prints the inline string below
        db "ANOS: 1990 A.D.",0x00        # string
L_0037be:
        jmp L_000c33           # return to dispatcher
