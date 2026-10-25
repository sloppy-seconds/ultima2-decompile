# sub_02e6 — mechanical clean (bulk wave); behavior not yet reviewed
# func 02E6..02F6  len 0011 B  evidence: reko
# strings: "TYPE -"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# body corrected: 2026-10-28e -- evidence: bytes 02E6..02E7 are `2f 00`, the tail of
#           `mov %al,0x2f` whose opcode 0xa2 is the forced-keep at asm/02E3. The mnemonics this
#           file opened with (das, add %dh,-0x5dfb(%bx,%si), cs add %ch,%al, out %ax,(%dx))
#           were those two bytes plus the real code after them decoded from the wrong offset,
#           and the lines after that were the inline string `TYPE -` decoded as code — the
#           rendering gap this header used to declare. Re-cut from the str_out calling
#           convention at 02ED, which prints the bytes immediately below it. Found by
#           tools/forced_keep_audit.py and tools/str_out_audit.py.
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_02e6:
L_0004e6:
        .byte 0x2f, 0x00   # tail of `mov %al,0x2f` (moffs `a2 2f 00`) started at asm/02E3
L_0004e8:
        mov    $0x5,%al
L_0004ea:
        .byte 0xa2, 0x2e, 0x00   # forced-kept: gas re-encodes 'mov %al,0x2e' differently
L_0004ed:
        call L_0051df          # str_out — prints the inline string below
        db "TYPE -",0x00        # string
