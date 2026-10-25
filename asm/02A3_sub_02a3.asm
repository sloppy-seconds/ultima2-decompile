# sub_02a3 — mechanical clean (bulk wave); behavior not yet reviewed
# func 02A3..02CA  len 0028 B  evidence: reko
# strings: "(C)-1983,1989 BY LORD BRITISH"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# body corrected: 2026-10-28e -- evidence: bytes 02A3..02A4 are `2f 00`, the tail of
#           `mov %al,0x2f` whose opcode 0xa2 is the forced-keep at asm/02A0. The mnemonics this
#           file opened with (das, add %dh,-0x5dfa(%bx,%si), cs add %ch,%al) were those two
#           bytes plus the real code after them decoded from the wrong offset, and the twenty
#           lines after that were the inline string `(C)-1983,1989 BY LORD BRITISH` decoded as
#           code — the rendering gap this header used to declare. Re-cut from the str_out
#           calling convention at 02AA, which prints the bytes immediately below it. Found by
#           tools/forced_keep_audit.py and tools/str_out_audit.py.
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_02a3:
L_0004a3:
        .byte 0x2f, 0x00   # tail of `mov %al,0x2f` (moffs `a2 2f 00`) started at asm/02A0
L_0004a5:
        mov    $0x6,%al
L_0004a7:
        .byte 0xa2, 0x2e, 0x00   # forced-kept: gas re-encodes 'mov %al,0x2e' differently
L_0004aa:
        call L_0051df          # str_out — prints the inline string below
        db "(C)-1983,1989 BY LORD BRITISH",0x00        # string
