# klimb_what_msg — the second half of KLIMB's refusal, and its return
# name-evidence: `AT?` completes the `-WHAT?` that asm/37F2 starts with `-WH`, then jumps to
#           cmd_done. One message across a fragment boundary, which is why the extractor cannot
#           express it as a single run and the engine prints the byte-identical DESCEND copy
#           instead — see the note in engine/tools/extract/extractor.py.
# func 380B..3811  len 0007 B  evidence: reko; role read from the bytes 2026-10-29
# provenance: static — the tail of the `-WHAT?` that asm/37F2 starts, decoded 2026-10-29
#           alongside cmd_K. Not yet observed executing in a harvest.
# strings: "AT?"
# calls: L_000c33
# confidence: high (role read directly off the bytes, 2026-10-29)
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
