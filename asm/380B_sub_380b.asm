# sub_380b — mechanical clean (bulk wave); behavior not yet reviewed
# func 380B..3811  len 0007 B  evidence: reko
# strings: "AT?"
# calls: L_000c33
# confidence: low (bytes proven by check_func.py)
# body corrected: 2026-10-28e -- evidence: the tail of the `-WHAT?` reject echo whose first
#           three bytes are at asm/37F2, then the dispatcher jmp. The four mnemonics this file
#           showed were `AT?` and the NUL read as code. Found by tools/forced_keep_audit.py and
#           tools/str_out_audit.py.
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_380b:
L_003a0b:
        db "AT?",0x00        # string; `-WH` is at asm/37F2
L_003a0f:
        jmp L_000c33           # return to dispatcher
