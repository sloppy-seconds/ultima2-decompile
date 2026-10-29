# klimb_msg — cmd_K's message, its site-kind gate, and the first half of its refusal
# name-evidence: the continuation of asm/37F1 cmd_K, cut by the Phase 2 map after the call
#           opcode. Owns `KLIMB`, then the kind test (4 or 5 or refuse), then the `-WH` half of
#           `-WHAT?` — the string straddles into asm/380B, which owns `AT?`. asm/3812 jumps back
#           to L_003a05 to reuse this refusal when the cell has no up-ladder feature, so the
#           message is reached by jump as well as by fall-through.
# func 37F2..380A  len 0019 B  evidence: reko; role read from the bytes 2026-10-29
# provenance: static — bytes read from asm/37F1's call target and the kind compares here,
#           decoded 2026-10-29 alongside cmd_K. Not yet observed executing in a harvest.
# strings: "KLIMB", "-WH"
# calls: L_0051df (str_out)
# confidence: high (handler role and gate read directly off the bytes, 2026-10-29)
# body corrected: 2026-10-28e -- evidence: cmd_K is two inline-string sites and a two-way test,
#           and the map cut both calls after their opcodes (asm/37F1, and the `e8` at 3805 kept
#           here). The five mnemonics after the first call were `KLIMB` read as code, and the
#           four-byte forced-keep at 37F9 was its NUL plus the real `movb 0x4a,%al` — gas does
#           encode that one as `a0 4a 00`, so it is now a mnemonic rather than a keep. `-WHAT?`
#           straddles the next boundary: this fragment owns `-WH`, asm/380B owns `AT?`. Found by
#           tools/forced_keep_audit.py and tools/str_out_audit.py.
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_37f2:
L_0039f2:
        .byte 0xeb, 0x17   # tail of `call L_0051df` (stop-trunc) started at asm/37F1
L_0039f4:
        db "KLIMB",0x00        # string
L_0039fa:
        movb   0x4a,%al
L_0039fd:
        cmp    $0x5,%al
L_0039ff:
        je L_003a12
L_003a01:
        cmp    $0x4,%al
L_003a03:
        je L_003a12
L_003a05:
        call L_0051df          # str_out — prints the inline string below
L_003a08:
        db "-WH"        # first half; `AT?` and the NUL are at asm/380B
