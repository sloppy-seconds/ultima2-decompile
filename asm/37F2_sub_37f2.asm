# sub_37f2 — mechanical clean (bulk wave); behavior not yet reviewed
# func 37F2..380A  len 0019 B  evidence: reko
# strings: "KLIMB", "-WH"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
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
