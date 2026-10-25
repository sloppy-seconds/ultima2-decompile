# sub_464e — mechanical clean (bulk wave); behavior not yet reviewed
# func 464E..4656  len 0009 B  evidence: reko
# strings: "SPELL-"
# calls: L_0051df (str_out)
# confidence: low (bytes proven by check_func.py)
# body corrected: 2026-10-28e -- evidence: the ordinary inline-string shape again, with the call
#           cut after its opcode at asm/464D. The whole file was `SPELL-` and the two operand
#           bytes of that call; the `(bad)` forced-keep was objdump having no mnemonic for the
#           first byte of the string, not an undecodable instruction. Re-cut from the call target
#           (file 0051DF, str_out) and the NUL terminator. Found by tools/forced_keep_audit.py and
#           tools/str_out_audit.py.
# bulk wave: L_<addr> labels kept as cross-reference anchors (CP3)
sub_464e:
L_00484e:
        .byte 0x8f, 0x09   # tail of `call L_0051df` (stop-trunc) started at asm/464D
L_004850:
        db "SPELL-",0x00        # string
